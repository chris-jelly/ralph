# Implementation Plan: Global Ralph + Per-Repo State

## Goal

Move Ralph from a per-repo copied framework (`scripts/ralph/`) to a global install (Linux/WSL-friendly) while preserving a traceable, repo-local history of Ralph activity and keeping transient state out of git with minimal `.gitignore` friction.

Target outcomes:

- Global install: `ralph` available on `PATH` and updatable without copying files into every repo.
- Repo traceability: activity leaves auditable artifacts in the repo (commits, specs updates, optional logs).
- Clean state: per-repo transient working files stored under `.ralph/` with either a single ignore rule or a nested `.gitignore`.
- Backward compatibility: existing repos with `scripts/ralph/` continue to work during migration.

## Non-Goals (for initial iteration)

- Ship official distro packages (deb/rpm/AUR) across distros.
- Add a full semantic versioning/release pipeline (can be added later).
- Rewrite prompts/agent flow beyond what’s needed for path changes and traceability.

## Current State (baseline)

- Framework files are copied into each repo (`scripts/ralph/`), and install appends many entries to the repo `.gitignore`.
- Transient working files live in `plans/` (gitignored) and `.claude/` (gitignored).
- Traceable history is mostly via commits and optional spec docs; planning artifacts are currently treated as ephemeral.

## Proposed Architecture

### Global install (tool)

Install location (recommended defaults):

- Code: `~/.local/share/ralph/` (or `/opt/ralph/` for system installs)
- Executable symlink: `~/.local/bin/ralph`

Install/update method:

- **Git clone + symlink** as primary.
- Optional: `curl` bootstrap script that performs the clone/symlink for users who want one-liner install.

### Per-repo files

Tracked in git:

- `specs/` (project knowledge)
- `.ralph/config` (repo-specific config; replacement for `scripts/ralph/ralph.conf`)
- Optional: `.ralph/README.md` (short “how to run Ralph here” note)

Not tracked in git (transient):

- `.ralph/plans/prd.json`
- `.ralph/plans/progress.txt`
- `.ralph/plans/implementation_plan.md` (if we keep this as a scratchpad)
- `.ralph/plans/archive/`
- `.ralph/plans/.last-branch`

Gitignore strategy (pick one):

1. **Single rule in repo `.gitignore`:** `.ralph/`
2. **Nested ignore (preferred for zero repo `.gitignore` edits):** create `.ralph/.gitignore` with:

   - `*`
   - `!config`
   - `!.gitignore`

This keeps only `.ralph/config` tracked by default.

## Traceability Design

The primary trace of “what Ralph did” remains:

- Git commits created during build mode (already traceable).

Add optional, lightweight traces:

- `.ralph/logs/` (ignored): raw execution logs, tool output, timestamps.
- Commit trailers (optional) added by the agent when committing:
  - `Ralph-Story: US123`
  - `Ralph-Run: <run-id>`

Keep `specs/` as the canonical, reviewed, repo-visible knowledge base. Summary mode can continue to propose spec changes, but those proposals can be written to `.ralph/` by default and optionally copied into `specs/` via a user command.

## Implementation Steps

### Phase 0: Decide the new repo-local paths

- Standardize on `.ralph/` at repo root.
- Define constants in the scripts:
  - `RALPH_REPO_DIR=.ralph`
  - `RALPH_PLANS_DIR=.ralph/plans`
  - `RALPH_CONFIG=.ralph/config`

### Phase 1: Add a global-entry CLI wrapper

Add a top-level executable script (e.g., `bin/ralph` or `ralph/cli.sh`) that:

- Resolves repo root (walk up until `.git/` found).
- Loads `.ralph/config` if present.
- Dispatches to existing modes: `plan`, `build`, `summary`, `doctor`, `init`, `migrate`.

Keep existing `ralph/ralph.sh` as the engine (or refactor it into a library sourced by the CLI).

### Phase 2: Implement `ralph init`

`ralph init` should:

- Create `specs/` and `specs/README.md` if missing (same templates as today).
- Create `.ralph/` structure:
  - `.ralph/config` (tool + iterations)
  - `.ralph/.gitignore` (nested ignore approach)
  - `.ralph/plans/` with initial placeholder files if helpful
- Avoid modifying repo root `.gitignore` by default.

### Phase 3: Repoint plan/build/summary to `.ralph/plans/`

Update runtime paths:

- `plans/prd.json` -> `.ralph/plans/prd.json`
- `plans/progress.txt` -> `.ralph/plans/progress.txt`
- `plans/archive/` -> `.ralph/plans/archive/`
- `plans/.last-branch` -> `.ralph/plans/.last-branch`
- `plans/implementation_plan.md` -> `.ralph/plans/implementation_plan.md`
- `plans/suggested_spec_changes.md` -> `.ralph/plans/suggested_spec_changes.md`

Update prompts (`AGENTS*.md`) to reference the new locations.

### Phase 4: Backward compatibility + migration

Add `ralph migrate` (or automatic detection):

- If `scripts/ralph/` exists and `.ralph/` does not, offer to:
  - Create `.ralph/` and move/copy config (`scripts/ralph/ralph.conf` -> `.ralph/config`)
  - Move `plans/` -> `.ralph/plans/` (optional; default copy)
  - Leave `scripts/ralph/` in place (do not delete automatically)

Add compatibility reads:

- If `.ralph/config` missing, fall back to `scripts/ralph/ralph.conf`.
- If `.ralph/plans/prd.json` missing, fall back to `plans/prd.json`.

#### Migration script (cleanup for old installs)

Create a standalone bash script intended to be run inside an existing target repo that previously installed Ralph the old way.

Proposed location in the Ralph repo:

- `ralph/migrate.sh` (distribution)

Script behavior:

- **Safety-first defaults:**
  - Support `--dry-run` (default on unless `--apply` is provided).
  - Support `--backup-dir <path>` (default `.ralph/migrate-backup/<timestamp>/`).
  - Never delete anything unless `--remove-old` is explicitly set.
  - Refuse to run if not inside a git repo (must find `.git/`).

- **Detect old layout:**
  - `scripts/ralph/` exists
  - `plans/` exists
  - `.gitignore` contains old Ralph entries

- **Create new layout if missing:**
  - `.ralph/`
  - `.ralph/.gitignore` (nested ignore pattern)
  - `.ralph/plans/`
  - `.ralph/config` (created from old `scripts/ralph/ralph.conf` if present, otherwise defaults)

- **Migrate working files (copy by default):**
  - If `plans/prd.json` exists, copy to `.ralph/plans/prd.json`
  - If `plans/progress.txt` exists, copy to `.ralph/plans/progress.txt`
  - If `plans/implementation_plan.md` exists, copy to `.ralph/plans/implementation_plan.md`
  - If `plans/suggested_spec_changes.md` exists, copy to `.ralph/plans/suggested_spec_changes.md`
  - If `plans/archive/` exists, copy to `.ralph/plans/archive/`
  - If `plans/.last-branch` exists, copy to `.ralph/plans/.last-branch`

- **Handle tracked files carefully:**
  - Leave `plans/.gitkeep` alone by default (do not delete or move tracked files).
  - If a repo has committed old framework files under `scripts/ralph/`, do not delete them automatically.

- **Gitignore cleanup (optional):**
  - With `--fix-gitignore`, remove old Ralph plan entries added by the old installer and optionally add a single `.ralph/` rule (only if nested ignore is not used).
  - Make changes reversible by writing a backup copy of `.gitignore` into the backup dir.

- **Optional old install cleanup:**
  - With `--remove-old`, move old directories into the backup dir rather than deleting:
    - `scripts/ralph/` -> `<backup>/scripts/ralph/`
    - `plans/` (only untracked/ignored files) -> `<backup>/plans/`
  - Print a post-run summary showing what was moved/copied and what remains.

CLI interface sketch:

```bash
# show what would change
./migrate.sh --dry-run

# perform migration safely, keep old files
./migrate.sh --apply

# migrate and also clean up old directories (by moving to backup)
./migrate.sh --apply --remove-old

# also clean up repo .gitignore entries
./migrate.sh --apply --fix-gitignore
```

### Phase 5: Linux/WSL installation docs and scripts

Provide two install paths:

1. **Git clone + symlink**
   - Clone `snarktank/ralph` to `~/.local/share/ralph`
   - Symlink `~/.local/bin/ralph` -> `~/.local/share/ralph/<path-to-cli>`

2. **Curl bootstrap (optional)**
   - Downloads a small installer that performs the above
   - Never auto-runs remote code beyond the installer itself

Document WSL considerations:

- Use Linux home directories for tool install.
- Ensure `~/.local/bin` is on PATH in `.bashrc`/`.zshrc`.

### Phase 6: Doctor updates

Update `doctor` to validate:

- Repo root contains `.ralph/config`
- `.ralph/plans/` exists and is writable
- Selected tool (`opencode`/`claude`/`codex`) is on PATH
- `specs/README.md` exists

### Phase 7: Tests

Update/extend bash tests to cover:

- `ralph init` idempotency
- Path resolution to repo root
- Backward compat path fallback
- `.ralph/.gitignore` behavior (only config tracked)

### Phase 8: Release/Update story

For global install via git clone:

- Update = `git -C ~/.local/share/ralph pull`

Optionally add:

- `ralph self-update` that runs the above when installed from git.

## Open Questions

1. Should `.ralph/config` be tracked in git by default (recommended) or remain local-only?
2. Should `.ralph/plans/implementation_plan.md` be tracked (shared) or kept ephemeral?
3. Do we want a stable “run id” written into commits (trailers) and/or into `.ralph/plans/progress.txt`?

## Acceptance Criteria

- A repo can run `ralph init` then `ralph plan/build/summary` without any copied `scripts/ralph/` directory.
- No required modifications to repo root `.gitignore` (nested ignore works).
- Working files live under `.ralph/` and do not pollute git status.
- Existing repos with `scripts/ralph/` continue to run, and `ralph migrate` offers a clean upgrade path.
