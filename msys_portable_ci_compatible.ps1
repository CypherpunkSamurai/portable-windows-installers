# Refresh Msys2 Installation

# Paths
$msys2_extract_dir = "$PWD\msys2"

# Variables
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
Write-Host "Extracting $msys2_nightly_file to Current Directory..."
# & ".\$msys2_nightly_file" -y -o"$msys2_extract_dir"
& ".\$msys2_nightly_file" -y -o"$PWD"
Write-Host "Moving msys64 to $msys2_extract_dir"
Move-Item "$PWD\msys64" $msys2_extract_dir



# * Msys2 Post Install
# $msys2_distro_path = Join-Path $msys2_extract_dir "msys64"
# Distro path is now moved to msys2_extract_dir
$msys2_distro_path = $msys2_extract_dir
Write-Host "Configuring MSYS2 environment..."

# Set Env PATH
$env:PATH="$msys2_distro_path\usr\bin;$env:PATH"

# Initialize Msys2
& "$msys2_distro_path\usr\bin\bash.exe" --login -c "echo 'Setting up MSYS2 environment...'"


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

# Run with custom shell
# msys2_shell.cmd -shell fish


# Install Requirements
pacman -S --noconfirm --needed git zsh make diffutils patchutils grep which wget curl mingw-w64-x86_64-toolchain
pacman -S --noconfirm --needed make yasm pkg-config autotools mingw-w64-x86_64-autotools
pacman -S --noconfirm --needed mingw-w64-x86_64-clang
