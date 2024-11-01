# Build ffmpeg and go-astiav using msys2 on windows 

# code was created from workflow file (https://github.com/asticode/go-astiav/blob/bc148523bc707cb628df76f2811c579d8b69ce9b/.github/workflows/test.yml)
# and patch (https://github.com/asticode/go-astiav/blob/bc148523bc707cb628df76f2811c579d8b69ce9b/.github/workflows/windows.patch)
# and makefile (https://github.com/asticode/go-astiav/blob/bc148523bc707cb628df76f2811c579d8b69ce9b/Makefile)

# Make
# make install-ffmpeg srcPath="/b/Code/go/rtc_screen/compile/ffmpeg/src" version="n7.0" patchPath="/b/Code/go/rtc_screen/compile/go-astiav/.github/workflows/windows.patch"
# here we call the Makefile in go-astiav to build FFmpeg
# we provide the following parameters:
# - srcPath: path to FFmpeg source code (it will clone it if missing)
# - version: FFmpeg version to build (we use n7.0 here)
# - patchPath: path to patch file to apply before
#   (the patch file changes only 1 file, ffbuild/library.mak)
#   (it 
#       replaces: 
#       "$(AR) $(ARFLAGS) $(AR_O) $^"
#       with 2 lines:
#       "$(file > objs.txt, $^)"
#       $(AR) $(ARFLAGS) $(AR_O) @objs.txt
# 

# The Makefile Commands are Simple
# install-ffmpeg:
# 	rm -rf $(srcPath)
# 	mkdir -p $(srcPath)
# 	cd $(srcPath) && git clone https://github.com/FFmpeg/FFmpeg .
# 	cd $(srcPath) && git checkout $(version)
# ifneq "" "$(patchPath)"
# 	cd $(srcPath) && git apply $(patchPath)
# endif
# 	cd $(srcPath) && ./configure --prefix=.. $(configure)
# 	cd $(srcPath) && make
# 	cd $(srcPath) && make install

# How To Use FFmpeg Lib for go-astiav from Build Cache
# B:\Code\go\rtc_screen\compile\ffmpeg\lib
# $env:CGO_LDFLAGS="-L$FFMPEG_PATH/lib"
# $env:CGO_CFLAGS="-I$FFMPEG_PATH/include"
# $env:PKG_CONFIG_PATH=$(bash -c "cygpath -w $FFMPEG_PATH") + "\lib\pkgconfig"

# Test if pkg-config works with built FFmpeg
# pkg-config --print-errors libavcodec

# Set Go Environment Variables (using go. not recommented)
# go env -w CGO_LDFLAGS="-L$FFMPEG_PATH/lib"
# go env -w CGO_CFLAGS="-I$FFMPEG_PATH/include"
# go env -w PKG_CONFIG_PATH="$(bash -c "cygpath -w $FFMPEG_PATH")\lib\pkgconfig"

# $env:PKG_CONFIG_PATH="$FFMPEG_PATH/lib/pkgconfig"
# go env -w PKG_CONFIG_PATH="$FFMPEG_PATH/lib/pkgconfig"



# ----------------------------------------------
#       Build FFmpeg using MSYS2 on Windows
# ----------------------------------------------

# * Variables
$current_folder = "$pwd"
$msys2_portable_dir = "msys2-portable"
$msys2_installation = "$pwd\$msys2_portable_dir\msys64"

# FFmpeg Config
$ffmpeg_version = "7.1"
# Tarball Url from https://www.ffmpeg.org/download.html#releases
$ffmpeg_tarball_release_url = "https://ffmpeg.org/releases/ffmpeg-$ffmpeg_version.tar.gz"
$ffmpeg_compile_folder = "$current_folder\ffmpeg"
$ffmpeg_tarball_file = "$ffmpeg_compile_folder\ffmpeg-$ffmpeg_version.tar.gz"

# Windows Patch
$windows_patch_url = "https://gist.github.com/CypherpunkSamurai/1e0120dae3aaadeb4121031f2c075250/raw/cc01065b980d511737fede22fa625210ba1a4944/ffmpeg_windows_build_patch.patch"
$windows_path_file = "$current_folder\windows.patch"

# Cleanup
function cleanup {
    # Remove build files
    Remove-Item -Path $ffmpeg_tarball_file -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $windows_path_file -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $ffmpeg_compile_folder -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Host -ForegroundColor Green "Cleanup complete!"
}

# Ask to Run Cleanup
$cleanup_response = Read-Host -Prompt "Cleanup Before Build? (y/n)"
if ($cleanup_response.ToLower() -eq "y") {
    cleanup
}

# Checks
if (!(Test-Path $msys2_installation)) {
    Write-Host -ForegroundColor Red "MSYS2 installation folder does not exist. Please point msys2_installation variable to a Msys2 Installation..."
    Write-Host -ForegroundColor Red "Exiting..."
    Exit 1
} else {
    Write-Host -ForegroundColor Green "MSYS2 installation found. Continuing with build..."
    # Set Env PATH
    $env:PATH="$msys2_installation\usr\bin;$env:PATH"
}

# Source Code
if (!(Test-Path $ffmpeg_compile_folder)) {
    # Change to FFmpeg source folder
    New-Item -ItemType Directory -Path $ffmpeg_compile_folder | Out-Null

    # Download FFmpeg source tarball
    Write-Host -ForegroundColor Green "Downloading FFmpeg source..."
    if (!(Test-Path $ffmpeg_tarball_file)) {
        Invoke-WebRequest -OutFile $ffmpeg_tarball_file -Uri $ffmpeg_tarball_release_url
    }

    Write-Host -ForegroundColor Green "Extracting FFmpeg source..."
    # Extract FFmpeg tarball to current folder
    cd "$ffmpeg_compile_folder"
    tar --force-local -xf $ffmpeg_tarball_file
    Move-Item -Path "$pwd\ffmpeg-$ffmpeg_version" -Destination "$ffmpeg_compile_folder\src" -Force -ErrorAction SilentlyContinue
}

# Apply Patches
cd $ffmpeg_compile_folder\src
Write-Host -ForegroundColor Green "Applying Windows build patches..."
Invoke-WebRequest -OutFile $windows_path_file -Uri $windows_patch_url
patch -p1 -i $windows_path_file --force
Write-Host -ForegroundColor Green "Windows build patches applied!"

# *[IMPORTANT] Configure like CI Builder 
# * https://www.msys2.org/docs/ci/#gitlab
# preserve current working folder
$env:CHERE_INVOKING = 'yes'
# * see:      https://www.msys2.org/docs/environments/
$env:MSYSTEM = 'MINGW64'
# Add Mingw64 to PATH
$env:Path = "$msys2_installation\mingw64\bin;" + $env:Path
$env:MSYS = "winsymlinks:nativestrict"
$env:MAKE = "mingw32-make"
# Install Requirement
# * check:    https://www.msys2.org/docs/package-naming/    
pacman -S --noconfirm --needed mingw-w64-x86_64-toolchain mingw-w64-x86_64-clang make yasm pkg-config autotools mingw-w64-x86_64-autotools

# Build FFmpeg
Write-Host -ForegroundColor Green "Building FFmpeg Step 1: Configure..."
cd $ffmpeg_compile_folder\src
bash -lc ' '
bash -lc 'pacman --noconfirm -Syuu'
bash -lc "
    cd $(cygpath -u $ffmpeg_compile_folder)/src
    echo 'Current Folder : ' $(pwd)
    # not really required but good for most projects to use autoreconf
    # autoreconf -fvi
    ./configure
    make V=1 check VERBOSE=t"

Write-Host -ForegroundColor Blue "Building FFmpeg Complete!"
cd $current_folder
