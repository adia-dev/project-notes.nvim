local M = {}

local function assert_eq(actual, expected, message)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message, vim.inspect(expected), vim.inspect(actual)))
	end
end

local function notes_path(root)
	local name = vim.fs.basename(root) or "project"
	local slug = name:gsub("[^%w%._%-]+", "-")
	return vim.fn.stdpath("data") .. "/project-notes/" .. slug .. "-" .. vim.fn.sha256(root):sub(1, 8) .. ".md"
end

local function with_project(name, fn)
	local tmp_parent = vim.fn.fnamemodify(vim.fn.tempname(), ":h")
	tmp_parent = vim.uv.fs_realpath(tmp_parent) or tmp_parent

	local root = tmp_parent
		.. "/project-notes.nvim-"
		.. name
		.. "-"
		.. vim.fn.sha256(tostring(vim.uv.hrtime())):sub(1, 8)
	local src = root .. "/file.lua"
	local note_path = notes_path(root)

	vim.fn.mkdir(root, "p")
	vim.fn.writefile({ "one", "two", "three", "four" }, src)
	vim.fn.mkdir(vim.fn.fnamemodify(note_path, ":h"), "p")

	local ok, err = xpcall(function()
		fn(root, src, note_path)
	end, debug.traceback)

	vim.fn.delete(note_path)
	vim.fn.delete(root, "rf")
	vim.bo.modified = false

	if not ok then
		error(err)
	end
end

local function write_notes(root, src, note_path)
	local bt = string.char(96)
	local fence = bt .. bt .. bt
	vim.fn.writefile({
		"# test",
		"",
		"Project: " .. bt .. root .. bt,
		"",
		"## Notes",
		"- note one (" .. bt .. src .. ":1" .. bt .. ")",
		fence .. "lua",
		"- not a note in code",
		fence,
		"- manual project note",
		"",
		"## Todo",
		"- [ ] todo two (" .. bt .. src .. ":2-3" .. bt .. ")",
	}, note_path)
end

function M.run()
	local notes = require("project-notes")
	notes.setup()

	assert_eq(vim.fn.exists(":ProjectNotesFind"), 2, "ProjectNotesFind command")
	assert_eq(vim.fn.maparg("<leader>nf", "n") ~= "", true, "project notes Telescope map")
	assert_eq(vim.fn.maparg("]n", "n") ~= "", true, "next note map")
	assert_eq(vim.fn.maparg("[n", "n") ~= "", true, "previous note map")

	with_project("signs", function(root, src, note_path)
		write_notes(root, src, note_path)
		vim.cmd.edit(vim.fn.fnameescape(src))

		notes.refresh(0)
		local ns = vim.api.nvim_get_namespaces()["project-notes.nvim"]
		local marks = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })

		assert_eq(#marks, 3, "note sign count")
		assert_eq(marks[1][2] + 1, 1, "first note line")
		assert_eq(vim.trim(marks[1][4].sign_text), "N", "first note sign")
		assert_eq(marks[2][2] + 1, 2, "todo range start")
		assert_eq(vim.trim(marks[2][4].sign_text), "T", "todo sign")
		assert_eq(vim.b.project_notes_count, 2, "buffer note count")
		assert_eq(vim.b.project_notes_todo_count, 1, "buffer todo count")
	end)

	with_project("jump", function(root, src, note_path)
		write_notes(root, src, note_path)
		vim.cmd.edit(vim.fn.fnameescape(src))
		vim.api.nvim_win_set_cursor(0, { 1, 0 })

		local previews = 0
		vim.lsp.util.open_floating_preview = function()
			previews = previews + 1
		end

		notes.next_note()
		assert_eq(vim.fn.line("."), 2, "next note jumps to todo")
		vim.wait(150, function()
			return previews == 1
		end)
		assert_eq(previews, 1, "jump opens deferred preview")

		notes.prev_note()
		assert_eq(vim.fn.line("."), 1, "previous note jumps back")
	end)

	with_project("telescope", function(root, src, note_path)
		write_notes(root, src, note_path)
		vim.cmd.edit(vim.fn.fnameescape(src))

		local captured_results
		local captured_prompt
		local selected
		local closed
		local previewer_spec

		package.loaded["telescope.finders"] = {
			new_table = function(spec)
				captured_results = spec.results
				return spec
			end,
		}
		package.loaded["telescope.config"] = {
			values = {
				generic_sorter = function()
					return "sorter"
				end,
			},
		}
		package.loaded["telescope.actions.state"] = {
			get_selected_entry = function()
				return { value = selected }
			end,
		}
		package.loaded["telescope.actions"] = {
			close = function(prompt)
				closed = prompt
			end,
			select_default = {
				replace = function(_, fn)
					selected = captured_results[3]
					fn()
				end,
			},
		}
		package.loaded["telescope.previewers"] = {
			new_buffer_previewer = function(spec)
				previewer_spec = spec
				return spec
			end,
		}
		package.loaded["telescope.pickers"] = {
			new = function(_, spec)
				captured_prompt = spec.prompt_title
				return {
					find = function()
						spec.attach_mappings(42)
					end,
				}
			end,
		}

		notes.find_project_notes()
		assert_eq(captured_prompt, "Project Notes", "Telescope prompt")
		assert_eq(#captured_results, 3, "project note entries")
		assert_eq(captured_results[2].target_path, nil, "manual note has no target path")
		assert_eq(closed, 42, "Telescope closes on select")
		assert_eq(vim.api.nvim_buf_get_name(0), src, "selection opens source file")
		assert_eq(vim.fn.line("."), 2, "selection jumps to target line")

		local preview_buf = vim.api.nvim_create_buf(false, true)
		previewer_spec.define_preview({ state = { bufnr = preview_buf } }, { value = captured_results[3] })
		local preview = table.concat(vim.api.nvim_buf_get_lines(preview_buf, 0, -1, false), "\n")

		assert_eq(preview:match("TODO") ~= nil, true, "preview includes kind")
		assert_eq(preview:match("todo two") ~= nil, true, "preview includes note text")
		assert_eq(preview:match("> 2 | two") ~= nil, true, "preview marks start line")
		assert_eq(preview:match("> 3 | three") ~= nil, true, "preview marks range line")
		assert_eq(vim.bo[preview_buf].filetype, "markdown", "preview filetype")
	end)

	print("project-notes tests ok")
end

return M
