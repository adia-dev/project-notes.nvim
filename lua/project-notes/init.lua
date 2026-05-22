local capture = require("project-notes.capture")
local setup = require("project-notes.setup")
local ui = require("project-notes.ui")

local M = {}

M.open = ui.open
M.close = ui.close
M.copy_path = ui.copy_path
M.refresh = ui.refresh
M.refresh_all = ui.refresh_all
M.preview_line = ui.preview_line
M.next_note = ui.next_note
M.prev_note = ui.prev_note
M.find_project_notes = ui.find_project_notes
M.list_buffer = ui.list_buffer

M.note = capture.note
M.todo = capture.todo
M.selection_note = capture.selection_note
M.selection_todo = capture.selection_todo

function M.setup(opts)
	return setup.setup(M, opts)
end

return M
