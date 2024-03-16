# Aria2 Install

# Constants
$ARIA2_PATH = "$PSScriptRoot\aria2c.exe"
$ARIA2_RELEASE = "https://github.com/q3aql/aria2-static-builds/releases/download/v1.36.0/aria2-1.36.0-win-64bit-build2.7z"

# Check for aria2.exe
if (Test-Path $ARIA2_PATH) {
    Write-Host "[i] aria2c.exe already exists in $PSScriptRoot"
    Write-Host "[!] Exiting..."
    return
} else {
    Write-Host "[i] Installing aria2"
}

# Download Aria2
if (-not (Test-Path "$PSScriptRoot\aria2.7z")) {
    Write-Host "[i] Downloading aria2"
    Invoke-WebRequest -Uri $ARIA2_RELEASE -OutFile "$PSScriptRoot\aria2.7z"
}

# Check if 7z.exe exists
if (-not (Test-Path "$PSScriptRoot\7z.exe")) {
    Write-Host "[!] 7z.exe not found in $PSScriptRoot"
    Write-Host "[!] Please install 7zip first"
    Write-Host "[!] Exiting..."
    return
}

# Extract aria2c.exe from aria2.7zt
Start-Process -FilePath "$PSScriptRoot\7z.exe" -ArgumentList "e $PSScriptRoot\aria2.7z -r *.exe -o$PSScriptRoot -aoa" -Wait -NoNewWindow -PassThru | Out-Null

# Remove aria2-* folder
Remove-Item -Path "$PSScriptRoot\aria2-*" -Recurse -Force
Remove-Item -Path "$PSScriptRoot\aria2.7z" -Force

# Check if aria2.exe exists
if (Test-Path $ARIA2_PATH) {
    Write-Host "[i] aria2.exe installed successfully"
} else {
    Write-Host "[!] aria2.exe not found in $PSScriptRoot"
    Write-Host "[!] Exiting..."
    return
}