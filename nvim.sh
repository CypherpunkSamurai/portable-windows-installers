#!/bin/bash
# ==========================================================================
# Portable Neovim Launcher
# 
# This script sets up and launches a portable instance of Neovim with:
# - Custom data directories under ./data
# - Parameter passing support
# - Portable path handling
# - Directory structure verification
# ==========================================================================

# Store the script's directory path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Verify Neovim executable exists
NVIM_PATH="$SCRIPT_DIR/bin/nvim"
if [ ! -f "$NVIM_PATH" ]; then
    echo "Error: Neovim executable not found at $NVIM_PATH"
    echo "Please ensure this script is in the same directory as the 'bin' folder."
    exit 1
fi

# Set up portable paths relative to script location
BASE_DIR="$SCRIPT_DIR/data"
export LOCALAPPDATA="$BASE_DIR/appdata"
export XDG_DATA_HOME="$BASE_DIR/data"
export XDG_CONFIG_HOME="$BASE_DIR/config"
export XDG_STATE_HOME="$BASE_DIR/state"
export XDG_CACHE_HOME="$BASE_DIR/cache"

# Create directory structure
echo "Setting up portable Neovim environment..."
DIRS_TO_CREATE=(
    "$BASE_DIR"
    "$LOCALAPPDATA"
    "$XDG_DATA_HOME"
    "$XDG_CONFIG_HOME"
    "$XDG_CONFIG_HOME/nvim"
    "$XDG_STATE_HOME"
    "$XDG_CACHE_HOME"
)

for dir in "${DIRS_TO_CREATE[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" || {
            echo "Error: Failed to create directory $dir"
            exit 1
        }
    fi
done

# Display configuration info if --debug parameter is passed
if [[ " $* " =~ " --debug " ]]; then
    echo -e "\nNeovim Portable Configuration:"
    echo "-------------------------------"
    echo "Script Location: $SCRIPT_DIR"
    echo "Base Directory: $BASE_DIR"
    echo "Config Location: $XDG_CONFIG_HOME/nvim\n"
fi

# Launch Neovim with all passed parameters
echo "Launching Neovim..."
"$NVIM_PATH" "$@" || {
    echo "Error launching Neovim"
    exit 1
}
