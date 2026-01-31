#!/bin/bash
set -u

# Test script for US-004: Path validation

RALPH_INSTALL="./ralph/install.sh"
TEST_DIR=$(mktemp -d)
echo "Running tests in $TEST_DIR"

# Cleanup on exit
trap 'rm -rf "$TEST_DIR"' EXIT

# Test 1: Non-existent Target Directory
echo "Test 1: Non-existent Target Directory"
NON_EXISTENT_DIR="$TEST_DIR/does_not_exist"
OUTPUT=$($RALPH_INSTALL --target "$NON_EXISTENT_DIR" 2>&1 || true)

if echo "$OUTPUT" | grep -q "Error: Target directory .* does not exist after expansion"; then
    echo "PASS: Caught non-existent target directory"
else
    echo "FAIL: Did not catch non-existent target directory"
    echo "Output was:"
    echo "$OUTPUT"
    exit 1
fi

# Test 2: Invalid Ralph Dir Parent
# We need a valid target dir for this test
git init "$TEST_DIR/valid_repo" > /dev/null
echo "Test 2: Invalid Ralph Dir Parent"
INVALID_RALPH_DIR="/non_existent_parent/ralph"
OUTPUT=$($RALPH_INSTALL --target "$TEST_DIR/valid_repo" --ralph-dir "$INVALID_RALPH_DIR" 2>&1 || true)

if echo "$OUTPUT" | grep -q "Error: Parent directory of .* does not exist"; then
    echo "PASS: Caught invalid ralph dir parent"
else
    echo "FAIL: Did not catch invalid ralph dir parent"
    echo "Output was:"
    echo "$OUTPUT"
    exit 1
fi

echo "All tests passed!"
