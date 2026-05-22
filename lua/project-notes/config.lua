local M = {}

local defaults = {
	notes_dir = vim.fn.stdpath("data") .. "/project-notes",
	root_markers = { ".git" },
	commands = true,
	autocmds = true,
	mappings = {
		enabled = true,
		open = "<leader>no",
		close = "<leader>nc",
		note = "<leader>nn",
		todo = "<leader>nt",
		find = "<leader>nf",
		list_buffer = "<leader>nl",
		preview_line = "<leader>np",
		refresh = "<leader>nr",
		copy_path = "<leader>nP",
		next_note = "]n",
		prev_note = "[n",
	},
	signs = {
		enabled = true,
		priority = 20,
		note = {
			text = "N",
			hl = "ProjectNotesSign",
		},
		todo = {
			text = "T",
			hl = "ProjectNotesTodoSign",
		},
	},
	highlights = {
		enabled = true,
		note = "DiagnosticInfo",
		todo = "DiagnosticWarn",
	},
	preview = {
		border = "rounded",
		jump_delay = 20,
	},
	telescope = {
		enabled = true,
		prompt_title = "Project Notes",
		preview_title = "Project Note Preview",
	},
}

local options = vim.deepcopy(defaults)

local function toggle_table(value, default)
	if value == false then
		local result = vim.deepcopy(default)
		result.enabled = false
		return result
	end

	if value == true or value == nil then
		return vim.deepcopy(default)
	end

	return vim.tbl_deep_extend("force", vim.deepcopy(default), value)
end

local function normalize_path(path)
	return vim.fs.normalize(vim.fn.expand(path))
end

function M.setup(opts)
	opts = opts or {}

	local merged = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts)
	merged.mappings = toggle_table(opts.mappings, defaults.mappings)
	merged.signs = toggle_table(opts.signs, defaults.signs)
	merged.highlights = toggle_table(opts.highlights, defaults.highlights)

	if type(merged.root_markers) == "string" then
		merged.root_markers = { merged.root_markers }
	end

	merged.notes_dir = normalize_path(merged.notes_dir)
	options = merged

	return options
end

function M.get()
	return options
end

function M.defaults()
	return vim.deepcopy(defaults)
end

return M
