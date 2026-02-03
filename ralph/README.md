# Ralph - Autonomous AI Agent Loop

Ralph is an autonomous coding agent that implements PRD user stories iteratively using AI coding tools.

## Quick Start

1. **Write specs** in `specs/` (optional but recommended)
2. **Create implementation plan** in `plans/implementation_plan.md` (interactive with your goals)
3. **Run plan mode**: `./ralph.sh plan` to generate `plans/prd.json`
4. **Review the PRD** and adjust stories if needed
5. **Run build mode**: `./ralph.sh` to implement the stories
6. **Optionally run summary mode**: `./ralph.sh summary` to suggest spec improvements

## How It Works

Ralph supports three modes for different phases of development:

### Three-Layer Model

1. **Specs (`specs/`)** - Human-curated documentation for project context
2. **Implementation Plan (`plans/implementation_plan.md`)** - Your interactive goal document
3. **PRD (`plans/prd.json`)** - AI-generated breakdown into actionable user stories

### Plan Mode

Reads your implementation plan and specs, searches the codebase to determine what exists vs. what's missing, then generates `plans/prd.json` with prioritized user stories. Also updates `implementation_plan.md` with findings.

**Does NOT:**
- Modify source code files
- Modify anything in `specs/`

### Build Mode

Implements the PRD iteratively. Each iteration:
1. Reads `plans/prd.json` for user stories
2. Implements the highest priority incomplete story
3. Runs quality checks (typecheck, lint, test)
4. Commits changes with format: `feat: [Story ID] - [Story Title]`
5. Updates the PRD to mark story as complete
6. Logs progress to `plans/progress.txt`

When all stories have `passes: true`, Ralph outputs `<promise>COMPLETE</promise>` and exits.

### Summary Mode

Analyzes a completed run and suggests improvements to your specs. Reads `plans/progress.txt`, `plans/prd.json`, and relevant `specs/*.md` files, then generates `plans/suggested_spec_changes.md` with recommendations.

**Does NOT:**
- Modify source code files
- Modify anything in `specs/`

## Specifications

The `specs/` directory contains human-curated project documentation that AI agents read selectively. This provides project-specific context without loading unnecessary files.

**How it works:**
- `specs/README.md` acts as an index that lists all specs organized by section with markdown tables
- Ralph reads specifications **selectively** based on the current story context (not all files at once)
- Ralph **never edits** specification files - they are human-maintained only

**Example structure:**
```
specs/
├── README.md                   # Index file - sections with tables listing specs and their purpose
├── api-patterns.md             # Read when working on API endpoints
├── ui-components.md            # Read when modifying UI code
└── database-schema.md          # Read when working on data models
```

## Usage

```bash
# Build mode (default) - implements PRD stories
./ralph.sh                 # Max 10 iterations
./ralph.sh 20             # Max 20 iterations

# Plan mode - reads implementation plan, generates PRD
./ralph.sh plan           # Max 10 iterations
./ralph.sh plan 5         # Max 5 iterations

# Summary mode - suggests spec improvements from completed run
./ralph.sh summary        # Single iteration

# Help
./ralph.sh --help
```

## Files

- `ralph.sh` - Main loop script
- `AGENTS.md` - Instructions given to each AI agent instance
- `prd.json.example` - Example PRD format
- `plans/prd.json` - Your project's PRD (you create this)
- `plans/progress.txt` - Auto-generated progress log
- `plans/archive/` - Archived PRDs from previous runs

## PRD Format

See `prd.json.example` for the complete format. Key fields:

```json
{
  "project": "Project Name",
  "branchName": "feature/branch-name",
  "description": "What this PRD accomplishes",
  "userStories": [
    {
      "id": "US-001",
      "title": "Story title",
      "description": "As a user, I want...",
      "acceptanceCriteria": ["Criterion 1", "Criterion 2"],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
```

## Tips

- **Keep stories small** - Each story should complete in one context window
- **Use acceptance criteria** - Clear, testable criteria help the AI know when it's done
- **Monitor progress.txt** - Check the "Learnings" sections for patterns discovered
- **Set realistic iterations** - Complex PRDs may need 15-20+ iterations

## Memory & Context

Ralph maintains memory across iterations through:

1. **Git history** - Each story is a separate commit
2. **`plans/progress.txt`** - Running log of what was done and learned
3. **`plans/prd.json`** - Updated `passes` status for each story
4. **Codebase Patterns suggestions** - Optional blocks embedded in progress entries

Each AI instance starts fresh with clean context, but these files provide continuity.

## Advanced

### Archiving

**Plan mode**: Always archives existing `plans/prd.json` and `plans/progress.txt` to `plans/archive/` before starting, creating a fresh planning cycle.

**Build mode**: When you start a new PRD (different `branchName`), Ralph automatically archives the previous run to `plans/archive/YYYY-MM-DD-branch-name/`.

### Quality Checks

Ralph expects your project to have quality checks. The AI will run whatever checks make sense for your project (e.g., `npm run typecheck`, `pytest`, `cargo test`).

## Troubleshooting

**Ralph keeps failing on the same story:**
- Check `plans/progress.txt` for error patterns
- Story might be too large - break it into smaller stories
- Acceptance criteria might be unclear or contradictory

**Ralph says COMPLETE but stories aren't done:**
- Check that PRD file is valid JSON
- Ensure `passes` field exists for each story
- Verify `plans/prd.json` path is correct

**No progress file generated:**
- Ensure `plans/` directory exists
- Check ralph.sh has execute permissions: `chmod +x ralph.sh`
- Verify you're in a git repository
