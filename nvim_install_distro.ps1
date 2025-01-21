# Neovim Distribution Installer for Portable Setup
# This script helps install various Neovim distributions to a portable
# Neovim installation's data directory

# Store the script's directory path
$SCRIPT_DIR = $PSScriptRoot
$CONFIG_DIR = Join-Path $SCRIPT_DIR "data\config\nvim"
$BACKUP_DIR = Join-Path $SCRIPT_DIR ("data\config\nvim_backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))

# Check if git is available
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git is not installed or not in PATH"
    Write-Host "Please install Git from https://git-scm.com/downloads"
    Pause
    exit 1
}

function Show-Menu {
    while ($true) {
        Clear-Host
        Write-Host "Neovim Distribution Installer"
        Write-Host "============================"
        Write-Host
        Write-Host "Available distributions:"
        Write-Host " 1) Abstract               - Minimal and beautiful"
        Write-Host " 2) AstroNvim             - Aesthetic and feature-rich"
        Write-Host " 3) CodeArt               - Modern and powerful"
        Write-Host " 4) CosmicNvim            - Fast and modular"
        Write-Host " 5) Ecovim                - Frontend-focused"
        Write-Host " 6) kickstart             - Simple starter config"
        Write-Host " 7) LazyVim               - Modern and fast"
        Write-Host " 8) LunarVim             - Full featured IDE"
        Write-Host " 9) LVIM IDE             - Extended LunarVim"
        Write-Host "10) mini.nvim             - Library of minimal plugins"
        Write-Host "11) NormalNvim            - Sane defaults"
        Write-Host "12) NvChad               - Blazingly fast"
        Write-Host "13) NvPak                - Full-featured dev environment"
        Write-Host "14) SpaceVim             - Community-driven"
        Write-Host
        Write-Host "Lightweight Options:"
        Write-Host "15) TinyVim              - Minimal NvChad"
        Write-Host "16) NeoVIM for Newbs     - Beginner friendly"
        Write-Host "17) yujiqo's neovim      - Simple and clean"
        Write-Host "18) ntk148v's neovim     - Minimal setup"
        Write-Host
        Write-Host "0) Exit"
        Write-Host

        $choice = Read-Host "Enter your choice (0-18)"

        if ($choice -eq "0") { exit 0 }

        # Handle existing config directory
        if (Test-Path $CONFIG_DIR) {
            Write-Host
            Write-Host "Warning: Configuration directory already exists at:"
            Write-Host $CONFIG_DIR
            $confirm = Read-Host "Do you want to overwrite it? (Y/N)"
            if ($confirm -eq "Y" -or $confirm -eq "y") {
                Write-Host "Backing up existing configuration..."
                New-Item -ItemType Directory -Force -Path $BACKUP_DIR | Out-Null
                Copy-Item -Path "$CONFIG_DIR\*" -Destination $BACKUP_DIR -Recurse -Force
                Remove-Item -Path $CONFIG_DIR -Recurse -Force
            }
            else {
                Write-Host "Installation cancelled by user."
                Pause
                continue
            }
        }

        # Create fresh config directory
        New-Item -ItemType Directory -Force -Path $CONFIG_DIR | Out-Null

        # Install selected distribution
        $success = $true
        try {
            switch ($choice) {
                "1" { git clone https://github.com/Abstract-IDE/Abstract.git $CONFIG_DIR }
                "2" { git clone https://github.com/AstroNvim/AstroNvim.git $CONFIG_DIR }
                "3" { git clone https://github.com/artart222/CodeArt.git $CONFIG_DIR }
                "4" { git clone https://github.com/CosmicNvim/CosmicNvim.git $CONFIG_DIR }
                "5" { git clone https://github.com/ecosse3/nvim.git $CONFIG_DIR }
                "6" { git clone https://github.com/nvim-lua/kickstart.nvim.git $CONFIG_DIR }
                "7" { git clone https://github.com/LazyVim/LazyVim.git $CONFIG_DIR }
                "8" { git clone https://github.com/lunarvim/lunarvim.git $CONFIG_DIR }
                "9" { 
                    Write-Host "LVIM IDE installation requires additional setup. Please visit their repository for instructions."
                    Pause
                    continue
                }
                "10" { git clone https://github.com/echasnovski/mini.nvim.git $CONFIG_DIR }
                "11" { git clone https://github.com/NormalNvim/NormalNvim.git $CONFIG_DIR }
                "12" { git clone https://github.com/NvChad/NvChad.git $CONFIG_DIR }
                "13" { git clone https://github.com/EvolveBeyond/NvPak.git $CONFIG_DIR }
                "14" { git clone https://github.com/SpaceVim/SpaceVim.git $CONFIG_DIR }
                "15" { git clone https://github.com/NvChad/tinyvim.git --depth 1 $CONFIG_DIR }
                "16" { git clone https://github.com/cpow/neovim-for-newbs.git $CONFIG_DIR }
                "17" { git clone https://github.com/yujiqo/nvim.git $CONFIG_DIR }
                "18" { git clone https://github.com/ntk148v/neovim-config.git $CONFIG_DIR }
                default {
                    Write-Host "Invalid choice!"
                    Pause
                    continue
                }
            }
        }
        catch {
            $success = $false
        }

        if (-not $success) {
            Write-Host
            Write-Host "Error: Installation failed!"
            Write-Host "Restoring backup..."
            Remove-Item -Path $CONFIG_DIR -Recurse -Force
            Copy-Item -Path "$BACKUP_DIR\*" -Destination $CONFIG_DIR -Recurse -Force
        }
        else {
            Write-Host
            Write-Host "Installation completed successfully!"
            Write-Host "Your previous configuration has been backed up to:"
            Write-Host $BACKUP_DIR
        }

        Write-Host
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 0
    }
}

# Start the script
Show-Menu