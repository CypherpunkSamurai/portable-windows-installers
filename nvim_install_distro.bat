@echo off
setlocal EnableDelayedExpansion

:: ========================================================================
:: Neovim Distribution Installer for Portable Setup
:: 
:: This script helps install various Neovim distributions to a portable
:: Neovim installation's data directory
:: ========================================================================

:: Store the script's directory path
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "CONFIG_DIR=%SCRIPT_DIR%\data\config\nvim"
set "BACKUP_DIR=%SCRIPT_DIR%\data\config\nvim_backup_%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%"

:: Check if git is available
where git >nul 2>nul
if %errorlevel% neq 0 (
    echo Error: Git is not installed or not in PATH
    echo Please install Git from https://git-scm.com/downloads
    pause
    exit /b 1
)

:: Menu function
:show_menu
cls
echo Neovim Distribution Installer
echo ============================
echo.
echo Available distributions:
echo  1) Abstract               - Minimal and beautiful
echo  2) AstroNvim             - Aesthetic and feature-rich
echo  3) CodeArt               - Modern and powerful
echo  4) CosmicNvim            - Fast and modular
echo  5) Ecovim                - Frontend-focused
echo  6) kickstart             - Simple starter config
echo  7) LazyVim               - Modern and fast
echo  8) LunarVim             - Full featured IDE
echo  9) LVIM IDE             - Extended LunarVim
echo 10) mini.nvim             - Library of minimal plugins
echo 11) NormalNvim            - Sane defaults
echo 12) NvChad               - Blazingly fast
echo 13) NvPak                - Full-featured dev environment
echo 14) SpaceVim             - Community-driven
echo.
echo Lightweight Options:
echo 15) TinyVim              - Minimal NvChad
echo 16) NeoVIM for Newbs     - Beginner friendly
echo 17) yujiqo's neovim      - Simple and clean
echo 18) ntk148v's neovim     - Minimal setup
echo.
echo 0) Exit
echo.

set /p choice="Enter your choice (0-18): "

:: Process choice
if "%choice%"=="0" exit /b 0

:: Backup and handle existing config if it exists
if exist "%CONFIG_DIR%" (
    echo.
    echo Warning: Configuration directory already exists at:
    echo %CONFIG_DIR%
    set /p confirm="Do you want to overwrite it? (Y/N): "
    if /i "!confirm!"=="Y" (
        echo Backing up existing configuration...
        mkdir "%BACKUP_DIR%" 2>nul
        xcopy /E /I /Q "%CONFIG_DIR%" "%BACKUP_DIR%" >nul
        rd /S /Q "%CONFIG_DIR%" 2>nul
    ) else (
        echo Installation cancelled by user.
        pause
        goto show_menu
    )
)
:: Create fresh config directory
mkdir "%CONFIG_DIR%" 2>nul

:: Install selected distribution
if "%choice%"=="1" (
    git clone https://github.com/Abstract-IDE/Abstract.git "%CONFIG_DIR%"
) else if "%choice%"=="2" (
    git clone https://github.com/AstroNvim/AstroNvim.git "%CONFIG_DIR%"
) else if "%choice%"=="3" (
    git clone https://github.com/artart222/CodeArt.git "%CONFIG_DIR%"
) else if "%choice%"=="4" (
    git clone https://github.com/CosmicNvim/CosmicNvim.git "%CONFIG_DIR%"
) else if "%choice%"=="5" (
    git clone https://github.com/ecosse3/nvim.git "%CONFIG_DIR%"
) else if "%choice%"=="6" (
    git clone https://github.com/nvim-lua/kickstart.nvim.git "%CONFIG_DIR%"
) else if "%choice%"=="7" (
    git clone https://github.com/LazyVim/LazyVim.git "%CONFIG_DIR%"
) else if "%choice%"=="8" (
    git clone https://github.com/lunarvim/lunarvim.git "%CONFIG_DIR%"
) else if "%choice%"=="9" (
    echo LVIM IDE installation requires additional setup. Please visit their repository for instructions.
    pause
    goto show_menu
) else if "%choice%"=="10" (
    git clone https://github.com/echasnovski/mini.nvim.git "%CONFIG_DIR%"
) else if "%choice%"=="11" (
    git clone https://github.com/NormalNvim/NormalNvim.git "%CONFIG_DIR%"
) else if "%choice%"=="12" (
    git clone https://github.com/NvChad/NvChad.git "%CONFIG_DIR%"
) else if "%choice%"=="13" (
    git clone https://github.com/EvolveBeyond/NvPak.git "%CONFIG_DIR%"
) else if "%choice%"=="14" (
    git clone https://github.com/SpaceVim/SpaceVim.git "%CONFIG_DIR%"
) else if "%choice%"=="15" (
    git clone https://github.com/NvChad/tinyvim.git --depth 1 "%CONFIG_DIR%"
) else if "%choice%"=="16" (
    git clone https://github.com/cpow/neovim-for-newbs.git "%CONFIG_DIR%"
) else if "%choice%"=="17" (
    git clone https://github.com/yujiqo/nvim.git "%CONFIG_DIR%"
) else if "%choice%"=="18" (
    git clone https://github.com/ntk148v/neovim-config.git "%CONFIG_DIR%"
) else (
    echo Invalid choice!
    pause
    goto show_menu
)

if %errorlevel% neq 0 (
    echo.
    echo Error: Installation failed!
    echo Restoring backup...
    rd /S /Q "%CONFIG_DIR%" 2>nul
    xcopy /E /I /Q "%BACKUP_DIR%" "%CONFIG_DIR%" >nul
) else (
    echo.
    echo Installation completed successfully!
    echo Your previous configuration has been backed up to:
    echo %BACKUP_DIR%
)

echo.
echo Press any key to exit...
pause >nul
exit /b 0