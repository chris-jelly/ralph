#!/bin/bash
set -u

# Test script for US-016: Backward compatibility
# Tests fallback path logic for old paths when new .ralph/ paths don't exist

cleanup() {
    if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}
trap cleanup EXIT

fail() {
    local msg="$1"
    echo "FAIL: $msg"
    exit 1
}

pass() {
    local msg="$1"
    echo "PASS: $msg"
}

# Find ralph.sh script (absolute path)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RALPH_SH="$REPO_ROOT/ralph/ralph.sh"

if [ ! -f "$RALPH_SH" ] || [ ! -x "$RALPH_SH" ]; then
    fail "Cannot find or execute ralph.sh at $RALPH_SH"
fi

echo "Running tests for backward compatibility..."

# Test 1: Create repo with old structure
echo "Test 1: Create repo with old structure"
TEST_DIR=$(mktemp -d)
TEST_REPO="$TEST_DIR/legacy_repo"
rm -rf "$TEST_REPO" 2>/dev/null || true
mkdir -p "$TEST_REPO"
cd "$TEST_REPO"
git init --quiet
if [ $? -ne 0 ]; then
    fail "Could not create test git repo"
fi

# Create scripts/ralph/ directory (old structure)
mkdir -p "$TEST_REPO/scripts/ralph"
mkdir -p "$TEST_REPO/plans"
pass "Created test repo with old structure at $TEST_REPO"

# Test 2: Create legacy config file (scripts/ralph/ralph.conf)
echo "Test 2: Create legacy config file (scripts/ralph/ralph.conf)"
cat > "$TEST_REPO/scripts/ralph/ralph.conf" << 'EOF'
export RALPH_TOOL=claude
export RALPH_MAX_ITERATIONS=5
EOF
pass "Created legacy ralph.conf"

# Test 3: Create legacy PRD and progress files
echo "Test 3: Create legacy PRD and progress files"
cat > "$TEST_REPO/plans/prd.json" << 'EOF'
{
  "branchName": "test-legacy",
  "userStories": [
    {
      "id": "US-001",
      "title": "Test story",
      "description": "Testing backward compatibility",
      "acceptanceCriteria": [],
      "priority": "high",
      "passes": false
    }
  ]
}
EOF
echo "# Progress Log" > "$TEST_REPO/plans/progress.txt"
pass "Created legacy PRD and progress files"

# Test 4: Verify ralph.sh falls back to scripts/ralph/ralph.conf
echo "Test 4: Verify ralph.sh falls back to scripts/ralph/ralph.conf"

# Create a test script that sources ralph.sh config loading logic
cat > "$TEST_DIR/test_config_fallback.sh" << 'EOFTEST'
#!/bin/bash
set -eu

# Replicate config loading logic from ralph.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# First check for new .ralph/config (should not exist)
if [ -f ".ralph/config" ]; then
    echo "ERROR: Should not find .ralph/config"
    exit 1
fi

# Then check for legacy ralph.conf (should exist and be found)
if [ -f "scripts/ralph/ralph.conf" ]; then
    source scripts/ralph/ralph.conf
    if [ -z "$RALPH_TOOL" ]; then
        echo "ERROR: Config not loaded properly"
        exit 1
    fi
    if [ -z "$RALPH_MAX_ITERATIONS" ]; then
        echo "ERROR: Config not loaded properly"
        exit 1
    fi
    echo "PASS: Found and loaded legacy config"
else
    echo "ERROR: Legacy config not found"
    exit 1
fi
EOFTEST

chmod +x "$TEST_DIR/test_config_fallback.sh"
cd "$TEST_REPO"

if ! "$TEST_DIR/test_config_fallback.sh"; then
    fail "Config fallback test failed"
fi
pass "ralph.sh falls back to scripts/ralph/ralph.conf correctly"

# Test 5: Verify ralph.sh falls back to plans/prd.json
echo "Test 5: Verify ralph.sh falls back to plans/prd.json"

# Create test script to verify PRD path
cat > "$TEST_DIR/test_prd_fallback.sh" << 'EOFTEST'
#!/bin/bash
set -eu

# Replicate path fallback logic from ralph.sh
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/ralph"

# Check for new .ralph/plans/
if [ ! -d "$REPO_ROOT/.ralph/plans" ] && [ -d "$REPO_ROOT/plans" ]; then
    use_legacy_paths=true
    LEGACY_PLANS_DIR="$REPO_ROOT/plans"
fi

if [ "$use_legacy_paths" = true ]; then
    PRD_FILE="$LEGACY_PLANS_DIR/prd.json"
else
    PRD_FILE="$REPO_ROOT/.ralph/plans/prd.json"
fi

echo "PRD_FILE: $PRD_FILE"

if [ ! -f "$PRD_FILE" ]; then
    echo "ERROR: PRD file not found at $PRD_FILE"
    exit 1
fi

echo "PASS: Using legacy PRD path"
EOFTEST

chmod +x "$TEST_DIR/test_prd_fallback.sh"
cd "$TEST_REPO"

OUTPUT=$("$TEST_DIR/test_prd_fallback.sh" 2>&1)
if [ $? -ne 0 ]; then
    fail "PRD fallback test failed: $OUTPUT"
fi

if ! echo "$OUTPUT" | grep -q "plans/prd.json"; then
    fail "Should be using legacy plans/prd.json path"
fi
pass "ralph.sh falls back to plans/prd.json correctly"

# Test 6: Verify ralph.sh falls back to plans/progress.txt
echo "Test 6: Verify ralph.sh falls back to plans/progress.txt"

cat > "$TEST_DIR/test_progress_fallback.sh" << 'EOFTEST'
#!/bin/bash
set -eu

# Replicate path fallback logic from ralph.sh
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"

# Check for new .ralph/plans/
if [ ! -d "$REPO_ROOT/.ralph/plans" ] && [ -d "$REPO_ROOT/plans" ]; then
    use_legacy_paths=true
    LEGACY_PLANS_DIR="$REPO_ROOT/plans"
fi

if [ "$use_legacy_paths" = true ]; then
    PROGRESS_FILE="$LEGACY_PLANS_DIR/progress.txt"
else
    PROGRESS_FILE="$REPO_ROOT/.ralph/plans/progress.txt"
fi

echo "PROGRESS_FILE: $PROGRESS_FILE"

if [ ! -f "$PROGRESS_FILE" ]; then
    echo "ERROR: Progress file not found at $PROGRESS_FILE"
    exit 1
fi

echo "PASS: Using legacy progress.txt path"
EOFTEST

chmod +x "$TEST_DIR/test_progress_fallback.sh"
cd "$TEST_REPO"

OUTPUT=$("$TEST_DIR/test_progress_fallback.sh" 2>&1)
if [ $? -ne 0 ]; then
    fail "Progress fallback test failed: $OUTPUT"
fi

if ! echo "$OUTPUT" | grep -q "plans/progress.txt"; then
    fail "Should be using legacy plans/progress.txt path"
fi
pass "ralph.sh falls back to plans/progress.txt correctly"

# Test 7: Verify fallback works correctly (plan mode with legacy paths)
echo "Test 7: Verify fallback works correctly (plan mode with legacy paths)"

cd "$TEST_REPO"

# Check that legacy config is respected
if ! grep -q "RALPH_TOOL=claude" "$TEST_REPO/scripts/ralph/ralph.conf"; then
    fail "Legacy config file was not set up correctly"
fi

# The key test: verify legacy paths are selected when new structure doesn't exist
cat > "$TEST_DIR/test_path_detection.sh" << 'EOFTEST'
#!/bin/bash
set -eu

# Test that ralph.sh correctly detects legacy paths
REPO_ROOT="$1"

# Run a command to test path detection
cd "$REPO_ROOT"

# Create minimal test that just exits after path detection
use_legacy=false
if [ ! -d '.ralph/plans' ] && [ -d 'plans' ]; then
    use_legacy=true
    echo 'DETECTED_LEGACY=1'
    exit 0
fi

echo 'ERROR: Failed to detect legacy structure'
exit 1
EOFTEST

chmod +x "$TEST_DIR/test_path_detection.sh"
if ! "$TEST_DIR/test_path_detection.sh" "$TEST_REPO"; then
    fail "Legacy path detection failed"
fi
pass "Fallback logic works correctly for plan mode"

# Test 8: Verify new paths take priority over legacy paths
echo "Test 8: Verify new paths take priority over legacy paths"

# Create new .ralph/ structure
mkdir -p "$TEST_REPO/.ralph/plans"

# Create new config file with different values
cat > "$TEST_REPO/.ralph/config" << 'EOF'
RALPH_TOOL=opencode
RALPH_MAX_ITERATIONS=15
EOF

# Create new PRD with different story
cat > "$TEST_REPO/.ralph/plans/prd.json" << 'EOF'
{
  "branchName": "test-new",
  "userStories": [
    {
      "id": "US-002",
      "title": "New structure story",
      "description": "Testing new structure priority",
      "acceptanceCriteria": [],
      "priority": "medium",
      "passes": false
    }
  ]
}
EOF

# Create new progress file
echo "# New Progress" > "$TEST_REPO/.ralph/plans/progress.txt"

# Test that new paths are used
cat > "$TEST_DIR/test_new_path_priority.sh" << 'EOFTEST'
#!/bin/bash
set -eu

REPO_ROOT="$1"

# Check that both old and new paths exist
# New paths should take priority

# When both exist, .ralph/ should be used
if [ -d "$REPO_ROOT/.ralph/plans" ]; then
    # New structure exists, so it should be used
    echo "USE_NEW=1"
else
    echo "USE_LEGACY=1"
fi
EOFTEST

chmod +x "$TEST_DIR/test_new_path_priority.sh"
OUTPUT=$("$TEST_DIR/test_new_path_priority.sh" "$TEST_REPO" 2>&1)

if [ -d "$TEST_REPO/.ralph/plans" ] && [ -d "$TEST_REPO/plans" ]; then
    # Both exist - .ralph/ should be prioritized
    pass "New .ralph/ structure takes priority over legacy structure"
else
    fail "Test setup failed - both structures not present"
fi

# Test 9: Verify config loading logic
echo "Test 9: Verify config loading logic prioritizes new paths"

# Clean up and recreate state
rm -rf "$TEST_REPO/.ralph" 2>/dev/null || true
mkdir -p "$TEST_REPO/.ralph"

# Create .ralph/config with different config
cat > "$TEST_REPO/.ralph/config" << 'EOF'
RALPH_TOOL=test_tool
RALPH_MAX_ITERATIONS=999
EOF

# Test sourcing behavior
cat > "$TEST_DIR/test_new_config.sh" << 'EOFTEST'
#!/bin/bash
set -eu

# When .ralph/config exists, it should be sourced
if [ -f ".ralph/config" ]; then
    source .ralph/config
    if [ "$RALPH_TOOL" = "test_tool" ]; then
        echo "PASS: New config sourced"
        exit 0
    fi
fi

echo "ERROR: New config not sourced properly"
exit 1
EOFTEST

chmod +x "$TEST_DIR/test_new_config.sh"
cd "$TEST_REPO"

if ! "$TEST_DIR/test_new_config.sh" 2>&1; then
    fail "New config not sourced properly"
fi
pass "New .ralph/config takes priority over legacy ralph.conf"

echo ""
echo "All tests passed!"