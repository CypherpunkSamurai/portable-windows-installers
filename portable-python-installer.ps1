# CypherpunkSamurai's Portable Python3.10 Installer
Write-Host "#################################################
#                                               #
#       Windows Portable Python Installer 🍺    #
#                                               #
#################################################
"

$INSTALL_FOLDER_NAME = "python"
Write-Host "
>> Installing to Folder: .\$INSTALL_FOLDER_NAME

"

# Check if the python folder exists
if (Test-Path $INSTALL_FOLDER_NAME -PathType Container) {
    # Echo error
    Write-Host "❌ Found Existing Installation!"
    # Write-Host ">> Installer will now exit..."
    # Exit 1
    # Echo Deleting Python folder
    Write-Host "✅ Using installed version from $INSTALL_FOLDER_NAME folder..."
    # Delete the python folder
    # Remove-Item -Path .\$INSTALL_FOLDER_NAME -Recurse -Force
    # Check if PATH.txt exists
    if (Test-Path PATH.txt) {
        # Read the PATH.txt file
        $python_path = Get-Content PATH.txt
        # Add Path to current path
        $env:Path = "$pwd;$pwd\Scripts;$env:Path"
        $env:Path = "$python_path;$env:Path"
        # Version
        python --version
        # Drop to a python shell
        Exit 0
    }
}

# Check AMD64 or x86
Write-Host "`[~] Checking Architecture... 🖥️"
# Set a variable to use later
$arch = (Get-WmiObject -Class Win32_Processor).AddressWidth
# Print the architecture
Write-Host ">> Architecture: $arch"


# Check if the python.zip file exists
if (Test-Path python310-installer.zip) {
    # Echo Python.zip exists
    Write-Host "✅ Python Installer zip exists!"
} else {
    # Echo Python.zip does not exist
    Write-Host "📥 Downloading Python.zip..."
    if ($arch -eq "64") {
        # Download the python310-installer.zip file
        Invoke-WebRequest -Uri https://www.python.org/ftp/python/3.10.0/python-3.10.0-embed-amd64.zip -OutFile python310-installer.zip
    } else {
        # Download the python310-installer.zip file
        Invoke-WebRequest -Uri https://www.python.org/ftp/python/3.10.0/python-3.10.0-embed-win32.zip -OutFile python310-installer.zip
    }
}

# Extract the python.zip file
Write-Host "📦 Extracting Python.zip..."
Expand-Archive -Path python310-installer.zip -DestinationPath $INSTALL_FOLDER_NAME

# Change directory to the python folder
Set-Location .\$INSTALL_FOLDER_NAME

# Get Pip
if (Test-Path get-pip.py) {
    Write-Host ">> Pip Installer Found in current folder..."
} elseif (Test-Path ..\get-pip.py) {
    Write-Host ">> Pip Installer Found in Parent Folder..."
    Write-Host ">> Copying Pip Installer..."
    Copy-Item ..\get-pip.py .\get-pip.py
    Copy-Item 
} else {
    Write-Host "📥 Downloading Pip..."
    Invoke-WebRequest -Uri https://bootstrap.pypa.io/get-pip.py -OutFile get-pip.py
}

# Create Folders silently
Write-Host ">> Creating Folders..."
New-Item -Name "Scripts" -ItemType "directory" -Force | Out-Null
New-Item -Name "Lib" -ItemType "directory" -Force | Out-Null
New-Item -Name "Lib/site-packages" -ItemType "directory" -Force | Out-Null
New-Item -Name "Include" -ItemType "directory" -Force | Out-Null
New-Item -Name "DLLs" -ItemType "directory" -Force | Out-Null

# Extract the python310.zip file
Write-Host "📦 Extracting python library..."
Expand-Archive -Path python310.zip -DestinationPath python310
Remove-Item -Path python310.zip -Force

# Add Content to the python.pth file
Write-Host "📝 Configuring Python Installation... "
# Add-Content -Path python310.pth -Value "python310.zip"
# Add-Content -Path python310.pth -Value "# Paths"
Add-Content -Path python310._pth -Value ".\python310"
Add-Content -Path python310._pth -Value ".\Scripts"
Add-Content -Path python310._pth -Value ".\Lib"
Add-Content -Path python310._pth -Value ".\Lib\site-packages"
Add-Content -Path python310._pth -Value ".\DLLs"
Add-Content -Path python310._pth -Value "."
Add-Content -Path python310._pth -Value ""
Add-Content -Path python310._pth -Value "# Import Sites"
Add-Content -Path python310._pth -Value "import site"

# Sitecustomize.py
Add-Content -Path sitecustomize.py -Value "import sys"
Add-Content -Path sitecustomize.py -Value "sys.path.insert(0, '')"

# Run the get-pip.py file
Write-Host "📦 Installing Pip..."
.\python.exe get-pip.py -q
if ($LASTEXITCODE -ne 0) {
    # Echo error
    Write-Host "❌ Pip Installation Failed!"
    # Change folder
    Set-Location ..
    # Exit the script
    Exit
}
Remove-Item -Path get-pip.py -Force

Write-Host "---------------------------"

# Prefix the python folder and scripts to path for current session
Write-Host "🛣️  Adding Python to` Path..."
$env:Path = "$pwd;$pwd\Scripts;$env:Path"

# Change directory to the root
Set-Location ..

# Check if pip and python give error code
Write-Host "🧪 Checking installation..."
python --version
if ($LASTEXITCODE -ne 0) {
    # Echo error
    Write-Host "❌ Python Installation Failed!"
    # Exit the script
    Exit
}
pip --version
if ($LASTEXITCODE -ne 0) {
    # Echo error
    Write-Host "❌ Pip Installation Failed!"
    # Exit the script
    Exit
}

# Write the path to a file
New-Item -ItemType File -Path .\PATH.txt -Value "$pwd\$INSTALL_FOLDER_NAME;$pwd\$INSTALL_FOLDER_NAME\Scripts" -Force | Out-Null

# Print Python
Write-Host "
--------------------------
|   ✅ Python Installed! |
--------------------------"
Exit 0

# Notes:
#   How this Installer is Wokring?
#   Simple:
#       1. Get Python Embedded Zip file for the current architecture
#       2. Extract the files to a folder, and open the folder
#       3. Make required folders (Scripts, Lib, DLL, Lib\site-packages)
#       4. Extract python*.zip file in this folder to a folder with same name
#       5. Edit python*._pth file to use these folders as imports. (.\importpath)
#           .\python310
#           .\Scripts
#           .\Lib
#       6. Uncomment / add `import site` to the end of the ._pth file
#          this will run sitecustomize.py whenever python runs
#       7. Edit sitecustomize.py file to
#           import sys
#           sys.path.insert(0, '')
#       8. Get pip from get-pip.py
#       9. Install pip
#       10. Add python and scripts folder to path
#       11. Check pip is working
