# -----------------------
#      Msys2 Portable
# -----------------------

# read https://community.chocolatey.org/packages/msys2#files for
# setup instructions

# Usage:
#  .\Msys2_Install.ps1 [-InstallPath <path>] [-VersionTag <tag>] [-NoUpdate] [-NoDevelopmentTools] [-NoMirrorOptimization] [-Force] [-help]
# 
# Run directly from the web:
#  iwr -useb https://raw.githubusercontent.com/CypherpunkSamurai/portable-windows-installers/refs/heads/master/msys2_portable.ps1 | iex
#  
# Run from web with parameters:
#  $params = @{InstallPath = "D:\msys2"; NoUpdate = $true}; 
#  iwr -useb https://raw.githubusercontent.com/username/repo/main/Msys2_Install.ps1 | iex; Msys2_Install @params
#
# -InstallPath <path>   : Path to install MSYS2 (default: current directory\msys2)
# -VersionTag <tag>     : Version tag to download (default: latest)
# -NoUpdate             : Skip updating the package database and core system packages
# -NoDevelopmentTools   : Skip installing GCC and other development tools
# -NoMirrorOptimization : Skip optimizing package mirrors
# -Force                : Remove existing installation if it exists
# -help                 : Show this help message

# Parse command line arguments
param(
    [string]$InstallPath = (Join-Path -Path (Get-Location) -ChildPath "msys2"),
    [string]$VersionTag = "latest",
    [switch]$NoUpdate,
    [switch]$NoDevelopmentTools,
    [switch]$NoMirrorOptimization,
    [switch]$Force,
    [switch]$help
)

# Check if help is requested
if ($help) {
    Write-Host "Usage:"
    Write-Host "  .\Msys2_Install.ps1 [-InstallPath <path>] [-VersionTag <tag>] [-NoUpdate] [-NoDevelopmentTools] [-NoMirrorOptimization] [-Force] [-help]"
    Write-Host ""
    Write-Host "Run directly from the web:"
    Write-Host "  iwr -useb https://raw.githubusercontent.com/username/repo/main/Msys2_Install.ps1 | iex"
    Write-Host ""
    Write-Host "Run from web with parameters:"
    Write-Host "  `$params = @{InstallPath = `"D:\msys2`"; NoUpdate = `$true}"
    Write-Host "  iwr -useb https://raw.githubusercontent.com/username/repo/main/Msys2_Install.ps1 | iex; Msys2_Install @params"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -InstallPath <path>   : Path to install MSYS2 (default: current directory\msys2)"
    Write-Host "  -VersionTag <tag>     : Version tag to download (default: latest)"
    Write-Host "  -NoUpdate             : Skip updating the package database and core system packages"
    Write-Host "  -NoDevelopmentTools   : Skip installing GCC and other development tools"
    Write-Host "  -NoMirrorOptimization : Skip optimizing package mirrors"
    Write-Host "  -Force                : Remove existing installation if it exists"
    Write-Host "  -help                 : Show this help message"
    exit
}

# GetDownloadUrl function to get the download URL for MSYS2 Installer
function Get-DownloadUrl {
    param (
        [string]$VersionTagString = "latest"
    )

    # Base URL for MSYS2 releases
    $msys2_repository = "msys2/msys2-installer"
    
    try {
        if ($VersionTagString -eq "latest") {
            # For latest version, fetch from GitHub API
            $api_url = "https://api.github.com/repos/$msys2_repository/releases/latest"
            $release = Invoke-RestMethod -Uri $api_url
        } else {
            # For specific version tag
            $api_url = "https://api.github.com/repos/$msys2_repository/releases/tags/$VersionTagString"
            $release = Invoke-RestMethod -Uri $api_url
        }
        
        # Find asset that matches the SFX pattern (*.sfx.exe)
        $asset = $release.assets | Where-Object { $_.name -match '\.sfx\.exe$' } | Select-Object -First 1
        
        if ($asset) {
            Write-Host "Found download: $($asset.name)"
            return $asset.browser_download_url
        } else {
            Write-Error "No SFX archive found in the release"
            exit 1
        }
    } catch {
        Write-Error "Failed to fetch release information: $_"
        exit 1
    }
}

# DownloadFile function to download a file from a URL
function DownloadFile {
    param (
        [string]$Url,
        [string]$DestinationPath
    )

    Write-Host "Downloading $Url to $DestinationPath..."
    try {
        Invoke-WebRequest -Uri $Url -OutFile $DestinationPath -UseBasicParsing
    } catch {
        Write-Error "Failed to download file: $_"
        exit 1
    }
}

# Extract-Msys2 function to extract the MSYS2 installer
function Extract-Msys2 {
    param (
        [string]$InstallerFile,
        [string]$DestinationPath
    )

    Write-Host "Extracting $InstallerFile to temporary location..."
    # !WARN! no-space after -o is required for 7z to work properly, otherwise it will fail
    & "$InstallerFile" -y -o"$DestinationPath"
    
    # Check for the bash.exe file in both possible locations
    if (Test-Path "$DestinationPath\usr\bin\bash.exe") {
        Write-Host "MSYS2 extracted directly to destination path"
    }
    elseif (Test-Path "$DestinationPath\msys64\usr\bin\bash.exe") {
        Write-Host "MSYS2 extracted to msys64 subdirectory - moving files up one level"
        
        # Get all items from msys64 directory
        $items = Get-ChildItem -Path "$DestinationPath\msys64" -Force
        
        # Move all items to the destination directory
        foreach ($item in $items) {
            $targetPath = Join-Path -Path $DestinationPath -ChildPath $item.Name
            Move-Item -Path $item.FullName -Destination $targetPath -Force
        }
        
        # Remove the now empty msys64 directory
        Remove-Item -Path "$DestinationPath\msys64" -Force -ErrorAction SilentlyContinue
        
        # Verify the move worked
        if (-not (Test-Path "$DestinationPath\usr\bin\bash.exe")) {
            Write-Error "Failed to move MSYS2 files from msys64 subdirectory"
            exit 1
        }
    }
    else {
        # List what was actually extracted for diagnostic purposes
        Write-Host "Listing extracted contents:"
        Get-ChildItem -Path $DestinationPath -Recurse -Depth 2 | ForEach-Object { Write-Host $_.FullName }
        
        Write-Error "Failed to extract MSYS2 properly. The bash.exe file couldn't be found."
        exit 1
    }
}

# Add a function to verify file existence before executing commands
function Invoke-MsysCommand {
    param (
        [string]$Msys2Path,
        [string]$Command
    )
    
    $bashPath = "$Msys2Path\usr\bin\bash.exe"
    if (Test-Path $bashPath) {
        & "$bashPath" --login -c $Command
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Command returned exit code $($LASTEXITCODE): $Command"
        }
    } else {
        Write-Error "Cannot execute command: bash.exe not found at $bashPath"
    }
}

# Update Msys2ConfigInit to use the new function
function Msys2ConfigInit {
    param (
        [string]$Msys2Path = $InstallPath
    )

    # Initialize MSYS2 environment
    Write-Host "Setting up MSYS2 environment..."
    Invoke-MsysCommand -Msys2Path $Msys2Path -Command "echo 'Setting up MSYS2 environment...'"

    # Clean and reinitialize GnuPG keys
    Remove-Item "$Msys2Path\etc\pacman.d\gnupg\*" -Force -Recurse -ErrorAction SilentlyContinue
    Invoke-MsysCommand -Msys2Path $Msys2Path -Command "pacman-key --init"
    Invoke-MsysCommand -Msys2Path $Msys2Path -Command "pacman-key --populate msys2"
    Invoke-MsysCommand -Msys2Path $Msys2Path -Command "pacman-key --refresh-keys"
}

# Update Msys2ConfigMirrors to use the new function
function Msys2ConfigMirrors {
    param (
        [string]$Msys2Path = $InstallPath
    )
    
    # Rank mirrors for all repositories
    foreach ($repo in @("clang32", "clang64", "mingw", "mingw32", "mingw64", "msys", "ucrt64")) {
        Write-Host "Creating Backup of $repo mirrorlist..."
        $mirrorListPath = "$Msys2Path\etc\pacman.d\mirrorlist.$repo"
        if (Test-Path $mirrorListPath) {
            Copy-Item $mirrorListPath "$mirrorListPath.bak" -ErrorAction SilentlyContinue
            if (Test-Path "$mirrorListPath.bak") {
                Write-Host "Ranking mirrors for $repo repository..."
                # Convert Windows paths to Unix paths for bash
                $unixPathBak = $mirrorListPath + ".bak" -replace '\\', '/'
                $unixPathOut = $mirrorListPath -replace '\\', '/'
                Invoke-MsysCommand -Msys2Path $Msys2Path -Command "rankmirrors -n 6 '$unixPathBak' > '$unixPathOut'"
            }
        }
    }
}

# Update Msys2ConfigUpdate to use the new function
function Msys2ConfigUpdate {
    param (
        [string]$Msys2Path = $InstallPath
    )

    # Update package database and core system packages
    Write-Host "Updating package database and core system packages..."
    Invoke-MsysCommand -Msys2Path $Msys2Path -Command "pacman -Syuu --noconfirm"
}

# Update Msys2ConfigDevelopmentTools to use the new function
function Msys2ConfigDevelopmentTools {
    param (
        [string]$Msys2Path = $InstallPath
    )

    # Install development tools
    Write-Host "Installing development tools..."
    Invoke-MsysCommand -Msys2Path $Msys2Path -Command "pacman -S --noconfirm --needed git zsh make diffutils patchutils grep which wget curl mingw-w64-x86_64-toolchain base-devel"
    Invoke-MsysCommand -Msys2Path $Msys2Path -Command "pacman -S --noconfirm --needed make yasm pkg-config autotools mingw-w64-x86_64-autotools"
    Invoke-MsysCommand -Msys2Path $Msys2Path -Command "pacman -S --noconfirm --needed mingw-w64-x86_64-clang mingw-w64-x86_64-ninja mingw-w64-x86_64-cmake"
    Invoke-MsysCommand -Msys2Path $Msys2Path -Command "pacman -S --noconfirm --needed mingw-w64-x86_64-bat"
}


function Main {
    # Check if the install path already exists
    if (Test-Path $InstallPath) {
        if ($Force) {
            Write-Host "Removing existing installation at $InstallPath"
            Remove-Item -Path $InstallPath -Force -Recurse
        } else {
            Write-Host "The specified install path already exists. Please choose a different path or use -Force to overwrite."
            exit 1
        }
    }

    # Create the install directory
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    
    # Get the download URL for MSYS2 installer
    $downloadUrl = Get-DownloadUrl -VersionTagString $VersionTag

    # Define the installer file name
    $installerFile = Join-Path -Path $InstallPath -ChildPath "msys2.sfx.exe"

    # Download the MSYS2 installer
    DownloadFile -Url $downloadUrl -DestinationPath $installerFile

    # Extract the MSYS2 installer
    Extract-Msys2 -InstallerFile $installerFile -DestinationPath $InstallPath

    # Remove the installer file after extraction
    Remove-Item $installerFile -Force

    # Initialize MSYS2 configuration
    Msys2ConfigInit -Msys2Path $InstallPath

    # Optimize mirrors for faster downloads if not skipped
    if (-not $NoMirrorOptimization) {
        Msys2ConfigMirrors -Msys2Path $InstallPath
    }

    # Update package database and core system packages if not skipped
    if (-not $NoUpdate) {
        Msys2ConfigUpdate -Msys2Path $InstallPath
    }

    # Install development tools if not skipped
    if (-not $NoDevelopmentTools) {
        Msys2ConfigDevelopmentTools -Msys2Path $InstallPath
    }

    Write-Host "MSYS2 has been installed successfully at $InstallPath"
    Write-Host "You can start MSYS2 by running '$InstallPath\msys2_shell.cmd -defterm -here -no-start -mingw64 -shell bash'"
    Out-File "$InstallPath\msys2_shell.cmd -defterm -here -no-start -mingw64 -shell bash" -FilePath .\MsysCmd_Mingw64.bat
}

# Execute the main function
Main
