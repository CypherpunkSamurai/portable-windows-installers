<#
.SYNOPSIS
    Creates a portable Rust installation with virtualenv-style activation scripts.

.DESCRIPTION
    This script creates a self-contained, portable Rust installation that can be
    moved between systems or run from external drives. Supports both GNU and MSVC toolchains.
    Creates Python virtualenv-style activate/deactivate scripts for shell integration.

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
    Version: 1.2
    Date: 2025-07-30
#>

param (
    [string]$InstallDir = ".\PortableRust",
    [string]$ToolchainVersion = "stable",
    [ValidateSet("gnu", "msvc")]
    [string]$ToolchainType = "gnu"
)

function Show-Banner {
    $bannerColor = "Cyan"
    $version = "v1.2"
    
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

function Create-ActivationScripts {
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
    
    Write-ColorMessage "Creating activation scripts..." "Cyan"
    
    # Create Scripts directory
    $scriptsDir = Join-Path $InstallDirectory "Scripts"
    if (-not (Test-Path -Path $scriptsDir)) {
        New-Item -Path $scriptsDir -ItemType Directory | Out-Null
    }
    
    # Create activate.bat for CMD (with command runner functionality)
    $activateBatPath = Join-Path $scriptsDir "activate.bat"
    
    $activateBatContent = @"
@echo off
REM Rust Virtual Environment Activation Script (CMD)
REM Can be used as: activate.bat [command...]

REM Set Rust environment
set "RUSTUP_HOME=%~dp0..\.rustup"
set "CARGO_HOME=%~dp0..\.cargo"
set "PATH=%~dp0..\.cargo\bin;%PATH%"

REM Check if arguments were provided
if "%~1"=="" goto :show_info

REM Run command with all arguments
%*
goto :end

:show_info
REM Save current environment for interactive mode
if not defined _RUST_OLD_PATH (
    set "_RUST_OLD_PATH=%PATH%"
)
if not defined _RUST_OLD_RUSTUP_HOME (
    if defined RUSTUP_HOME (
        set "_RUST_OLD_RUSTUP_HOME=%RUSTUP_HOME%"
    )
)
if not defined _RUST_OLD_CARGO_HOME (
    if defined CARGO_HOME (
        set "_RUST_OLD_CARGO_HOME=%CARGO_HOME%"
    )
)
if not defined _RUST_OLD_PROMPT (
    set "_RUST_OLD_PROMPT=%PROMPT%"
)

set "PROMPT=(rust-env) %PROMPT%"

echo Rust environment activated (CMD)
echo Toolchain: $HostArch
echo.
echo Available commands: rustc, cargo, rustup
echo To deactivate, run: deactivate
echo.
echo Quick start: cargo new my_project

:end
"@

    # Create deactivate.bat for CMD
    $deactivateBatPath = Join-Path $scriptsDir "deactivate.bat"
    $deactivateBatContent = @"
@echo off
REM Rust Virtual Environment Deactivation Script (CMD)
if defined _RUST_OLD_PATH (
    set "PATH=%_RUST_OLD_PATH%"
    set "_RUST_OLD_PATH="
)
if defined _RUST_OLD_RUSTUP_HOME (
    set "RUSTUP_HOME=%_RUST_OLD_RUSTUP_HOME%"
    set "_RUST_OLD_RUSTUP_HOME="
) else (
    set "RUSTUP_HOME="
)
if defined _RUST_OLD_CARGO_HOME (
    set "CARGO_HOME=%_RUST_OLD_CARGO_HOME%"
    set "_RUST_OLD_CARGO_HOME="
) else (
    set "CARGO_HOME="
)
if defined _RUST_OLD_PROMPT (
    set "PROMPT=%_RUST_OLD_PROMPT%"
    set "_RUST_OLD_PROMPT="
)

echo Rust environment deactivated
"@

    # Create activate.ps1 for PowerShell (with command runner functionality)
    $activatePs1Path = Join-Path $scriptsDir "Activate.ps1"
    $activatePs1Content = @"
# Rust Virtual Environment Activation Script (PowerShell)
# Can be used as: .\Activate.ps1 [command...]

param(
    [Parameter(ValueFromRemainingArguments=`$true)]
    [string[]]`$Command
)

function global:deactivate {
    # Restore old environment variables
    if (`$env:_RUST_OLD_PATH) {
        `$env:PATH = `$env:_RUST_OLD_PATH
        Remove-Item -Path Env:_RUST_OLD_PATH
    }
    
    if (`$env:_RUST_OLD_RUSTUP_HOME) {
        `$env:RUSTUP_HOME = `$env:_RUST_OLD_RUSTUP_HOME
        Remove-Item -Path Env:_RUST_OLD_RUSTUP_HOME
    } elseif (`$env:RUSTUP_HOME) {
        Remove-Item -Path Env:RUSTUP_HOME
    }
    
    if (`$env:_RUST_OLD_CARGO_HOME) {
        `$env:CARGO_HOME = `$env:_RUST_OLD_CARGO_HOME
        Remove-Item -Path Env:_RUST_OLD_CARGO_HOME
    } elseif (`$env:CARGO_HOME) {
        Remove-Item -Path Env:CARGO_HOME
    }
    
    # Restore old prompt
    if (Get-Command _OLD_RUST_PROMPT -ErrorAction SilentlyContinue) {
        Copy-Item -Path Function:_OLD_RUST_PROMPT -Destination Function:prompt
        Remove-Item -Path Function:_OLD_RUST_PROMPT
    }
    
    # Remove the deactivate function
    Remove-Item -Path Function:deactivate
    
    Write-Host "Rust environment deactivated" -ForegroundColor Green
}

# Get script directory and set paths
`$scriptDir = Split-Path -Parent `$MyInvocation.MyCommand.Path
`$installDir = Split-Path -Parent `$scriptDir
`$rustupDir = Join-Path `$installDir ".rustup"
`$cargoDir = Join-Path `$installDir ".cargo"

# Set Rust environment
`$env:RUSTUP_HOME = `$rustupDir
`$env:CARGO_HOME = `$cargoDir
`$env:PATH = "`$cargoDir\bin;" + `$env:PATH

# Check if command arguments were provided
if (`$Command) {
    # Run command mode - execute the command directly
    `$commandString = `$Command -join ' '
    Invoke-Expression `$commandString
} else {
    # Interactive mode - show activation info and set up environment
    
    # Save current environment
    if (-not `$env:_RUST_OLD_PATH) {
        `$env:_RUST_OLD_PATH = `$env:PATH
    }
    if (`$env:RUSTUP_HOME -and -not `$env:_RUST_OLD_RUSTUP_HOME) {
        `$env:_RUST_OLD_RUSTUP_HOME = `$env:RUSTUP_HOME
    }
    if (`$env:CARGO_HOME -and -not `$env:_RUST_OLD_CARGO_HOME) {
        `$env:_RUST_OLD_CARGO_HOME = `$env:CARGO_HOME
    }

    # Save and modify prompt
    if (Get-Command prompt -ErrorAction SilentlyContinue) {
        Copy-Item -Path Function:prompt -Destination Function:_OLD_RUST_PROMPT
    }

    function global:prompt {
        Write-Host "(rust-env) " -NoNewline -ForegroundColor Yellow
        if (Get-Command _OLD_RUST_PROMPT -ErrorAction SilentlyContinue) {
            & _OLD_RUST_PROMPT
        } else {
            "PS " + (Get-Location) + "> "
        }
    }

    Write-Host "Rust environment activated (PowerShell)" -ForegroundColor Green
    Write-Host "Toolchain: $HostArch" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Available commands: " -NoNewline
    Write-Host "rustc, cargo, rustup" -ForegroundColor White
    Write-Host "To deactivate, run: " -NoNewline
    Write-Host "deactivate" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Quick start: " -NoNewline
    Write-Host "cargo new my_project" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Command runner usage: " -NoNewline
    Write-Host ".\Scripts\Activate.ps1 cargo --version" -ForegroundColor Gray
}
"@

    # Create README.txt with NFO banner and usage instructions
    $readmePath = Join-Path $InstallDirectory "README.txt"
    $currentDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $userName = "CypherpunkSamurai"
    $scriptUrl = "https://gist.github.com/CypherpunkSamurai/a62f8ed2dec66430656a637126419f78#file-PortableRust-ps1"
    
    $readmeContent = @"
╔═════════════════════════════════════════════════════════════════════╗
║                                                                     ║
║   ██████╗  ██████╗ ██████╗ ████████╗ █████╗ ██████╗ ██╗     ███████╗ ║
║   ██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝██╔══██╗██╔══██╗██║     ██╔════╝ ║
║   ██████╔╝██║   ██║██████╔╝   ██║   ███████║██████╔╝██║     █████╗   ║
║   ██╔═══╝ ██║   ██║██╔══██╗   ██║   ██╔══██║██╔══██╗██║     ██╔══╝   ║
║   ██║     ╚██████╔╝██║  ██║   ██║   ██║  ██║██████╔╝███████╗███████╗ ║
║   ╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═════╝ ╚══════╝╚══════╝ ║
║                                                                     ║
║   ██████╗ ██╗   ██╗███████╗████████╗                               ║
║   ██╔══██╗██║   ██║██╔════╝╚══██╔══╝                               ║
║   ██████╔╝██║   ██║███████╗   ██║                                  ║
║   ██╔══██╗██║   ██║╚════██║   ██║                                  ║
║   ██║  ██║╚██████╔╝███████║   ██║                                  ║
║   ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝                                  ║
║                                                                     ║
╠═════════════════════════════════════════════════════════════════════╣
║                                                                     ║
║  Created by: CypherpunkSamurai                                      ║
║  Date: $currentDate                                    ║
║  Toolchain: $HostArch                                     ║
║                                                                     ║
║  Script: $scriptUrl ║
║                                                                     ║
╚═════════════════════════════════════════════════════════════════════╝

USAGE INSTRUCTIONS (Enhanced venv-style):
------------------------------------------

1. ACTIVATE the Rust environment (Interactive Mode):

   CMD/Command Prompt:
   > Scripts\activate.bat

   PowerShell:
   PS> .\Scripts\Activate.ps1

2. RUN COMMANDS DIRECTLY (Command Mode):

   PowerShell:
   PS> .\Scripts\Activate.ps1 cargo --version
   PS> .\Scripts\Activate.ps1 cargo new my_project
   PS> .\Scripts\Activate.ps1 cargo build

   CMD:
   > Scripts\activate.bat cargo --version
   > Scripts\activate.bat cargo new my_project

3. DEACTIVATE the Rust environment:
   
   From any activated shell (interactive mode only):
   > deactivate

4. VERIFY installation:
   > .\Scripts\Activate.ps1 rustc --version
   > .\Scripts\Activate.ps1 cargo --version
   > .\Scripts\Activate.ps1 rustup --version

5. CARGO QUICK START:
   > .\Scripts\Activate.ps1 cargo new hello_world
   > cd hello_world
   > ..\Scripts\Activate.ps1 cargo run

6. COMMON CARGO COMMANDS:
   > .\Scripts\Activate.ps1 cargo build          # Compile the project
   > .\Scripts\Activate.ps1 cargo test           # Run tests
   > .\Scripts\Activate.ps1 cargo doc --open     # Generate and open documentation
   > .\Scripts\Activate.ps1 cargo install <crate> # Install a crate globally
   > .\Scripts\Activate.ps1 cargo search <query> # Search for crates

FEATURES:
---------
- ✅ Portable installation (can be moved/copied anywhere)
- ✅ Virtual environment-style activation/deactivation
- ✅ Full Cargo support with optimized configuration
- ✅ Preserves your original environment variables
- ✅ Visual prompt indication when activated
- ✅ Works with CMD and PowerShell
- ✅ No global system PATH modification
- ✅ Pre-configured Cargo settings for better performance

ENVIRONMENT VARIABLES (when activated):
---------------------------------------
- RUSTUP_HOME=$RustupDir
- CARGO_HOME=$CargoDir
- PATH=$CargoDir\bin;[original PATH]

This is a completely portable Rust installation that can be moved
to any Windows system and will continue to work without modification.

Happy Coding! 🦀
"@

    try {
        $activateBatContent | Out-File -FilePath $activateBatPath -Encoding ASCII
        $deactivateBatContent | Out-File -FilePath $deactivateBatPath -Encoding ASCII
        $activatePs1Content | Out-File -FilePath $activatePs1Path -Encoding UTF8
        $readmeContent | Out-File -FilePath $readmePath -Encoding UTF8
        
        Write-ColorMessage "Created activation scripts:" "Green"
        Write-ColorMessage "  - $activateBatPath" "Yellow"
        Write-ColorMessage "  - $deactivateBatPath" "Yellow"
        Write-ColorMessage "  - $activatePs1Path" "Yellow"
        Write-ColorMessage "  - $readmePath" "Yellow"
        
        return $true
    }
    catch {
        Write-ColorMessage "Failed to create activation scripts: $_" "Red"
        exit 1
    }
}

function Test-RustInstallation {
    param (
        [Parameter(Mandatory=$true)]
        [string]$CargoDir,
        
        [Parameter(Mandatory=$true)]
        [string]$RustupDir
    )
    
    Write-ColorMessage "Verifying Rust installation..." "Cyan"
    
    $cargoBinPath = Join-Path $CargoDir "bin\cargo.exe"
    $rustcBinPath = Join-Path $CargoDir "bin\rustc.exe"
    $rustupBinPath = Join-Path $CargoDir "bin\rustup.exe"
    
    $allTestsPassed = $true
    
    # Test Cargo
    if (Test-Path -Path $cargoBinPath) {
        try {
            $cargoOutput = & $cargoBinPath --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-ColorMessage "✅ Cargo: $cargoOutput" "Green"
            } else {
                Write-ColorMessage "❌ Cargo test failed with exit code: $LASTEXITCODE" "Red"
                $allTestsPassed = $false
            }
        }
        catch {
            Write-ColorMessage "❌ Cargo test failed: $_" "Red"
            $allTestsPassed = $false
        }
    } else {
        Write-ColorMessage "❌ Cargo executable not found at: $cargoBinPath" "Red"
        $allTestsPassed = $false
    }
    
    # Test Rustc
    if (Test-Path -Path $rustcBinPath) {
        try {
            $rustcOutput = & $rustcBinPath --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-ColorMessage "✅ Rustc: $rustcOutput" "Green"
            } else {
                Write-ColorMessage "❌ Rustc test failed with exit code: $LASTEXITCODE" "Red"
                $allTestsPassed = $false
            }
        }
        catch {
            Write-ColorMessage "❌ Rustc test failed: $_" "Red"
            $allTestsPassed = $false
        }
    } else {
        Write-ColorMessage "❌ Rustc executable not found at: $rustcBinPath" "Red"
        $allTestsPassed = $false
    }
    
    # Test Rustup
    if (Test-Path -Path $rustupBinPath) {
        try {
            $rustupOutput = & $rustupBinPath --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-ColorMessage "✅ Rustup: $rustupOutput" "Green"
            } else {
                Write-ColorMessage "❌ Rustup test failed with exit code: $LASTEXITCODE" "Red"
                $allTestsPassed = $false
            }
        }
        catch {
            Write-ColorMessage "❌ Rustup test failed: $_" "Red"
            $allTestsPassed = $false
        }
    } else {
        Write-ColorMessage "❌ Rustup executable not found at: $rustupBinPath" "Red"
        $allTestsPassed = $false
    }
    
    return $allTestsPassed
}

function Initialize-CargoConfig {
    param (
        [Parameter(Mandatory=$true)]
        [string]$CargoDir
    )
    
    Write-ColorMessage "Setting up Cargo configuration..." "Cyan"
    
    # Create .cargo/config.toml for better defaults (directly in .cargo directory)
    $cargoConfigPath = Join-Path $CargoDir "config.toml"
    $cargoConfigContent = @"
# Portable Rust Cargo Configuration
# This file ensures Cargo works optimally in portable mode

[build]
# Use all available CPU cores for compilation (let Cargo auto-detect)
# jobs = 0  # Commented out - some Cargo versions don't support 0

[cargo-new]
# Default template settings
name = "Your Name"
email = "your.email@example.com"

[net]
# Retry configuration for better reliability
retry = 3

[term]
# Better progress reporting
progress.when = "auto"
progress.width = 80

# Uncomment and modify these sections as needed:
# [source.crates-io]
# replace-with = "mirror"
# 
# [source.mirror]
# registry = "https://your-mirror-registry.com"

# [target.x86_64-pc-windows-msvc]
# linker = "link.exe"

# [target.x86_64-pc-windows-gnu]
# linker = "gcc"
"@
    
    try {
        $cargoConfigContent | Out-File -FilePath $cargoConfigPath -Encoding UTF8
        Write-ColorMessage "Created Cargo config: $cargoConfigPath" "Green"
        return $true
    }
    catch {
        Write-ColorMessage "Warning: Could not create Cargo config: $_" "Yellow"
        return $false
    }
}

function Test-CargoFunctionality {
    param (
        [Parameter(Mandatory=$true)]
        [string]$CargoDir,
        
        [Parameter(Mandatory=$true)]
        [string]$InstallDir
    )
    
    Write-ColorMessage "Testing Cargo functionality..." "Cyan"
    
    $cargoBinPath = Join-Path $CargoDir "bin\cargo.exe"
    $testProjectDir = Join-Path $InstallDir "test_project"
    
    try {
        # Create a test project
        if (Test-Path -Path $testProjectDir) {
            Remove-Item -Path $testProjectDir -Recurse -Force
        }
        
        $createResult = & $cargoBinPath "new" $testProjectDir --name "test_project" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-ColorMessage "⚠️  Cargo new command failed: $createResult" "Yellow"
            return $false
        }
        
        # Try to build the test project
        Push-Location $testProjectDir
        try {
            $buildResult = & $cargoBinPath "check" 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-ColorMessage "✅ Cargo functionality test passed" "Green"
                return $true
            } else {
                Write-ColorMessage "⚠️  Cargo check failed: $buildResult" "Yellow"
                return $false
            }
        }
        finally {
            Pop-Location
        }
    }
    catch {
        Write-ColorMessage "⚠️  Cargo functionality test failed: $_" "Yellow"
        return $false
    }
    finally {
        # Clean up test project
        if (Test-Path -Path $testProjectDir) {
            Remove-Item -Path $testProjectDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Show-Usage {
    Write-ColorMessage "`nUsage Information (Enhanced Dual-Mode Experience):" "Magenta"
    
    Write-ColorMessage "`n🦀 Interactive Mode (Traditional venv-style):" "Cyan"
    Write-ColorMessage "  .\Scripts\Activate.ps1          " -NoNewline; Write-ColorMessage "# Activate environment" "Gray"
    Write-ColorMessage "  Scripts\activate.bat            " -NoNewline; Write-ColorMessage "# Activate (CMD)" "Gray"
    Write-ColorMessage "  deactivate                      " -NoNewline; Write-ColorMessage "# Exit environment" "Gray"
    
    Write-ColorMessage "`n🚀 Command Mode (Direct execution):" "Cyan"
    Write-ColorMessage "  .\Scripts\Activate.ps1 cargo --version    " -NoNewline; Write-ColorMessage "# Run single command" "Gray"
    Write-ColorMessage "  Scripts\activate.bat cargo new my_project " -NoNewline; Write-ColorMessage "# CMD version" "Gray"
    
    Write-ColorMessage "`n📦 Common Command Examples:" "Magenta"
    Write-ColorMessage "  .\Scripts\Activate.ps1 cargo new my_project    " -NoNewline; Write-ColorMessage "# Create new project" "Gray"
    Write-ColorMessage "  .\Scripts\Activate.ps1 cargo build            " -NoNewline; Write-ColorMessage "# Build project" "Gray"
    Write-ColorMessage "  .\Scripts\Activate.ps1 cargo run              " -NoNewline; Write-ColorMessage "# Run project" "Gray"
    Write-ColorMessage "  .\Scripts\Activate.ps1 cargo test             " -NoNewline; Write-ColorMessage "# Run tests" "Gray"
    Write-ColorMessage "  .\Scripts\Activate.ps1 cargo search serde     " -NoNewline; Write-ColorMessage "# Search crates.io" "Gray"
    
    Write-ColorMessage "`n✨ Workflow examples:" "Magenta"
    Write-ColorMessage "  Quick command execution:" "Cyan"
    Write-ColorMessage "    .\Scripts\Activate.ps1 cargo new hello_world" "White"
    Write-ColorMessage "    cd hello_world" "White"
    Write-ColorMessage "    ..\Scripts\Activate.ps1 cargo run" "White"
    Write-ColorMessage " " "White"
    Write-ColorMessage "  Traditional interactive mode:" "Cyan"
    Write-ColorMessage "    .\Scripts\Activate.ps1" "White"
    Write-ColorMessage "    cargo new my_project" "White"
    Write-ColorMessage "    cd my_project" "White"
    Write-ColorMessage "    cargo run" "White"
    Write-ColorMessage "    deactivate" "White"
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
    
    # Verify Rust installation
    $installationValid = Test-RustInstallation -CargoDir $CargoDir -RustupDir $RustupDir
    
    if (-not $installationValid) {
        Write-ColorMessage "⚠️  Some components failed verification, but installation may still work" "Yellow"
        Write-ColorMessage "Try activating the environment and running commands manually" "Yellow"
    }
    
    # Initialize Cargo configuration
    Initialize-CargoConfig -CargoDir $CargoDir
    
    # Test Cargo functionality
    $cargoWorking = Test-CargoFunctionality -CargoDir $CargoDir -InstallDir $InstallDir
    
    if (-not $cargoWorking) {
        Write-ColorMessage "⚠️  Cargo functionality test failed, but installation may still work" "Yellow"
    }
    
    # Create activation scripts (venv-style)
    Create-ActivationScripts -InstallDirectory $InstallDir -RustupDir $RustupDir -CargoDir $CargoDir -HostArch $HostArch
    
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
