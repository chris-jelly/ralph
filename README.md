# Ralph

![Ralph](ralph.webp)


This is a fork of [snarktank/ralph](https://github.com/snarktank/ralph), originally based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/). This fork contains significant changes and additions, some of them may even be useful.

## Safety Warning

**Running Ralph outside a sandbox environment is dangerous.** Ralph spawns autonomous AI agents that execute code, modify files, and run shell commands repeatedly without human intervention. Depending on your Codex/Opencode settings (especially auto-approval modes), this can have unintended consequences.

**Recommended:** Run Ralph inside an isolated environment. [DevPod](https://devpod.sh/) is one option for quickly spinning up disposable dev containers.

See the [DevPod CLI quickstart](https://devpod.sh/docs/quickstart/devpod-cli) for more options.

## Prerequisites

- One of the following AI coding tools installed and authenticated:
  - [Codex CLI](https://github.com/openai/codex) (default)
  - [Opencode](https://github.com/anomalyco/opencode) (`npm install -g @anomalyco/opencode`)
- `jq` installed 
- A git repository for your project

## Setup

```bash
# Clone Ralph
git clone https://github.com/chris-jelly/ralph.git
cd ralph

# Install into your project
./ralph/install.sh --target /path/to/your/project
```

The installer supports `~` expansion, environment variables, and relative paths.

## Workflow

1. **Create a PRD**
   ```
   Load the prd skill and create a PRD for [your feature]
   ```

2. **Convert to Ralph format**
   ```
   Load the ralph skill and convert tasks/prd-[name].md to prd.json
   ```

3. **Run Ralph**
   ```bash
   # Using Codex (default)
   ./scripts/ralph/ralph.sh [max_iterations]

   # Using Opencode
   ./scripts/ralph/ralph.sh --tool opencode [max_iterations]
   ```

## Key Files

| File | Purpose |
|------|---------|
| `ralph.sh` | The bash loop that spawns fresh AI instances |
| `AGENTS.md` | Build-mode prompt |
| `AGENTS_plan.md` | Plan-mode prompt |
| `AGENTS_summary.md` | Summary-mode prompt |
| `prd.json` | User stories with `passes` status (the task list) |
| `plans/progress.txt` | Append-only learnings for future iterations |
| `skills/prd/` | Skill for generating PRDs |
| `skills/ralph/` | Skill for converting PRDs to JSON |

## Critical Concepts

- **Each iteration = Fresh context**: New AI instance, clean slate. Memory persists only in git, `progress.txt`, and `prd.json`.
- **Small tasks**: Each PRD item should complete in one context window.
- **Progress logging is critical**: After each iteration, Ralph appends to `plans/progress.txt`. This is the primary memory between iterations.
- **Feedback loops**: Typecheck, tests, and CI must stay green.

## Debugging

```bash
# See which stories are done
cat plans/prd.json | jq '.userStories[] | {id, title, passes}'

# See learnings from previous iterations
cat plans/progress.txt

# Check git history
git log --oneline -10
```

## References

- [Original Ralph article](https://ghuntley.com/ralph/)
- [Codex CLI](https://github.com/openai/codex)
- [Opencode documentation](https://opencode.ai)
