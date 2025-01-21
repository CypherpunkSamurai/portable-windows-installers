#!/bin/bash

# Neovim Distribution Installer for Portable Setup
# This script helps install various Neovim distributions to a portable
# Neovim installation's data directory

# Store the script's directory path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/data/config/nvim"
BACKUP_DIR="$SCRIPT_DIR/data/config/nvim_backup_$(date +%Y%m%d_%H%M%S)"

# Check if git is available
if ! command -v git &> /dev/null; then
    echo "Error: Git is not installed or not in PATH"
    echo "Please install Git from https://git-scm.com/downloads"
    read -p "Press Enter to continue..."
    exit 1
fi

show_menu() {
    while true; do
        clear
        echo "Neovim Distribution Installer"
        echo "============================"
        echo
        echo "Available distributions:"
        echo " 1) Abstract               - Minimal and beautiful"
        echo " 2) AstroNvim             - Aesthetic and feature-rich"
        echo " 3) CodeArt               - Modern and powerful"
        echo " 4) CosmicNvim            - Fast and modular"
        echo " 5) Ecovim                - Frontend-focused"
        echo " 6) kickstart             - Simple starter config"
        echo " 7) LazyVim               - Modern and fast"
        echo " 8) LunarVim             - Full featured IDE"
        echo " 9) LVIM IDE             - Extended LunarVim"
        echo "10) mini.nvim             - Library of minimal plugins"
        echo "11) NormalNvim            - Sane defaults"
        echo "12) NvChad               - Blazingly fast"
        echo "13) NvPak                - Full-featured dev environment"
        echo "14) SpaceVim             - Community-driven"
        echo
        echo "Lightweight Options:"
        echo "15) TinyVim              - Minimal NvChad"
        echo "16) NeoVIM for Newbs     - Beginner friendly"
        echo "17) yujiqo's neovim      - Simple and clean"
        echo "18) ntk148v's neovim     - Minimal setup"
        echo
        echo "0) Exit"
        echo

        read -p "Enter your choice (0-18): " choice

        [ "$choice" = "0" ] && exit 0

        # Handle existing config directory
        if [ -d "$CONFIG_DIR" ]; then
            echo
            echo "Warning: Configuration directory already exists at:"
            echo "$CONFIG_DIR"
            read -p "Do you want to overwrite it? (y/N) " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                echo "Backing up existing configuration..."
                mkdir -p "$BACKUP_DIR"
                cp -r "$CONFIG_DIR/"* "$BACKUP_DIR/"
                rm -rf "$CONFIG_DIR"
            else
                echo "Installation cancelled by user."
                read -p "Press Enter to continue..."
                continue
            fi
        fi

        # Create fresh config directory
        mkdir -p "$CONFIG_DIR"

        # Install selected distribution
        success=true
        case $choice in
            1) git clone https://github.com/Abstract-IDE/Abstract.git "$CONFIG_DIR" || success=false ;;
            2) git clone https://github.com/AstroNvim/AstroNvim.git "$CONFIG_DIR" || success=false ;;
            3) git clone https://github.com/artart222/CodeArt.git "$CONFIG_DIR" || success=false ;;
            4) git clone https://github.com/CosmicNvim/CosmicNvim.git "$CONFIG_DIR" || success=false ;;
            5) git clone https://github.com/ecosse3/nvim.git "$CONFIG_DIR" || success=false ;;
            6) git clone https://github.com/nvim-lua/kickstart.nvim.git "$CONFIG_DIR" || success=false ;;
            7) git clone https://github.com/LazyVim/LazyVim.git "$CONFIG_DIR" || success=false ;;
            8) git clone https://github.com/lunarvim/lunarvim.git "$CONFIG_DIR" || success=false ;;
            9)
                echo "LVIM IDE installation requires additional setup. Please visit their repository for instructions."
                read -p "Press Enter to continue..."
                continue
                ;;
            10) git clone https://github.com/echasnovski/mini.nvim.git "$CONFIG_DIR" || success=false ;;
            11) git clone https://github.com/NormalNvim/NormalNvim.git "$CONFIG_DIR" || success=false ;;
            12) git clone https://github.com/NvChad/NvChad.git "$CONFIG_DIR" || success=false ;;
            13) git clone https://github.com/EvolveBeyond/NvPak.git "$CONFIG_DIR" || success=false ;;
            14) git clone https://github.com/SpaceVim/SpaceVim.git "$CONFIG_DIR" || success=false ;;
            15) git clone https://github.com/NvChad/tinyvim.git --depth 1 "$CONFIG_DIR" || success=false ;;
            16) git clone https://github.com/cpow/neovim-for-newbs.git "$CONFIG_DIR" || success=false ;;
            17) git clone https://github.com/yujiqo/nvim.git "$CONFIG_DIR" || success=false ;;
            18) git clone https://github.com/ntk148v/neovim-config.git "$CONFIG_DIR" || success=false ;;
            *)
                echo "Invalid choice!"
                read -p "Press Enter to continue..."
                continue
                ;;
        esac

        if ! $success; then
            echo
            echo "Error: Installation failed!"
            echo "Restoring backup..."
            rm -rf "$CONFIG_DIR"
            cp -r "$BACKUP_DIR/"* "$CONFIG_DIR/"
        else
            echo
            echo "Installation completed successfully!"
            echo "Your previous configuration has been backed up to:"
            echo "$BACKUP_DIR"
        fi

        echo
        read -p "Press Enter to exit..."
        exit 0
    done
}

# Start the script
show_menu
