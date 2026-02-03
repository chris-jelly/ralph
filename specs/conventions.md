# Conventions

## Commit Messages

Ralph-driven commits use: `feat: [Story ID] - [Story Title]`

Example: `feat: US-003 - Add path expansion support`

Manual/human commits use conventional commits loosely (`feat:`, `fix:`, `chore:`, etc.).

## Progress Logging

`plans/progress.txt` is **append-only**. Never replace the file contents, only append.

Each story entry follows this format:
```
## [Date/Time] - [Story ID]
- What was implemented
- Files changed
- **Learnings for future iterations:**
  - Patterns discovered
  - Gotchas encountered
  - Useful context

### Codebase Patterns Suggestions (optional)

<!-- RALPH_CODEBASE_PATTERNS_SUGGESTIONS_START -->
- Add: ...
- Update: ...
- Remove: ...
<!-- RALPH_CODEBASE_PATTERNS_SUGGESTIONS_END -->
---
```

### Codebase Patterns Suggestion Blocks

If you discover a reusable pattern that should be documented for future iterations, include a block in your story entry using the exact start/end markers so summary mode can reliably extract it.

Rules:
- Only include general, reusable patterns (not story-specific notes)
- Keep the text actionable (what to do / where / why)
- If you have no suggestions, omit the block entirely

## Quality Checks

Ralph agents must run quality checks before committing. What constitutes "quality checks" is project-specific. For the Ralph repo itself:
- Shell scripts: No formal linter configured; ensure `set -e` or `set -euo pipefail`
- Flowchart: `npm run build` in `flowchart/`
- Tests: Run individual test scripts in `tests/` manually (`bash tests/test_*.sh`)

## Testing

Tests live in `tests/` as standalone bash scripts. No test runner or CI for tests — run them directly. The GitHub Actions workflow only builds/deploys the flowchart.

## Distribution Sync

After changing files in `ralph/` (distribution source), the local installation at `scripts/ralph/` does not auto-update. Re-run install or manually copy changed files. This is a known manual step.

## Branch Naming

PRD branches use the `ralph/` prefix: `ralph/feature-name`. This prefix is stripped when creating archive folder names.
