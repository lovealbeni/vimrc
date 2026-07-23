# Efficient Editing with Pure Vimscript

A `.vimrc` with zero plugin dependencies, implementing fuzzy search, a file tree,
Git status/diff, git blame, a buffer switcher bar, and line-level Git change
markers — all in pure Vimscript.

## Design Philosophy

I wanted an editor that is just an editor — it shouldn't rely on any IDE
features to do its job. In my design, every feature is implemented purely
through text. My design exists only to better serve the purpose of an editor,
packing in the basic features I actually use in daily development.

## Requirements

- Vim 8.2+ (requires popup windows, text properties, `matchfuzzy()`, etc.)
- Optional dependencies:
  - [ripgrep (rg)](https://github.com/BurntSushi/ripgrep): used for file listing
    and content search. Without rg, filename search automatically falls back to
    Vim's built-in `globpath`, and content search is unavailable.
  - `git`: required for Git-related features
  - `diff`: required for line-level change markers (ships with the system)

## Installation

```sh
cp .vimrc ~/.vimrc
```

The `<leader>` key is set to `<Space>`.

## Feature Overview

| Key | Feature |
|-----|---------|
| `<leader>ff` | Fuzzy search project file names (with preview) |
| `<leader>fg` | Search project contents (with preview) |
| `<leader>e` | Toggle the file tree sidebar |
| `<leader>g` | Open the Git status window (with split diff) |
| `<leader>b` | Bottom buffer switcher bar |
| `<leader>d` | Preview the diff of the change hunk under the cursor |
| `<leader>p` | `:find` the word under the cursor (slashes stripped) |
| `<leader>l` | Toggle whitespace visibility |
| `Ctrl-s` | Save (writes only when modified) |
| `Ctrl-h/j/k/l` | Move between split windows |

---

## Fuzzy Search (`<leader>ff` / `<leader>fg`)

A popup-based fuzzy search written in pure Vimscript, with a result list on the
left and a live preview (with syntax highlighting) on the right.

- `<leader>ff`: fuzzy search file names in the project (`rg --files`, including
  hidden files, excluding `.git`)
- `<leader>fg`: search project contents; searching starts after at least 2
  characters are typed (`rg --vimgrep`, smart-case)
- In visual mode, select some text first and then press `<leader>ff` /
  `<leader>fg` to use the selection as the search keyword
- When filename fuzzy matching yields no results, it automatically falls back
  to "fragment similarity" matching — handy for pasting text containing quotes,
  line numbers, or partial paths

Keys inside the popup:

| Key | Action |
|-----|--------|
| `Ctrl-j` / `Ctrl-k` (or `↑` `↓`) | Move selection up/down |
| Enter | Open in the current window |
| `-` | Open in a horizontal split |
| `\` | Open in a vertical split |
| `Esc` / `Ctrl-c` | Close |
| Backspace | Delete one character |

After pressing Enter in content search (`<leader>fg`), the file opens and jumps
to the matching line, which is highlighted in the preview pane.

Command forms are also available: `:FFiles`, `:FGrep`.

## File Tree (`<leader>e`)

Opens a 30-column-wide directory tree sidebar on the left; press `<leader>e`
again to close it. Directories come first, then files, sorted by name
(case-insensitive), excluding `.git`.

Keys inside the tree:

| Key | Action |
|-----|--------|
| Enter / `o` | Open file, or expand/collapse a directory |
| `-` | Open file in a horizontal split |
| `\` | Open file in a vertical split |
| `r` | Refresh directory contents |
| `q` | Close the sidebar |

## Git Status Window (`<leader>g`)

Opens a Git status interface in a separate tab page (must be inside a git
repository):

- Left: `git status` list of changed files (`M`, `A`, `??` status markers)
- Middle/right: two panes showing a live split diff using Vim's built-in diff
  mode (old version | new version)
  - Staged files: HEAD vs index
  - Unstaged files: index vs working tree
  - Untracked files: empty vs file contents

Keys in the status list:

| Key | Action |
|-----|--------|
| `j` / `k` | Move the selection; the diff on the right updates live |
| Enter | Open the selected file |
| `s` | Stage the selected file (`git add`; also works for untracked files/directories) |
| `u` | Unstage the selected file (`git restore --staged`; falls back to `git reset` on older git) |
| `r` | Refresh status |
| `q` | Close |

## Line-Level Git Change Markers and Diff Preview

- Refreshes automatically after opening/saving a file, and about 0.3 seconds
  after editing stops
- The sign column to the left of the line numbers marks the current file's
  changes relative to the git index:
  - Green `+` = added lines
  - Yellow `~` = modified lines
  - All lines of untracked files are marked as added
- Place the cursor inside a change hunk and press `<leader>d` to pop up a full
  diff preview of that hunk (with context and diff syntax highlighting); press
  `q` or `Esc` to close

## Statusline Git Blame

After the cursor rests for about 1 second (`updatetime=1000`), the right side
of the statusline shows the blame information for the current line:

```
 [Author 2024-01-15 Commit summary…]
```

The same line is not queried repeatedly; uncommitted changes show
`[Not committed]`.

## Buffer Switcher Bar (`<leader>b`)

Pops up a horizontal buffer bar at the bottom, where each buffer gets a
two-letter identifier (green = switch to it, red = close it). Identifiers are
assigned in the order `a b c ... z aa bb ...`.

| Key | Action |
|-----|--------|
| `Tab` / `Shift-Tab` | Cycle through buffers (takes effect immediately) |
| Letter keys | Filter by identifier; when only one candidate remains, the switch/close executes immediately |
| Enter | Switch to the currently selected buffer; if the input exactly matches an identifier, that action is executed |
| Backspace | Delete input |
| `Esc` | Close |

Buffers with unsaved changes have a `+` after their names and will not be
closed.

## Auto Completion

Based on Vim's built-in completion (no plugins needed):

- The completion menu pops up automatically when entering insert mode and on
  every printable character typed (except for `help` and `gitcommit`
  filetypes)
- Completion sources: current file, other buffers, dictionary, tags, include
  files, etc.
- `Ctrl-n` / `Ctrl-p` to move between candidates
- Omni completion (`Ctrl-x Ctrl-o`) is configured for HTML / CSS / JavaScript /
  TypeScript

## Other Editing Enhancements

- **Automatic indent detection**: 2-space indent by default; when opening a
  file, the first 100 lines are scanned and `shiftwidth`/`tabstop` are
  adjusted to the indentation width the file actually uses
- **Whitespace display** (toggle with `<leader>l`): Tab shown as `→`,
  leading/trailing spaces shown as dark gray `·`, and nbsp shown as `␣`
- **External file changes**: `autoread` is enabled; checks happen when the
  cursor rests, when switching buffers, or when the window gains focus. If both
  disk and Vim have modifications, a popup asks:
  - `Y`: overwrite the disk with Vim's contents
  - `N`: discard Vim's changes and load the latest contents from disk
  - `Esc`: leave it for now; ask again next time
- **Search**: highlight search results (`hlsearch`), incremental search
  (`incsearch`)
- **Interface**: line numbers, file name at the top of each window (winbar),
  always-visible statusline with modified marker `[+]`, and reports for any
  number of lines changed (`report=0`)
- **Path lookup**: `path` includes `**`, so with `set wildmenu` you can use
  `:find` to look up files recursively; `<leader>p` takes the word under the
  cursor, strips slashes, and runs `:find`
