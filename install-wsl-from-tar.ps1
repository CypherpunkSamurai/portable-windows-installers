#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Ubuntu WSL Distribution Installer and User Setup Script
    
.DESCRIPTION
    This script imports an Ubuntu WSL distribution from a tar.gz file and sets up proper users
    with Ubuntu-specific groups, sudo privileges, and secure configurations.
    
.PARAMETER DistroPath
    Path to the WSL distribution tar.gz file
    
.PARAMETER DistroName
    Name for the WSL distribution
    
.PARAMETER Username
    Username to create in the WSL distribution (default: ubuntu)
    
.PARAMETER Password
    Password for the new user (will be prompted if not provided)
    
.PARAMETER InstallLocation
    Location to install the WSL distribution (default: C:\WSL)

.EXAMPLE
    .\installer.ps1 -DistroPath ".\install.tar.gz" -DistroName "Ubuntu-22.04"
    
.NOTES
    Requires Windows 10 version 2004 or higher (Build 19041 or higher)
    Requires WSL 2 feature to be enabled
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$DistroPath,
    
    [Parameter(Mandatory = $true, Position = 1)]
    [string]$DistroName,
    
    [Parameter(Mandatory = $false)]
    [string]$Username = "ubuntu",
    
    [Parameter(Mandatory = $false)]
    [SecureString]$Password,
    
    [Parameter(Mandatory = $false)]
    [string]$InstallLocation = "C:\Tools\WSL",

    [Parameter(Mandatory = $false)]
    [switch]$Python3Ubuntu,

    [Parameter(Mandatory = $false)]
    [switch]$Python3Miniconda,

    [Parameter(Mandatory = $false)]
    [switch]$Python3Miniforge,

    [Parameter(Mandatory = $false)]
    [switch]$NodeUbuntu,

    [Parameter(Mandatory = $false)]
    [switch]$NodeNvm,
    
    [Parameter(Mandatory = $false)]
    [switch]$NodePnpm,

    [Parameter(Mandatory = $false)]
    [switch]$NodeBun,

    [Parameter(Mandatory = $false)]
    [ValidateSet("bash", "zsh", "fish")]
    [string]$Shell = "bash",

    [Parameter(Mandatory = $false)]
    [switch]$Ffmpeg
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to check WSL requirements
function Test-WSLRequirements {
    Write-ColorOutput "Checking WSL requirements..." "Yellow"
    
    # Check Windows version
    $osInfo = Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, WindowsBuildLabEx
    Write-ColorOutput "Windows Version: $($osInfo.WindowsVersion)" "Cyan"
    Write-ColorOutput "Build: $($osInfo.WindowsBuildLabEx)" "Cyan"
    
    # Check if WSL is available
    try {
        wsl --status 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✓ WSL is available" "Green"
        }
        else {
            throw "WSL not available"
        }
    }
    catch {
        Write-ColorOutput "✗ WSL 2 is not available. Please enable Virtual Machine Platform feature first." "Red"
        Write-ColorOutput "Run: Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform" "Yellow"
        exit 1
    }
}

# Function to validate distribution file
function Test-DistributionFile {
    param([string]$Path)
    
    Write-ColorOutput "Validating distribution file..." "Yellow"
    
    if (-not (Test-Path $Path)) {
        throw "Distribution file not found: $Path"
    }
    
    $fileInfo = Get-Item $Path
    if ($fileInfo.Name.EndsWith(".tar.gz") -or $fileInfo.Extension -eq ".tar") {
        # File is valid
    }
    else {
        throw "Invalid file format. Expected .tar.gz or .tar file, got: $($fileInfo.Name)"
    }
    
    Write-ColorOutput "✓ Distribution file validated: $($fileInfo.Name)" "Green"
    Write-ColorOutput "File size: $([math]::Round($fileInfo.Length / 1MB, 2)) MB" "Cyan"
    
    # Return the full path
    return $fileInfo.FullName
}

# Function to create installation directory
function New-InstallationDirectory {
    param([string]$Path)
    
    Write-ColorOutput "Creating installation directory..." "Yellow"
    
    if (-not (Test-Path $Path)) {
        try {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
            Write-ColorOutput "✓ Created directory: $Path" "Green"
        }
        catch {
            throw "Failed to create installation directory: $Path"
        }
    }
    else {
        Write-ColorOutput "✓ Directory already exists: $Path" "Green"
    }
}

# Function to import WSL distribution
function Import-WSLDistribution {
    param(
        [string]$DistroPath,
        [string]$DistroName,
        [string]$InstallLocation
    )
    
    Write-ColorOutput "Importing WSL distribution..." "Yellow"
    
    $distroInstallPath = Join-Path $InstallLocation $DistroName
    
    # Check if distribution already exists
    $existingDistros = wsl --list --quiet
    if ($existingDistros -contains $DistroName) {
        Write-ColorOutput "Warning: Distribution '$DistroName' already exists. Unregistering first..." "Yellow"
        wsl --unregister $DistroName
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "Warning: Failed to unregister existing distribution" "Yellow"
        }
    }
    
    try {
        # Import the distribution
        $importCommand = "wsl --import `"$DistroName`" `"$distroInstallPath`" `"$DistroPath`" --version 2"
        Write-ColorOutput "Running: $importCommand" "Cyan"
        
        Invoke-Expression $importCommand
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✓ Successfully imported distribution: $DistroName" "Green"
        }
        else {
            throw "Failed to import distribution. Exit code: $LASTEXITCODE"
        }
    }
    catch {
        throw "Failed to import WSL distribution: $($_.Exception.Message)"
    }
}

# Function to set up user account
function Set-WSLUserAccount {
    param(
        [string]$DistroName,
        [string]$Username,
        [SecureString]$Password
    )
    
    Write-ColorOutput "Setting up user account..." "Yellow"
    
    # Convert SecureString to plain text or use default
    if ($Password) {
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
    } else {
        $plainPassword = "ubuntu"
        Write-ColorOutput "Password not provided. Using default password: ubuntu" "Yellow"
    }
    
    try {
        # Check if user already exists
        $userCheck = wsl -d $DistroName -u root sh -c "id -u $Username 2>/dev/null || echo 'notfound'"
        if ($userCheck -ne "notfound") {
            Write-ColorOutput "User $Username already exists. Modifying user..." "Yellow"
            # Ensure home directory and shell are set correctly
            wsl -d $DistroName -u root usermod -s /bin/bash -d /home/$Username $Username
        }
        else {
            # Create user account
            $createUserCommand = "wsl -d $DistroName -u root useradd -m -s /bin/bash $Username"
            Write-ColorOutput "Creating user: $Username" "Cyan"
            Invoke-Expression $createUserCommand
        }
        
        # Set password
        $setPasswordCommand = "wsl -d $DistroName -u root sh -c 'echo `"$Username`:$plainPassword`" | chpasswd'"
        Write-ColorOutput "Setting password for user: $Username" "Cyan"
        Invoke-Expression $setPasswordCommand
        
        # Add user to Ubuntu-specific groups
        $addSudoCommand = "wsl -d $DistroName -u root usermod -aG sudo $Username"
        Write-ColorOutput "Adding user to sudo group" "Cyan"
        Invoke-Expression $addSudoCommand
        
        # Add user to additional Ubuntu groups for better functionality
        $addGroupsCommand = "wsl -d $DistroName -u root usermod -aG adm,dialout,cdrom,floppy,sudo,audio,dip,video,plugdev,netdev $Username"
        Write-ColorOutput "Adding user to Ubuntu groups (adm, dialout, cdrom, floppy, audio, dip, video, plugdev, netdev)" "Cyan"
        Invoke-Expression $addGroupsCommand
        
        # Configure sudoers to allow passwordless sudo for the user
        $sudoersLine = "$Username ALL=(ALL) NOPASSWD:ALL"
        $sudoersCommand = "wsl -d $DistroName -u root sh -c 'echo `"$sudoersLine`" > /etc/sudoers.d/$Username'"
        Write-ColorOutput "Configuring sudo access" "Cyan"
        Invoke-Expression $sudoersCommand
        
        # Set proper permissions on sudoers file
        $chmodCommand = "wsl -d $DistroName -u root chmod 440 /etc/sudoers.d/$Username"
        Invoke-Expression $chmodCommand
        
        Write-ColorOutput "✓ Successfully created user: $Username" "Green"
        Write-ColorOutput "✓ User added to sudo group" "Green"
        Write-ColorOutput "✓ Sudo access configured" "Green"
        
        return $plainPassword
    }
    catch {
        throw "Failed to set up user account: $($_.Exception.Message)"
    }
}

# Function to set up /etc/wsl.conf
function Set-WSLConf {
    param(
        [string]$DistroName,
        [string]$Username
    )
 
    Write-ColorOutput "Setting up /etc/wsl.conf..." "Yellow"
 
    $wslConfContent = @"
[user]
default=$Username
 
[boot]
systemd=true
 
[network]
generateResolvConf = true
"@
 
    try {
        $wslConfContent = $wslConfContent -replace "`r`n", "`n"
        $base64Content = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($wslConfContent))
        $wslConfCommand = "wsl -d $DistroName -u root sh -c 'echo `"$base64Content`" | base64 -d > /etc/wsl.conf'"
        Invoke-Expression $wslConfCommand
        Write-ColorOutput "✓ /etc/wsl.conf created successfully" "Green"
    }
    catch {
        throw "Failed to create /etc/wsl.conf: $($_.Exception.Message)"   
    }
}


 
# Function to validate installation parameters
function Validate-InstallationParameters {
    param(
        [switch]$Python3Ubuntu,
        [switch]$Python3Miniconda,
        [switch]$Python3Miniforge,
        [switch]$NodeUbuntu,
        [switch]$NodeNvm,
        [switch]$NodePnpm,
        [switch]$NodeBun
    )

    $pythonFlags = @($Python3Ubuntu, $Python3Miniconda, $Python3Miniforge) | Where-Object { $_ -eq $true }
    if ($pythonFlags.Count -gt 1) {
        throw "Only one Python installation flag can be specified at a time."
    }

    $nodeFlags = @($NodeUbuntu, $NodeNvm, $NodePnpm, $NodeBun) | Where-Object { $_ -eq $true }
    if ($nodeFlags.Count -gt 1) {
        throw "Only one Node.js installation flag can be specified at a time."
    }
}

# Function to configure WSL distribution
function Set-WSLConfiguration {
    param(
        [string]$DistroName,
        [string]$Username
    )
    
    Write-ColorOutput "Configuring WSL distribution..." "Yellow"
    
    try {
        # Update package lists
        Write-ColorOutput "Updating package lists..." "Cyan"
        wsl -d $DistroName -u root apt update -y
        wsl -d $DistroName -u root apt upgrade -y
        
        # Install Ubuntu-specific essential packages
        wsl -d $DistroName -u root apt install -y bash curl wget git vim nano htop build-essential software-properties-common apt-transport-https ca-certificates gnupg lsb-release openssh-client zip unzip
        wsl -d $DistroName -u root apt install -y net-tools iputils-ping dnsutils
        # Configure timezone to UTC for WSL
        wsl -d $DistroName -u root ln -sf /usr/share/zoneinfo/UTC /etc/localtime
        
        Write-ColorOutput "✓ WSL distribution configured successfully" "Green"
    }
    catch {
        Write-ColorOutput "Warning: Some configuration steps failed: $($_.Exception.Message)" "Yellow"
    }
}
 
# Function to install Development Tools
function Install-DevelopmentTools {
    param(
        [string]$DistroName,
        [string]$Username
    )
 
    Write-ColorOutput "Installing requested development tools..." "Yellow"
 
    if ($Python3Ubuntu) {
        Write-ColorOutput "Installing standard Python3..." "Cyan"
        wsl -d $DistroName -u root apt install -y python-is-python3 python3 python3-pip python3-venv
        Write-ColorOutput "Creating python and pip symlinks..." "Cyan"
        wsl -d $DistroName -u root sh -c "update-alternatives --install /usr/bin/python python /usr/bin/python3 1"
        wsl -d $DistroName -u root sh -c "update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1"
    }
    elseif ($Python3Miniconda) {
        Write-ColorOutput "Installing Miniconda..." "Cyan"
        $installScript = @"
mkdir -p ~/miniconda3
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
rm ~/miniconda3/miniconda.sh
~/miniconda3/bin/conda init bash
~/miniconda3/bin/conda init zsh
~/miniconda3/bin/conda init fish
~/miniconda3/bin/conda config --set auto_activate_base false
source ~/.bashrc
~/miniconda3/bin/conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
~/miniconda3/bin/conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
"@
        $installScript = $installScript -replace "`r`n", "`n"
        wsl -d $DistroName -u $Username sh -c $installScript
        Write-ColorOutput "To complete Miniconda setup, please start a new shell or run 'source ~/.bashrc'" "Yellow"
    }
    elseif ($Python3Miniforge) {
        Write-ColorOutput "Installing Miniforge..." "Cyan"
        
        # Get uname and uname -m results directly from WSL
        $wslUname = (wsl -d $DistroName -u $Username sh -c "uname" | Out-String).Trim()
        $wslUnameM = (wsl -d $DistroName -u $Username sh -c "uname -m" | Out-String).Trim()
 
        Write-ColorOutput "Detected UNAME: $wslUname" "Cyan"
        Write-ColorOutput "Detected UNAME_M: $wslUnameM" "Cyan"
 
        # Initialize conda and configure it within a single shell session using Base64 encoding
        $condaConfigScriptContent = @"
curl -Lf https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$wslUname-$wslUnameM.sh -o ~/miniforge3.sh
bash ~/miniforge3.sh -b -p ~/condaforge
rm ~/miniforge3.sh
~/condaforge/bin/conda init bash
~/condaforge/bin/conda init zsh
~/condaforge/bin/conda init fish
~/condaforge/bin/conda config --set auto_activate_base false
"@
        # Ensure Linux-style line endings before Base64 encoding
        $condaConfigScriptContent = $condaConfigScriptContent -replace "`r`n", "`n"
 
        $base64Script = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($condaConfigScriptContent))
        
        # Write Base64 string to a temp file in WSL
        wsl -d $DistroName -u $Username sh -c "echo '$base64Script' > /tmp/conda_config.b64"
        
        # Decode and execute the script from the temp file
        wsl -d $DistroName -u $Username sh -c "base64 -d /tmp/conda_config.b64 > /tmp/conda_config.sh && chmod +x /tmp/conda_config.sh && bash /tmp/conda_config.sh"
        
        # Clean up temp files
        wsl -d $DistroName -u $Username sh -c "rm /tmp/conda_config.b64 /tmp/conda_config.sh"
        
        Write-ColorOutput "To complete Miniforge setup, please start a new shell or run 'source ~/.bashrc'" "Yellow"
    }
    if ($NodeUbuntu) {
        Write-ColorOutput "Installing standard Node.js..." "Cyan"
        wsl -d $DistroName -u root apt install -y nodejs npm
    }
    elseif ($NodeNvm) {
        Write-ColorOutput "Installing NVM (Node Version Manager)..." "Cyan"
        $installScript = @"
export NVM_DIR="/home/$Username/.nvm"

# Create a script file to be sourced
touch /home/$Username/.bash_env

# Download and install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | PROFILE="/home/$Username/.bash_env" bash

# Source the new environment to make nvm available
. /home/$Username/.bash_env

# Add a startup command to .bashrc
echo '. /home/$Username/.bash_env' >> /home/$Username/.bashrc

# Install and use the latest LTS version of Node.js
nvm install --lts
nvm use --lts
"@
        $installScript = $installScript -replace "`r`n", "`n"
        wsl -d $DistroName -u $Username bash -c "$installScript"
        Write-ColorOutput "To complete NVM setup, please start a new shell or run 'source ~/.bashrc'" "Yellow"
    }
    elseif ($NodePnpm) {
        Write-ColorOutput "Installing Node.js with pnpm..." "Cyan"
        
        # Install nvm (Node Version Manager) and use LTS version
        $installScript = @"
export NVM_DIR="/home/$Username/.nvm"

# Create a script file to be sourced
touch /home/$Username/.bash_env

# Download and install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | PROFILE="/home/$Username/.bash_env" bash

# Source the new environment to make nvm available
. /home/$Username/.bash_env

# Add a startup command to .bashrc
echo '. /home/$Username/.bash_env' >> /home/$Username/.bashrc

# Install and use the latest LTS version of Node.js
nvm install --lts
nvm use --lts
"@
        $installScript = $installScript -replace "`r`n", "`n"
        wsl -d $DistroName -u $Username bash -c "$installScript"

        # Install pnpm
        $installScript = @"
# Install pnpm
curl -fsSL https://get.pnpm.io/install.sh | sh -
"@
        $installScript = $installScript -replace "`r`n", "`n"
        wsl -d $DistroName -u $Username sh -c $installScript
        Write-ColorOutput "To complete pnpm setup, please start a new shell or run 'source ~/.bashrc'" "Yellow"
    }
    elseif ($NodeBun) {
        Write-ColorOutput "Installing Bun..." "Cyan"

        # Install nvm (Node Version Manager) and use LTS version
        $installScript = @"
export NVM_DIR="/home/$Username/.nvm"

# Create a script file to be sourced
touch /home/$Username/.bash_env

# Download and install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | PROFILE="/home/$Username/.bash_env" bash

# Source the new environment to make nvm available
. /home/$Username/.bash_env

# Add a startup command to .bashrc
echo '. /home/$Username/.bash_env' >> /home/$Username/.bashrc

# Install and use the latest LTS version of Node.js
nvm install --lts
nvm use --lts
"@
        $installScript = $installScript -replace "`r`n", "`n"
        wsl -d $DistroName -u $Username bash -c "$installScript"
        
        $installScript = @"
# Install bun
curl -fsSL https://bun.sh/install | bash
"@
        $installScript = $installScript -replace "`r`n", "`n"
        wsl -d $DistroName -u $Username bash -c "$installScript"
        
        Write-ColorOutput "To complete Bun setup, please start a new shell or run 'source ~/.bashrc'" "Yellow"
    }
 
    Write-ColorOutput "✓ Development tools installation process completed." "Green"
}

# Function to install FFmpeg
function Install-FFmpeg {
    param(
        [string]$DistroName,
        [string]$Username
    )

    Write-ColorOutput "Installing FFmpeg..." "Yellow"

    wsl -d $DistroName -u $Username apt install -y ffmpeg

    Write-ColorOutput "✓ FFmpeg installation process completed." "Green"
}

# Function to install Oh-My-Bash
function Install-Shell-Config {
    param(
        [string]$ShellName,
        [string]$Username
    )

    if ($ShellName -eq "bash") {
        Write-ColorOutput "Installing Oh-My-Bash..." "Yellow"
        wsl -d $DistroName -u $Username apt install -y bash
        wsl -d $DistroName -u $Username bash -c "bash -c $(wget https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh -O -)"
        # OSH_THEME="random" or "simple" or "cypher"
        wsl -d $DistroName -u $Username bash -c "echo 'export OSH_THEME=\"cypher\"' >> ~/.bashrc"
        # Change Shell to Bash
        wsl -d $DistroName -u $Username bash -c 'chsh -s $(which bash)'
    }
    elseif ($ShellName -eq "zsh") {
        Write-ColorOutput "Installing Oh-My-Zsh..." "Yellow"
        wsl -d $DistroName -u $Username apt install -y zsh
        wsl -d $DistroName -u $Username "curl -fsSL https://install.ohmyz.sh | zsh"
        # ZSH_THEME="random" or "simple" or "cypher"
        wsl -d $DistroName -u $Username sh -c "echo 'export ZSH_THEME=\"cypher\"' >> ~/.zshrc"
        # Change Shell to Zsh
        wsl -d $DistroName -u $Username sh -c 'chsh -s $(which zsh)'
    }
    elseif ($ShellName -eq "fish") {
        Write-ColorOutput "Installing Fish..." "Yellow"
        wsl -d $DistroName -u $Username apt install -y fish
        # Install Oh-My-Fish
        wsl -d $DistroName -u $Username fish -c "curl https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install | fish"
        # Change Shell to Fish
        wsl -d $DistroName -u $Username sh -c 'chsh -s $(which fish)'
    }
    else {
        throw "Invalid shell name: $ShellName"
    }
}

# Function to install Neovim
function Install-Neovim {
    param(
        [string]$DistroName,
        [string]$Username
    )

    Write-ColorOutput "Installing Neovim..." "Yellow"
    
    # Download Neovim Nightly
    $downloadUrl = "https://github.com/neovim/neovim/releases/download/nightly/nvim-linux-x86_64.tar.gz"

    wsl -d $DistroName -u $Username wget -O ~/nvim.tar.gz $downloadUrl

    # Extract Neovim Nightly
    wsl -d $DistroName -u $Username mkdir -p ~/.local/bin
    wsl -d $DistroName -u $Username tar -xzf ~/nvim.tar.gz -C ~/.local/bin

    # Install Kickstart Neovim Distro
    wsl -d $DistroName -u $Username sh -c "apt install -y git"
    wsl -d $DistroName -u $Username sh -c "git clone https://github.com/nvim-lua/kickstart.nvim.git ~/.config/nvim"

    # Alias Neovim
    wsl -d $DistroName -u $Username sh -c "echo 'alias nvim=\"~/.local/bin/nvim\"' >> ~/.bashrc"

    Write-ColorOutput "✓ Neovim installation process completed." "Green"
}

# Function to test the installation
function Test-WSLInstallation {
    param(
        [string]$DistroName,
        [string]$Username
    )
    
    Write-ColorOutput "Testing WSL installation..." "Yellow"
    
    try {
        # Test basic functionality
        $testCommand = "wsl -d $DistroName -u $Username whoami"
        $result = Invoke-Expression $testCommand
        
        if ($result -eq $Username) {
            Write-ColorOutput "✓ Basic functionality test passed" "Green"
        }
        else {
            throw "Basic functionality test failed. Expected: $Username, Got: $result"
        }
        
        # Test sudo access
        $sudoTestCommand = "wsl -d $DistroName -u $Username sudo whoami"
        $sudoResult = Invoke-Expression $sudoTestCommand
        
        if ($sudoResult -eq "root") {
            Write-ColorOutput "✓ Sudo access test passed" "Green"
        }
        else {
            throw "Sudo access test failed. Expected: root, Got: $sudoResult"
        }
        
        Write-ColorOutput "✓ All tests passed successfully!" "Green"
    }
    catch {
        throw "Installation test failed: $($_.Exception.Message)"
    }
}



# Main execution
function Main {
    Write-ColorOutput "===============================================" "Magenta"
    Write-ColorOutput "    WSL Distribution Installer Script" "Magenta"
    Write-ColorOutput "===============================================" "Magenta"
    Write-ColorOutput ""
    
    # Check requirements
    Test-WSLRequirements

    # Validate installation parameters
    Validate-InstallationParameters -Python3Ubuntu:$Python3Ubuntu -Python3Miniconda:$Python3Miniconda -Python3Miniforge:$Python3Miniforge `
                                    -NodeUbuntu:$NodeUbuntu -NodeNvm:$NodeNvm -NodePnpm:$NodePnpm -NodeBun:$NodeBun
    
    # Validate distribution file and get full path
    $fullDistroPath = Test-DistributionFile -Path $DistroPath
    
    # Create installation directory
    New-InstallationDirectory -Path $InstallLocation
    
    # Import WSL distribution
    Import-WSLDistribution -DistroPath $fullDistroPath -DistroName $DistroName -InstallLocation $InstallLocation
    
    # Set up user account
    $finalPassword = Set-WSLUserAccount -DistroName $DistroName -Username $Username -Password $Password
    
    # Set up /etc/wsl.conf
    Set-WSLConf -DistroName $DistroName -Username $Username

    Write-ColorOutput "Terminating WSL distribution for /etc/wsl.conf to take effect..." "Yellow"
    wsl --terminate $DistroName
    
    # Configure WSL distribution
    Set-WSLConfiguration -DistroName $DistroName -Username $Username
 
    # Install development tools if requested
    if ($Python3Ubuntu -or $Python3Miniconda -or $Python3Miniforge -or $NodeUbuntu -or $NodeNvm -or $NodePnpm -or $NodeBun) {
        Install-DevelopmentTools -DistroName $DistroName -Username $Username
    }

    # Install shell if requested
    if ($Shell) {
        Install-Shell-Config -ShellName $Shell -Username $Username
    }

    # Install FFmpeg if requested
    if ($Ffmpeg) {
        Install-FFmpeg -DistroName $DistroName -Username $Username
    }
    
    # Test the installation
    Test-WSLInstallation -DistroName $DistroName -Username $Username
    
    # Display summary
    Write-ColorOutput ""
    Write-ColorOutput "===============================================" "Green"
    Write-ColorOutput "    Installation Summary" "Green"
    Write-ColorOutput "===============================================" "Green"
    Write-ColorOutput "Distribution Name: $DistroName" "White"
    Write-ColorOutput "Installation Path: $InstallLocation\$DistroName" "White"
    Write-ColorOutput "Username: $Username" "White"
    Write-ColorOutput "Password: $finalPassword" "White"
    Write-ColorOutput ""
    Write-ColorOutput "To start the distribution, run:" "Yellow"
    Write-ColorOutput "wsl -d $DistroName" "Cyan"
    Write-ColorOutput ""
    Write-ColorOutput "To set as default distribution, run:" "Yellow"
    Write-ColorOutput "wsl --set-default $DistroName" "Cyan"
    Write-ColorOutput ""
    Write-ColorOutput "Installation completed successfully!" "Green"
}
 
# Execute main function
try {
    Main
}
catch {
    Write-ColorOutput "✗ Installation failed: $($_.Exception.Message)" "Red"
    Write-ColorOutput "Please check the error message above and try again." "Yellow"
    exit 1
}
