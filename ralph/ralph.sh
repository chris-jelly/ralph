#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop for OpenCode
# Usage: ./ralph.sh [max_iterations]

set -e

MAX_ITERATIONS=10

if [[ $# -gt 0 && "$1" =~ ^[0-9]+$ ]]; then
  MAX_ITERATIONS="$1"
fi

if [[ "$1" == "--help" ]]; then
  echo "Usage: ./ralph.sh [max_iterations]"
  echo "Runs the Ralph agent loop."
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/../..")"
PLANS_DIR="$REPO_ROOT/plans"
PRD_FILE="$PLANS_DIR/prd.json"
PROGRESS_FILE="$PLANS_DIR/progress.txt"
ARCHIVE_DIR="$PLANS_DIR/archive"
LAST_BRANCH_FILE="$PLANS_DIR/.last-branch"

if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")
  
  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    DATE=$(date +%Y-%m-%d)
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"
    
    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "   Archived to: $ARCHIVE_FOLDER"
    
    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

# Tool selection
TOOL="${RALPH_TOOL:-opencode}"

# Validate tool
case "$TOOL" in
  opencode|claude|codex)
    ;;
  *)
    echo "Error: Unknown tool '$TOOL'. Supported tools: opencode, claude, codex" >&2
    exit 1
    ;;
esac

echo "Starting Ralph using $TOOL - Max iterations: $MAX_ITERATIONS"

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "==============================================================="
  echo "  Ralph Iteration $i of $MAX_ITERATIONS"
  echo "==============================================================="

  AGENT_PROMPT="$(cat "$SCRIPT_DIR/AGENTS.md")"

  case "$TOOL" in
    opencode)
      OUTPUT=$(opencode run "$AGENT_PROMPT" 2>&1 | tee /dev/stderr) || true
      ;;
    claude)
      OUTPUT=$(claude code --message "$AGENT_PROMPT" 2>&1 | tee /dev/stderr) || true
      ;;
    codex)
      OUTPUT=$(codex exec "$AGENT_PROMPT" 2>&1 | tee /dev/stderr) || true
      ;;
  esac
  
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Ralph completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi
  
  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
