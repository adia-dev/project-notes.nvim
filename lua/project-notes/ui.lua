local config = require("project-notes.config")
local paths = require("project-notes.paths")
local store = require("project-notes.store")

local M = {}

local signs_ns = vim.api.nvim_create_namespace("project-notes.nvim")

function M.open()
	vim.cmd.edit(vim.fn.fnameescape(paths.ensure_notes_file()))
end

function M.close()
	local current_name = vim.api.nvim_buf_get_name(0)
	local target = paths.is_notes_path(current_name) and current_name or paths.notes_path()
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

function M.copy_path()
	local path = paths.ensure_notes_file()
	vim.fn.setreg("+", path)
	vim.notify("Copied project notes path", vim.log.levels.INFO)
end

function M.refresh(bufnr, skip_redraw)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_loaded(bufnr) then
		return
	end

	vim.api.nvim_buf_clear_namespace(bufnr, signs_ns, 0, -1)

	local index = store.note_index(bufnr)
	local todo_count = 0
	for _, entry in ipairs(index.entries) do
		if entry.kind == "todo" then
			todo_count = todo_count + 1
		end
	end

	vim.b[bufnr].project_notes_count = #index.entries
	vim.b[bufnr].project_notes_todo_count = todo_count

	local signs = config.get().signs
	if signs.enabled then
		for lnum, entries in pairs(index.by_line) do
			local has_todo = false
			for _, entry in ipairs(entries) do
				if entry.kind == "todo" then
					has_todo = true
					break
				end
			end

			local sign = has_todo and signs.todo or signs.note
			vim.api.nvim_buf_set_extmark(bufnr, signs_ns, lnum - 1, 0, {
				sign_text = sign.text,
				sign_hl_group = sign.hl,
				priority = signs.priority,
			})
		end
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
	local index = store.note_index()
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

	vim.lsp.util.open_floating_preview(lines, "markdown", { border = config.get().preview.border })
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
	end, config.get().preview.jump_delay)
end

local function jump_note(direction)
	local lines = store.noted_lines()
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
		"`" .. paths.display_path(path) .. "`",
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
		title = config.get().telescope.preview_title,
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

	local entries = store.project_note_entries()
	if #entries == 0 then
		vim.notify("No project notes found", vim.log.levels.INFO)
		return
	end

	if not config.get().telescope.enabled then
		select_project_note(entries)
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
			prompt_title = config.get().telescope.prompt_title,
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
	local index = store.note_index()
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

return M
