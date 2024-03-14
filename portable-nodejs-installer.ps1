# CypherpunkSamurai's Portable NodeJS Installer
Write-Host "#################################################
#                                               #
#       Windows Portable NodeJS Installer 🍺    #
#                                               #
#################################################
"

$INSTALL_FOLDER_NAME = "nodejs"
$INSTALL_FILE_NAME = "nodejs.zip"
Write-Host "
>> Installing to Folder: .\$INSTALL_FOLDER_NAME

"

# Check if the nodejs folder exists
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


# Download the NodeJS zip file
if (Test-Path "$INSTALL_FILE_NAME") {
    # Echo error
    Write-Host "`n📦 Found Existing NodeJS Zip!"
} else {
    Write-Host "`n📥 Downloading NodeJS..."
    # Download the NodeJS zip file
    if ($arch -eq 64) {
        # Download the 64-bit version
        Invoke-WebRequest -Uri "https://nodejs.org/dist/v20.11.1/node-v20.11.1-win-x64.zip" -OutFile "$INSTALL_FILE_NAME"
    } elseif ($arch -eq 32) {
        # Download the 32-bit version
        Invoke-WebRequest -Uri "https://nodejs.org/dist/v20.11.1/node-v20.11.1-win-x86.zip" -OutFile "$INSTALL_FILE_NAME"
    } else {
        # Echo error
        Write-Host "❌ Unknown Architecture!"
        Write-Host ">> Installer will now exit..."
        Exit 1
    }
}

# Unzip the NodeJS zip file
Write-Host "`n📦 Unzipping NodeJS..."
# Unzip the NodeJS zip file
Expand-Archive -Path "$INSTALL_FILE_NAME" -DestinationPath .\$INSTALL_FOLDER_NAME

# Change Directory to the NodeJS folder
Write-Host "`📂 Changing Directory to .\$INSTALL_FOLDER_NAME..."
Set-Location .\$INSTALL_FOLDER_NAME

# Move the subdirectory contents to current directory
Get-ChildItem -Path .\* -Recurse | Move-Item -Destination .\ -Force

# Remove the subdirectory
Remove-Item -Path .\node-* -Recurse -Force

# Install Latest Npm Version
.\npm install -g --force --upgrade npm yarn

# Set current folder prefix to the PATH
Write-Host "`n🔗 Adding .\$INSTALL_FOLDER_NAME to PATH..."
$env:Path = "$pwd;$pwd\node_modules\.bin;$env:Path"

# Change Directory to the parent directory
Set-Location ..

# Test Installation
Write-Host "`n🧪 Testing Installation..."
node -v
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ NodeJS Installation Failed!"
    Write-Host ">> Installer will now exit..."
    Exit 1
}
npm -v
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Npm Installation Failed!"
    Write-Host ">> Installer will now exit..."
    Exit 1
}
yarn -v
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Yarn Installation Failed!"
    Write-Host ">> Installer will now exit..."
    Exit 1
}

New-Item -ItemType File -Path .\PATH.txt -Value "$pwd\$INSTALL_FOLDER_NAME\cmd;$pwd\$INSTALL_FOLDER_NAME\node_modules\.bin;" -Force | Out-Null

# Echo Success
Write-Host "`n🎉 NodeJS Installation Successful!"