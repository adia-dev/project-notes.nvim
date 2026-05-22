local M = {}

local notes_dir = vim.fn.stdpath("data") .. "/project-notes"
local signs_ns = vim.api.nvim_create_namespace("project-notes.nvim")

local function is_notes_path(path)
	return path ~= "" and path:sub(1, #notes_dir + 1) == notes_dir .. "/" and path:sub(-3) == ".md"
end

local function current_notes_path(bufnr)
	local path = vim.api.nvim_buf_get_name(bufnr or 0)
	if is_notes_path(path) then
		return path
	end
end

local function project_root(bufnr)
	bufnr = bufnr or 0
	local name = vim.api.nvim_buf_get_name(bufnr)
	local start = name ~= "" and vim.fs.dirname(name) or vim.uv.cwd()

	return vim.fs.root(start, { ".git" }) or start
end

local function display_path(path)
	local home = vim.uv.os_homedir()
	if path:sub(1, #home) == home then
		return "~" .. path:sub(#home + 1)
	end

	return path
end

local function notes_path(bufnr)
	local current = current_notes_path(bufnr)
	if current then
		return current, notes_dir
	end

	local root = project_root(bufnr)
	local name = vim.fs.basename(root) or "project"
	local slug = name:gsub("[^%w%._%-]+", "-")
	local hash = vim.fn.sha256(root):sub(1, 8)

	return notes_dir .. "/" .. slug .. "-" .. hash .. ".md", root
end

local function ensure_notes_file()
	vim.fn.mkdir(notes_dir, "p")

	local path, root = notes_path()
	if vim.fn.filereadable(path) == 0 then
		vim.fn.writefile({
			"# " .. (vim.fs.basename(root) or "Project") .. " Notes",
			"",
			"Project: `" .. display_path(root) .. "`",
			"",
			"## Notes",
			"",
			"## Todo",
			"",
		}, path)
	end

	return path
end

local function current_context(start_line, end_line)
	if is_notes_path(vim.api.nvim_buf_get_name(0)) then
		return nil
	end

	local path = vim.fn.expand("%")
	if path == "" then
		return nil
	end

	start_line = start_line or vim.fn.line(".")
	end_line = end_line or start_line

	if start_line == end_line then
		return path .. ":" .. start_line
	end

	return path .. ":" .. start_line .. "-" .. end_line
end

local function append_to_section(section, item)
	local path = ensure_notes_file()
	local lines = vim.fn.readfile(path)
	local header = "## " .. section
	local header_idx
	local items = type(item) == "table" and item or { item }

	for i, line in ipairs(lines) do
		if line == header then
			header_idx = i
			break
		end
	end

	if not header_idx then
		table.insert(lines, "")
		table.insert(lines, header)
		header_idx = #lines
	end

	for i, line in ipairs(items) do
		table.insert(lines, header_idx + i, line)
	end
	vim.fn.writefile(lines, path)
	if M.refresh_all then
		M.refresh_all()
	end
	vim.notify("Captured in " .. vim.fn.fnamemodify(path, ":t"), vim.log.levels.INFO)
end

local function selected_lines()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local start_line = start_pos[2]
	local end_line = end_pos[2]

	if start_line > end_line then
		start_line, end_line = end_line, start_line
	end

	local mode = vim.fn.visualmode()
	if mode == "" then
		mode = "v"
	end

	local ok, lines = pcall(vim.fn.getregion, start_pos, end_pos, { type = mode })
	if ok then
		return lines, start_line, end_line
	end

	return vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false), start_line, end_line
end

local function parse_ref(ref)
	local ref_path, start_line, end_line = ref:match("^(.*):(%d+)%-(%d+)$")
	if ref_path then
		return ref_path, tonumber(start_line), tonumber(end_line)
	end

	ref_path, start_line = ref:match("^(.*):(%d+)$")
	if ref_path then
		return ref_path, tonumber(start_line), tonumber(start_line)
	end
end

local function normalize_ref_path(path, root)
	path = vim.fn.expand(path)

	if path:sub(1, 1) == "/" then
		return vim.fs.normalize(path)
	end

	return vim.fs.normalize(root .. "/" .. path)
end

local function clean_entry_text(line)
	return line:gsub("^%s*%- %[[ xX]%]%s*", ""):gsub("^%s*%- %s*", ""):gsub("%s*%(`[^`]+`%)", "")
end

local function note_index(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local buf_name = vim.api.nvim_buf_get_name(bufnr)
	if buf_name == "" or is_notes_path(buf_name) then
		return { by_line = {}, entries = {}, notes_path = nil }
	end

	local path, root = notes_path(bufnr)
	if vim.fn.filereadable(path) == 0 then
		return { by_line = {}, entries = {}, notes_path = path }
	end

	local buf_path = vim.fs.normalize(buf_name)
	local buf_line_count = vim.api.nvim_buf_line_count(bufnr)
	local lines = vim.fn.readfile(path)
	local section = "Notes"
	local by_line = {}
	local entries = {}

	for note_lnum, line in ipairs(lines) do
		local header = line:match("^##%s+(.+)$")
		if header then
			section = header
		end

		for ref in line:gmatch("`([^`]+:%d+%-?%d*)`") do
			local ref_path, start_line, end_line = parse_ref(ref)
			if ref_path and normalize_ref_path(ref_path, root) == buf_path then
				local entry = {
					kind = section == "Todo" and "todo" or "note",
					text = clean_entry_text(line),
					note_lnum = note_lnum,
					start_line = start_line,
					end_line = end_line,
					ref = ref,
					notes_path = path,
				}

				table.insert(entries, entry)
				for lnum = math.max(1, start_line), math.min(end_line, buf_line_count) do
					by_line[lnum] = by_line[lnum] or {}
					table.insert(by_line[lnum], entry)
				end
			end
		end
	end

	return { by_line = by_line, entries = entries, notes_path = path }
end

local function notes_file_root(path, fallback)
	if vim.fn.filereadable(path) == 0 then
		return fallback
	end

	for _, line in ipairs(vim.fn.readfile(path, "", 20)) do
		local root = line:match("^Project:%s+`(.+)`")
		if root then
			return vim.fn.expand(root)
		end
	end

	return fallback
end

local function project_note_entries(bufnr)
	local path, root = notes_path(bufnr)
	root = notes_file_root(path, root)

	if vim.fn.filereadable(path) == 0 then
		return {}, path
	end

	local section = "Notes"
	local in_fence = false
	local entries = {}

	for note_lnum, line in ipairs(vim.fn.readfile(path)) do
		if line:match("^```") then
			in_fence = not in_fence
		end

		local header = line:match("^##%s+(.+)$")
		if header and not in_fence then
			section = header
		end

		if not in_fence and line:match("^%s*%-") then
			local ref = line:match("`([^`]+:%d+%-?%d*)`")
			local ref_path, start_line, end_line
			if ref then
				ref_path, start_line, end_line = parse_ref(ref)
			end

			table.insert(entries, {
				kind = section == "Todo" and "todo" or "note",
				text = clean_entry_text(line),
				note_lnum = note_lnum,
				ref = ref,
				notes_path = path,
				target_path = ref_path and normalize_ref_path(ref_path, root) or nil,
				start_line = start_line,
				end_line = end_line,
			})
		end
	end

	return entries, path
end

local function noted_lines(bufnr)
	local index = note_index(bufnr)
	local lines = {}

	for lnum in pairs(index.by_line) do
		table.insert(lines, lnum)
	end
	table.sort(lines)

	return lines
end

local function fenced_preview(lines)
	if not lines or #lines == 0 or is_notes_path(vim.api.nvim_buf_get_name(0)) then
		return {}
	end

	local preview = { "```" .. vim.bo.filetype }
	vim.list_extend(preview, lines)
	table.insert(preview, "```")
	table.insert(preview, "")

	return preview
end

local function capture_item(prefix, input, start_line, end_line, preview_lines)
	local item = { prefix .. input }
	local context = current_context(start_line, end_line)
	if context then
		item[1] = item[1] .. " (`" .. context .. "`)"
	end

	vim.list_extend(item, fenced_preview(preview_lines))

	return item
end

local function capture(section, prompt, prefix)
	vim.ui.input({ prompt = prompt }, function(input)
		if not input or input == "" then
			return
		end

		append_to_section(
			section,
			capture_item(prefix, input, vim.fn.line("."), vim.fn.line("."), {
				vim.api.nvim_get_current_line(),
			})
		)
	end)
end

local function capture_selection(section, prompt, prefix, fallback_title)
	local lines, start_line, end_line = selected_lines()
	if #lines == 0 then
		return
	end

	vim.ui.input({ prompt = prompt }, function(input)
		if input == nil then
			return
		end

		local title = input ~= "" and input or fallback_title
		append_to_section(section, capture_item(prefix, title, start_line, end_line, lines))
	end)
end

function M.open()
	vim.cmd.edit(vim.fn.fnameescape(ensure_notes_file()))
end

function M.close()
	local current_name = vim.api.nvim_buf_get_name(0)
	local target = is_notes_path(current_name) and current_name or notes_path()
	local wins = vim.api.nvim_tabpage_list_wins(0)

	for _, win in ipairs(wins) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.api.nvim_buf_get_name(buf) == target then
			if vim.bo[buf].modified then
				vim.api.nvim_buf_call(buf, function()
					vim.cmd.write()
				end)
			end

			if #wins > 1 then
				vim.api.nvim_win_close(win, false)
			else
				vim.api.nvim_buf_delete(buf, {})
			end
			return
		end
	end

	vim.notify("Project notes are not open", vim.log.levels.INFO)
end

function M.note()
	capture("Notes", "Note: ", "- ")
end

function M.todo()
	capture("Todo", "Todo: ", "- [ ] ")
end

function M.selection_note()
	capture_selection("Notes", "Selection note: ", "- ", "Selection")
end

function M.selection_todo()
	capture_selection("Todo", "Selection todo: ", "- [ ] ", "Selection")
end

function M.copy_path()
	local path = ensure_notes_file()
	vim.fn.setreg("+", path)
	vim.notify("Copied project notes path", vim.log.levels.INFO)
end

function M.refresh(bufnr, skip_redraw)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_loaded(bufnr) then
		return
	end

	vim.api.nvim_buf_clear_namespace(bufnr, signs_ns, 0, -1)

	local index = note_index(bufnr)
	local todo_count = 0
	for _, entry in ipairs(index.entries) do
		if entry.kind == "todo" then
			todo_count = todo_count + 1
		end
	end

	vim.b[bufnr].project_notes_count = #index.entries
	vim.b[bufnr].project_notes_todo_count = todo_count

	for lnum, entries in pairs(index.by_line) do
		local has_todo = false
		for _, entry in ipairs(entries) do
			if entry.kind == "todo" then
				has_todo = true
				break
			end
		end

		vim.api.nvim_buf_set_extmark(bufnr, signs_ns, lnum - 1, 0, {
			sign_text = has_todo and "T" or "N",
			sign_hl_group = has_todo and "ProjectNotesTodoSign" or "ProjectNotesSign",
			priority = 20,
		})
	end

	if not skip_redraw then
		pcall(vim.cmd.redrawtabline)
	end
end

function M.refresh_all()
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			M.refresh(bufnr, true)
		end
	end
	pcall(vim.cmd.redrawtabline)
end

function M.preview_line()
	local index = note_index()
	local entries = index.by_line[vim.fn.line(".")]
	if not entries or #entries == 0 then
		vim.notify("No project notes for this line", vim.log.levels.INFO)
		return
	end

	local lines = {}
	for _, entry in ipairs(entries) do
		local label = entry.kind == "todo" and "TODO" or "NOTE"
		table.insert(lines, "- **" .. label .. "** " .. entry.text)
		table.insert(lines, "  `" .. entry.ref .. "`")
	end

	vim.lsp.util.open_floating_preview(lines, "markdown", { border = "rounded" })
end

local function defer_preview_line(target_line)
	local win = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_get_current_buf()

	vim.defer_fn(function()
		if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_get_current_win() ~= win then
			return
		end
		if vim.api.nvim_get_current_buf() ~= buf or vim.fn.line(".") ~= target_line then
			return
		end

		M.preview_line()
	end, 20)
end

local function jump_note(direction)
	local lines = noted_lines()
	if #lines == 0 then
		vim.notify("No project notes for this buffer", vim.log.levels.INFO)
		return
	end

	local current = vim.fn.line(".")
	local target
	for _ = 1, vim.v.count1 do
		if direction > 0 then
			target = lines[1]
			for _, lnum in ipairs(lines) do
				if lnum > current then
					target = lnum
					break
				end
			end
		else
			target = lines[#lines]
			for i = #lines, 1, -1 do
				if lines[i] < current then
					target = lines[i]
					break
				end
			end
		end

		current = target
		vim.api.nvim_win_set_cursor(0, { target, 0 })
	end

	vim.cmd("normal! zz")
	defer_preview_line(target)
end

function M.next_note()
	jump_note(1)
end

function M.prev_note()
	jump_note(-1)
end

local function format_project_entry(entry)
	local label = entry.kind == "todo" and "TODO" or "NOTE"
	local location = entry.ref or (vim.fn.fnamemodify(entry.notes_path, ":t") .. ":" .. entry.note_lnum)

	return label .. " " .. location .. "  " .. entry.text
end

local function open_project_entry(entry)
	local path = entry.target_path
	local line = entry.start_line

	if not path or vim.fn.filereadable(path) == 0 then
		path = entry.notes_path
		line = entry.note_lnum
	end

	vim.cmd.edit(vim.fn.fnameescape(path))
	vim.api.nvim_win_set_cursor(0, { math.max(1, line or 1), 0 })
	vim.cmd("normal! zz")
end

local function filetype_for_path(path)
	if vim.filetype and vim.filetype.match then
		return vim.filetype.match({ filename = path }) or ""
	end

	return ""
end

local function project_entry_preview_lines(entry)
	local label = entry.kind == "todo" and "TODO" or "NOTE"
	local location = entry.ref or (vim.fn.fnamemodify(entry.notes_path, ":t") .. ":" .. entry.note_lnum)
	local path = entry.target_path
	local start_line = entry.start_line
	local end_line = entry.end_line or start_line
	local source_title = "Source"

	if not path or vim.fn.filereadable(path) == 0 then
		path = entry.notes_path
		start_line = entry.note_lnum
		end_line = entry.note_lnum
		source_title = "Notes File"
	end

	local lines = {
		"# " .. label,
		"",
		entry.text ~= "" and entry.text or "(empty note)",
		"",
		"Location: `" .. location .. "`",
		"",
		"## " .. source_title,
		"",
		"`" .. display_path(path) .. "`",
		"",
	}

	if vim.fn.filereadable(path) == 0 then
		table.insert(lines, "File is not readable.")
		return lines
	end

	local file_lines = vim.fn.readfile(path)
	local first = math.max(1, (start_line or 1) - 3)
	local last = math.min(#file_lines, (end_line or start_line or 1) + 3)

	table.insert(lines, "```" .. filetype_for_path(path))
	for lnum = first, last do
		local marker = lnum >= start_line and lnum <= end_line and ">" or " "
		table.insert(lines, string.format("%s %d | %s", marker, lnum, file_lines[lnum] or ""))
	end
	table.insert(lines, "```")

	return lines
end

local function project_notes_previewer(previewers)
	return previewers.new_buffer_previewer({
		title = "Project Note Preview",
		define_preview = function(self, entry)
			vim.bo[self.state.bufnr].modifiable = true
			vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, project_entry_preview_lines(entry.value))
			vim.bo[self.state.bufnr].filetype = "markdown"
			vim.bo[self.state.bufnr].modifiable = false
		end,
	})
end

local function select_project_note(entries)
	vim.ui.select(entries, {
		prompt = "Project notes",
		format_item = format_project_entry,
	}, function(entry)
		if entry then
			open_project_entry(entry)
		end
	end)
end

function M.find_project_notes(opts)
	opts = opts or {}

	local entries = project_note_entries()
	if #entries == 0 then
		vim.notify("No project notes found", vim.log.levels.INFO)
		return
	end

	local ok_pickers, pickers = pcall(require, "telescope.pickers")
	local ok_finders, finders = pcall(require, "telescope.finders")
	local ok_actions, actions = pcall(require, "telescope.actions")
	local ok_state, action_state = pcall(require, "telescope.actions.state")
	local ok_config, telescope_config = pcall(require, "telescope.config")
	local ok_previewers, previewers = pcall(require, "telescope.previewers")
	if not (ok_pickers and ok_finders and ok_actions and ok_state and ok_config and ok_previewers) then
		select_project_note(entries)
		return
	end

	pickers
		.new(opts, {
			prompt_title = "Project Notes",
			finder = finders.new_table({
				results = entries,
				entry_maker = function(entry)
					local display = format_project_entry(entry)
					return {
						value = entry,
						display = display,
						ordinal = display,
						filename = entry.target_path or entry.notes_path,
						lnum = entry.start_line or entry.note_lnum,
					}
				end,
			}),
			previewer = project_notes_previewer(previewers),
			sorter = telescope_config.values.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					if selection then
						open_project_entry(selection.value)
					end
				end)
				return true
			end,
		})
		:find()
end

function M.list_buffer()
	local index = note_index()
	if #index.entries == 0 then
		vim.notify("No project notes for this buffer", vim.log.levels.INFO)
		return
	end

	vim.ui.select(index.entries, {
		prompt = "Project notes",
		format_item = function(entry)
			local label = entry.kind == "todo" and "TODO" or "NOTE"
			return label .. " " .. entry.ref .. "  " .. entry.text
		end,
	}, function(entry)
		if not entry then
			return
		end

		vim.cmd.edit(vim.fn.fnameescape(entry.notes_path))
		vim.api.nvim_win_set_cursor(0, { entry.note_lnum, 0 })
	end)
end

function M.setup()
	vim.cmd("highlight default link ProjectNotesSign DiagnosticInfo")
	vim.cmd("highlight default link ProjectNotesTodoSign DiagnosticWarn")

	vim.api.nvim_create_user_command("ProjectNotes", M.open, { desc = "Open project notes" })
	vim.api.nvim_create_user_command("ProjectNotesClose", M.close, { desc = "Close project notes" })
	vim.api.nvim_create_user_command("ProjectNote", M.note, { desc = "Capture project note" })
	vim.api.nvim_create_user_command("ProjectTodo", M.todo, { desc = "Capture project todo" })
	vim.api.nvim_create_user_command("ProjectNotesRefresh", M.refresh_all, { desc = "Refresh project note signs" })
	vim.api.nvim_create_user_command("ProjectNotesFind", function()
		M.find_project_notes()
	end, { desc = "Find project notes" })

	vim.keymap.set("n", "<leader>no", M.open, { desc = "Open project notes" })
	vim.keymap.set("n", "<leader>nc", M.close, { desc = "Close project notes" })
	vim.keymap.set("n", "<leader>nn", M.note, { desc = "Capture project note" })
	vim.keymap.set("x", "<leader>nn", M.selection_note, { desc = "Capture selection note" })
	vim.keymap.set("n", "<leader>nt", M.todo, { desc = "Capture project todo" })
	vim.keymap.set("x", "<leader>nt", M.selection_todo, { desc = "Capture selection todo" })
	vim.keymap.set("n", "<leader>nf", M.find_project_notes, { desc = "Find project notes" })
	vim.keymap.set("n", "<leader>nl", M.list_buffer, { desc = "List buffer notes" })
	vim.keymap.set("n", "<leader>np", M.preview_line, { desc = "Preview line notes" })
	vim.keymap.set("n", "<leader>nr", M.refresh_all, { desc = "Refresh note signs" })
	vim.keymap.set("n", "<leader>nP", M.copy_path, { desc = "Copy project notes path" })
	vim.keymap.set("n", "]n", M.next_note, { desc = "Next project note" })
	vim.keymap.set("n", "[n", M.prev_note, { desc = "Previous project note" })

	local group = vim.api.nvim_create_augroup("project_notes", { clear = true })
	vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
		group = group,
		callback = function(event)
			if is_notes_path(vim.api.nvim_buf_get_name(event.buf)) then
				M.refresh_all()
			else
				M.refresh(event.buf)
			end
		end,
	})
end

return M
