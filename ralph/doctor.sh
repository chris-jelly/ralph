#!/bin/bash
set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASS="${GREEN}PASS${NC}"
FAIL="${RED}FAIL${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Path constants for .ralph/ structure
RALPH_REPO_DIR="${RALPH_REPO_DIR:-.ralph}"
RALPH_CONFIG="${RALPH_CONFIG:-$RALPH_REPO_DIR/config}"
RALPH_PLANS_DIR="${RALPH_PLANS_DIR:-$RALPH_REPO_DIR/plans}"

# Try to find repo root
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    REPO_ROOT="$(git rev-parse --show-toplevel)"
else
    # Fallback for when not in git (unlikely for Ralph but possible)
    REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

echo "Running Ralph Doctor..."
echo "  Script: $SCRIPT_DIR"
echo "  Root:   $REPO_ROOT"
echo "----------------------------------------"

FAILED=0

# Helper to report failure with a suggestion
report_fail() {
    echo -e "[$FAIL] $1"
    if [ -n "${2:-}" ]; then
        echo "       Hint: $2"
    fi
    FAILED=1
}

# 1. ralph.sh exists and executable
if [[ -x "$SCRIPT_DIR/ralph.sh" ]]; then
    echo -e "[$PASS] ralph.sh is executable"
else
    if [[ -f "$SCRIPT_DIR/ralph.sh" ]]; then
        report_fail "ralph.sh is not executable" "Run: chmod +x $SCRIPT_DIR/ralph.sh"
    else
        report_fail "ralph.sh not found in $SCRIPT_DIR" "Re-run install.sh"
    fi
fi

# 2. AGENTS.md exists
if [[ -f "$SCRIPT_DIR/AGENTS.md" ]]; then
    echo -e "[$PASS] AGENTS.md exists"
else
    report_fail "AGENTS.md not found in $SCRIPT_DIR" "Re-run install.sh or copy AGENTS.md manually"
fi

# 3. AGENTS_plan.md exists (required for plan mode)
if [[ -f "$SCRIPT_DIR/AGENTS_plan.md" ]]; then
    echo -e "[$PASS] AGENTS_plan.md exists"
else
    report_fail "AGENTS_plan.md not found in $SCRIPT_DIR" "Re-run install.sh"
fi

# 4. AGENTS_summary.md exists (required for summary mode)
if [[ -f "$SCRIPT_DIR/AGENTS_summary.md" ]]; then
    echo -e "[$PASS] AGENTS_summary.md exists"
else
    report_fail "AGENTS_summary.md not found in $SCRIPT_DIR" "Re-run install.sh"
fi

# 5. .ralph/config exists
if [[ -f "$REPO_ROOT/$RALPH_CONFIG" ]]; then
    echo -e "[$PASS] $RALPH_CONFIG exists"
else
    report_fail "$RALPH_CONFIG not found" "Run: ralph init or create the config file"
fi

# 6. .ralph/plans/ directory exists and is writable
if [[ -d "$REPO_ROOT/$RALPH_PLANS_DIR" ]]; then
    if [[ -w "$REPO_ROOT/$RALPH_PLANS_DIR" ]]; then
        echo -e "[$PASS] $RALPH_PLANS_DIR/ exists and is writable"
    else
        report_fail "$RALPH_PLANS_DIR/ is not writable" "Fix permissions: chmod +w $REPO_ROOT/$RALPH_PLANS_DIR"
    fi
else
    report_fail "$RALPH_PLANS_DIR directory not found" "Create it with: ralph init or mkdir -p $REPO_ROOT/$RALPH_PLANS_DIR"
fi

# 7. .ralph/.gitignore exists with nested ignore pattern
RALPH_GITIGNORE="$REPO_ROOT/$RALPH_REPO_DIR/.gitignore"
if [[ -f "$RALPH_GITIGNORE" ]]; then
    if grep -q '\*' "$RALPH_GITIGNORE" && grep -q 'config' "$RALPH_GITIGNORE" && grep -q '^[!][.]gitignore$' "$RALPH_GITIGNORE"; then
        echo -e "[$PASS] .ralph/.gitignore has nested ignore pattern"
    else
        report_fail ".ralph/.gitignore missing nested ignore pattern" "Should contain: *, !config, !.gitignore"
    fi
else
    report_fail ".ralph/.gitignore not found" "Run: ralph init to create it with nested ignore pattern"
fi

# Load configuration if exists
if [ -f "$REPO_ROOT/$RALPH_CONFIG" ] || [ -f "$SCRIPT_DIR/ralph.conf" ]; then
    if [ -f "$REPO_ROOT/$RALPH_CONFIG" ]; then
        source "$REPO_ROOT/$RALPH_CONFIG"
    elif [ -f "$SCRIPT_DIR/ralph.conf" ]; then
        source "$SCRIPT_DIR/ralph.conf"
    fi
fi

# 8. CLI Tool
TOOL="${RALPH_TOOL:-opencode}"
if command -v "$TOOL" >/dev/null 2>&1; then
    echo -e "[$PASS] Tool '$TOOL' is installed"
else
    report_fail "Tool '$TOOL' not found in PATH" "Install '$TOOL' or set RALPH_TOOL environment variable"
fi

# 9. ralph.sh runs
if [[ -x "$SCRIPT_DIR/ralph.sh" ]]; then
    if "$SCRIPT_DIR/ralph.sh" --help >/dev/null 2>&1; then
        echo -e "[$PASS] ralph.sh runs successfully"
    else
        report_fail "ralph.sh failed to run" "Try running '$SCRIPT_DIR/ralph.sh --help' to debug"
    fi
fi

# 10. .ralph/plans/implementation_plan.md (informational only)
if [[ -f "$REPO_ROOT/$RALPH_PLANS_DIR/implementation_plan.md" ]]; then
    echo -e "[$PASS] implementation_plan.md exists"
else
    echo "[INFO] implementation_plan.md not found (optional: create for plan mode)"
fi

# 11. specs/ directory and README.md
if [[ -d "$REPO_ROOT/specs" ]]; then
    if [[ -f "$REPO_ROOT/specs/README.md" ]]; then
        echo -e "[$PASS] Specs configured (specs/README.md exists)"
    else
        report_fail "specs/ exists but missing README.md index" "Create specs/README.md for proper spec documentation"
    fi
else
    report_fail "specs/ directory not found" "Create specs/ directory and specs/README.md for project specifications"
fi

# 12. Model Configuration (informational)
echo "----------------------------------------"
echo "Model Configuration:"

MODELS_DISPLAYED=0

# Display mode-specific models if set
if [[ -n "${RALPH_PLAN_MODEL:-}" ]]; then
    echo "  RALPH_PLAN_MODEL: $RALPH_PLAN_MODEL"
    MODELS_DISPLAYED=1
    # Warn if contains spaces
    if [[ "$RALPH_PLAN_MODEL" =~ [[:space:]] ]]; then
        echo -e "  ${RED}WARNING${NC}: Model string contains spaces (invalid)"
    fi
fi

if [[ -n "${RALPH_BUILD_MODEL:-}" ]]; then
    echo "  RALPH_BUILD_MODEL: $RALPH_BUILD_MODEL"
    MODELS_DISPLAYED=1
    # Warn if contains spaces
    if [[ "$RALPH_BUILD_MODEL" =~ [[:space:]] ]]; then
        echo -e "  ${RED}WARNING${NC}: Model string contains spaces (invalid)"
    fi
fi

if [[ -n "${RALPH_REVIEW_MODEL:-}" ]]; then
    echo "  RALPH_REVIEW_MODEL: $RALPH_REVIEW_MODEL"
    MODELS_DISPLAYED=1
    # Warn if contains spaces
    if [[ "$RALPH_REVIEW_MODEL" =~ [[:space:]] ]]; then
        echo -e "  ${RED}WARNING${NC}: Model string contains spaces (invalid)"
    fi
fi

# Display global fallback if set
if [[ -n "${RALPH_MODEL:-}" ]]; then
    echo "  RALPH_MODEL (global fallback): $RALPH_MODEL"
    MODELS_DISPLAYED=1
    # Warn if contains spaces
    if [[ "$RALPH_MODEL" =~ [[:space:]] ]]; then
        echo -e "  ${RED}WARNING${NC}: Model string contains spaces (invalid)"
    fi
fi

if [[ $MODELS_DISPLAYED -eq 0 ]]; then
    echo "  (none configured - using tool defaults)"
fi

echo "  Fallback chain: RALPH_<MODE>_MODEL → RALPH_MODEL → tool default"

if [[ "$FAILED" -eq 0 ]]; then
    echo "----------------------------------------"
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
else
    echo "----------------------------------------"
    echo -e "${RED}Doctor found issues.${NC}"
    exit 1
fi
