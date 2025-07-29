<#
.SYNOPSIS
    Creates a portable Rust installation with customizable toolchain.

.DESCRIPTION
    This script creates a self-contained, portable Rust installation that can be
    moved between systems or run from external drives. Supports both GNU and MSVC toolchains.

.PARAMETER InstallDir
    Directory where portable Rust will be installed. Default: .\PortableRust

.PARAMETER ToolchainVersion
    Rust toolchain version to install. Default: stable (Options: stable, beta, nightly, or specific version)

.PARAMETER ToolchainType
    Type of toolchain to install. Default: gnu (Options: gnu, msvc)

.EXAMPLE
    .\Install-PortableRust.ps1
    Creates a portable Rust installation with GNU toolchain in .\PortableRust

.EXAMPLE
    .\Install-PortableRust.ps1 -ToolchainType msvc
    Creates a portable Rust installation with MSVC toolchain

.EXAMPLE
    .\Install-PortableRust.ps1 -InstallDir "D:\Rust" -ToolchainVersion "nightly" -ToolchainType "gnu"
    Creates a portable nightly Rust installation with GNU toolchain in D:\Rust

.EXAMPLE
    iwr -useb https://raw.githubusercontent.com/yourusername/Install-PortableRust.ps1/main/Install-PortableRust.ps1 | iex
    Downloads and runs the script directly

.NOTES
    Author: CypherpunkSamurai
    Version: 1.1
    Date: 2025-04-18
#>

param (
    [string]$InstallDir = ".\PortableRust",
    [string]$ToolchainVersion = "stable",
    [ValidateSet("gnu", "msvc")]
    [string]$ToolchainType = "gnu"
)

function Show-Banner {
    $bannerColor = "Cyan"
    $version = "v1.1"
    
    Write-Host "`n=======================================================" -ForegroundColor $bannerColor
    Write-Host "              PORTABLE RUST INSTALLER $version" -ForegroundColor $bannerColor
    Write-Host "=======================================================" -ForegroundColor $bannerColor
    Write-Host " A tool to create portable Rust development environments" -ForegroundColor $bannerColor
    Write-Host "=======================================================" -ForegroundColor $bannerColor
    Write-Host ""
}

function Write-ColorMessage {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [string]$ForegroundColor = "White",
        
        [switch]$NoNewline
    )
    
    $params = @{
        Object = $Message
        ForegroundColor = $ForegroundColor
    }
    
    if ($NoNewline) {
        $params.Add("NoNewline", $true)
    }
    
    Write-Host @params
}

function Initialize-InstallationDirectory {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    Write-ColorMessage "Setting up installation directory..." "Cyan"
    
    # Create installation directory if it doesn't exist
    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -ItemType Directory | Out-Null
        Write-ColorMessage "Created directory: $Path" "Green"
    }
    
    # Get absolute path for installation directory
    $absolutePath = (Resolve-Path $Path).Path
    Write-ColorMessage "Installation directory: $absolutePath" "Yellow"
    
    return $absolutePath
}

function Get-RustupInitializer {
    param (
        [Parameter(Mandatory=$true)]
        [string]$InstallDirectory
    )
    
    $rustupInitUrl = "https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe"
    $rustupInitPath = Join-Path $InstallDirectory "rustup-init.exe"
    
    try {
        Write-ColorMessage "Downloading rustup-init.exe... " "Cyan" -NoNewline
        $ProgressPreference = "SilentlyContinue" # Makes downloads faster
        Invoke-WebRequest -Uri $rustupInitUrl -OutFile $rustupInitPath
        Write-ColorMessage "DONE!" "Green"
        return $rustupInitPath
    }
    catch {
        Write-ColorMessage "FAILED!" "Red"
        Write-ColorMessage "Error: $_" "Red"
        exit 1
    }
}

function Install-Rust {
    param (
        [Parameter(Mandatory=$true)]
        [string]$InitializerPath,
        
        [Parameter(Mandatory=$true)]
        [string]$ToolchainVersion,
        
        [Parameter(Mandatory=$true)]
        [string]$HostArch
    )
    
    try {
        Write-ColorMessage "Installing Rust ($ToolchainVersion) with $HostArch toolchain..." "Cyan"
        
        # Run rustup-init.exe non-interactively
        & $InitializerPath --no-modify-path -y --default-toolchain $ToolchainVersion --default-host $HostArch
        
        if ($LASTEXITCODE -ne 0) {
            throw "rustup-init.exe failed with exit code $LASTEXITCODE"
        }
        
        Write-ColorMessage "Rust installation completed successfully!" "Green"
        
        # Delete the rustup-init.exe as it's no longer needed
        Remove-Item -Path $InitializerPath -Force
        Write-ColorMessage "Removed rustup-init.exe" "Green"
        
        return $true
    }
    catch {
        Write-ColorMessage "Failed to install Rust: $_" "Red"
        exit 1
    }
}

function Create-LauncherScripts {
    param (
        [Parameter(Mandatory=$true)]
        [string]$InstallDirectory,
        
        [Parameter(Mandatory=$true)]
        [string]$RustupDir,
        
        [Parameter(Mandatory=$true)]
        [string]$CargoDir,
        
        [Parameter(Mandatory=$true)]
        [string]$HostArch
    )
    
    Write-ColorMessage "Creating launcher scripts..." "Cyan"
    
    # Create "Open Terminal Here" for CMD
    $cmdHerePath = Join-Path $InstallDirectory "open-cmd-here.bat"
    $cmdHereContent = @"
@echo off
setlocal
set RUSTUP_HOME=$RustupDir
set CARGO_HOME=$CargoDir
set PATH=$CargoDir\bin;%PATH%

echo Rust Environment Ready! (CMD)
echo Toolchain: $HostArch

echo Type 'rustc --version', 'cargo --version', or 'rustup --version' to verify installation.
echo
echo Write-Host 'For more information, visit: https://www.rust-lang.org/'
cd %~dp0
cmd /k
"@

    # Check for PowerShell executables
    $isPwshInstalled = (Get-Command pwsh -ErrorAction SilentlyContinue) -ne $null
    $isPowershellInstalled = (Get-Command powershell -ErrorAction SilentlyContinue) -ne $null

    if ($isPowershellInstalled) {
        # Create "Open Terminal Here" for PowerShell
        $psHerePath = Join-Path $InstallDirectory "open-powershell-here.bat"
        $psHereContent = @"
@echo off
setlocal
set RUSTUP_HOME=$RustupDir
set CARGO_HOME=$CargoDir
set PATH=$CargoDir\bin;%PATH%

echo Starting PowerShell with Rust environment...
cd %~dp0
powershell -NoExit -Command "
    `$env:RUSTUP_HOME = '$RustupDir'
    `$env:CARGO_HOME = '$CargoDir'
    `$env:PATH = '$CargoDir\bin;' + `$env:PATH
    
    Write-Host 'Rust Environment Ready! (PowerShell)' -ForegroundColor Green
    Write-Host 'Toolchain: $HostArch' -ForegroundColor Cyan
    Write-Host 'Rustup Home: ' -NoNewline -ForegroundColor Cyan
    Write-Host `$env:RUSTUP_HOME -ForegroundColor Yellow
    Write-Host 'Cargo Home: ' -NoNewline -ForegroundColor Cyan
    Write-Host `$env:CARGO_HOME -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'Type ''rustc --version'', ''cargo --version'', or ''rustup --version'' to verify installation.' -ForegroundColor Yellow
    Write-Host 'For more information, visit: https://www.rust-lang.org/' -ForegroundColor Yellow
"
"@
        $psHereContent | Out-File -FilePath $psHerePath -Encoding ASCII
    }

    if ($isPwshInstalled) {
        # Create "Open Terminal Here" for PowerShell 7
        $pwshHerePath = Join-Path $InstallDirectory "open-powershell7-here.bat"
        $pwshHereContent = @"
@echo off
setlocal
set RUSTUP_HOME=$RustupDir
set CARGO_HOME=$CargoDir
set PATH=$CargoDir\bin;%PATH%

echo Starting PowerShell 7 with Rust environment...
cd %~dp0
pwsh -NoExit -Command "
    `$env:RUSTUP_HOME = '$RustupDir'
    `$env:CARGO_HOME = '$CargoDir'
    `$env:PATH = '$CargoDir\bin;' + `$env:PATH
    
    Write-Host 'Rust Environment Ready! (PowerShell 7)' -ForegroundColor Green
    Write-Host 'Toolchain: $HostArch' -ForegroundColor Cyan
    Write-Host 'Rustup Home: ' -NoNewline -ForegroundColor Cyan
    Write-Host `$env:RUSTUP_HOME -ForegroundColor Yellow
    Write-Host 'Cargo Home: ' -NoNewline -ForegroundColor Cyan
    Write-Host `$env:CARGO_HOME -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'Type ''rustc --version'', ''cargo --version'', or ''rustup --version'' to verify installation.' -ForegroundColor Yellow
    Write-Host 'For more information, visit: https://www.rust-lang.org/' -ForegroundColor Yellow
"
"@
        $pwshHereContent | Out-File -FilePath $pwshHerePath -Encoding ASCII
    }


    # Create README.txt with NFO banner
    $readmePath = Join-Path $InstallDirectory "README.txt"
    $currentDate = "2025-04-18 18:34:28"
    $userName = "CypherpunkSamurai"
    $scriptUrl = "https://gist.github.com/CypherpunkSamurai/a62f8ed2dec66430656a637126419f78#file-PortableRust-ps1"
    
    $readmeContent = @"
â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
â•‘                                                                     â•‘
â•‘   â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—  â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â–ˆâ–ˆâ•—     â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â•‘
â•‘   â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•—â–ˆâ–ˆâ•”â•â•â•â–ˆâ–ˆâ•—â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•—â•šâ•â•â–ˆâ–ˆâ•”â•â•â•â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•—â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•—â–ˆâ–ˆâ•‘     â–ˆâ–ˆâ•”â•â•â•â•â• â•‘
â•‘   â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•”â•â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ•‘â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•”â•   â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•‘â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•”â•â–ˆâ–ˆâ•‘     â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—   â•‘
â•‘   â–ˆâ–ˆâ•”â•â•â•â• â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ•‘â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•—   â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•‘â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•—â–ˆâ–ˆâ•‘     â–ˆâ–ˆâ•”â•â•â•   â•‘
â•‘   â–ˆâ–ˆâ•‘     â•šâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•”â•â–ˆâ–ˆâ•‘  â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ•‘  â–ˆâ–ˆâ•‘â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•”â•â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â•‘
â•‘   â•šâ•â•      â•šâ•â•â•â•â•â• â•šâ•â•  â•šâ•â•   â•šâ•â•   â•šâ•â•  â•šâ•â•â•šâ•â•â•â•â•â• â•šâ•â•â•â•â•â•â•â•šâ•â•â•â•â•â•â• â•‘
â•‘                                                                     â•‘
â•‘   â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â–ˆâ–ˆâ•—   â–ˆâ–ˆâ•—â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—                               â•‘
â•‘   â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•—â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ•‘â–ˆâ–ˆâ•”â•â•â•â•â•â•šâ•â•â–ˆâ–ˆâ•”â•â•â•                               â•‘
â•‘   â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•”â•â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ•‘â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—   â–ˆâ–ˆâ•‘                                  â•‘
â•‘   â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•—â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ•‘â•šâ•â•â•â•â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ•‘                                  â•‘
â•‘   â–ˆâ–ˆâ•‘  â–ˆâ–ˆâ•‘â•šâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•”â•â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•‘   â–ˆâ–ˆâ•‘                                  â•‘
â•‘   â•šâ•â•  â•šâ•â• â•šâ•â•â•â•â•â• â•šâ•â•â•â•â•â•â•   â•šâ•â•                                  â•‘
â•‘                                                                     â•‘
â• â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£
â•‘                                                                     â•‘
â•‘  Created by: CypherpunkSamurai                                      â•‘
â•‘  Date: $currentDate                                    â•‘
â•‘  Toolchain: $HostArch                                     â•‘
â•‘                                                                     â•‘
â•‘  Script: $scriptUrl â•‘
â•‘                                                                     â•‘
â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

USAGE INSTRUCTIONS:
------------------
1. Open a terminal in this directory:
   - CMD: open-cmd-here.bat
   - PowerShell: open-powershell-here.bat

2. Environment Variables (for scripts):
   - RUSTUP_HOME=$RustupDir
   - CARGO_HOME=$CargoDir
   - PATH=$CargoDir\bin;%PATH%

This is a portable Rust installation that can be moved anywhere,
even to another computer or USB drive, and will continue to work.

Happy Coding!
"@

    try {
        $cmdHereContent | Out-File -FilePath $cmdHerePath -Encoding ASCII
        Write-ColorMessage "  - $cmdHerePath" "Yellow"
        
        if ($isPowershellInstalled) {
            $psHereContent | Out-File -FilePath $psHerePath -Encoding ASCII
            Write-ColorMessage "  - $psHerePath" "Yellow"
        }
        if ($isPwshInstalled) {
            $pwshHereContent | Out-File -FilePath $pwshHerePath -Encoding ASCII
            Write-ColorMessage "  - $pwshHerePath" "Yellow"
        }
        $readmeContent | Out-File -FilePath $readmePath -Encoding UTF8
        
        Write-ColorMessage "Created launcher scripts:" "Green"
        Write-ColorMessage "  - $cmdHerePath" "Yellow"
        Write-ColorMessage "  - $psHerePath" "Yellow"
        Write-ColorMessage "  - $readmePath" "Yellow"
        
        return $true
    }
    catch {
        Write-ColorMessage "Failed to create launcher scripts: $_" "Red"
        exit 1
    }
}

function Show-Usage {
    Write-ColorMessage "`nUsage Information:" "Magenta"
    Write-ColorMessage "open-cmd-here.bat" "Yellow"
    Write-ColorMessage "  Open PowerShell in directory:  " -NoNewline
    Write-ColorMessage "open-powershell-here.bat" "Yellow"
    Write-ColorMessage "`nEnvironment Variables (for scripts):" "Magenta"
    Write-ColorMessage "  RUSTUP_HOME=[InstallDir]\.rustup" "Yellow"
    Write-ColorMessage "  CARGO_HOME=[InstallDir]\.cargo" "Yellow"
    Write-ColorMessage "  PATH=[InstallDir]\.cargo\bin;%PATH%" "Yellow"
    Write-ColorMessage "`n"
}

function Install-PortableRust {
    param (
        [string]$InstallDir = ".\PortableRust",
        [string]$ToolchainVersion = "stable",
        [ValidateSet("gnu", "msvc")]
        [string]$ToolchainType = "gnu"
    )
    
    $ErrorActionPreference = "Stop"
    $Host.UI.RawUI.WindowTitle = "Portable Rust Installer"
    
    # Set the host based on toolchain type
    $HostArch = "x86_64-pc-windows-$ToolchainType"
    
    # Display banner
    Show-Banner
    
    Write-ColorMessage "Starting Portable Rust Installation" "White"
    Write-ColorMessage "  Toolchain: $HostArch" "Yellow"
    Write-ColorMessage "  Version: $ToolchainVersion" "Yellow"
    Write-ColorMessage "  Target: $InstallDir" "Yellow"
    Write-ColorMessage "`n"
    
    # Initialize installation directory
    $InstallDir = Initialize-InstallationDirectory -Path $InstallDir
    $RustupDir = Join-Path $InstallDir ".rustup"
    $CargoDir = Join-Path $InstallDir ".cargo"
    
    # Set environment variables for this session
    $env:RUSTUP_HOME = $RustupDir
    $env:CARGO_HOME = $CargoDir
    $env:PATH = "$CargoDir\bin;$env:PATH"
    
    # Download rustup-init.exe
    $rustupInitPath = Get-RustupInitializer -InstallDirectory $InstallDir
    
    # Install Rust
    Install-Rust -InitializerPath $rustupInitPath -ToolchainVersion $ToolchainVersion -HostArch $HostArch
    
    # Create launcher scripts
    Create-LauncherScripts -InstallDirectory $InstallDir -RustupDir $RustupDir -CargoDir $CargoDir -HostArch $HostArch
    
    # Show final instructions
    Write-ColorMessage "`nPortable Rust installation is ready!" "Green"
    Show-Usage
}

# This allows the script to be imported as a module or run directly
# Check if the script is being run directly or through Invoke-Expression
if ($MyInvocation.InvocationName -ne '.') {
    # Script running directly or via iwr | iex
    $scriptParams = @{}
    
    if ($PSBoundParameters.ContainsKey('InstallDir')) {
        $scriptParams['InstallDir'] = $InstallDir
    }
    
    if ($PSBoundParameters.ContainsKey('ToolchainVersion')) {
        $scriptParams['ToolchainVersion'] = $ToolchainVersion
    }
    
    if ($PSBoundParameters.ContainsKey('ToolchainType')) {
        $scriptParams['ToolchainType'] = $ToolchainType
    }
    
    Install-PortableRust @scriptParams
}

# Fix the module exporting issue - only try to export if we're clearly in a module context
# This is a safer check that doesn't rely on ScriptName which might be empty
if ($PSScriptRoot -and (Test-Path -Path "$PSScriptRoot\*.psm1")) {
    # We're clearly in a module, so exporting is safe
    Export-ModuleMember -Function Install-PortableRust
}
