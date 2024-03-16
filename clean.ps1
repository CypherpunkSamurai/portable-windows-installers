# Cleaner for Portable Installations

# Remove all .exe files
Get-ChildItem -Path $PSScriptRoot -Filter *.exe | ForEach-Object { Remove-Item -Path $_.FullName -Force }

# Remove all .7z files
Get-ChildItem -Path $PSScriptRoot -Filter *.7z | ForEach-Object { Remove-Item -Path $_.FullName -Force }

# Remove all subfolders in $PSScriptRoot
Get-ChildItem -Path $PSScriptRoot -Directory | ForEach-Object { Remove-Item -Path $_.FullName -Recurse -Force }

# Echo
Write-Host "[i] Cleaning Complete! ✨"