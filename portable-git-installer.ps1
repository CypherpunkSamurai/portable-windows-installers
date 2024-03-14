# CypherpunkSamurai's Portable Git Installer
Write-Host "#################################################
#                                               #
#       Windows Portable Git Installer 🍺       #
#                                               #
#################################################
"

$INSTALL_FOLDER_NAME = "git"
$INSTALL_FILE_NAME = "git-installer.zip"
Write-Host "
>> Installing to Folder: .\$INSTALL_FOLDER_NAME
"

# Check if the git folder exists
if (Test-Path $INSTALL_FOLDER_NAME -PathType Container) {
    # Echo error
    Write-Host "❌ Found Existing Installation!"
    # Write-Host ">> Installer will now exit..."
    # Exit 1
    # Echo Deleting folder
    Write-Host "🗑️  Deleting $INSTALL_FOLDER_NAME folder..."
    # Delete the folder
    Remove-Item -Path .\$INSTALL_FOLDER_NAME -Recurse -Force
}

# Check AMD64 or x86
Write-Host "`n[~] Checking Architecture... 🖥️"
# Set a variable to use later
$arch = (Get-WmiObject -Class Win32_Processor).AddressWidth
# Print the architecture
Write-Host ">> Architecture: $arch"

# Download the Git zip file
if (Test-Path "$INSTALL_FILE_NAME") {
    Write-Host "`n📦 Found Existing Git Zip!"
} else {
    Write-Host "`n📥 Downloading Git..."
    if ($arch -eq 64) {
        # Download the 64-bit version
        Invoke-WebRequest -OutFile .\$INSTALL_FILE_NAME -Uri "https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.2/MinGit-2.42.0.2-64-bit.zip"
    } elseif ($arch -eq 32) {
        # Download the 32-bit version
        Invoke-WebRequest -OutFile .\$INSTALL_FILE_NAME -Uri "https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.2/MinGit-2.42.0.2-32-bit.zip"
    } else {
        # Echo error
        Write-Host "❌ Unknown Architecture!"
        Write-Host ">> Installer will now exit..."
        Exit 1
    }
}

# Unzip the Git zip file
Write-Host "`n📦 Unzipping Git..."
Expand-Archive -Path .\$INSTALL_FILE_NAME -DestinationPath .\$INSTALL_FOLDER_NAME

# Change directory to the git folder
Set-Location .\$INSTALL_FOLDER_NAME

# Prefix the git bin folder to the PATH
Write-Host "`n🔗 Adding Git to PATH..."
$env:Path = "$pwd\cmd;$env:Path"

# Change back
Set-Location ..

# Test the git command
Write-Host "`n🔍 Testing Git..."
git --version
if ($LASTEXITCODE -eq 1) {
    # Echo error
    Write-Host "❌ Git Test Failed!"
    Write-Host ">> Installer will now exit..."
    Exit 1
}

New-Item -ItemType File -Path .\PATH.txt -Value "$pwd\$INSTALL_FOLDER_NAME\cmd;" -Force | Out-Null

# Echo success
Write-Host "`n🎉 Git Installed Successfully!"