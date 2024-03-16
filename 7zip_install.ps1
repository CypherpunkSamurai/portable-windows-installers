# 7zip Portable Insatller

# Constants
$7ZIP_VERSION = "2401"
$7ZIP_URL = "https://www.7-zip.org/a/7z$7ZIP_VERSION-x64.msi"
$MSI_PACKAGE = "7zip-installer.msi"

# Current folder + 7zip
$INSTALL_FOLDER = Join-Path $PSScriptRoot "7zip"

# Check for 7z.exe
if (Test-Path "$PSScriptRoot\7z.exe") {
    Write-Host "[i] 7z.exe already exists in $PSScriptRoot"
    Write-Host "[!] Exiting..."
    return
} else {
    Write-Host "[i] Installing 7zip $7ZIP_VERSION"
}

# Download 7zip
Invoke-WebRequest -Uri $7ZIP_URL -OutFile $MSI_PACKAGE
# Extract MSI Files to Temp Folder
Start-Process msiexec -Wait -ArgumentList "/a $MSI_PACKAGE /qb TARGETDIR=$INSTALL_FOLDER"

# Copy $INSTALL_FOLDER\Files\7-Zip\7z.exe to $PSScriptRoot\7z.exe
Copy-Item -Path "$INSTALL_FOLDER\Files\7-Zip\7z.exe" -Destination "$PSScriptRoot\7z.exe"

# Remove MSI Package and .\7zip\Files Recursively
Remove-Item -Path "$INSTALL_FOLDER" -Recurse -Force
Remove-Item -Path $PSScriptRoot\$MSI_PACKAGE -Force