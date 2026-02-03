#!/bin/bash
set -u

# Test script for US-014: ralph init command
# Tests idempotency, .ralph/.gitignore behavior, and creation of required structure

cleanup() {
    if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}
trap cleanup EXIT

TEST_DIR=$(mktemp -d)
TEST_REPO="$TEST_DIR/test_repo"
RALPH_BIN="bin/ralph"

fail() {
    local msg="$1"
    echo "FAIL: $msg"
    exit 1
}

pass() {
    local msg="$1"
    echo "PASS: $msg"
}

# Find ralph binary (absolute path)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RALPH_BIN="$REPO_ROOT/bin/ralph"

if [ ! -f "$RALPH_BIN" ] || [ ! -x "$RALPH_BIN" ]; then
    fail "Cannot find or execute ralph binary at $RALPH_BIN"
fi

echo "Running tests for ralph init command..."

# Test 1: Create temp test repo
echo "Test 1: Create temp test repo"
rm -rf "$TEST_REPO" 2>/dev/null || true
mkdir -p "$TEST_REPO"
cd "$TEST_REPO"
git init --quiet
if [ $? -ne 0 ]; then
    fail "Could not create test git repo"
fi
pass "Created temporary test repository at $TEST_REPO"

# Test 2: Run ralph init
echo "Test 2: Run ralph init"
OUTPUT=$("$RALPH_BIN" init 2>&1)
if [ $? -ne 0 ]; then
    fail "ralph init failed with error: $OUTPUT"
fi
pass "ralph init executed successfully"

# Test 3: Verify .ralph/config created
echo "Test 3: Verify .ralph/config created"
if [ ! -f "$TEST_REPO/.ralph/config" ]; then
    fail ".ralph/config was not created"
fi
pass ".ralph/config was created"

# Test 4: Verify .ralph/config has correct content
echo "Test 4: Verify .ralph/config has correct content"
if ! grep -q 'RALPH_TOOL=' "$TEST_REPO/.ralph/config"; then
    fail ".ralph/config does not contain RALPH_TOOL"
fi
if ! grep -q 'RALPH_MAX_ITERATIONS=' "$TEST_REPO/.ralph/config"; then
    fail ".ralph/config does not contain RALPH_MAX_ITERATIONS"
fi
pass ".ralph/config contains expected configuration"

# Test 5: Verify .ralph/.gitignore created
echo "Test 5: Verify .ralph/.gitignore created"
if [ ! -f "$TEST_REPO/.ralph/.gitignore" ]; then
    fail ".ralph/.gitignore was not created"
fi
pass ".ralph/.gitignore was created"

# Test 6: Verify .ralph/.gitignore has correct pattern (nested ignore)
echo "Test 6: Verify .ralph/.gitignore has correct nested ignore pattern"
GITIGNORE_CONTENT=$(cat "$TEST_REPO/.ralph/.gitignore")
if ! echo "$GITIGNORE_CONTENT" | grep -q '^\*$'; then
    fail ".ralph/.gitignore does not contain '*' pattern"
fi
if ! echo "$GITIGNORE_CONTENT" | grep -q '^!config$'; then
    fail ".ralph/.gitignore does not contain '!config' pattern"
fi
if ! echo "$GITIGNORE_CONTENT" | grep -q '^!\.gitignore$'; then
    fail ".ralph/.gitignore does not contain '!.gitignore' pattern"
fi
pass ".ralph/.gitignore has correct nested ignore pattern"

# Test 7: Verify .ralph/plans/ created
echo "Test 7: Verify .ralph/plans/ created"
if [ ! -d "$TEST_REPO/.ralph/plans" ]; then
    fail ".ralph/plans directory was not created"
fi
pass ".ralph/plans directory was created"

# Test 8: Verify .ralph/plans/archive/ created
echo "Test 8: Verify .ralph/plans/archive/ created"
if [ ! -d "$TEST_REPO/.ralph/plans/archive" ]; then
    fail ".ralph/plans/archive directory was not created"
fi
pass ".ralph/plans/archive directory was created"

# Test 9: Verify specs/README.md created
echo "Test 9: Verify specs/README.md created"
if [ ! -f "$TEST_REPO/specs/README.md" ]; then
    fail "specs/README.md was not created"
fi
pass "specs/README.md was created"

# Test 10: Verify repo root .gitignore not modified
echo "Test 10: Verify repo root .gitignore not modified"
ORIGINAL_GITIGNORE_CONTENT=$(cat "$TEST_REPO/.gitignore")
pass "Captured original .gitignore content"

# Test 11: Running ralph init again is safe (idempotency)
echo "Test 11: Running ralph init again is safe (idempotency)"
OUTPUT2=$("$RALPH_BIN" init 2>&1)
if [ $? -ne 0 ]; then
    fail "ralph init failed on second run: $OUTPUT2"
fi
pass "ralph init executed successfully on second run"

# Verify no changes to .ralph/config
CONFIG_AFTER=$(cat "$TEST_REPO/.ralph/config")
if [ "$CONFIG_AFTER" != "$CONFIG_AFTER" ]; then
    fail ".ralph/config was modified on second run"
fi
pass ".ralph/config was not modified on second run"

# Verify repo root .gitignore still not modified
GITIGNORE_AFTER=$(cat "$TEST_REPO/.gitignore")
if [ "$ORIGINAL_GITIGNORE_CONTENT" != "$GITIGNORE_AFTER" ]; then
    fail "Repo root .gitignore was modified on second run"
fi
pass "Repo root .gitignore was not modified on second run (idempotent)"

# Test 12: Verify config sourcing works
echo "Test 12: Verify config sourcing works"
cd "$TEST_REPO"
# Source the config and verify values are available
source .ralph/config
if [ -z "$RALPH_TOOL" ]; then
    fail "RALPH_TOOL was not set after sourcing config"
fi
if [ -z "$RALPH_MAX_ITERATIONS" ]; then
    fail "RALPH_MAX_ITERATIONS was not set after sourcing config"
fi
pass "Config sourcing works correctly"
cd - > /dev/null

echo ""
echo "All tests passed!"