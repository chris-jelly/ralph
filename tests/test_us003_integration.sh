#!/bin/bash
set -u

# Setup
RALPH_ROOT=$(pwd)
TEST_DIR=$(mktemp -d)
INSTALL_SCRIPT="$RALPH_ROOT/ralph/install.sh"

echo "Running integration tests in $TEST_DIR"

cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Test 1: Relative path
echo "Test 1: Relative path (scripts/ralph)"
mkdir -p "$TEST_DIR/repo1"
cd "$TEST_DIR/repo1"
git init -q
"$INSTALL_SCRIPT" --target . --ralph-dir scripts/ralph --tool opencode > /dev/null

if [ -d "$TEST_DIR/repo1/scripts/ralph" ]; then
    echo "PASS: Relative path created correctly"
else
    echo "FAIL: Relative path not created"
    exit 1
fi

# Test 2: Absolute path
echo "Test 2: Absolute path ($TEST_DIR/repo2/custom/ralph)"
mkdir -p "$TEST_DIR/repo2"
cd "$TEST_DIR/repo2"
git init -q
ABS_PATH="$TEST_DIR/repo2/custom/ralph"
"$INSTALL_SCRIPT" --target . --ralph-dir "$ABS_PATH" --tool opencode > /dev/null

if [ -d "$ABS_PATH" ]; then
    echo "PASS: Absolute path created correctly"
else
    echo "FAIL: Absolute path not created"
    exit 1
fi

# Test 3: Home relative path
# We'll use a subdir in home to be safe, but we can't easily pollute real home.
# We can mock HOME for the script?
# install.sh uses $HOME variable.
echo "Test 3: Home relative path (~/tmp_ralph_test)"
mkdir -p "$TEST_DIR/repo3"
cd "$TEST_DIR/repo3"
git init -q

# Create a fake home
FAKE_HOME="$TEST_DIR/fake_home"
mkdir -p "$FAKE_HOME"
export HOME="$FAKE_HOME"

# Note: install.sh uses ~ which bash expands before passing to script?
# No, if quoted or passed as arg.
# If I use --ralph-dir ~/tmp_ralph_test in this script, bash expands it to $HOME/tmp_ralph_test.
# To test the script's expansion of ~, I must quote it so bash doesn't expand it.
# BUT install.sh receives it as argument.
# If I run: ./install.sh --ralph-dir "~/foo", $2 is ~/foo.
# If I run: ./install.sh --ralph-dir ~/foo, $2 is /home/user/foo (expanded by shell).

# US-003 says "Supports ~ notation".
# If the user types `~/foo` in shell, shell expands it. The script receives absolute path.
# If the user types `\~/foo` or inside interactive prompt, script receives `~/foo`.

# Testing interactive input or quoted input:
"$INSTALL_SCRIPT" --target . --ralph-dir "~/tmp_ralph_test" --tool opencode > /dev/null

if [ -d "$FAKE_HOME/tmp_ralph_test" ]; then
    echo "PASS: Tilde expansion working (internal)"
else
    echo "FAIL: Tilde expansion failed"
    exit 1
fi

# Test 4: Env var expansion (internal)
# Again, shell expands vars usually. But if passed in single quotes...
echo "Test 4: Env var expansion (\$HOME/var_test)"
mkdir -p "$TEST_DIR/repo4"
cd "$TEST_DIR/repo4"
git init -q

"$INSTALL_SCRIPT" --target . --ralph-dir '$HOME/var_test' --tool opencode > /dev/null

if [ -d "$FAKE_HOME/var_test" ]; then
    echo "PASS: Env var expansion working (internal)"
else
    echo "FAIL: Env var expansion failed"
    exit 1
fi

echo "All tests passed!"
