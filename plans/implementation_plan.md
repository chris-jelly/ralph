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

## Findings

### Current State Assessment

**What Exists (Implemented):**
- Distribution files in `ralph/`: ralph.sh, doctor.sh, install.sh, AGENTS*.md
- Local installation in `scripts/ralph/` (consumer copy)
- Plans directory structure: `plans/` with prd.json, progress.txt, implementation_plan.md, archive/
- Specs directory: `specs/` with README.md index, architecture.md, conventions.md
- Three modes working: plan, build, summary
- Tool abstraction supports opencode, claude, codex via RALPH_TOOL env var
- Gitignore configured for old structure (plans/, .claude/)
- Test infrastructure exists: tests/ directory with standalone bash scripts

**What is Missing (Not Implemented):**
- `.ralph/` directory structure does not exist anywhere
- Path constants (RALPH_REPO_DIR, RALPH_PLANS_DIR, RALPH_CONFIG) not defined
- Global CLI wrapper (bin/ralph) does not exist
- `ralph init` subcommand not implemented
- `ralph migrate` subcommand not implemented
- `ralph self-update` subcommand not implemented
- migrate.sh distribution script does not exist
- curl bootstrap script does not exist
- install.sh creates scripts/ralph/ structure, not .ralph/
- install.sh modifies repo .gitignore
- No backward compatibility path fallback logic
- ralph.sh has hardcoded paths to plans/ directory
- AGENTS*.md files reference plans/ not .ralph/plans/
- doctor.sh validates plans/ and old structure, not .ralph/
- No tests for new functionality (init, migration, path resolution, backward compat)

**Key Discovery Points:**
1. Current structure uses hardcoded paths throughout (plans/, scripts/ralph/)
2. No separation of global tool vs per-repo state - everything is copied into each repo
3. install.sh modifies repo .gitignore with multiple entries, not clean nested approach
4. No detection or migration logic for old installations
5. Tests exist but only cover basic functionality, none for new architecture

**Blockers Identified:**
- None identified - all work can proceed incrementally

**Recommended Implementation Order:**
Based on dependencies and risk:
1. US-001: Define path constants (foundation)
2. US-005: Update ralph.sh paths (engine core)
3. US-006: Update AGENTS prompts (agent contract)
4. US-002 + US-003: Create global CLI wrapper (entry point)
5. US-004: Implement ralph init (zero-friction setup)
6. US-007: Update doctor.sh (health checks)
7. US-008: Add backward compat fallback (safety net)
8. US-011: Update install.sh (distribution)
9. US-009: Create migrate.sh (migration safety)
10. US-010: Implement ralph migrate (user-friendly entry)
11. US-014-017: Create tests (confidence)
12. US-012, US-013: Add convenience features (optional)
13. US-018: Update documentation (finalize)

## Open Questions

1. Should `.ralph/config` be tracked in git by default (recommended) or remain local-only?
2. Should `.ralph/plans/implementation_plan.md` be tracked (shared) or kept ephemeral?
3. Do we want a stable “run id” written into commits (trailers) and/or into `.ralph/plans/progress.txt`?

## Acceptance Criteria

- A repo can run `ralph init` then `ralph plan/build/summary` without any copied `scripts/ralph/` directory.
- No required modifications to repo root `.gitignore` (nested ignore works).
- Working files live under `.ralph/` and do not pollute git status.
- Existing repos with `scripts/ralph/` continue to run, and `ralph migrate` offers a clean upgrade path.

## Relevant Specs

- specs/architecture.md - Stateless iterations, distribution model, three modes, file flows
- specs/conventions.md - Commit format, progress logging, quality checks, testing, branch naming
