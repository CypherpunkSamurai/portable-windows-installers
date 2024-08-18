# FDM Portable Installer
# This in"staller gets a copy of Free Download Manager and creates a portable version of it in current folder
# @Author: Rakesh Chowdhury


# URLS
$FDM_LATEST = "https://files2.freedownloadmanager.org/6/latest/fdm_x64_setup.exe"
$FDM_EXE = "fdm_x64_setup.exe"
$TARGET_FOLDER = "$pwd\FDM_Portable"
$INNO_EXTRACTOR_URL = "https://github.com/dscharrer/innoextract/releases/download/1.9/innoextract-1.9-windows.zip"
$INNO_EXTRACTOR_ZIP = "innoextract.zip"


# Function to Download FDM
function DownloadFDM {
    Write-Host "Downloading FDM"
    Invoke-WebRequest -Uri $FDM_LATEST -OutFile $FDM_EXE
}

# Function to extract FDM
function ExtractFDM {
    Write-Host "Extracting FDM"
    mkdir $TARGET_FOLDER
    Invoke-WebRequest -Uri $INNO_EXTRACTOR_URL -OutFile $INNO_EXTRACTOR_ZIP
    Expand-Archive -Path $INNO_EXTRACTOR_ZIP -DestinationPath $TARGET_FOLDER
    & "$TARGET_FOLDER\innoextract\innoextract.exe" $FDM_EXE
}

# Function to cleanup
function Cleanup {
    Remove-Item $FDM_EXE -Force -ErrorAction SilentlyContinue
    Remove-Item $INNO_EXTRACTOR_ZIP -Force -ErrorAction SilentlyContinue
    Remove-Item "$pwd\innoextract" -Recurse -Force -ErrorAction SilentlyContinue
}

# Check
if (Test-Path $TARGET_FOLDER && -not (Test-Path $FDM_EXE) && -not (Test-Path $INNO_EXTRACTOR_ZIP)) {
    Write-Host "FDM already downloaded"
} else {
    DownloadFDM
}
# Extract
if (Test-Path $TARGET_FOLDER) {
    Write-Host "FDM already extracted"
} else {
    ExtractFDM
}
# Cleanup
Cleanup

# Run
Start-Process "$TARGET_FOLDER\fdm.exe" -NoNewWindow
exit 0