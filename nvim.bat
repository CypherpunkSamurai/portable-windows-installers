@echo off
setlocal EnableDelayedExpansion

:: ========================================================================
:: Portable Neovim Launcher
:: 
:: This script sets up and launches a portable instance of Neovim with:
:: - Custom data directories under .\data
:: - Parameter passing support
:: - Portable path handling
:: - Directory structure verification
:: ========================================================================

:: Store the script's directory path (handles spaces in path)
set "SCRIPT_DIR=%~dp0"
:: Remove trailing backslash
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

:: Verify Neovim executable exists
if not exist "%SCRIPT_DIR%\bin\nvim.exe" (
    echo Error: Neovim executable not found at %SCRIPT_DIR%\bin\nvim.exe
    echo Please ensure this script is in the same directory as the 'bin' folder.
    exit /b 1
)

:: Set up portable paths relative to script location
set "BASE_DIR=%SCRIPT_DIR%\data"
set "LOCALAPPDATA=%BASE_DIR%\appdata"
set "XDG_DATA_HOME=%BASE_DIR%\data"
set "XDG_CONFIG_HOME=%BASE_DIR%\config"
set "XDG_STATE_HOME=%BASE_DIR%\state"
set "XDG_CACHE_HOME=%BASE_DIR%\cache"

:: Create directory structure
echo Setting up portable Neovim environment...
set "DIRS_TO_CREATE=%BASE_DIR% %LOCALAPPDATA% %XDG_DATA_HOME% %XDG_CONFIG_HOME% %XDG_CONFIG_HOME%\nvim %XDG_STATE_HOME% %XDG_CACHE_HOME%"

for %%d in (%DIRS_TO_CREATE%) do (
    if not exist "%%d" (
        mkdir "%%d"
        if !errorlevel! neq 0 (
            echo Error: Failed to create directory %%d
            exit /b 1
        )
    )
)

:: Display configuration info if --debug parameter is passed
for %%a in (%*) do (
    if "%%a"=="--debug" (
        echo.
        echo Neovim Portable Configuration:
        echo -------------------------------
        echo Script Location: %SCRIPT_DIR%
        echo Base Directory: %BASE_DIR%
        echo Config Location: %XDG_CONFIG_HOME%\nvim
        echo.
    )
)

:: Launch Neovim with all passed parameters
echo Launching Neovim...
"%SCRIPT_DIR%\bin\nvim.exe" %*

:: Preserve errorlevel from Neovim
exit /b %errorlevel%