# ==========================================================================
# Portable Neovim Launcher
# 
# This script sets up and launches a portable instance of Neovim with:
# - Custom data directories under .\data
# - Parameter passing support
# - Portable path handling
# - Directory structure verification
# ==========================================================================

# Store the script's directory path
$scriptDir = $PSScriptRoot

# Verify Neovim executable exists
$nvimPath = Join-Path $scriptDir "bin\nvim.exe"
if (-not (Test-Path $nvimPath)) {
    Write-Error "Error: Neovim executable not found at $nvimPath"
    Write-Error "Please ensure this script is in the same directory as the 'bin' folder."
    exit 1
}

# Set up portable paths relative to script location
$baseDir = Join-Path $scriptDir "data"
$env:LOCALAPPDATA = Join-Path $baseDir "appdata"
$env:XDG_DATA_HOME = Join-Path $baseDir "data"
$env:XDG_CONFIG_HOME = Join-Path $baseDir "config"
$env:XDG_STATE_HOME = Join-Path $baseDir "state"
$env:XDG_CACHE_HOME = Join-Path $baseDir "cache"

# Create directory structure
Write-Host "Setting up portable Neovim environment..."
$dirsToCreate = @(
    $baseDir,
    $env:LOCALAPPDATA,
    $env:XDG_DATA_HOME,
    $env:XDG_CONFIG_HOME,
    (Join-Path $env:XDG_CONFIG_HOME "nvim"),
    $env:XDG_STATE_HOME,
    $env:XDG_CACHE_HOME
)

foreach ($dir in $dirsToCreate) {
    if (-not (Test-Path $dir)) {
        try {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        catch {
            Write-Error "Error: Failed to create directory $dir"
            Write-Error $_.Exception.Message
            exit 1
        }
    }
}

# Display configuration info if --debug parameter is passed
if ($args -contains "--debug") {
    Write-Host "`nNeovim Portable Configuration:"
    Write-Host "-------------------------------"
    Write-Host "Script Location: $scriptDir"
    Write-Host "Base Directory: $baseDir"
    Write-Host "Config Location: $($env:XDG_CONFIG_HOME)\nvim`n"
}

# Launch Neovim with all passed parameters
Write-Host "Launching Neovim..."
try {
    & $nvimPath $args
    exit $LASTEXITCODE
}
catch {
    Write-Error "Error launching Neovim: $($_.Exception.Message)"
    exit 1
}