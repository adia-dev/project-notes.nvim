local config = require("project-notes.config")

local M = {}

function M.notes_dir()
	return config.get().notes_dir
end

function M.is_notes_path(path)
	local notes_dir = M.notes_dir()
	return path ~= "" and path:sub(1, #notes_dir + 1) == notes_dir .. "/" and path:sub(-3) == ".md"
end

function M.current_notes_path(bufnr)
	local path = vim.api.nvim_buf_get_name(bufnr or 0)
	if M.is_notes_path(path) then
		return path
	end
end

function M.project_root(bufnr)
	bufnr = bufnr or 0
	local name = vim.api.nvim_buf_get_name(bufnr)
	local start = name ~= "" and vim.fs.dirname(name) or vim.uv.cwd()

	return vim.fs.root(start, config.get().root_markers) or start
end

function M.display_path(path)
	local home = vim.uv.os_homedir()
	if path:sub(1, #home) == home then
		return "~" .. path:sub(#home + 1)
	end

	return path
end

function M.notes_path(bufnr)
	local current = M.current_notes_path(bufnr)
	if current then
		return current, M.notes_dir()
	end

	local root = M.project_root(bufnr)
	local name = vim.fs.basename(root) or "project"
	local slug = name:gsub("[^%w%._%-]+", "-")
	local hash = vim.fn.sha256(root):sub(1, 8)

	return M.notes_dir() .. "/" .. slug .. "-" .. hash .. ".md", root
end

function M.ensure_notes_file()
	vim.fn.mkdir(M.notes_dir(), "p")

	local path, root = M.notes_path()
	if vim.fn.filereadable(path) == 0 then
		vim.fn.writefile({
			"# " .. (vim.fs.basename(root) or "Project") .. " Notes",
			"",
			"Project: `" .. M.display_path(root) .. "`",
			"",
			"## Notes",
			"",
			"## Todo",
			"",
		}, path)
	end

	return path
end

return M
