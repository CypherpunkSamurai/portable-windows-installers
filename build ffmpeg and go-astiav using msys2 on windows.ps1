# Build ffmpeg and go-astiav using msys2 on windows 

# code was created from workflow file (https://github.com/asticode/go-astiav/blob/bc148523bc707cb628df76f2811c579d8b69ce9b/.github/workflows/test.yml)
# and patch (https://github.com/asticode/go-astiav/blob/bc148523bc707cb628df76f2811c579d8b69ce9b/.github/workflows/windows.patch)
# and makefile (https://github.com/asticode/go-astiav/blob/bc148523bc707cb628df76f2811c579d8b69ce9b/Makefile)


# Variables
$InstallPath = "$PWD\compile"
$Msys2Path = "$InstallPath\msys64"

# Set Environment Variables
$env:PATH="$Msys2Path\usr\bin;$env:PATH"
# Set Mingw64 Path
$env:PATH="$Msys2Path\mingw64\bin;$env:PATH"

# Set ENV Vars Temporarily
$env:CGO_LDFLAGS="-L$Msys2Path\mingw64\lib"
$env:CGO_CFLAGS="-I$Msys2Path\mingw64\include"
$env:PKG_CONFIG_PATH="$Msys2Path\mingw64\lib\pkgconfig"



# Echo
Write-Host "Updating packages..."


# Update Packages
pacman -Syu --noconfirm --needed

# Install MinGW-w64 toolchain
pacman -S --noconfirm --needed mingw-w64-x86_64-toolchain
pacman -S --noconfirm --needed diffutils


# Source Code
# Change folder to Install Folder
Set-Location $InstallPath
$FFMPEG_PATH="$(bash -c 'cygpath -u "$PWD"')/ffmpeg"
# clone https://github.com/asticode/go-astiav
if (!(Test-Path -Path "$InstallPath/go-astiav")) {
    Write-Host "Getting go-astiav repo..."
    git clone "https://github.com/asticode/go-astiav"
}
# change directory
cd go-astiav


# FFMPEG Version
$FFMPEG_VERSION="n7.0"
$FFMPEG_TAG="ffmpeg-$FFMPEG_VERSION-Windows"
$FFMPEG_PATCH_PATH="$(bash -c 'cygpath -u "$PWD/.github/workflows/windows.patch"')"

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
make install-ffmpeg srcPath="$FFMPEG_PATH/src" version="$FFMPEG_VERSION" patchPath=$FFMPEG_PATCH_PATH

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

# Use FFmpeg from Build Cache
# B:\Code\go\rtc_screen\compile\ffmpeg\lib
$env:CGO_LDFLAGS="-L$FFMPEG_PATH/lib"
$env:CGO_CFLAGS="-I$FFMPEG_PATH/include"
$env:PKG_CONFIG_PATH=$(bash -c "cygpath -w $FFMPEG_PATH") + "\lib\pkgconfig"

# Test if pkg-config works with built FFmpeg
# pkg-config --print-errors libavcodec

# Set Go Environment Variables
# go env -w CGO_LDFLAGS="-L$FFMPEG_PATH/lib"
# go env -w CGO_CFLAGS="-I$FFMPEG_PATH/include"
# go env -w PKG_CONFIG_PATH="$(bash -c "cygpath -w $FFMPEG_PATH")\lib\pkgconfig"


# $env:PKG_CONFIG_PATH="$FFMPEG_PATH/lib/pkgconfig"
# go env -w PKG_CONFIG_PATH="$FFMPEG_PATH/lib/pkgconfig"
