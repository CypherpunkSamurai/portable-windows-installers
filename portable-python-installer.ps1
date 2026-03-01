<#
.SYNOPSIS
    CypherpunkSamurai's Portable Python Installer
.DESCRIPTION
    Installs a completely portable Windows Embedded Python distribution.
    Fetches versions from python.org and enforces relative paths for pip wrappers.
.PARAMETER Version
    The Python version to install. Use "latest" for the most recent available version.
    Default: "latest"
.PARAMETER InstallFolder
    The folder name where Python will be installed.
    Default: "python"
.PARAMETER ListVersions
    Lists available Python versions with embedded releases and exits.
    When used with -Version, shows availability for that specific version.
.PARAMETER Arch
    Architecture to install. Options: amd64, win32, arm64.
    Defaults to system architecture (amd64 for 64-bit, win32 for 32-bit).
.PARAMETER Force
    Force reinstallation by deleting existing installation folder.
.PARAMETER NoActivator
    Skip creating activation scripts (activate.bat, activate.ps1).
.EXAMPLE
    .\portable-python-installer.ps1
    Installs the latest portable Python version.
.EXAMPLE
    .\portable-python-installer.ps1 -Version 3.12.0
    Installs Python version 3.12.0.
.EXAMPLE
    .\portable-python-installer.ps1 -ListVersions
    Lists all available Python versions with embedded releases.
.EXAMPLE
    .\portable-python-installer.ps1 -ListVersions -Version 3.12.0
    Shows availability of embedded releases for Python 3.12.0.
.EXAMPLE
    .\portable-python-installer.ps1 -Force
    Reinstalls Python even if an existing installation is found.
.EXAMPLE
    .\portable-python-installer.ps1 -Version 3.12.0 -NoActivator
    Installs Python without creating activation scripts.
#>
param (
    [string]$Version = "latest",
    [string]$InstallFolder = "python",
    [switch]$ListVersions,
    [ValidateSet("amd64", "win32", "arm64")]
    [string]$Arch = "",
    [switch]$Force,
    [switch]$NoActivator
)

# TLS 1.2 for secure downloads
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-PythonEmbeddableLinks {
    param (
        [Parameter(Mandatory=$false)]
        [ValidateSet("amd64", "win32", "arm64")]
        [string]$Arch = "amd64",

        [Parameter(Mandatory=$false)]
        [int]$Limit = 20
    )

    try {
        # Fetch versions from python.org FTP
        $ftpUrl = "https://www.python.org/ftp/python/"
        $response = Invoke-WebRequest -Uri $ftpUrl -UseBasicParsing
        
        # Parse versions using Regex and filter for stable releases (3.5+)
        $matches = [regex]::Matches($response.Content, '<a href="(\d+\.\d+\.\d+)/">')
        $allVersions = $matches | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
        
        # Filter: Version must be 3.5 or higher and stable (no alpha/beta/rc)
        $versions = $allVersions | Where-Object {
            $_ -match '^3\.(5|[6-9]|\d{2,})\.\d+$'
        } | Sort-Object { [version]$_ } -Descending | Select-Object -First $Limit

        $results = foreach ($v in $versions) {
            $downloadUrl = "https://www.python.org/ftp/python/$v/python-$v-embed-$Arch.zip"
            
            [PSCustomObject]@{
                Version = $v
                Arch    = $Arch
                Link    = $downloadUrl
            }
        }

        return $results
    }
    catch {
        Write-Error "Failed to fetch Python versions: $($_.Exception.Message)"
        return $null
    }
}

# Determine architecture
$is64Bit = [Environment]::Is64BitOperatingSystem
if ($Arch -eq "") {
    $Arch = if ($is64Bit) { "amd64" } else { "win32" }
}

Write-Host "#################################################"
Write-Host "#                                               #"
Write-Host "#       Windows Portable Python Installer       #"
Write-Host "#                                               #"
Write-Host "#################################################"
Write-Host ""

$INSTALL_FOLDER_NAME = $InstallFolder
Write-Host ">> Target Folder: .\$INSTALL_FOLDER_NAME"
Write-Host ">> Architecture: $Arch"
Write-Host ""

# Fetch available Python versions
Write-Host "[~] Fetching Python versions from python.org..."
$availableReleases = Get-PythonEmbeddableLinks -Arch $Arch -Limit 20
$availableVersions = $availableReleases | Select-Object -ExpandProperty Version

if ($null -eq $availableVersions -or $availableVersions.Count -eq 0) {
    Write-Host "Failed to fetch Python versions from PyPI!"
    Exit 1
}

# Handle -ListVersions switch
if ($ListVersions) {
    Write-Host ""
    Write-Host "Available Python versions with embedded releases:"
    Write-Host "------------------------------------------------"
    
    if ($Version -ne "latest" -and $Version -match '^\d+\.\d+\.\d+$') {
        # Show specific version info
        Write-Host ""
        Write-Host "Checking availability for version: $Version"
        
        $architectures = @("amd64", "win32", "arm64")
        foreach ($a in $architectures) {
            $url = "https://www.python.org/ftp/python/$Version/python-$Version-embed-$a.zip"
            try {
                $null = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
                Write-Host "  [$a]: AVAILABLE - $url"
            } catch {
                Write-Host "  [$a]: NOT AVAILABLE"
            }
        }
    } else {
        # Show list of all versions with embedded releases
        $counter = 1
        foreach ($release in $availableReleases) {
            $marker = if ($counter -eq 1) { " (latest)" } else { "" }
            Write-Host "  $counter. $($release.Version)$marker"
            $counter++
        }
        Write-Host ""
        Write-Host "Tip: Use -Version <version> to install a specific version."
        Write-Host "     Example: .\portable-python-installer.ps1 -Version 3.12.0"
    }
    Write-Host ""
    Exit 0
}

# Determine version to install
if ($Version -eq "latest") {
    $Version = $availableVersions[0]
    Write-Host ">> Selected Latest Version: $Version"
} elseif ($Version -notin $availableVersions) {
    # Version not in top 20, do a live check
    $testUrl = "https://www.python.org/ftp/python/$Version/python-$Version-embed-$Arch.zip"
    try {
        $null = Invoke-WebRequest -Uri $testUrl -Method Head -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        Write-Host ">> Selected Version: $Version (verified)"
    } catch {
        Write-Host "Version $Version not found or not available as embedded release!"
        Write-Host ">> Available versions include: $($availableVersions[0..9] -join ', ')..."
        Exit 1
    }
} else {
    Write-Host ">> Selected Version: $Version"
}

$zipName = "python-$Version-embed-$Arch.zip"
$downloadUrl = "https://www.python.org/ftp/python/$Version/$zipName"

# Check for Existing Installation
if (Test-Path $INSTALL_FOLDER_NAME -PathType Container) {
    if ($Force) {
        Write-Host "Force flag set. Removing existing installation in $INSTALL_FOLDER_NAME..."
        Remove-Item -Path $INSTALL_FOLDER_NAME -Recurse -Force
        if (Test-Path PATH.txt) { Remove-Item -Path PATH.txt -Force }
    } else {
        Write-Host "Found Existing Installation in $INSTALL_FOLDER_NAME!"
        if (Test-Path PATH.txt) {
            $python_path = Get-Content PATH.txt
            $env:Path = "$python_path;$env:Path"
            python --version
            Exit 0
        }
    }
}
if (Test-Path $INSTALL_FOLDER_NAME -PathType Container) {
    Write-Host "Found Existing Installation in $INSTALL_FOLDER_NAME!"
    if (Test-Path PATH.txt) {
        $python_path = Get-Content PATH.txt
        $env:Path = "$python_path;$env:Path"
        python --version
        Exit 0
    }
}

# Download Python Zip
if (Test-Path $zipName) {
    Write-Host "Python Installer zip ($zipName) exists!"
} else {
    Write-Host "Downloading Python $Version Embedded Zip..."
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipName -ErrorAction Stop
    } catch {
        Write-Host "Failed to download Python $Version! The embedded release may not be available."
        Write-Host "   Error: $_"
        Exit 1
    }
}

# Extract the Python Embedded Archive
Write-Host "Extracting Python..."
if (Test-Path $INSTALL_FOLDER_NAME) { Remove-Item -Path $INSTALL_FOLDER_NAME -Recurse -Force }
Expand-Archive -Path $zipName -DestinationPath $INSTALL_FOLDER_NAME -Force

# Navigate to Installation Folder
Set-Location .\$INSTALL_FOLDER_NAME

# Fetch Pip
if (Test-Path ..\get-pip.py) {
    Write-Host ">> Pip Installer Found in Parent Folder, copying..."
    Copy-Item ..\get-pip.py .\get-pip.py
} else {
    Write-Host "Downloading Pip..."
    Invoke-WebRequest -Uri https://bootstrap.pypa.io/get-pip.py -OutFile get-pip.py
}

# Create Required Environment Folders
Write-Host ">> Creating Directory Structure..."
New-Item -Name "Scripts" -ItemType "directory" -Force | Out-Null
New-Item -Name "Lib" -ItemType "directory" -Force | Out-Null
New-Item -Name "Lib\site-packages" -ItemType "directory" -Force | Out-Null
New-Item -Name "Include" -ItemType "directory" -Force | Out-Null
New-Item -Name "DLLs" -ItemType "directory" -Force | Out-Null

# Extract Python Standard Library Zip to a folder (solves dynamic versioning and lib2to3 issues)
$stdlibZip = Get-ChildItem -Filter "python*.zip" | Select-Object -First 1
if ($stdlibZip) {
    $stdlibName = $stdlibZip.BaseName
    Write-Host "Extracting python library ($($stdlibZip.Name)) to .\$stdlibName..."
    Expand-Archive -Path $stdlibZip.Name -DestinationPath $stdlibName -Force
    Remove-Item -Path $stdlibZip.Name -Force
}

# Dynamically Configure the ._pth file
Write-Host "Configuring Python Imports (.pth)..."
$pthFile = Get-ChildItem -Filter "python*._pth" | Select-Object -First 1
if ($pthFile) {
    $pthContent = @(
        ".\$stdlibName",
        ".\Scripts",
        ".\Lib",
        ".\Lib\site-packages",
        ".\DLLs",
        ".",
        "",
        "# Import Sites",
        "import site"
    )
    Set-Content -Path $pthFile.Name -Value $pthContent
}

# Sitecustomize.py for True Portability
Write-Host "Configuring sitecustomize.py for fully portable packages..."
$siteCustomize = @"
import sys
import os

# Insert current directory
sys.path.insert(0, '')

# Magic patch for fully portable packages:
# If pip is being executed, trick it into thinking the executable is just 'python.exe'.
# This forces pip's distlib to create wrappers (like jupyter.exe, pytest.exe) with 
# a relative shebang (#!python.exe) instead of an absolute path tied to the machine!
try:
    if sys.argv:
        _arg0 = sys.argv[0].lower()
        if 'pip' in _arg0 or 'get-pip' in _arg0:
            sys.executable = 'python.exe'
except Exception:
    pass
"@
Set-Content -Path sitecustomize.py -Value $siteCustomize

# Install Pip
Write-Host "Installing Pip..."
.\python.exe get-pip.py --no-warn-script-location -q
if ($LASTEXITCODE -ne 0) {
    Write-Host "Pip Installation Failed!"
    Set-Location ..
    Exit 1
}
Remove-Item -Path get-pip.py -Force

Write-Host "---------------------------"

# Configure PATH for current setup block
Write-Host "Adding Python to Path..."
$env:Path = "$pwd;$pwd\Scripts;$env:Path"

# Validate Installation
Write-Host "Checking installation..."
python --version
if ($LASTEXITCODE -ne 0) {
    Write-Host "Python Installation Failed!"
    Set-Location ..
    Exit 1
}

pip --version
if ($LASTEXITCODE -ne 0) {
    Write-Host "Pip Installation Failed!"
    Set-Location ..
    Exit 1
}

# Move back to root directory
Set-Location ..

# Write the installation paths
New-Item -ItemType File -Path .\PATH.txt -Value "$pwd\$INSTALL_FOLDER_NAME;$pwd\$INSTALL_FOLDER_NAME\Scripts" -Force | Out-Null
# Create activation scripts unless -NoActivator is specified
if (-not $NoActivator) {
    Write-Host "Creating activation scripts..."
    
    # CMD/Batch activation script
    $activateBat = @'
@echo off
REM Store original PATH
set "_OLD_VIRTUAL_PATH=%PATH%"
set "_OLD_VIRTUAL_PROMPT=%PROMPT%"

REM Set environment variables
set "VIRTUAL_ENV=%~dp0"
set "PATH=%VIRTUAL_ENV%;%VIRTUAL_ENV%Scripts;%PATH%"

REM Update prompt
if defined _OLD_VIRTUAL_PROMPT (
    set "PROMPT=%_OLD_VIRTUAL_PROMPT%"
) else (
    set "_OLD_VIRTUAL_PROMPT=%PROMPT%"
)
set "PROMPT=(python) %PROMPT%"

echo Python environment activated.
echo Type 'deactivate' to exit.

REM Deactivation via doskey macro
doskey deactivate=set "PATH=%_OLD_VIRTUAL_PATH%" $T set "PROMPT=%_OLD_VIRTUAL_PROMPT%" $T set "VIRTUAL_ENV=" $T set "_OLD_VIRTUAL_PATH=" $T set "_OLD_VIRTUAL_PROMPT=" $T doskey deactivate=
'@
    Set-Content -Path "$INSTALL_FOLDER_NAME\activate.bat" -Value $activateBat
    
    # PowerShell activation script - mimics real venv behavior
    $activatePs1 = @'
# Activate Python environment (venv-style)

# Save current state
$global:_OLD_VIRTUAL_PATH = $env:PATH
$global:_OLD_VIRTUAL_PROMPT = $function:prompt
$env:VIRTUAL_ENV = $PSScriptRoot

# Add to PATH
$env:PATH = "$env:VIRTUAL_ENV;$env:VIRTUAL_ENV\Scripts;$env:PATH"

# Modify prompt function
function global:prompt {
    Write-Host -NoNewline -ForegroundColor Green "(python) "
    if ($global:_OLD_VIRTUAL_PROMPT) {
        & $global:_OLD_VIRTUAL_PROMPT
    } else {
        "PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) "
    }
}

# Deactivate function
function global:deactivate {
    if ($global:_OLD_VIRTUAL_PATH) {
        $env:PATH = $global:_OLD_VIRTUAL_PATH
        Remove-Variable -Scope Global -Name _OLD_VIRTUAL_PATH
    }
    if ($global:_OLD_VIRTUAL_PROMPT) {
        $function:prompt = $global:_OLD_VIRTUAL_PROMPT
        Remove-Variable -Scope Global -Name _OLD_VIRTUAL_PROMPT
    }
    if ($env:VIRTUAL_ENV) {
        Remove-Item -Path Env:VIRTUAL_ENV
    }
    Remove-Item -Path Function:\deactivate
    Write-Host "Environment deactivated." -ForegroundColor Yellow
}

Write-Host "Python environment activated." -ForegroundColor Green
Write-Host "Type 'deactivate' to exit." -ForegroundColor Gray
'@
    Set-Content -Path "$INSTALL_FOLDER_NAME\activate.ps1" -Value $activatePs1
    
    Write-Host "Activation scripts created:"
    Write-Host "  - activate.bat (for CMD)"
    Write-Host "  - activate.ps1 (for PowerShell)"
} else {
    Write-Host "Skipping activation script creation (-NoActivator specified)."
}

Write-Host ""
Write-Host "-----------------------------------"
Write-Host "|   Portable Python Installed!   |"
Write-Host "-----------------------------------"
Write-Host "Version  : $Version"
Write-Host "Location : .\$INSTALL_FOLDER_NAME"
Write-Host ""
Write-Host "To use this portable environment:"
if (-not $NoActivator) {
    Write-Host "  CMD:     $INSTALL_FOLDER_NAME\activate.bat"
    Write-Host "  PowerShell: .\$INSTALL_FOLDER_NAME\activate.ps1"
} else {
    Write-Host "  Add these paths to your PATH:"
    Write-Host "    $pwd\$INSTALL_FOLDER_NAME"
    Write-Host "    $pwd\$INSTALL_FOLDER_NAME\Scripts"
}
Exit 0
Write-Host ""
Write-Host "Note: If you're using with IDA Pro, ensure to configure the Python using `.\idapyswitch.exe --force-path .\python312\python3.dll --auto-apply`"
Write-Host ""
Write-Host "-----------------------------------"
Write-Host "|   Portable Python Installed!   |"
Write-Host "-----------------------------------"
Write-Host "Version  : $Version"
Write-Host "Location : .\$INSTALL_FOLDER_NAME"
Write-Host ""
Write-Host "To use this portable environment, ensure the paths in PATH.txt are prefixed to your system PATH."
Exit 0
