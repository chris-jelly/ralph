#!/bin/bash
# Ralph Migration Script - Migrate old installations to new .ralph/ structure
# Usage: ./migrate.sh [--apply] [--dry-run] [--backup-dir <path>] [--fix-gitignore] [--remove-old]

set -e

# Default values
DRY_RUN=true
APPLY=false
BACKUP_DIR=".ralph/migrate-backup/$(date +%Y%m%d-%H%M%S)"
FIX_GITIGNORE=false
REMOVE_OLD=false
VERBOSE=false

# Script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Help message
usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

Migrate old Ralph installations to new .ralph/ structure safely.

OPTIONS:
  --apply             Actually perform migration (default is dry-run)
  --dry-run           Show what would change without doing anything (default)
  --backup-dir PATH   Custom backup directory (default: .ralph/migrate-backup/<timestamp>)
  --fix-gitignore     Clean up old Ralph entries from repo .gitignore
  --remove-old        Move old directories to backup instead of leaving them
  -v, --verbose       Show detailed output
  -h, --help          Show this help message

EXAMPLES:
  # Show what would change
  $(basename "$0") --dry-run

  # Perform migration safely, keep old files
  $(basename "$0") --apply

  # Migrate and also clean up old directories
  $(basename "$0") --apply --remove-old

  # Migrate and clean up .gitignore
  $(basename "$0") --apply --fix-gitignore

  # Full cleanup
  $(basename "$0") --apply --fix-gitignore --remove-old

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --apply)
      APPLY=true
      DRY_RUN=false
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      APPLY=false
      shift
      ;;
    --backup-dir)
      BACKUP_DIR="$2"
      shift 2
      ;;
    --fix-gitignore)
      FIX_GITIGNORE=true
      shift
      ;;
    --remove-old)
      REMOVE_OLD=true
      shift
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo -e "${RED}Error: Unknown option '$1'${NC}" >&2
      echo "Use --help for usage information" >&2
      exit 1
      ;;
  esac
done

# Verify we're in a git repository
if [ -z "$REPO_ROOT" ]; then
  echo -e "${RED}Error: Not in a git repository${NC}" >&2
  echo "This script must be run inside a git repository" >&2
  exit 1
fi

echo "Ralph Migration Script"
echo "======================"
echo ""
echo "Repo root: $REPO_ROOT"
echo "Backup directory: $BACKUP_DIR"
echo "Mode: $([ "$APPLY" = true ] && echo "APPLY" || echo "DRY-RUN")"
echo ""

# Paths for old and new structures
OLD_RALPH_DIR="$REPO_ROOT/scripts/ralph"
OLD_PLANS_DIR="$REPO_ROOT/plans"
NEW_RALPH_DIR="$REPO_ROOT/.ralph"
NEW_PLANS_DIR="$NEW_RALPH_DIR/plans"
NEW_CONFIG="$NEW_RALPH_DIR/config"
NEW_GITIGNORE="$NEW_RALPH_DIR/.gitignore"
REPO_GITIGNORE="$REPO_ROOT/.gitignore"

# Check if old layout exists
OLD_LAYOUT_EXISTS=false
if [ -d "$OLD_RALPH_DIR" ] || [ -d "$OLD_PLANS_DIR" ]; then
  OLD_LAYOUT_EXISTS=true
fi

if [ "$OLD_LAYOUT_EXISTS" = false ]; then
  echo -e "${YELLOW}Warning: No old Ralph installation detected${NC}"
  echo "Old layout (scripts/ralph/ or plans/) not found"
  echo ""
  read -p "Continue anyway? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Migration cancelled"
    exit 0
  fi
fi

# Backup existing .gitignore if we're going to modify it
if [ "$FIX_GITIGNORE" = true ] && [ -f "$REPO_GITIGNORE" ]; then
  echo "Will backup .gitignore to: $BACKUP_DIR/.gitignore.bak"
fi

# Actions to perform (in order)
ACTIONS=()

# 1. Create new .ralph/ structure
if [ ! -d "$NEW_RALPH_DIR" ]; then
  ACTIONS+=("create_dir:$NEW_RALPH_DIR")
fi
if [ ! -d "$NEW_PLANS_DIR" ]; then
  ACTIONS+=("create_dir:$NEW_PLANS_DIR")
fi

# 2. Create .ralph/.gitignore with nested ignore pattern
if [ ! -f "$NEW_GITIGNORE" ]; then
  ACTIONS+=("create_gitignore:$NEW_GITIGNORE")
fi

# 3. Create .ralph/config from old ralph.conf or defaults
if [ -f "$OLD_RALPH_DIR/ralph.conf" ] && [ ! -f "$NEW_CONFIG" ]; then
  ACTIONS+=("copy_config:$OLD_RALPH_DIR/ralph.conf:$NEW_CONFIG")
elif [ ! -f "$NEW_CONFIG" ]; then
  ACTIONS+=("create_default_config:$NEW_CONFIG")
fi

# 4. Migrate working files from plans/ to .ralph/plans/
if [ -d "$OLD_PLANS_DIR" ]; then
  if [ -f "$OLD_PLANS_DIR/prd.json" ]; then
    ACTIONS+=("copy_file:$OLD_PLANS_DIR/prd.json:$NEW_PLANS_DIR/prd.json")
  fi
  if [ -f "$OLD_PLANS_DIR/progress.txt" ]; then
    ACTIONS+=("copy_file:$OLD_PLANS_DIR/progress.txt:$NEW_PLANS_DIR/progress.txt")
  fi
  if [ -f "$OLD_PLANS_DIR/implementation_plan.md" ]; then
    ACTIONS+=("copy_file:$OLD_PLANS_DIR/implementation_plan.md:$NEW_PLANS_DIR/implementation_plan.md")
  fi
  if [ -f "$OLD_PLANS_DIR/suggested_spec_changes.md" ]; then
    ACTIONS+=("copy_file:$OLD_PLANS_DIR/suggested_spec_changes.md:$NEW_PLANS_DIR/suggested_spec_changes.md")
  fi
  if [ -f "$OLD_PLANS_DIR/.last-branch" ]; then
    ACTIONS+=("copy_file:$OLD_PLANS_DIR/.last-branch:$NEW_PLANS_DIR/.last-branch")
  fi
  if [ -d "$OLD_PLANS_DIR/archive" ]; then
    ACTIONS+=("copy_dir:$OLD_PLANS_DIR/archive:$NEW_PLANS_DIR/archive")
  fi
fi

# 5. Fix .gitignore
if [ "$FIX_GITIGNORE" = true ] && [ -f "$REPO_GITIGNORE" ]; then
  ACTIONS+=("backup_gitignore:$REPO_GITIGNORE:$BACKUP_DIR/.gitignore.bak")
  ACTIONS+=("clean_gitignore:$REPO_GITIGNORE")
fi

# 6. Remove old installation (move to backup)
if [ "$REMOVE_OLD" = true ]; then
  if [ -d "$OLD_RALPH_DIR" ]; then
    ACTIONS+=("remove_dir:$OLD_RALPH_DIR:$BACKUP_DIR/scripts/ralph")
  fi
  if [ -d "$OLD_PLANS_DIR" ]; then
    ACTIONS+=("remove_plans:$OLD_PLANS_DIR:$BACKUP_DIR/plans")
  fi
fi

# Summary of planned actions
echo "Planned actions:"
echo "----------------"
ACTION_COUNT=0
for action in "${ACTIONS[@]}"; do
  ACTION_TYPE="${action%%:*}"
  ACTION_DETAILS="${action#*:}"
  ((ACTION_COUNT++))
  
  case $ACTION_TYPE in
    create_dir)
      echo "  $ACTION_COUNT. Create directory: $ACTION_DETAILS"
      ;;
    create_gitignore)
      echo "  $ACTION_COUNT. Create .ralph/.gitignore with nested ignore pattern"
      ;;
    copy_config)
      OLD_PATH="${ACTION_DETAILS%%:*}"
      NEW_PATH="${ACTION_DETAILS#*:}"
      echo "  $ACTION_COUNT. Copy ralph.conf to config: $NEW_PATH"
      ;;
    create_default_config)
      echo "  $ACTION_COUNT. Create default config: $ACTION_DETAILS"
      ;;
    copy_file)
      OLD_PATH="${ACTION_DETAILS%%:*}"
      NEW_PATH="${ACTION_DETAILS#*:}"
      FILENAME=$(basename "$NEW_PATH")
      echo "  $ACTION_COUNT. Copy file: $FILENAME"
      ;;
    copy_dir)
      OLD_PATH="${ACTION_DETAILS%%:*}"
      NEW_PATH="${ACTION_DETAILS#*:}"
      echo "  $ACTION_COUNT. Copy directory: $(basename '$NEW_PATH')"
      ;;
    backup_gitignore)
      echo "  $ACTION_COUNT. Backup .gitignore"
      ;;
    clean_gitignore)
      echo "  $ACTION_COUNT. Clean old Ralph entries from .gitignore"
      ;;
    remove_dir)
      echo "  $ACTION_COUNT. Move old ralph/ to backup"
      ;;
    remove_plans)
      echo "  $ACTION_COUNT. Move old plans/ to backup"
      ;;
  esac
done

if [ "$ACTION_COUNT" -eq 0 ]; then
  echo "  (No actions needed - everything already migrated)"
fi

echo ""

if [ "$DRY_RUN" = true ]; then
  echo "DRY-RUN MODE: No changes will be made"
  echo ""
  echo "To perform the migration, run: $(basename "$0") --apply"
  exit 0
fi

# Apply mode
echo "APPLY MODE: Performing migration..."
echo ""

# Create backup directory
if ! mkdir -p "$BACKUP_DIR"; then
  echo -e "${RED}Error: Failed to create backup directory${NC}" >&2
  exit 1
fi

echo "Backup directory created: $BACKUP_DIR"
echo ""

# Execute actions
SUCCESS_COUNT=0
FAILURE_COUNT=0

for action in "${ACTIONS[@]}"; do
  ACTION_TYPE="${action%%:*}"
  ACTION_DETAILS="${action#*:}"
  
  if [ "$VERBOSE" = true ]; then
    echo "Executing: $ACTION_TYPE ($ACTION_DETAILS)"
  fi
  
  case $ACTION_TYPE in
    create_dir)
      if mkdir -p "$ACTION_DETAILS"; then
        echo -e "${GREEN}✓${NC} Created: $ACTION_DETAILS"
        ((SUCCESS_COUNT++))
      else
        echo -e "${RED}✗${NC} Failed to create: $ACTION_DETAILS" >&2
        ((FAILURE_COUNT++))
      fi
      ;;
    create_gitignore)
      cat > "$ACTION_DETAILS" << 'EOF'
# Ralph files - only track config and this .gitignore
*
!config
!.gitignore
EOF
      echo -e "${GREEN}✓${NC} Created .ralph/.gitignore with nested ignore"
      ((SUCCESS_COUNT++))
      ;;
    copy_config)
      OLD_PATH="${ACTION_DETAILS%%:*}"
      NEW_PATH="${ACTION_DETAILS#*:}"
      if cp "$OLD_PATH" "$NEW_PATH"; then
        echo -e "${GREEN}✓${NC} Copied ralph.conf to config"
        ((SUCCESS_COUNT++))
      else
        echo -e "${RED}✗${NC} Failed to copy ralph.conf" >&2
        ((FAILURE_COUNT++))
      fi
      ;;
    create_default_config)
      cat > "$ACTION_DETAILS" << 'EOF'
# Ralph configuration
RALPH_TOOL=opencode
RALPH_MAX_ITERATIONS=10
EOF
      echo -e "${GREEN}✓${NC} Created default config"
      ((SUCCESS_COUNT++))
      ;;
    copy_file)
      OLD_PATH="${ACTION_DETAILS%%:*}"
      NEW_PATH="${ACTION_DETAILS#*:}"
      if cp "$OLD_PATH" "$NEW_PATH"; then
        FILENAME=$(basename "$NEW_PATH")
        echo -e "${GREEN}✓${NC} Copied: $FILENAME"
        ((SUCCESS_COUNT++))
      else
        echo -e "${RED}✗${NC} Failed to copy: $FILENAME" >&2
        ((FAILURE_COUNT++))
      fi
      ;;
    copy_dir)
      OLD_PATH="${ACTION_DETAILS%%:*}"
      NEW_PATH="${ACTION_DETAILS#*:}"
      if mkdir -p "$NEW_PATH" && cp -r "$OLD_PATH"/* "$NEW_PATH"/; then
        DIRNAME=$(basename "$NEW_PATH")
        echo -e "${GREEN}✓${NC} Copied: $DIRNAME/"
        ((SUCCESS_COUNT++))
      else
        echo -e "${RED}✗${NC} Failed to copy: $DIRNAME/" >&2
        ((FAILURE_COUNT++))
      fi
      ;;
    backup_gitignore)
      OLD_PATH="${ACTION_DETAILS%%:*}"
      NEW_PATH="${ACTION_DETAILS#*:}"
      if cp "$OLD_PATH" "$NEW_PATH"; then
        echo -e "${GREEN}✓${NC} Backed up .gitignore"
        ((SUCCESS_COUNT++))
      else
        echo -e "${RED}✗${NC} Failed to backup .gitignore" >&2
        ((FAILURE_COUNT++))
      fi
      ;;
    clean_gitignore)
      OLD_PATH="$ACTION_DETAILS"
      if grep -q "plans/prd.json\|plans/progress.txt" "$OLD_PATH" 2>/dev/null; then
        TEMP_FILE=$(mktemp)
        sed -E '/^plans\/(prd\.json|progress\.txt|implementation_plan\.md|suggested_spec_changes\.md|archive|\.gitignore|\.last-branch)/d' "$OLD_PATH" > "$TEMP_FILE"
        mv "$TEMP_FILE" "$OLD_PATH"
        echo -e "${GREEN}✓${NC} Cleaned old Ralph entries from .gitignore"
        ((SUCCESS_COUNT++))
      else
        echo -e "${BLUE}⊙${NC} No old Ralph entries in .gitignore" >&2
        ((FAILURE_COUNT++))
      fi
      ;;
    remove_dir)
      OLD_PATH="${ACTION_DETAILS%%:*}"
      NEW_PATH="${ACTION_DETAILS#*:}"
      if mkdir -p "$(dirname "$NEW_PATH")" && mv "$OLD_PATH" "$NEW_PATH"; then
        echo -e "${GREEN}✓${NC} Moved ralph/ to backup"
        ((SUCCESS_COUNT++))
      else
        echo -e "${RED}✗${NC} Failed to move ralph/" >&2
        ((FAILURE_COUNT++))
      fi
      ;;
    remove_plans)
      OLD_PATH="${ACTION_DETAILS%%:*}"
      NEW_PATH="${ACTION_DETAILS#*:}"
      mkdir -p "$(dirname "$NEW_PATH")"
      # Move only untracked files
      if [ -f "$OLD_PATH/.gitkeep" ]; then
        # Move contents only, leave .gitkeep
        if find "$OLD_PATH" -mindepth 1 -maxdepth 1 ! -name '.gitkeep' -exec mv -t "$NEW_PATH" {} + 2>/dev/null; then
          echo -e "${GREEN}✓${NC} Moved plans/ contents (tracked files preserved)"
          ((SUCCESS_COUNT++))
        else
          echo -e "${RED}✗${NC} Failed to move plans/" >&2
          ((FAILURE_COUNT++))
        fi
      else
        if mv "$OLD_PATH" "$NEW_PATH"; then
          echo -e "${GREEN}✓${NC} Moved plans/ to backup"
          ((SUCCESS_COUNT++))
        else
          echo -e "${RED}✗${NC} Failed to move plans/" >&2
          ((FAILURE_COUNT++))
        fi
      fi
      ;;
  esac
done

echo ""
echo "======================"
echo "Migration Summary"
echo "======================"
echo "Actions performed: $ACTION_COUNT"
echo "Successful: $SUCCESS_COUNT"
if [ "$FAILURE_COUNT" -gt 0 ]; then
  echo "Failed: $FAILURE_COUNT"
fi
echo ""

# Post-run summary
echo "New structure:"
echo "  $NEW_RALPH_DIR/"
echo "  $NEW_RALPH_DIR/config"
echo "  $NEW_RALPH_DIR/.gitignore"
echo "  $NEW_RALPH_DIR/plans/"
echo ""

if [ "$REMOVE_OLD" = true ]; then
  echo "Old installation moved to backup: $BACKUP_DIR"
else
  echo "Old installation preserved in place (use --remove-old to move to backup)"
fi

if [ "$FIX_GITIGNORE" = true ]; then
  echo ".gitignore cleaned (backup: $BACKUP_DIR/.gitignore.bak)"
fi

echo ""
echo "Migration ${GREEN}complete${NC}!"

if [ "$FAILURE_COUNT" -gt 0 ]; then
  echo -e "${YELLOW}Warning: Some actions failed. Check the output above.${NC}"
  exit 1
fi

exit 0