local paths = require("project-notes.paths")

local M = {}

function M.parse_ref(ref)
	local ref_path, start_line, end_line = ref:match("^(.*):(%d+)%-(%d+)$")
	if ref_path then
		return ref_path, tonumber(start_line), tonumber(end_line)
	end

	ref_path, start_line = ref:match("^(.*):(%d+)$")
	if ref_path then
		return ref_path, tonumber(start_line), tonumber(start_line)
	end
end

function M.normalize_ref_path(path, root)
	path = vim.fn.expand(path)

	if path:sub(1, 1) == "/" then
		return vim.fs.normalize(path)
	end

	return vim.fs.normalize(root .. "/" .. path)
end

function M.clean_entry_text(line)
	return line:gsub("^%s*%- %[[ xX]%]%s*", ""):gsub("^%s*%- %s*", ""):gsub("%s*%(`[^`]+`%)", "")
end

function M.append_to_section(section, item)
	local path = paths.ensure_notes_file()
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
	return path
end

function M.note_index(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local buf_name = vim.api.nvim_buf_get_name(bufnr)
	if buf_name == "" or paths.is_notes_path(buf_name) then
		return { by_line = {}, entries = {}, notes_path = nil }
	end

	local path, root = paths.notes_path(bufnr)
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
			local ref_path, start_line, end_line = M.parse_ref(ref)
			if ref_path and M.normalize_ref_path(ref_path, root) == buf_path then
				local entry = {
					kind = section == "Todo" and "todo" or "note",
					text = M.clean_entry_text(line),
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

function M.notes_file_root(path, fallback)
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

function M.project_note_entries(bufnr)
	local path, root = paths.notes_path(bufnr)
	root = M.notes_file_root(path, root)

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
				ref_path, start_line, end_line = M.parse_ref(ref)
			end

			table.insert(entries, {
				kind = section == "Todo" and "todo" or "note",
				text = M.clean_entry_text(line),
				note_lnum = note_lnum,
				ref = ref,
				notes_path = path,
				target_path = ref_path and M.normalize_ref_path(ref_path, root) or nil,
				start_line = start_line,
				end_line = end_line,
			})
		end
	end

	return entries, path
end

function M.noted_lines(bufnr)
	local index = M.note_index(bufnr)
	local lines = {}

	for lnum in pairs(index.by_line) do
		table.insert(lines, lnum)
	end
	table.sort(lines)

	return lines
end

return M
