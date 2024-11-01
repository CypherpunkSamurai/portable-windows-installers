# -----------------------
#      Msys2 Portable
# -----------------------

# * Variables
$msys2_portable_dir = "msys2-portable"
$msys2_extract_dir = "$pwd\$msys2_portable_dir"

# Get Latest Release from Github API
$msys2_repository = "msys2/msys2-installer"
$release_api = "https://api.github.com/repos/$msys2_repository/releases/latest"
$msys2_nightly_file = "msys2-nightly.sfx.exe"



# Check if Msys2 is already extracted
if (Test-Path $msys2_extract_dir) {
    Write-Host "MSYS2 is already installed to $msys2_extract_dir"
    $reinstall = Read-Host "Do you want to reinstall MSYS2? (y/n)"
    if ($reinstall -ne 'y') {
        Exit 1
    }
    Remove-Item $msys2_extract_dir -Recurse -Force
}

# Check if Msys2 installer is already downloaded
if (!(Test-Path $msys2_nightly_file)) {       
    # Fetch the Latest Url
    # Parse [0].assets[] where "name" ends with ".sfx.exe" 
    $release_url_nightly = (Invoke-RestMethod -Uri $release_api)[0] | Select-Object -ExpandProperty assets | Where-Object {$_.name -like "*.sfx.exe"} | Select-Object -ExpandProperty browser_download_url

    # Print Download Link
    Write-Host "Downloading MSYS2 Nightly from: $release_url_nightly"

    # Download File
    Invoke-WebRequest -Uri $release_url_nightly -OutFile $msys2_nightly_file

    # Notify download completion
    Write-Host "MSYS2 Nightly download complete: $msys2_nightly_file"
} else {
    Write-Host "MSYS2 Nightly already downloaded: $msys2_nightly_file"
}

# Extract SFX Archive
Write-Host "Extracting $msys2_nightly_file"
& ".\$msys2_nightly_file" -y -o"$msys2_extract_dir"



# * Msys2 Post Install
$msys2_distro_path = Join-Path $msys2_extract_dir "msys64"
Write-Host "Configuring MSYS2 environment..."

# Set Env PATH
$env:PATH="$msys2_distro_path\usr\bin;$env:PATH"

# Clean GnuPG keys and Update
Remove-Item "$msys2_distro_path\etc\pacman.d\gnupg\*" -Force -Recurse -ErrorAction SilentlyContinue
# Pacman Get Keys
# rm -r /etc/pacman.d/gnupg/ && pacman-key --init && pacman-key --populate msys2 && pacman-key --refresh-keys
# use "bash pacman-key" as pacman-key is a script
& "$msys2_distro_path\usr\bin\bash.exe" "$msys2_distro_path\usr\bin\pacman-key" --init
& "$msys2_distro_path\usr\bin\bash.exe" "$msys2_distro_path\usr\bin\pacman-key" --populate msys2
& "$msys2_distro_path\usr\bin\bash.exe" "$msys2_distro_path\usr\bin\pacman-key" --refresh-keys

# Rank Mirrors
foreach ($repo in @("clang32", "clang64", "mingw", "mingw32", "mingw64", "msys", "ucrt64")) {
    Write-Host "Creating Backup of $repo mirrorlist..."
    Copy-Item "$msys2_distro_path\etc\pacman.d\mirrorlist.$repo" "$msys2_distro_path\etc\pacman.d\mirrorlist.$repo.bak" -ErrorAction SilentlyContinue
    if (Test-Path "$msys2_distro_path\etc\pacman.d\mirrorlist.$repo.bak") {
        Write-Host "Ranking mirrors for $repo repository..."
        & "$msys2_distro_path\usr\bin\bash.exe" "$msys2_distro_path\usr\bin\rankmirrors" -n 6 "$msys2_distro_path\etc\pacman.d\mirrorlist.$repo.bak" > "$msys2_distro_path\etc\pacman.d\mirrorlist.$repo"
    }
}

# Update Packages
pacman -Syu --noconfirm

# Install Mingw-w64 packages
pacman -S --noconfirm mingw-w64-x86_64-toolchain
# Install make, diffutils, grep, which for building from source
pacman -S --noconfirm make diffutils patchutils grep which wget curl
# Install git for source control
pacman -S --noconfirm git

# Complete Msys2 Post Install
Write-Host "MSYS2 installation and configuration complete!"
