# Installation

This spec defines the supported installation model(s) for Ralph.

## Global install (recommended)

Install Ralph once and make `ralph` available on `PATH`.

Recommended defaults:

- Code: `~/.local/share/ralph/`
- Executable symlink: `~/.local/bin/ralph`

Update flow when installed from git:

- `git -C ~/.local/share/ralph pull`

## Repo-local initialization

Repos should contain:

- `specs/` (tracked)
- `.ralph/` (tracked config + ignored working state; see `specs/repo-layout.md`)
