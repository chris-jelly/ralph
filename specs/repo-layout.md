# Repo Layout

This spec defines the canonical repo-local files Ralph uses, what is tracked in git vs transient, and how to keep git status clean.

## Canonical repo-local state: `.ralph/`

Ralph stores all per-repo state under a single directory at the repo root:

```
.ralph/
  config                 # Tracked: repo-specific configuration
  .gitignore              # Tracked: nested ignore rules (recommended)
  plans/                  # Not tracked: working state for plan/build/summary
    prd.json
    progress.txt
    suggested_spec_changes.md
    implementation_plan.md
    .last-branch
    archive/
  logs/                   # Not tracked: optional raw run logs
```

### Tracked vs transient

- Tracked in git:
  - `specs/`
  - `.ralph/config`
  - `.ralph/.gitignore`
- Not tracked in git (transient):
  - `.ralph/plans/**`
  - `.ralph/logs/**`

## Gitignore strategy

Preferred approach: nested ignore so the repo root `.gitignore` does not need changes.

Create `.ralph/.gitignore` with:

```
*
!config
!.gitignore
```

This ignores everything under `.ralph/` except `.ralph/config` and `.ralph/.gitignore`.

## Legacy layout (backward compatibility)

Older installs store state under:

```
scripts/ralph/            # Copied framework (old install style)
plans/                    # Working directory (gitignored)
```

During migration, the tool may support reading legacy locations when `.ralph/` is missing.
