# Architecture

## Core Constraint: Stateless Iterations

Each Ralph iteration spawns a fresh AI agent process with no shared memory. All persistence is through files and git. This is the foundational design constraint — everything else follows from it.

## Repository Layout

Ralph has a **distribution model**: source-of-truth files live in `ralph/`, and `install.sh` copies them into target repos (default: `scripts/ralph/`). When working on Ralph itself, `scripts/ralph/` is the local installation — a consumer copy, not the source.

```
ralph/              # Distribution files (SOURCE OF TRUTH)
  ralph.sh          # Agent loop orchestrator
  doctor.sh         # Installation health checks
  install.sh        # Sets up Ralph in target repos
  AGENTS.md         # Build-mode prompt
  AGENTS_plan.md    # Plan-mode prompt
  AGENTS_summary.md # Summary-mode prompt

scripts/ralph/      # Local installation (CONSUMER COPY, may be stale)

plans/              # Working directory (gitignored except .gitkeep)
  prd.json          # Current PRD — the contract between modes
  progress.txt      # Append-only log across iterations
  implementation_plan.md  # Human input for plan mode
  .last-branch      # Tracks current branch for archive detection
  archive/          # Timestamped snapshots of previous runs

specs/              # Human-curated specs (read-only for agents)

skills/             # Amp/Claude Code skills for PRD creation
flowchart/          # React Flow presentation app (deployed to GitHub Pages)
```

**Key rule:** Edit files in `ralph/`, not `scripts/ralph/`. The local installation must be re-synced manually after distribution file changes (no automation for this yet).

## Three Modes

Ralph operates in three sequential modes, each with its own AGENTS prompt file:

**Plan** (`AGENTS_plan.md`): Reads `implementation_plan.md` + specs, searches codebase, generates `prd.json`. No code changes. Always archives existing files first.

**Build** (`AGENTS.md`): Loops up to `MAX_ITERATIONS`. Each iteration picks the highest-priority incomplete story, implements it, runs checks, commits, marks it passing. Archives only on branch change.

**Summary** (`AGENTS_summary.md`): Single-shot. Reads progress.txt + prd.json from a completed build, outputs `suggested_spec_changes.md`. No code or spec changes.

## File Flow

```
Human writes:   implementation_plan.md, specs/*.md
Plan reads:     implementation_plan.md, specs/*.md, codebase
Plan writes:    prd.json, implementation_plan.md (findings section)

Build reads:    prd.json, progress.txt, specs/*.md (selectively)
Build writes:   source code, prd.json (passes:true), progress.txt (append, including optional Codebase Patterns suggestion blocks), git commits

Summary reads:  progress.txt (including Codebase Patterns suggestion blocks), prd.json, specs/*.md (selectively)
Summary writes: suggested_spec_changes.md

Human reviews:  suggested_spec_changes.md → updates specs manually
```

## Identity and Archiving

The `branchName` field in prd.json is the identity of a run. ralph.sh tracks it in `.last-branch`. Build mode archives (copies prd.json + progress.txt to `plans/archive/`) when it detects the branch name has changed. Plan mode always archives unconditionally on start — each plan invocation begins a fresh cycle.

## Tool Abstraction

ralph.sh supports multiple AI tools via `RALPH_TOOL` env var (default: `opencode`). Each tool has a different CLI invocation pattern:

- `opencode run "$PROMPT"` (Amp CLI, the default)
- `claude code --message "$PROMPT"` (Claude Code)
- `codex exec "$PROMPT"` (Codex)

The entire AGENTS markdown content is passed as a single prompt string. Prompts must be self-contained — no includes or external references.

## Specs Contract

The `specs/` directory is **read-only for all agents**. Only humans edit specs. Agents in all three modes are explicitly forbidden from modifying spec files. The summary mode produces _suggestions_ for spec changes in `plans/suggested_spec_changes.md`, which humans then review and apply.

`specs/README.md` acts as a routing index — agents read it to determine which spec files are relevant to their current task, then read only those files. This keeps token usage proportional to relevance rather than total spec volume.
