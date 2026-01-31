#!/bin/bash
set -u

# Test script for US-006: Path expansion
# This script extracts the expand_path function from ralph/install.sh and tests it.

RALPH_INSTALL="ralph/install.sh"

if [ ! -f "$RALPH_INSTALL" ]; then
    echo "Error: $RALPH_INSTALL not found"
    exit 1
fi

# Extract the expand_path function
# We use sed to print lines from 'expand_path() {' up to the first '}' starting the line
# Note: This assumes standard formatting in install.sh
eval "$(sed -n '/^expand_path() {/,/^}/p' "$RALPH_INSTALL")"

# Check if function was defined
if ! command -v expand_path >/dev/null; then
    echo "Error: Could not extract expand_path function from $RALPH_INSTALL"
    exit 1
fi

echo "Running tests for expand_path function..."

FAILURES=0

assert_path() {
    local input="$1"
    local expected="$2"
    local description="$3"
    
    local actual
    actual=$(expand_path "$input")
    
    if [ "$actual" == "$expected" ]; then
        echo "PASS: $description"
    else
        echo "FAIL: $description"
        echo "  Input:    $input"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        FAILURES=$((FAILURES + 1))
    fi
}

# Setup test environment
TEST_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_TMP"' EXIT

# Test 1: ~ expands to home directory
# Note: expand_path logic might depend on python's os.path.expanduser which uses $HOME
# or shell expansion.
# We compare against $HOME
assert_path "~" "$HOME" "~ expands to HOME"
assert_path "~/" "$HOME" "~/ expands to HOME"

# Test 2: $HOME variable expands correctly
# This requires the variable to be expanded BEFORE passing to the function usually by the shell,
# but the requirement implies the function handles it?
# The function uses python's os.path.expandvars, so it SHOULD handle unexpanded vars if passed in single quotes.
# However, in normal shell usage, variables are expanded before the function sees them.
# US-002 says: "TARGET_DIR input is processed through expand_path() after argument parsing"
# If the user passes --target '$HOME/foo' (quoted), then the function receives '$HOME/foo'.
# Let's test that.
assert_path "\$HOME" "$HOME" "\$HOME variable expands"
assert_path "\$HOME/foo" "$HOME/foo" "\$HOME/foo expands"

# Test 3: Relative path ../test converts to absolute
# We need to be in a known directory to test relative paths
mkdir -p "$TEST_TMP/subdir"
cd "$TEST_TMP/subdir"
EXPECTED_PARENT="$TEST_TMP"
assert_path ".." "$EXPECTED_PARENT" "Relative path .. converts to absolute"

# Test 4: Already absolute path remains unchanged
assert_path "/tmp" "/tmp" "Absolute path /tmp remains unchanged"

# Test 5: Mixed format
# ~/test/$USER (if USER is set)
if [ -n "${USER:-}" ]; then
    assert_path "~/test/\$USER" "$HOME/test/$USER" "Mixed format ~/test/\$USER works"
fi

# Test 6: Verify it handles paths that don't exist yet (it should just expand string)
assert_path "/non/existent/path" "/non/existent/path" "Non-existent absolute path preserved"

if [ "$FAILURES" -eq 0 ]; then
    echo "All tests passed!"
    exit 0
else
    echo "$FAILURES tests failed"
    exit 1
fi
