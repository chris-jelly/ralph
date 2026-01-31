#!/bin/bash
set -euo pipefail

# Default values
TARGET_DIR="."
RALPH_DIR_NAME="scripts/ralph"
TOOL="opencode"
MAX_ITERATIONS="10"

# Help message
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Installs Ralph into a target repository.

Options:
  --target DIR          Directory to install into (default: current directory)
  --ralph-dir DIR       Where to create scripts/ralph (default: scripts/ralph)
  --tool TOOL           AI tool to use: opencode, claude, codex (default: opencode)
  --max-iterations N    Maximum iterations for the agent loop (default: 10)
  --help                Show this help message
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --target)
            TARGET_DIR="$2"
            shift 2
            ;;
        --ralph-dir)
            RALPH_DIR_NAME="$2"
            shift 2
            ;;
        --tool)
            TOOL="$2"
            shift 2
            ;;
        --max-iterations)
            MAX_ITERATIONS="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1"
            show_help
            exit 1
            ;;
    esac
done

# Resolve absolute path for target directory (if it exists)
if [ -d "$TARGET_DIR" ]; then
    TARGET_DIR=$(cd "$TARGET_DIR" && pwd)
fi

echo "Installing Ralph..."
echo "Target: $TARGET_DIR"
echo "Ralph Dir: $RALPH_DIR_NAME"
echo "Tool: $TOOL"
echo "Max Iterations: $MAX_ITERATIONS"

# Validation: Check if target is a git repository
if [ ! -d "$TARGET_DIR/.git" ]; then
    echo "Error: Target directory '$TARGET_DIR' is not a git repository."
    exit 1
fi

# Validation: Check if Ralph is already installed
INSTALL_PATH="$TARGET_DIR/$RALPH_DIR_NAME"
if [ -d "$INSTALL_PATH" ]; then
    echo "Error: Ralph appears to be already installed at '$INSTALL_PATH'."
    echo "Please remove it or choose a different directory."
    exit 1
fi

# Validate Tool
if [[ ! "$TOOL" =~ ^(opencode|claude|codex)$ ]]; then
    echo "Error: Invalid tool '$TOOL'. Must be one of: opencode, claude, codex."
    exit 1
fi

echo "Validation passed."

# Define Source Directory (where this script is located)
SOURCE_DIR=$(cd "$(dirname "$0")" && pwd)

echo "Creating directories..."
# Create Ralph installation directory
mkdir -p "$INSTALL_PATH"

# Create plans directory in target root
mkdir -p "$TARGET_DIR/plans"
# Create .gitkeep
touch "$TARGET_DIR/plans/.gitkeep"

echo "Copying files from $SOURCE_DIR..."

# Helper function to copy file and validate
copy_file() {
    local SRC="$1"
    local DEST="$2"
    if [ -f "$SRC" ]; then
        cp "$SRC" "$DEST"
    else
        echo "Error: Source file '$SRC' not found."
        exit 1
    fi
}

copy_file "$SOURCE_DIR/ralph.sh" "$INSTALL_PATH/"
copy_file "$SOURCE_DIR/doctor.sh" "$INSTALL_PATH/"
copy_file "$SOURCE_DIR/AGENTS.md" "$INSTALL_PATH/"
copy_file "$SOURCE_DIR/prd.json.example" "$INSTALL_PATH/"

# Make scripts executable
chmod +x "$INSTALL_PATH/ralph.sh"
chmod +x "$INSTALL_PATH/doctor.sh"

# Update .gitignore
GITIGNORE="$TARGET_DIR/.gitignore"
echo "Updating .gitignore..."

# Helper function to append line if not exists
append_if_missing() {
    local FILE="$1"
    local LINE="$2"
    
    # Create file if it doesn't exist
    if [ ! -f "$FILE" ]; then
        touch "$FILE"
    fi
    
    # Check if line exists (exact match)
    if ! grep -Fxq "$LINE" "$FILE"; then
        # Ensure newline before appending if file is not empty and doesn't end with newline
        if [ -s "$FILE" ] && [ "$(tail -c1 "$FILE" | wc -l)" -eq 0 ]; then
            echo "" >> "$FILE"
        fi
        echo "$LINE" >> "$FILE"
    fi
}

append_if_missing "$GITIGNORE" ""
append_if_missing "$GITIGNORE" "# Ralph"
append_if_missing "$GITIGNORE" ".claude/"
append_if_missing "$GITIGNORE" "plans/archive/"

echo "Success! Ralph installed to $INSTALL_PATH"
