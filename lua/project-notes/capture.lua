local paths = require("project-notes.paths")
local store = require("project-notes.store")

local M = {}

local function current_context(start_line, end_line)
	if paths.is_notes_path(vim.api.nvim_buf_get_name(0)) then
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

local function fenced_preview(lines)
	if not lines or #lines == 0 or paths.is_notes_path(vim.api.nvim_buf_get_name(0)) then
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

local function refresh_all()
	local ok, project_notes = pcall(require, "project-notes")
	if ok and project_notes.refresh_all then
		project_notes.refresh_all()
	end
end

local function append_to_section(section, item)
	local path = store.append_to_section(section, item)
	refresh_all()
	vim.notify("Captured in " .. vim.fn.fnamemodify(path, ":t"), vim.log.levels.INFO)
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

return M
