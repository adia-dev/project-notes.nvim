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

With lazy.nvim:

```lua
{
  "adia-dev/project-notes.nvim",
  config = function()
    require("project-notes").setup()
  end,
}
```

With a local checkout:

```lua
{
  dir = "~/.local/share/nvim/project-notes.nvim",
  name = "project-notes.nvim",
  config = function()
    require("project-notes").setup()
  end,
}
```

Telescope is optional. If `nvim-telescope/telescope.nvim` is installed, `ProjectNotesFind` uses it; otherwise it falls back to `vim.ui.select`.

Manual checkout:

```sh
git clone https://github.com/adia-dev/project-notes.nvim.git ~/.local/share/nvim/project-notes.nvim
```

Then point your plugin manager at that local directory with `dir = "~/.local/share/nvim/project-notes.nvim"`.

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
