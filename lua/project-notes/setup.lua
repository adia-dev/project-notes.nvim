local config = require("project-notes.config")
local paths = require("project-notes.paths")

local M = {}

local group_name = "project_notes"
local installed_maps = {}

local command_specs = {
	{ name = "ProjectNotes", method = "open", desc = "Open project notes" },
	{ name = "ProjectNotesClose", method = "close", desc = "Close project notes" },
	{ name = "ProjectNote", method = "note", desc = "Capture project note" },
	{ name = "ProjectTodo", method = "todo", desc = "Capture project todo" },
	{ name = "ProjectNotesRefresh", method = "refresh_all", desc = "Refresh project note signs" },
	{ name = "ProjectNotesFind", method = "find_project_notes", desc = "Find project notes" },
}

local map_specs = {
	{ mode = "n", key = "open", method = "open", desc = "Open project notes" },
	{ mode = "n", key = "close", method = "close", desc = "Close project notes" },
	{ mode = "n", key = "note", method = "note", desc = "Capture project note" },
	{ mode = "x", key = "note", method = "selection_note", desc = "Capture selection note" },
	{ mode = "n", key = "todo", method = "todo", desc = "Capture project todo" },
	{ mode = "x", key = "todo", method = "selection_todo", desc = "Capture selection todo" },
	{ mode = "n", key = "find", method = "find_project_notes", desc = "Find project notes" },
	{ mode = "n", key = "list_buffer", method = "list_buffer", desc = "List buffer notes" },
	{ mode = "n", key = "preview_line", method = "preview_line", desc = "Preview line notes" },
	{ mode = "n", key = "refresh", method = "refresh_all", desc = "Refresh note signs" },
	{ mode = "n", key = "copy_path", method = "copy_path", desc = "Copy project notes path" },
	{ mode = "n", key = "next_note", method = "next_note", desc = "Next project note" },
	{ mode = "n", key = "prev_note", method = "prev_note", desc = "Previous project note" },
}

local function clear_commands()
	for _, spec in ipairs(command_specs) do
		pcall(vim.api.nvim_del_user_command, spec.name)
	end
end

local function clear_maps()
	for _, map in ipairs(installed_maps) do
		pcall(vim.keymap.del, map.mode, map.lhs)
	end
	installed_maps = {}
end

local function clear_autocmds()
	pcall(vim.api.nvim_del_augroup_by_name, group_name)
end

local function configure_highlights(opts)
	if not opts.highlights.enabled then
		return
	end

	vim.cmd("highlight default link " .. opts.signs.note.hl .. " " .. opts.highlights.note)
	vim.cmd("highlight default link " .. opts.signs.todo.hl .. " " .. opts.highlights.todo)
end

local function configure_commands(api, opts)
	clear_commands()

	if not opts.commands then
		return
	end

	for _, spec in ipairs(command_specs) do
		vim.api.nvim_create_user_command(spec.name, function()
			api[spec.method]()
		end, { desc = spec.desc })
	end
end

local function configure_maps(api, opts)
	clear_maps()

	if not opts.mappings.enabled then
		return
	end

	for _, spec in ipairs(map_specs) do
		local lhs = opts.mappings[spec.key]
		if lhs and lhs ~= "" then
			vim.keymap.set(spec.mode, lhs, api[spec.method], { desc = spec.desc, silent = true })
			table.insert(installed_maps, { mode = spec.mode, lhs = lhs })
		end
	end
end

local function configure_autocmds(api, opts)
	clear_autocmds()

	if not opts.autocmds then
		return
	end

	local group = vim.api.nvim_create_augroup(group_name, { clear = true })
	vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
		group = group,
		callback = function(event)
			if paths.is_notes_path(vim.api.nvim_buf_get_name(event.buf)) then
				api.refresh_all()
			else
				api.refresh(event.buf)
			end
		end,
	})
end

function M.setup(api, opts)
	local normalized = config.setup(opts)

	configure_highlights(normalized)
	configure_commands(api, normalized)
	configure_maps(api, normalized)
	configure_autocmds(api, normalized)

	return normalized
end

return M
