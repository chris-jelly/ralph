#!/bin/bash
set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASS="${GREEN}PASS${NC}"
FAIL="${RED}FAIL${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# 3. plans/ directory exists
if [[ -d "$REPO_ROOT/plans" ]]; then
    echo -e "[$PASS] plans/ directory exists"
else
    report_fail "plans/ directory not found at $REPO_ROOT/plans" "Create it with: mkdir -p plans"
fi

# 4. .gitignore has Ralph entries
if [[ -f "$REPO_ROOT/.gitignore" ]]; then
    # Check for .claude/ or # Ralph
    if grep -qF ".claude/" "$REPO_ROOT/.gitignore" || grep -qF "# Ralph" "$REPO_ROOT/.gitignore"; then
        echo -e "[$PASS] .gitignore contains Ralph entries"
    else
        report_fail ".gitignore missing Ralph entries" "Add '.claude/' and 'plans/archive/' to .gitignore"
    fi
else
    report_fail ".gitignore not found at repo root" "Create .gitignore and add Ralph entries"
fi

# Load configuration if exists
if [ -f "$SCRIPT_DIR/ralph.conf" ]; then
    source "$SCRIPT_DIR/ralph.conf"
fi

# 5. CLI Tool
TOOL="${RALPH_TOOL:-opencode}"
if command -v "$TOOL" >/dev/null 2>&1; then
    echo -e "[$PASS] Tool '$TOOL' is installed"
else
    report_fail "Tool '$TOOL' not found in PATH" "Install '$TOOL' or set RALPH_TOOL environment variable"
fi

# 6. ralph.sh runs
if [[ -x "$SCRIPT_DIR/ralph.sh" ]]; then
    if "$SCRIPT_DIR/ralph.sh" --help >/dev/null 2>&1; then
        echo -e "[$PASS] ralph.sh runs successfully"
    else
        report_fail "ralph.sh failed to run" "Try running '$SCRIPT_DIR/ralph.sh --help' to debug"
    fi
fi

if [[ "$FAILED" -eq 0 ]]; then
    echo "----------------------------------------"
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
else
    echo "----------------------------------------"
    echo -e "${RED}Doctor found issues.${NC}"
    exit 1
fi
