# project-notes.nvim

Small project-scoped notes and todos for Neovim. Notes are stored as Markdown files under `stdpath("data")/project-notes`, link back to source files, and include captured source previews.

## Features

- Capture notes and todos from the current line or visual selection.
- Store one notes file per project root.
- Add sign-column cues for noted lines and todo ranges.
- Show bufferline note counts through `vim.b.project_notes_count`.
- Jump between noted lines with `[n` and `]n`.
- Find all project notes with Telescope, including a preview pane.

## Installation

With lazy.nvim and plugin-managed mappings:

```lua
{
  "adia-dev/project-notes.nvim",
  opts = {},
}
```

For command/key lazy-loading, let lazy.nvim own the keymaps and disable the plugin's built-in mappings:

```lua
{
  "adia-dev/project-notes.nvim",
  cmd = {
    "ProjectNotes",
    "ProjectNotesClose",
    "ProjectNote",
    "ProjectTodo",
    "ProjectNotesRefresh",
    "ProjectNotesFind",
  },
  keys = {
    { "<leader>no", function() require("project-notes").open() end, desc = "Open project notes" },
    { "<leader>nc", function() require("project-notes").close() end, desc = "Close project notes" },
    { "<leader>nn", function() require("project-notes").note() end, desc = "Capture project note" },
    { "<leader>nn", function() require("project-notes").selection_note() end, mode = "x", desc = "Capture selection note" },
    { "<leader>nt", function() require("project-notes").todo() end, desc = "Capture project todo" },
    { "<leader>nt", function() require("project-notes").selection_todo() end, mode = "x", desc = "Capture selection todo" },
    { "<leader>nf", function() require("project-notes").find_project_notes() end, desc = "Find project notes" },
    { "<leader>nl", function() require("project-notes").list_buffer() end, desc = "List buffer notes" },
    { "<leader>np", function() require("project-notes").preview_line() end, desc = "Preview line notes" },
    { "<leader>nr", function() require("project-notes").refresh_all() end, desc = "Refresh note signs" },
    { "<leader>nP", function() require("project-notes").copy_path() end, desc = "Copy project notes path" },
    { "]n", function() require("project-notes").next_note() end, desc = "Next project note" },
    { "[n", function() require("project-notes").prev_note() end, desc = "Previous project note" },
  },
  opts = {
    mappings = false,
  },
}
```

With a local checkout:

```lua
{
  dir = "~/.local/share/nvim/project-notes.nvim",
  name = "project-notes.nvim",
  main = "project-notes",
  opts = {},
}
```

Telescope is optional. If `nvim-telescope/telescope.nvim` is installed, `ProjectNotesFind` uses it; otherwise it falls back to `vim.ui.select`.

Manual checkout:

```sh
git clone https://github.com/adia-dev/project-notes.nvim.git ~/.local/share/nvim/project-notes.nvim
```

Then point your plugin manager at that local directory with `dir = "~/.local/share/nvim/project-notes.nvim"`.

## Configuration

`setup()` accepts a table and can be called directly by packer or through lazy.nvim `opts`.

```lua
require("project-notes").setup({
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
    note = { text = "N", hl = "ProjectNotesSign" },
    todo = { text = "T", hl = "ProjectNotesTodoSign" },
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
})
```

Use `mappings = false`, `commands = false`, `autocmds = false`, or `signs = false` to disable those integrations.

## Usage

Default mappings:

| Mapping | Mode | Action |
| --- | --- | --- |
| `<leader>no` | Normal | Open the project notes file |
| `<leader>nc` | Normal | Close the project notes window |
| `<leader>nn` | Normal/Visual | Capture a note |
| `<leader>nt` | Normal/Visual | Capture a todo |
| `<leader>nf` | Normal | Find project notes |
| `<leader>nl` | Normal | List notes for the current buffer |
| `<leader>np` | Normal | Preview notes for the current line |
| `<leader>nr` | Normal | Refresh note signs |
| `<leader>nP` | Normal | Copy the notes file path |
| `]n` / `[n` | Normal | Next/previous noted line |

Commands:

```vim
:ProjectNotes
:ProjectNotesClose
:ProjectNote
:ProjectTodo
:ProjectNotesFind
:ProjectNotesRefresh
```

## Note Format

Notes are written as Markdown:

````md
## Notes
- Check this path (`lua/example.lua:12`)
```lua
local path = vim.fn.expand("%")
```

- Selection note (`lua/example.lua:12-16`)
```lua
local path = vim.fn.expand("%")
if path == "" then
  return nil
end
```

## Todo
- [ ] Refactor this branch (`lua/example.lua:44`)
```lua
local result = do_work(input)
```
````

The backticked location is used for signs, `[n` / `]n` navigation, and Telescope previews. The fenced block is a snapshot of the line or visual range at capture time, so the note keeps useful context even if the source later changes.

## Development

Run the test suite with Neovim:

```sh
make test
```

Equivalent direct command:

```sh
mkdir -p /tmp/project-notes.nvim-test/data \
  /tmp/project-notes.nvim-test/state \
  /tmp/project-notes.nvim-test/cache
XDG_DATA_HOME=/tmp/project-notes.nvim-test/data \
XDG_STATE_HOME=/tmp/project-notes.nvim-test/state \
XDG_CACHE_HOME=/tmp/project-notes.nvim-test/cache \
nvim --headless -n -i NONE -u tests/minimal_init.lua \
  -c "lua require('tests.project_notes_spec').run()" +qa!
```

Format Lua files:

```sh
stylua lua tests
```
