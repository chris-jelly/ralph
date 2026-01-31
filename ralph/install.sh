#!/bin/bash
set -euo pipefail

# Initialize variables
TARGET_DIR=""
RALPH_DIR_NAME=""
TOOL=""
MAX_ITERATIONS=""

# Utility: Expand paths (~, vars, relative)
expand_path() {
    local path="$1"
    # Use python3 for robust expansion if available
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import os, sys; print(os.path.abspath(os.path.expandvars(os.path.expanduser(sys.argv[1]))))" "$path"
    else
        # Fallback: Basic tilde expansion
        if [[ "$path" == "~/"* ]]; then
            path="${HOME}/${path:2}"
        elif [[ "$path" == "~" ]]; then
            path="$HOME"
        fi
        
        # Fallback: realpath for absolute path
        if command -v realpath >/dev/null 2>&1; then
            realpath -m "$path"
        else
            # Last resort: simplistic absolute path
            if [[ "$path" != /* ]]; then
                echo "$(pwd)/$path"
            else
                echo "$path"
            fi
        fi
    fi
}

# Help message
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Installs Ralph into a target repository.

This script will:
1. Create the 'plans' directory structure.
2. Install Ralph scripts (ralph.sh, doctor.sh).
3. Set up the selected AI tool configuration.
4. Update .gitignore with Ralph-specific patterns.

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

# Interactive Mode: Prompt for missing values if running in a terminal
if [ -t 0 ]; then
    echo "Ralph Installation Setup"
    echo "========================"
    
    if [ -z "$TARGET_DIR" ]; then
        read -p "Target directory to install into [.]: " input
        TARGET_DIR="${input:-.}"
    fi
    
    if [ -z "$RALPH_DIR_NAME" ]; then
        read -p "Directory to create ralph scripts in [scripts/ralph]: " input
        RALPH_DIR_NAME="${input:-scripts/ralph}"
    fi
    
    if [ -z "$TOOL" ]; then
        echo ""
        echo "Select AI tool:"
        echo "1) opencode (default)"
        echo "2) claude"
        echo "3) codex"
        read -p "Enter choice [1]: " input
        case "$input" in
            2|claude) TOOL="claude" ;;
            3|codex) TOOL="codex" ;;
            *) TOOL="opencode" ;;
        esac
    fi
    
    if [ -z "$MAX_ITERATIONS" ]; then
        read -p "Max iterations [10]: " input
        MAX_ITERATIONS="${input:-10}"
    fi
fi

# Apply defaults for any remaining empty variables (non-interactive mode)
TARGET_DIR="${TARGET_DIR:-.}"
RALPH_DIR_NAME="${RALPH_DIR_NAME:-scripts/ralph}"
TOOL="${TOOL:-opencode}"
MAX_ITERATIONS="${MAX_ITERATIONS:-10}"

# Expand TARGET_DIR to handle ~, env vars, and relative paths
ORIGINAL_TARGET_DIR="$TARGET_DIR"
TARGET_DIR=$(expand_path "$TARGET_DIR")

# Validation: Check if expanded TARGET_DIR exists
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Target directory '$TARGET_DIR' does not exist after expansion. Please check the path."
    echo "Original input: $ORIGINAL_TARGET_DIR"
    exit 1
fi

# Resolve absolute path for target directory (if it exists)
if [ -d "$TARGET_DIR" ]; then
    TARGET_DIR=$(cd "$TARGET_DIR" && pwd)
fi

# Expand RALPH_DIR_NAME
# Logic: If absolute (after expansion), use as is. If relative, append to TARGET_DIR.
IS_ABS="no"
if command -v python3 >/dev/null 2>&1; then
    IS_ABS=$(python3 -c "import os, sys; path=os.path.expandvars(os.path.expanduser(sys.argv[1])); print('yes' if os.path.isabs(path) else 'no')" "$RALPH_DIR_NAME")
else
    # Fallback checks
    TEMP_PATH="$RALPH_DIR_NAME"
    if [[ "$TEMP_PATH" == "~/"* ]]; then
        TEMP_PATH="${HOME}/${TEMP_PATH:2}"
    elif [[ "$TEMP_PATH" == "~" ]]; then
        TEMP_PATH="$HOME"
    fi
    
    if [[ "$TEMP_PATH" == /* ]]; then
        IS_ABS="yes"
    fi
fi

if [ "$IS_ABS" == "yes" ]; then
    RALPH_DIR_NAME=$(expand_path "$RALPH_DIR_NAME")
else
    RALPH_DIR_NAME=$(expand_path "$TARGET_DIR/$RALPH_DIR_NAME")
fi

# Validation: Check if parent directory of RALPH_DIR_NAME exists (or is inside TARGET_DIR)
RALPH_PARENT_DIR=$(dirname "$RALPH_DIR_NAME")
if [[ "$RALPH_PARENT_DIR" == "$TARGET_DIR" ]] || [[ "$RALPH_PARENT_DIR" == "$TARGET_DIR"/* ]]; then
    # Parent is inside target directory (or is target directory), so we can create it
    :
else
    # Parent is outside target directory, so it must exist
    if [ ! -d "$RALPH_PARENT_DIR" ]; then
        echo "Error: Parent directory of '$RALPH_DIR_NAME' does not exist."
        echo "Directory '$RALPH_PARENT_DIR' must exist for installation outside the target directory."
        exit 1
    fi
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
INSTALL_PATH="$RALPH_DIR_NAME"
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

# Create configuration file
echo "Creating ralph.conf..."
cat << EOF > "$INSTALL_PATH/ralph.conf"
# Ralph Configuration
export RALPH_TOOL="$TOOL"
export RALPH_MAX_ITERATIONS="$MAX_ITERATIONS"
EOF

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

# Generate README.md
echo "Generating README.md..."
cat << EOF > "$INSTALL_PATH/README.md"
# Ralph - Autonomous Coding Agent

Ralph is an autonomous AI agent loop that works through your PRD items one by one.

## Configuration

- **Tool**: $TOOL
- **Max Iterations**: $MAX_ITERATIONS
- **Plans Directory**: ../plans/

## Quick Start

1. **Define your project**: Edit \`plans/prd.json\` (copied from example).
2. **Run Ralph**:
   \`\`\`bash
   ./$RALPH_DIR_NAME/ralph.sh
   \`\`\`
   
## Usage

Ralph will:
1. Read the PRD.
2. Pick the highest priority incomplete story.
3. Use **$TOOL** to implement it.
4. Run tests and checks.
5. Commit changes.
6. Repeat until done or max iterations ($MAX_ITERATIONS) reached.

## Commands

- Run Ralph: \`./ralph.sh\`
- Run Validation: \`./doctor.sh\`

For full documentation, see [Ralph Documentation](https://github.com/example/ralph)
EOF

echo ""
echo "Success! Ralph installed to $INSTALL_PATH"
echo ""
echo "Next Steps:"
echo "1. Edit 'plans/prd.json' to define your project requirements."
echo "2. Run './$RALPH_DIR_NAME/ralph.sh' to start the agent."
echo ""
