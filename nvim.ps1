# ==========================================================================
# Portable Neovim Launcher
# 
# This script sets up and launches a portable instance of Neovim with:
# - Custom data directories under .\data
# - Parameter passing support
# - Portable path handling
# - Directory structure verification
# - Neovim nightly installation
# ==========================================================================

# Function to download and install Neovim nightly
function Install-NeovimNightly {
    param(
        [string]$InstallDir = $PSScriptRoot
    )
    
    $nightlyUrl = "https://github.com/neovim/neovim/releases/download/nightly/nvim-win64.zip"
    $tempZip = Join-Path $env:TEMP "nvim-win64.zip"
    $extractPath = Join-Path $env:TEMP "nvim-extract"
    $targetDir = Join-Path $InstallDir "neovim"
    
    Write-Host "Downloading Neovim nightly..."
    try {
        # Download the zip file
        Invoke-WebRequest -Uri $nightlyUrl -OutFile $tempZip -UseBasicParsing
        Write-Host "Download completed successfully."
        
        # Create extraction directory
        if (Test-Path $extractPath) {
            Remove-Item $extractPath -Recurse -Force
        }
        New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
        
        # Extract zip file
        Write-Host "Extracting Neovim..."
        Expand-Archive -Path $tempZip -DestinationPath $extractPath -Force
        
        # Find the nvim-win64 folder in extracted contents
        $nvimFolder = Get-ChildItem -Path $extractPath -Directory | Where-Object { $_.Name -like "*nvim*" } | Select-Object -First 1
        if (-not $nvimFolder) {
            throw "Could not find nvim folder in extracted archive"
        }
        
        # Remove existing installation if it exists
        if (Test-Path $targetDir) {
            Write-Host "Removing existing Neovim installation..."
            Remove-Item $targetDir -Recurse -Force
        }
        
        # Move extracted files to target directory
        Write-Host "Installing Neovim to $targetDir..."
        Move-Item $nvimFolder.FullName $targetDir
        
        # Cleanup
        Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
        Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        
        Write-Host "Neovim nightly installed successfully!"
        return $true
    }
    catch {
        Write-Error "Failed to install Neovim nightly: $($_.Exception.Message)"
        # Cleanup on error
        Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
        Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        return $false
    }
}

# Store the script's directory path
$scriptDir = $PSScriptRoot

# Check for install parameter
if ($args -contains "--install-nightly") {
    $response = Read-Host "Do you want to download and install Neovim nightly? (y/N)"
    if ($response -eq 'y' -or $response -eq 'Y' -or $response -eq 'yes') {
        if (Install-NeovimNightly -InstallDir $scriptDir) {
            Write-Host "Installation completed. You can now run this script without --install-nightly to launch Neovim."
        } else {
            Write-Error "Installation failed. Please try again or install manually."
            exit 1
        }
        exit 0
    } else {
        Write-Host "Installation cancelled."
        exit 0
    }
}

# Look for Neovim executable in multiple possible locations
$nvimPaths = @(
    (Join-Path $scriptDir "bin\nvim.exe"),           # Original location
    (Join-Path $scriptDir "neovim\bin\nvim.exe")     # Nightly installation location
)

$nvimPath = $null
foreach ($path in $nvimPaths) {
    if (Test-Path $path) {
        $nvimPath = $path
        break
    }
}

if (-not $nvimPath) {
    Write-Error "Error: Neovim executable not found."
    Write-Error "Searched locations:"
    foreach ($path in $nvimPaths) {
        Write-Error "  - $path"
    }
    Write-Error ""
    Write-Error "To install Neovim nightly automatically, run:"
    Write-Error "  .\nvim-portable.ps1 --install-nightly"
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
    Write-Host "Neovim Path: $nvimPath"
    Write-Host "Base Directory: $baseDir"
    Write-Host "Config Location: $($env:XDG_CONFIG_HOME)\nvim`n"
}

# Filter out our custom parameters before passing to Neovim
$nvimArgs = $args | Where-Object { $_ -ne "--debug" -and $_ -ne "--install-nightly" }

# Launch Neovim with filtered parameters
Write-Host "Launching Neovim..."
try {
    & $nvimPath $nvimArgs
    exit $LASTEXITCODE
}
catch {
    Write-Error "Error launching Neovim: $($_.Exception.Message)"
    exit 1
}
