# Msys2 Portable

# check if choco is installed
if (-Not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolatey not found, install Chocolatey and continue..."
    Exit 1
}

# Variables
# Install Path (current fodler + "msys2")
$InstallPath = "$PWD\compile"
$Msys2Path = "$InstallPath\msys64"


# Extract MSYS2
if (-Not (Test-Path $InstallPath)) {
    # Get Msys2
    if (-Not (Test-Path ".\msys2.exe")){
        Invoke-WebRequest -Uri "https://github.com/msys2/msys2-installer/releases/download/2024-07-27/msys2-base-x86_64-20240727.sfx.exe" -OutFile "msys2.exe"
    }
    # Extract
    .\msys2.exe x -y -o"$InstallPath"
    # Remove OLD PGP Keys and Init Keys
    Remove-Item "$Msys2Path\etc\pacman.d\gnupg\*" -Force -Recurse -ErrorAction SilentlyContinue

    # Pacman Get Keys
    # rm -r /etc/pacman.d/gnupg/ && pacman-key --init && pacman-key --populate msys2 && pacman-key --refresh-keys
    # use "bash pacman-key" as pacman-key is a script
    & "$Msys2Path\usr\bin\bash.exe" "$Msys2Path\usr\bin\pacman-key" --init
    & "$Msys2Path\usr\bin\bash.exe" "$Msys2Path\usr\bin\pacman-key" --populate msys2
    & "$Msys2Path\usr\bin\bash.exe" "$Msys2Path\usr\bin\pacman-key" --refresh-keys

    # copy backup
    cp "$Msys2Path\etc\pacman.d\mirrorlist" "$Msys2Path\etc\pacman.d\mirrorlist.bak"
    cp "$Msys2Path\etc\pacman.d\mirrorlist.mingw64" "$Msys2Path\etc\pacman.d\mirrorlist.mingw64.bak"
    # rank
    & "$Msys2Path\usr\bin\bash.exe" "$Msys2Path\usr\bin\rankmirrors" -n 6 "$Msys2Path\etc\pacman.d\mirrorlist.bak" > "$Msys2Path\etc\pacman.d\mirrorlist"
    & "$Msys2Path\usr\bin\bash.exe" "$Msys2Path\usr\bin\rankmirrors" -n 6 "$Msys2Path\etc\pacman.d\mirrorlist.mingw64.bak" > "$Msys2Path\etc\pacman.d\mirrorlist.mingw64"
}

# Change folder to Install Folder
Set-Location $InstallPath

# Set Environment Variables
$env:PATH="$Msys2Path\usr\bin;$env:PATH"
# Set Mingw64 Path
$env:PATH="$Msys2Path\mingw64\bin;$env:PATH"

# Set ENV Vars Temporarily
$env:CGO_LDFLAGS="-L$Msys2Path\mingw64\lib"
$env:CGO_CFLAGS="-I$Msys2Path\mingw64\include"
$env:PKG_CONFIG_PATH="$Msys2Path\mingw64\lib\pkgconfig"

# Update Packages
pacman -Syu

# Compile sample code
echo "FFMPEG_PATH=$(cygpath -u $(pwd))/ffmpeg" >> $env:INSTALLER_ENV

# Change folder to InstallPath
Set-Location $InstallPath

# Install Choco Packages
Set-ExecutionPolicy Bypass -Scope Process -Force;
$Packages = 'pkgconfiglite', 'make', 'yasm'
ForEach ($PackageName in $Packages)
{
    choco install $PackageName -f -y --allow-empty-checksums --no-progress --require-elevation=false
}

# Change folder to InstallPath
Set-Location $InstallPath

# Install MinGW-w64 toolchain
bash -c "pacman -S --noconfirm mingw-w64-x86_64-toolchain"
