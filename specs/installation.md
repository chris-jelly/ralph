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

The `.ralph/config` file can contain model configuration and other environment variables. Typical model configuration:

```bash
# Model configuration (fallback chain: RALPH_<MODE>_MODEL → RALPH_MODEL → tool default)
# export RALPH_PLAN_MODEL=claude-opus-4     # Smart model for planning
# export RALPH_BUILD_MODEL=codex-mini       # Cheap model for builds  
# export RALPH_REVIEW_MODEL=claude          # Review/summary mode
# export RALPH_MODEL=opencode-default       # Global fallback

# Uncomment and set the models you want to use
```

The fallback chain allows you to configure different models per mode (plan, build, review) while providing a global default. When no model is configured, each tool uses its own default.
