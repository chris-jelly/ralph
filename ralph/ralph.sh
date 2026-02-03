#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop for OpenCode
# Usage: ./ralph.sh [build] [max_iterations]
# Usage: ./ralph.sh plan [max_iterations]
# Usage: ./ralph.sh summary

set -e

MODE="build"
MAX_ITERATIONS="${RALPH_MAX_ITERATIONS:-10}"

if [[ $# -gt 0 ]]; then
  case "$1" in
    --help)
      echo "Usage: ./ralph.sh [build] [max_iterations]"
      echo "       ./ralph.sh plan [max_iterations]"
      echo "       ./ralph.sh summary"
      echo ""
      echo "Modes:"
      echo "  build     Build mode: Run AI coding loop to implement PRD (default)"
      echo "  plan      Plan mode: Read specs/ and generate prd.json (archives first)"
      echo "  summary   Summary mode: Generate suggested spec changes (one shot)"
      echo ""
      echo "Arguments:"
      echo "  max_iterations  Maximum loop iterations (default: 10)"
      echo ""
      echo "Examples:"
      echo "  ./ralph.sh"
      echo "  ./ralph.sh 20"
      echo "  ./ralph.sh plan"
      echo "  ./ralph.sh plan 5"
      echo "  ./ralph.sh summary"
      exit 0
      ;;
    plan|summary)
      MODE="$1"
      ;;
    build|[0-9]*)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
      fi
      ;;
    *)
      echo "Error: Unknown mode '$1'" >&2
      echo "Use --help for usage information" >&2
      exit 1
      ;;
  esac
fi

if [[ $# -gt 1 ]] && [[ "$2" =~ ^[0-9]+$ ]]; then
  MAX_ITERATIONS="$2"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/../..")"

# Path constants for .ralph/ structure
RALPH_REPO_DIR="${RALPH_REPO_DIR:-.ralph}"
RALPH_CONFIG="${RALPH_CONFIG:-$RALPH_REPO_DIR/config}"
RALPH_PLANS_DIR="${RALPH_PLANS_DIR:-$RALPH_REPO_DIR/plans}"

# File paths
PRD_FILE="$REPO_ROOT/$RALPH_PLANS_DIR/prd.json"
PROGRESS_FILE="$REPO_ROOT/$RALPH_PLANS_DIR/progress.txt"
ARCHIVE_DIR="$REPO_ROOT/$RALPH_PLANS_DIR/archive"
LAST_BRANCH_FILE="$REPO_ROOT/$RALPH_PLANS_DIR/.last-branch"
RALPH_CONFIG_FILE="$REPO_ROOT/$RALPH_CONFIG"

# Legacy path constant for backward compatibility (deprecated)
PLANS_DIR="$REPO_ROOT/$RALPH_PLANS_DIR"

# Determine path fallback for backward compatibility
# Check for new .ralph/ paths first, fall back to legacy paths if they don't exist
use_legacy_paths=false
if [ ! -d "$REPO_ROOT/$RALPH_PLANS_DIR" ] && [ -d "$REPO_ROOT/plans" ]; then
  use_legacy_paths=true
  LEGACY_PLANS_DIR="$REPO_ROOT/plans"
  LEGACY_CONFIG_FILE="$SCRIPT_DIR/ralph.conf"
fi

# Set file paths based on legacy detection
if [ "$use_legacy_paths" = true ]; then
  PRD_FILE="$LEGACY_PLANS_DIR/prd.json"
  PROGRESS_FILE="$LEGACY_PLANS_DIR/progress.txt"
  ARCHIVE_DIR="$LEGACY_PLANS_DIR/archive"
  LAST_BRANCH_FILE="$LEGACY_PLANS_DIR/.last-branch"
else
  PRD_FILE="$REPO_ROOT/$RALPH_PLANS_DIR/prd.json"
  PROGRESS_FILE="$REPO_ROOT/$RALPH_PLANS_DIR/progress.txt"
  ARCHIVE_DIR="$REPO_ROOT/$RALPH_PLANS_DIR/archive"
  LAST_BRANCH_FILE="$REPO_ROOT/$RALPH_PLANS_DIR/.last-branch"
fi

# Load configuration if exists (checked in both old and new locations)
if [ -f "$REPO_ROOT/$RALPH_CONFIG" ] || [ -f "$SCRIPT_DIR/ralph.conf" ]; then
  if [ -f "$REPO_ROOT/$RALPH_CONFIG" ]; then
    source "$REPO_ROOT/$RALPH_CONFIG"
  elif [ -f "$SCRIPT_DIR/ralph.conf" ]; then
    source "$SCRIPT_DIR/ralph.conf"
  fi
fi

# Plan mode: archive existing files and reset progress
if [ "$MODE" = "plan" ]; then
  DATE=$(date +%Y-%m-%d-%H%M%S)
  ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-plan-mode"
  
  echo "Archiving existing files for plan mode..."
  mkdir -p "$ARCHIVE_FOLDER"
  [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/" && echo "   Archived: prd.json"
  [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/" && echo "   Archived: progress.txt"
  
  echo "Resetting progress log for new planning cycle..."
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started (plan mode): $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

# Build mode: archive if branch changed
if [ "$MODE" = "build" ] && [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
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

if [ "$MODE" != "summary" ] && [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  MODE_NAME="$MODE"
  [ -z "$MODE_NAME" ] && MODE_NAME="build"
  echo "Started ($MODE_NAME mode): $(date)" >> "$PROGRESS_FILE"
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

# Select AGENTS file based on mode
case "$MODE" in
  plan)
    AGENTS_FILE="$SCRIPT_DIR/AGENTS_plan.md"
    MODE_DISPLAY="plan"
    ;;
  summary)
    AGENTS_FILE="$SCRIPT_DIR/AGENTS_summary.md"
    MODE_DISPLAY="summary"
    ;;
  *)
    AGENTS_FILE="$SCRIPT_DIR/AGENTS.md"
    MODE_DISPLAY="build"
    ;;
esac

echo "Starting Ralph ($MODE_DISPLAY mode) using $TOOL"

# Summary mode: run once
if [ "$MODE" = "summary" ]; then
  echo ""
  echo "==============================================================="
  echo "  Ralph Summary Mode"
  echo "==============================================================="
  
  AGENT_PROMPT="$(cat "$AGENTS_FILE")"
  
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
  
  echo ""
  echo "Summary mode complete."
  exit 0
fi

# Build and plan modes: run loop
echo "Max iterations: $MAX_ITERATIONS"

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "==============================================================="
  echo "  Ralph Iteration $i of $MAX_ITERATIONS ($MODE_DISPLAY mode)"
  echo "==============================================================="

  AGENT_PROMPT="$(cat "$AGENTS_FILE")"

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
    echo "Agent signaled COMPLETE. Verifying PRD..."
    
    # Verify all stories actually pass in prd.json
    if command -v jq &>/dev/null && [ -f "$PRD_FILE" ]; then
      INCOMPLETE=$(jq '[.userStories[] | select(.passes != true)] | length' "$PRD_FILE" 2>/dev/null || echo "")
      if [ -n "$INCOMPLETE" ] && [ "$INCOMPLETE" -gt 0 ]; then
        echo "WARNING: Agent claimed COMPLETE but $INCOMPLETE story(ies) still have passes != true in prd.json"
        echo "Continuing iterations..."
        sleep 2
        continue
      fi
      echo "Verified: all stories pass in prd.json"
    else
      echo "Note: jq not available or prd.json missing, skipping verification"
    fi
    
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
