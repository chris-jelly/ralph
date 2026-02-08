# Implementation Plan: Per-Mode Model Configuration for Ralph

## Goal
Add support for configuring different AI models for each Ralph mode (build, plan, summary), allowing users to use cheaper models for planning and more capable models for building.

## Context
Currently, Ralph supports selecting the AI tool (opencode, claude, codex) via `RALPH_TOOL`, but doesn't allow specifying which model to use within each tool. All modes use the same model. Users may want to:
- Use cheaper/faster models for plan mode (generating PRDs)
- Use more capable models for build mode (actual implementation)
- Use specialized models for summary mode (analyzing and documenting)

## Relevant Specs
- None yet - this is a new feature

## Proposed Implementation

### Phase 1: Configuration Support
Add new environment variables to `.ralph/config`:
- `RALPH_BUILD_MODEL` - Model for build mode (default: tool's default)
- `RALPH_PLAN_MODEL` - Model for plan mode (default: tool's default)  
- `RALPH_SUMMARY_MODEL` - Model for summary mode (default: tool's default)

### Phase 2: Tool-Specific Model Flags
Update `ralph.sh` to pass model parameters to each tool:
- **OpenCode**: Uses `--model` flag or `OPENCODE_MODEL` env var
- **Claude Code**: Uses `--model` flag or `CLAUDE_CODE_MODEL` env var
- **Codex**: Uses `--model` flag or `CODEX_MODEL` env var

### Phase 3: Install Script Updates
Update `install.sh` to:
- Prompt for optional model configuration during setup
- Write model settings to `.ralph/config`

### Phase 4: Documentation
Update README and AGENTS.md to document the new configuration options.

## Acceptance Criteria
1. Users can set different models for build, plan, and summary modes
2. Configuration is stored in `.ralph/config` alongside existing settings
3. Each AI tool receives the correct model parameter
4. Backwards compatible - existing setups without model config continue to work
5. Doctor script validates model configuration if set

## Files to Modify
- `ralph/ralph.sh` - Add model parameter passing
- `ralph/install.sh` - Add model configuration prompts
- `ralph/doctor.sh` - Add model validation
- `ralph/AGENTS.md` - Document model configuration
- `ralph/README.md` - Update user documentation

## Notes
- Need to research exact model flag format for each tool
- Should validate that specified models are available/supported
- Consider adding a `--model` flag to ralph.sh for one-off overrides
