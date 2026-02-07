#!/bin/bash
# Ralph bootstrap installer
# Usage: curl -fsSL https://raw.githubusercontent.com/chris-jelly/ralph/main/ralph/bootstrap.sh | bash
#
# Installs Ralph globally by cloning the repo and symlinking the CLI onto PATH.
#
# Environment variables:
#   RALPH_INSTALL_DIR  — where to clone the repo  (default: ~/.local/share/ralph)
#   RALPH_BIN_DIR      — where to place the symlink (default: ~/.local/bin)
#   RALPH_REPO_URL     — git clone URL             (default: https://github.com/chris-jelly/ralph.git)

set -euo pipefail

RALPH_REPO_URL="${RALPH_REPO_URL:-https://github.com/chris-jelly/ralph.git}"
RALPH_INSTALL_DIR="${RALPH_INSTALL_DIR:-$HOME/.local/share/ralph}"
RALPH_BIN_DIR="${RALPH_BIN_DIR:-$HOME/.local/bin}"
RALPH_BIN="$RALPH_BIN_DIR/ralph"
RALPH_TARGET="$RALPH_INSTALL_DIR/bin/ralph"

info()  { echo "  $*"; }
error() { echo "ERROR: $*" >&2; }

# ── Pre-flight checks ──────────────────────────────────────────────

if ! command -v git >/dev/null 2>&1; then
    error "git is required but not found on PATH."
    exit 1
fi

# ── Install or update ──────────────────────────────────────────────

if [ -d "$RALPH_INSTALL_DIR/.git" ]; then
    echo "Ralph is already installed at $RALPH_INSTALL_DIR"
    echo "Updating..."
    git -C "$RALPH_INSTALL_DIR" pull --ff-only || {
        error "git pull failed. You may have local changes in $RALPH_INSTALL_DIR"
        exit 1
    }
else
    if [ -e "$RALPH_INSTALL_DIR" ]; then
        error "$RALPH_INSTALL_DIR exists but is not a git repository."
        error "Remove it first if you want a fresh install."
        exit 1
    fi

    echo "Installing Ralph to $RALPH_INSTALL_DIR"
    mkdir -p "$(dirname "$RALPH_INSTALL_DIR")"
    git clone "$RALPH_REPO_URL" "$RALPH_INSTALL_DIR"
fi

# ── Verify the CLI entry point exists ──────────────────────────────

if [ ! -f "$RALPH_TARGET" ]; then
    error "Expected CLI entry point not found at $RALPH_TARGET"
    error "The repository may be corrupt. Try removing $RALPH_INSTALL_DIR and re-running."
    exit 1
fi

chmod +x "$RALPH_TARGET"

# ── Create symlink ─────────────────────────────────────────────────

mkdir -p "$RALPH_BIN_DIR"

if [ -L "$RALPH_BIN" ]; then
    # Replace existing symlink
    ln -sf "$RALPH_TARGET" "$RALPH_BIN"
    info "Updated symlink: $RALPH_BIN -> $RALPH_TARGET"
elif [ -e "$RALPH_BIN" ]; then
    error "$RALPH_BIN already exists and is not a symlink."
    error "Remove it manually if you want the bootstrap to manage it."
    exit 1
else
    ln -s "$RALPH_TARGET" "$RALPH_BIN"
    info "Created symlink: $RALPH_BIN -> $RALPH_TARGET"
fi

# ── PATH check ─────────────────────────────────────────────────────

path_ok=false
case ":$PATH:" in
    *":$RALPH_BIN_DIR:"*) path_ok=true ;;
esac

echo ""
echo "Ralph installed successfully!"
echo ""

if [ "$path_ok" = true ]; then
    info "ralph is on your PATH. You're all set."
else
    echo "  ~/.local/bin is not on your PATH. Add it by running:"
    echo ""
    # Detect current shell
    current_shell="$(basename "${SHELL:-/bin/bash}")"
    case "$current_shell" in
        zsh)
            echo "    echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc"
            echo "    source ~/.zshrc"
            ;;
        fish)
            echo "    fish_add_path ~/.local/bin"
            ;;
        *)
            echo "    echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
            echo "    source ~/.bashrc"
            ;;
    esac
    echo ""
fi

echo "Next steps:"
echo "  cd <your-project>"
echo "  ralph init"
echo "  ralph plan"
echo "  ralph build"
echo ""
