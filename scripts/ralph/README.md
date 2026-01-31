# Ralph - Autonomous AI Agent Loop

Ralph is an autonomous coding agent that implements PRD user stories iteratively using AI coding tools.

## Quick Start

1. **Create a PRD** in `plans/prd.json` (use `prd.json.example` as template)
2. **Run Ralph**: `./ralph.sh [max_iterations]`
3. **Monitor progress** in `plans/progress.txt`

## How It Works

Ralph spawns fresh AI agent instances (OpenCode by default) in a loop. Each iteration:

1. Reads `plans/prd.json` for user stories
2. Implements the highest priority incomplete story
3. Runs quality checks (typecheck, lint, test)
4. Commits changes with format: `feat: [Story ID] - [Story Title]`
5. Updates the PRD to mark story as complete
6. Logs progress to `plans/progress.txt`

When all stories have `passes: true`, Ralph outputs `<promise>COMPLETE</promise>` and exits.

## Usage

```bash
# Run with default max iterations (10)
./ralph.sh

# Run with custom max iterations
./ralph.sh 20
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
4. **Codebase Patterns** - Consolidated learnings at the top of progress.txt

Each AI instance starts fresh with clean context, but these files provide continuity.

## Advanced

### Archiving

When you start a new PRD (different `branchName`), Ralph automatically archives the previous run to `plans/archive/YYYY-MM-DD-branch-name/`.

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
