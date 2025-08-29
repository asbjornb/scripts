#!/bin/bash
# Add the scripts directory to PATH in Linux/WSL
# Usage: ./add-to-path.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_RC=""

# Detect the shell and set the appropriate RC file
if [[ -n "$ZSH_VERSION" ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ -n "$BASH_VERSION" ]]; then
    if [[ -f "$HOME/.bashrc" ]]; then
        SHELL_RC="$HOME/.bashrc"
    else
        SHELL_RC="$HOME/.bash_profile"
    fi
else
    echo "⚠️  Unknown shell. Defaulting to .bashrc"
    SHELL_RC="$HOME/.bashrc"
fi

echo "=== Adding Scripts to PATH ==="
echo "Script directory: $SCRIPT_DIR"
echo "Shell config: $SHELL_RC"

# Check if already in PATH
if echo "$PATH" | grep -q "$SCRIPT_DIR"; then
    echo "✅ Scripts directory is already in PATH"
    exit 0
fi

# Check if already added to shell config
if [[ -f "$SHELL_RC" ]] && grep -q "$SCRIPT_DIR" "$SHELL_RC"; then
    echo "✅ Scripts directory is already configured in $SHELL_RC"
    echo "💡 Run 'source $SHELL_RC' or restart your terminal to reload PATH"
    exit 0
fi

# Add to PATH in shell config
echo "" >> "$SHELL_RC"
echo "# Added by add-to-path.sh - Scripts directory" >> "$SHELL_RC"
echo "export PATH=\"$SCRIPT_DIR:\$PATH\"" >> "$SHELL_RC"

echo "✅ Added scripts directory to $SHELL_RC"
echo ""
echo "To complete the setup, run:"
echo "source $SHELL_RC"