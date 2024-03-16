# ComfyUI Installer

$CURRENT_FOLDER = $PSScriptRoot + "\"

# Constants
$COMFYUI_RELEASE = "https://github.com/comfyanonymous/ComfyUI/releases/download/latest/ComfyUI_windows_portable_nvidia_cu121_or_cpu.7z"
$COMFYUI_HOME = $CURRENT_FOLDER + "ComfyUI_windows_portable"
$COMFYUI_7ZIP = $CURRENT_FOLDER + "ComfyUI.7z"

# ComfyUI Manager
$COMFYUI_MANAGER = "https://github.com/ltdrdata/ComfyUI-Manager/archive/refs/heads/main.zip"

# Use aria2c to download the release
# Use 16 connections and 4MiB chunks
# Ignore SSL errors
if (-not (Test-Path "$PSScriptRoot\aria2c.exe")) {
    Write-Host "[!] aria2c.exe not found in $PSScriptRoot"
    Write-Host "[!] Please install aria2 first"
    Write-Host "[!] Exiting..."
    return
}
if (-not (Test-Path $COMFYUI_HOME)) {
    Write-Host "[i] No ComfyUI Installation..."
    # Check if ComfyUI 7z exists
    if (-not (Test-Path $COMFYUI_7ZIP)) {
        Write-Host "[i] Downloading ComfyUI 7z"
        Start-Process -FilePath "$PSScriptRoot\aria2c.exe" -ArgumentList "--out=$COMFYUI_7ZIP", "--max-connection-per-server=16", "--split=16", "--min-split-size=4M", "--summary-interval=0", "--disable-ipv6", "--check-certificate=false", "--auto-file-renaming=false", "--allow-overwrite=true", "--file-allocation=none", "--continue=true", "--dir=$PSScriptRoot", $COMFYUI_RELEASE -Wait
    } else {
        Write-Host "[i] ComfyUI 7z already exists"
    }
}

# Check if 7z is installed
if (-not (Test-Path "$PSScriptRoot\7z.exe")) {
    Write-Host "[!] 7z.exe not found in $PSScriptRoot"
    Write-Host "[!] Please install 7z first"
    Write-Host "[!] Exiting..."
    return
}

# Extract ComfyUI 7z if COMFYUI_HOME does not exist
if (-not (Test-Path $COMFYUI_HOME)) {
    Write-Host "[i] Extracting ComfyUI"
    # Extract ComfyUI 7z
    Start-Process -FilePath "$PSScriptRoot\7z.exe" -ArgumentList "x", "-o$PSScriptRoot -aoa -y", $COMFYUI_7ZIP -Wait -NoNewWindow -PassThru
    # Ask for deletion of 7z
    Write-Host "[?] Delete ComfyUI 7z?"
    $delete7z = Read-Host "y/N"
    if ($delete7z -eq "Y") {
        Remove-Item -Path $COMFYUI_7ZIP -Force
    }
} else {
    Write-Host "[i] ComfyUI already exists"
}

# Check if ComfyUI Manager exists
if (-not (Test-Path $COMFYUI_HOME\ComfyUI\custom_nodes\ComfyUI-Manager)) {
    Write-Host "[i] No ComfyUI Manager Installation..."
    # Change directory to ComfyUI
    Set-Location $COMFYUI_HOME
    .\python_embeded\python.exe -s -m -q pip install gitpython
    .\python_embeded\python.exe -c "import git; git.Repo.clone_from('https://github.com/ltdrdata/ComfyUI-Manager', './ComfyUI/custom_nodes/ComfyUI-Manager')"
} else {
    Write-Host "[i] ComfyUI Manager already exists"
}

# Install These Nodes from ComfyUI Manager
# - Insight Face - https://github.com/Gourieff/comfyui-reactor-node
# - IPAdapter - https://github.com/cubiq/ComfyUI_IPAdapter_plus
# - Impact Pack - https://github.com/ltdrdata/ComfyUI-Impact-Pack
# - Aux - https://github.com/Fannovel16/comfyui_controlnet_aux
# - Ultimate (for v1.5) - https://github.com/ssitu/ComfyUI_UltimateSDUpscale

# Install These CLIP Vision Nodes from ComfyUI Manager Models Tab
#  place models to ./ipadapter/ and ./loras/ (model with lora in the name)
# - CLIP VIT H - https://huggingface.co/laion/CLIP-ViT-H-14-laion2B-s32B-b79K
# - IP Adapter Models
#   - FaceID IPAdapter: https://huggingface.co/h94/IP-Adapter-FaceID/tree/main (download ip-adapter-faceid-plusv2_sdv1.5.bin and safetensors)
#   - Normal IPAdapter: https://huggingface.co/h94/IP-Adapter/tree/main (download models/ip-adapter-plus-face-sdv1.5 safetensors)

# Models
# https://civitai.com/models/132632/epicphotogasm?modelVersionId=363565
# https://civitai.com/models/241415/picxreal?modelVersionId=272376