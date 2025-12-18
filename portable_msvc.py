#!/usr/bin/env python3
r"""
# Portable MSVC without Visual Studio Community Installer
- https://github.com/jonathanpeppers/boots
- https://github.com/tgbender/portablemsvc
- https://github.com/prenaux/ham/blob/5c4f4cd2e5056ad35fbef77a7fee92691fa8edc0/toolsets/msvc_19_x64/portable-msvc.py#L54
- https://github.com/AriLeGrand/sfml/blob/main/main.py
- https://github.com/Pandinosaurus/PortableBuildTools/blob/b4f7724ee00b168091f2a6cc7812385513ce7e99/source/pbt.c#L563


## How to Use?

Get the code:
```shell
# using curl
curl -LO https://gist.githubusercontent.com/CypherpunkSamurai/36554614a97e26ee6a4044a013611257/raw/portable_msvc.py
# using powershell
powershell irm https://gist.githubusercontent.com/CypherpunkSamurai/36554614a97e26ee6a4044a013611257/raw/portable_msvc.py -OutFile portable_msvc.py
```

Run `python portable_msvc.py --accept-license`

Run `.\setup_x64.bat` and test with `cl.exe`, it should now be in path

### BUILDING AND RUNNING PROGRAMS

@echo off
setlocal

REM Set up the portable MSVC environment
call ..\msvc\setup_x64.bat

REM Create build directory if it doesn't exist
if not exist build mkdir build

REM Configure and build with CMake
cd build
cmake .. -G "NMake Makefiles" -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release

echo.
if %ERRORLEVEL% EQU 0 (
    echo Build succeeded!
    echo Executable created: build\bt_radios.exe

    echo.
    echo Running the program...
    echo.
    bt_radios.exe

    if %ERRORLEVEL% EQU 0 (
        echo.
        echo Program executed successfully!
    ) else (
        echo.
        echo Program failed with error level %ERRORLEVEL%
    )
) else (
    echo Build failed with error level %ERRORLEVEL%
)

cd ..

"""

import io
import os
import sys
import stat
import json
import shutil
import hashlib
import zipfile
import tempfile
import argparse
import subprocess
import urllib.error
import urllib.request
from pathlib import Path
import platform

# Configuration
OUTPUT_DIR = Path("msvc")
DOWNLOADS_DIR = Path("downloads")


def detect_host():
    """Detect host architecture"""
    machine = platform.machine().lower()
    if machine == "amd64":
        return "x64"
    elif machine == "arm64":
        return "arm64"
    elif machine == "x86":
        return "x86"
    return "x64"


DEFAULT_HOST = detect_host()
ALL_HOSTS = ["x64", "x86", "arm64"]
DEFAULT_TARGET = detect_host()
ALL_TARGETS = ["x64", "x86", "arm", "arm64"]

MANIFEST_URL = "https://aka.ms/vs/17/release/channel"
MANIFEST_PREVIEW_URL = "https://aka.ms/vs/17/pre/channel"

# Global state
ssl_context = None
total_download = 0


class DownloadManager:
    def __init__(self):
        self.total_bytes = 0

    def simple_download(self, url):
        """Download content from URL"""
        with urllib.request.urlopen(url, context=ssl_context) as response:
            return response.read()

    def download_with_progress(self, url, expected_hash, filename):
        """Download file with progress tracking and hash verification"""
        file_path = DOWNLOADS_DIR / filename

        # Check if file already exists and is valid
        if file_path.exists():
            data = file_path.read_bytes()
            if hashlib.sha256(data).hexdigest() == expected_hash.lower():
                print(f"\r{filename} ... OK")
                return data

        # Download the file
        with file_path.open("wb") as file:
            data_buffer = io.BytesIO()

            with urllib.request.urlopen(url, context=ssl_context) as response:
                total_size = int(response.headers["Content-Length"])
                downloaded = 0

                while True:
                    chunk = response.read(1 << 20)  # 1MB chunks
                    if not chunk:
                        break

                    file.write(chunk)
                    data_buffer.write(chunk)
                    downloaded += len(chunk)

                    progress = downloaded * 100 // total_size
                    print(f"\r{filename} ... {progress}%", end="")

            print()  # New line after progress

            # Verify hash
            data = data_buffer.getvalue()
            actual_hash = hashlib.sha256(data).hexdigest()
            if expected_hash.lower() != actual_hash:
                sys.exit(f"Hash mismatch for {filename}")

            self.total_bytes += len(data)
            return data


class MSIParser:
    @staticmethod
    def extract_cab_files(msi_data):
        """Extract .cab file names from MSI data"""
        index = 0
        cab_files = []

        while True:
            index = msi_data.find(b".cab", index + 4)
            if index < 0:
                break
            cab_name = msi_data[index - 32 : index + 4].decode("ascii")
            cab_files.append(cab_name)

        return cab_files


class VSInstaller:
    def __init__(self, args):
        self.args = args
        self.downloader = DownloadManager()
        self.msi_parser = MSIParser()

        # Validate arguments
        self.host = args.host
        self.targets = args.target.split(",")
        self._validate_targets()

    def _validate_targets(self):
        """Validate target architectures"""
        for target in self.targets:
            if target not in ALL_TARGETS:
                sys.exit(f"Unknown target architecture: {target}")

    def _find_first_item(self, items, condition=lambda x: True):
        """Find first item matching condition"""
        return next((item for item in items if condition(item)), None)

    def setup_ssl_context(self):
        """Setup SSL context for downloads"""
        global ssl_context

        try:
            return self.downloader.simple_download(self._get_manifest_url())
        except urllib.error.URLError as err:
            import ssl

            if isinstance(err.args[0], ssl.SSLCertVerificationError):
                print("ERROR: SSL certificate verification error")
                try:
                    import certifi

                    print("NOTE: Retrying with certifi certificates")
                    ssl_context = ssl.create_default_context(cafile=certifi.where())
                    return self.downloader.simple_download(self._get_manifest_url())
                except ModuleNotFoundError:
                    print("ERROR: Please install 'certifi' package")
                    sys.exit(1)
            else:
                raise

    def _get_manifest_url(self):
        """Get the appropriate manifest URL"""
        return MANIFEST_PREVIEW_URL if self.args.preview else MANIFEST_URL

    def get_manifest(self):
        """Download and parse main manifest"""
        manifest_data = self.setup_ssl_context()
        return json.loads(manifest_data)

    def get_vs_manifest(self, main_manifest):
        """Download VS-specific manifest"""
        item_name = (
            "Microsoft.VisualStudio.Manifests.VisualStudioPreview"
            if self.args.preview
            else "Microsoft.VisualStudio.Manifests.VisualStudio"
        )

        vs_item = self._find_first_item(
            main_manifest["channelItems"], lambda x: x["id"] == item_name
        )
        payload_url = vs_item["payloads"][0]["url"]

        vs_manifest_data = self.downloader.simple_download(payload_url)
        return json.loads(vs_manifest_data)

    def parse_available_versions(self, vs_manifest):
        """Parse available MSVC and SDK versions"""
        packages = {}
        for package in vs_manifest["packages"]:
            package_id = package["id"].lower()
            packages.setdefault(package_id, []).append(package)

        msvc_versions = {}
        sdk_versions = {}

        for package_id, package_list in packages.items():
            # Parse MSVC versions
            if package_id.startswith("microsoft.vc.") and package_id.endswith(
                ".tools.hostx64.targetx64.base"
            ):
                version = ".".join(package_id.split(".")[2:4])
                if version[0].isnumeric():
                    msvc_versions[version] = package_id

            # Parse SDK versions
            elif package_id.startswith(
                "microsoft.visualstudio.component.windows10sdk."
            ) or package_id.startswith(
                "microsoft.visualstudio.component.windows11sdk."
            ):
                version = package_id.split(".")[-1]
                if version.isnumeric():
                    sdk_versions[version] = package_id

        return packages, msvc_versions, sdk_versions

    def select_versions(self, msvc_versions, sdk_versions):
        """Select MSVC and SDK versions to use"""
        if self.args.show_versions:
            print("MSVC versions:", " ".join(sorted(msvc_versions.keys())))
            print("Windows SDK versions:", " ".join(sorted(sdk_versions.keys())))
            sys.exit(0)

        # Select MSVC version
        msvc_ver = self.args.msvc_version or max(sorted(msvc_versions.keys()))
        if msvc_ver not in msvc_versions:
            sys.exit(f"Unknown MSVC version: {msvc_ver}")

        # Select SDK version
        sdk_ver = self.args.sdk_version or max(sorted(sdk_versions.keys()))
        if sdk_ver not in sdk_versions:
            sys.exit(f"Unknown Windows SDK version: {sdk_ver}")

        # Get full version strings
        msvc_package_id = msvc_versions[msvc_ver]
        full_msvc_version = ".".join(msvc_package_id.split(".")[2:6])

        return full_msvc_version, sdk_ver, msvc_package_id, sdk_versions[sdk_ver]

    def accept_license(self, main_manifest):
        """Handle license acceptance"""
        if self.args.accept_license:
            return

        tools = self._find_first_item(
            main_manifest["channelItems"],
            lambda x: x["id"] == "Microsoft.VisualStudio.Product.BuildTools",
        )
        resource = self._find_first_item(
            tools["localizedResources"], lambda x: x["language"] == "en-us"
        )
        license_url = resource["license"]

        response = input(f"Accept Visual Studio license at {license_url} [Y/N]? ")
        if not response or response[0].lower() != "y":
            sys.exit(0)

    def create_directories(self):
        """Create necessary directories"""
        OUTPUT_DIR.mkdir(exist_ok=True)
        DOWNLOADS_DIR.mkdir(exist_ok=True)

    def download_msvc(self, packages, msvc_version):
        """Download MSVC packages"""
        print("Downloading MSVC packages...")

        # Base packages
        msvc_packages = [
            "microsoft.visualcpp.dia.sdk",
            f"microsoft.vc.{msvc_version}.crt.headers.base",
            f"microsoft.vc.{msvc_version}.crt.source.base",
            f"microsoft.vc.{msvc_version}.asan.headers.base",
            f"microsoft.vc.{msvc_version}.pgo.headers.base",
        ]

        # Target-specific packages
        for target in self.targets:
            msvc_packages.extend(
                [
                    f"microsoft.vc.{msvc_version}.tools.host{self.host}.target{target}.base",
                    f"microsoft.vc.{msvc_version}.tools.host{self.host}.target{target}.res.base",
                    f"microsoft.vc.{msvc_version}.crt.{target}.desktop.base",
                    f"microsoft.vc.{msvc_version}.crt.{target}.store.base",
                    f"microsoft.vc.{msvc_version}.premium.tools.host{self.host}.target{target}.base",
                    f"microsoft.vc.{msvc_version}.pgo.{target}.base",
                ]
            )

            # ASAN packages (only for x86/x64)
            if target in ["x86", "x64"]:
                msvc_packages.append(f"microsoft.vc.{msvc_version}.asan.{target}.base")

            # Redistributable packages
            redist_suffix = ".onecore.desktop" if target == "arm" else ""
            redist_pkg = (
                f"microsoft.vc.{msvc_version}.crt.redist.{target}{redist_suffix}.base"
            )

            if redist_pkg not in packages:
                redist_name = f"microsoft.visualcpp.crt.redist.{target}{redist_suffix}"
                redist = self._find_first_item(packages[redist_name])
                redist_pkg = self._find_first_item(
                    redist["dependencies"], lambda dep: dep.endswith(".base")
                ).lower()

            msvc_packages.append(redist_pkg)

        # Download and extract packages
        for package_name in sorted(msvc_packages):
            if package_name not in packages:
                print(f"\r{package_name} ... !!! MISSING !!!")
                continue

            package = self._find_first_item(
                packages[package_name], lambda p: p.get("language") in (None, "en-US")
            )

            for payload in package["payloads"]:
                filename = payload["fileName"]
                data = self.downloader.download_with_progress(
                    payload["url"], payload["sha256"], filename
                )

                # Extract ZIP contents
                with zipfile.ZipFile(DOWNLOADS_DIR / filename) as zip_file:
                    for name in zip_file.namelist():
                        if name.startswith("Contents/"):
                            output_path = OUTPUT_DIR / Path(name).relative_to(
                                "Contents"
                            )
                            output_path.parent.mkdir(parents=True, exist_ok=True)
                            output_path.write_bytes(zip_file.read(name))

    def download_sdk(self, packages, sdk_package_id):
        """Download Windows SDK packages"""
        print("Downloading Windows SDK packages...")

        # SDK package names
        sdk_packages = [
            "Windows SDK for Windows Store Apps Tools-x86_en-us.msi",
            "Windows SDK for Windows Store Apps Headers-x86_en-us.msi",
            "Windows SDK for Windows Store Apps Headers OnecoreUap-x86_en-us.msi",
            "Windows SDK for Windows Store Apps Libs-x86_en-us.msi",
            "Universal CRT Headers Libraries and Sources-x86_en-us.msi",
        ]

        # Add target-specific packages
        for target in ALL_TARGETS:
            sdk_packages.extend(
                [
                    f"Windows SDK Desktop Headers {target}-x86_en-us.msi",
                    f"Windows SDK OnecoreUap Headers {target}-x86_en-us.msi",
                ]
            )

        for target in self.targets:
            sdk_packages.append(f"Windows SDK Desktop Libs {target}-x86_en-us.msi")

        # Download and install SDK
        with tempfile.TemporaryDirectory(dir=DOWNLOADS_DIR) as temp_dir:
            sdk_package = packages[sdk_package_id][0]
            sdk_package = packages[
                self._find_first_item(sdk_package["dependencies"]).lower()
            ][0]

            msi_files = []
            cab_files = []

            # Download MSI files
            for package_name in sorted(sdk_packages):
                payload = self._find_first_item(
                    sdk_package["payloads"],
                    lambda p: p["fileName"] == f"Installers\\{package_name}",
                )
                if payload is None:
                    continue

                msi_files.append(DOWNLOADS_DIR / package_name)
                data = self.downloader.download_with_progress(
                    payload["url"], payload["sha256"], package_name
                )
                cab_files.extend(self.msi_parser.extract_cab_files(data))

            # Download CAB files
            for cab_name in cab_files:
                payload = self._find_first_item(
                    sdk_package["payloads"],
                    lambda p: p["fileName"] == f"Installers\\{cab_name}",
                )
                self.downloader.download_with_progress(
                    payload["url"], payload["sha256"], cab_name
                )

            print("Installing MSI files...")

            # Install MSI files
            for msi_file in msi_files:
                subprocess.check_call(
                    [
                        "msiexec.exe",
                        "/a",
                        str(msi_file),
                        "/quiet",
                        "/qn",
                        f"TARGETDIR={OUTPUT_DIR.resolve()}",
                    ]
                )
                (OUTPUT_DIR / msi_file.name).unlink()

    def setup_environment(self):
        """Setup the development environment"""
        print("Setting up environment...")

        # Get actual versions from installed files
        msvc_version = next((OUTPUT_DIR / "VC/Tools/MSVC").glob("*")).name
        sdk_version = next((OUTPUT_DIR / "Windows Kits/10/bin").glob("*")).name

        self._move_debug_runtime(msvc_version)
        self._copy_debug_interface_access(msvc_version)
        self._cleanup_unnecessary_files(msvc_version, sdk_version)
        self._create_build_files(msvc_version, sdk_version)
        self._create_setup_scripts(msvc_version, sdk_version)

    def _move_debug_runtime(self, msvc_version):
        """Move debug CRT runtime files"""
        redist_dir = OUTPUT_DIR / "VC/Redist"
        if not redist_dir.exists():
            return

        redist_version = next((redist_dir / "MSVC").glob("*")).name
        source_dir = redist_dir / "MSVC" / redist_version / "debug_nonredist"

        for target in self.targets:
            for dll_file in (source_dir / target).glob("**/*.dll"):
                destination = (
                    OUTPUT_DIR
                    / "VC/Tools/MSVC"
                    / msvc_version
                    / f"bin/Host{self.host}"
                    / target
                )
                dll_file.replace(destination / dll_file.name)

        shutil.rmtree(redist_dir)

    def _copy_debug_interface_access(self, msvc_version):
        """Copy debug interface access DLL"""
        msdia_files = {
            "x86": "msdia140.dll",
            "x64": "amd64/msdia140.dll",
            "arm": "arm/msdia140.dll",
            "arm64": "arm64/msdia140.dll",
        }

        destination_base = (
            OUTPUT_DIR / "VC/Tools/MSVC" / msvc_version / f"bin/Host{self.host}"
        )
        source_file = OUTPUT_DIR / "DIA%20SDK/bin" / msdia_files[self.host]

        for target in self.targets:
            shutil.copyfile(source_file, destination_base / target / source_file.name)

        shutil.rmtree(OUTPUT_DIR / "DIA%20SDK")

    def _cleanup_unnecessary_files(self, msvc_version, sdk_version):
        """Remove unnecessary files and directories"""
        # Remove unnecessary directories
        cleanup_dirs = [
            "Common7",
            f"VC/Tools/MSVC/{msvc_version}/Auxiliary",
        ]

        for dir_path in cleanup_dirs:
            shutil.rmtree(OUTPUT_DIR / dir_path, ignore_errors=True)

        # Remove target-specific unnecessary files
        for target in self.targets:
            target_cleanup = [
                f"VC/Tools/MSVC/{msvc_version}/lib/{target}/store",
                f"VC/Tools/MSVC/{msvc_version}/lib/{target}/uwp",
                f"VC/Tools/MSVC/{msvc_version}/lib/{target}/enclave",
                f"VC/Tools/MSVC/{msvc_version}/lib/{target}/onecore",
                f"VC/Tools/MSVC/{msvc_version}/bin/Host{self.host}/{target}/onecore",
            ]

            for dir_path in target_cleanup:
                shutil.rmtree(OUTPUT_DIR / dir_path, ignore_errors=True)

        # Remove SDK unnecessary files
        sdk_cleanup = [
            "Windows Kits/10/Catalogs",
            "Windows Kits/10/DesignTime",
            f"Windows Kits/10/bin/{sdk_version}/chpe",
            f"Windows Kits/10/Lib/{sdk_version}/ucrt_enclave",
        ]

        for dir_path in sdk_cleanup:
            shutil.rmtree(OUTPUT_DIR / dir_path, ignore_errors=True)

        # Remove unused architecture files
        for arch in ALL_TARGETS:
            if arch not in self.targets:
                shutil.rmtree(
                    OUTPUT_DIR / f"Windows Kits/10/Lib/{sdk_version}/ucrt/{arch}",
                    ignore_errors=True,
                )
                shutil.rmtree(
                    OUTPUT_DIR / f"Windows Kits/10/Lib/{sdk_version}/um/{arch}",
                    ignore_errors=True,
                )

            if arch != self.host:
                shutil.rmtree(
                    OUTPUT_DIR / f"VC/Tools/MSVC/{msvc_version}/bin/Host{arch}",
                    ignore_errors=True,
                )
                shutil.rmtree(
                    OUTPUT_DIR / f"Windows Kits/10/bin/{sdk_version}/{arch}",
                    ignore_errors=True,
                )

        # Remove telemetry executable
        for target in self.targets:
            telemetry_exe = (
                OUTPUT_DIR
                / "VC/Tools/MSVC"
                / msvc_version
                / f"bin/Host{self.host}/{target}/vctip.exe"
            )
            telemetry_exe.unlink(missing_ok=True)

    def _create_build_files(self, msvc_version, sdk_version):
        """Create build files for NVCC compatibility"""
        build_dir = OUTPUT_DIR / "VC/Auxiliary/Build"
        build_dir.mkdir(parents=True, exist_ok=True)

        (build_dir / "vcvarsall.bat").write_text(
            "rem both bat files are here only for nvcc, do not call them manually"
        )
        (build_dir / "vcvars64.bat").touch()

    def _create_setup_scripts(self, msvc_version, sdk_version):
        """Create setup batch and PowerShell files for each target"""
        for target in self.targets:
            # Batch file content
            setup_content = f"""@echo off

set VSCMD_ARG_HOST_ARCH={self.host}
set VSCMD_ARG_TGT_ARCH={target}

set VCToolsVersion={msvc_version}
set WindowsSDKVersion={sdk_version}\\

set VCToolsInstallDir=%~dp0VC\\Tools\\MSVC\\{msvc_version}\\
set WindowsSdkBinPath=%~dp0Windows Kits\\10\\bin\\

set PATH=%~dp0VC\\Tools\\MSVC\\{msvc_version}\\bin\\Host{self.host}\\{target};%~dp0Windows Kits\\10\\bin\\{sdk_version}\\{self.host};%~dp0Windows Kits\\10\\bin\\{sdk_version}\\{self.host}\\ucrt;%PATH%
set INCLUDE=%~dp0VC\\Tools\\MSVC\\{msvc_version}\\include;%~dp0Windows Kits\\10\\Include\\{sdk_version}\\ucrt;%~dp0Windows Kits\\10\\Include\\{sdk_version}\\shared;%~dp0Windows Kits\\10\\Include\\{sdk_version}\\um;%~dp0Windows Kits\\10\\Include\\{sdk_version}\\winrt;%~dp0Windows Kits\\10\\Include\\{sdk_version}\\cppwinrt
set LIB=%~dp0VC\\Tools\\MSVC\\{msvc_version}\\lib\\{target};%~dp0Windows Kits\\10\\Lib\\{sdk_version}\\ucrt\\{target};%~dp0Windows Kits\\10\\Lib\\{sdk_version}\\um\\{target}
"""
            (OUTPUT_DIR / f"setup_{target}.bat").write_text(setup_content)

            # PowerShell script content
            ps_content = f"""# Visual Studio 2022 {target} Environment Setup

$env:VSCMD_ARG_HOST_ARCH = "{self.host}"
$env:VSCMD_ARG_TGT_ARCH = "{target}"

$env:VCToolsVersion = "{msvc_version}"
$env:WindowsSDKVersion = "{sdk_version}\\\"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$env:VCToolsInstallDir = Join-Path $ScriptRoot "VC\\Tools\\MSVC\\{msvc_version}\\\"
$env:WindowsSdkBinPath = Join-Path $ScriptRoot "Windows Kits\\10\\bin\\\"

$env:PATH = @(
    Join-Path $ScriptRoot "VC\\Tools\\MSVC\\{msvc_version}\\bin\\Host{self.host}\\{target}"
    Join-Path $ScriptRoot "Windows Kits\\10\\bin\\{sdk_version}\\{self.host}"
    Join-Path $ScriptRoot "Windows Kits\\10\\bin\\{sdk_version}\\{self.host}\\ucrt"
    $env:PATH
) -join ";\"

$env:INCLUDE = @(
    Join-Path $ScriptRoot "VC\\Tools\\MSVC\\{msvc_version}\\include"
    Join-Path $ScriptRoot "Windows Kits\\10\\Include\\{sdk_version}\\ucrt"
    Join-Path $ScriptRoot "Windows Kits\\10\\Include\\{sdk_version}\\shared"
    Join-Path $ScriptRoot "Windows Kits\\10\\Include\\{sdk_version}\\um"
    Join-Path $ScriptRoot "Windows Kits\\10\\Include\\{sdk_version}\\winrt"
    Join-Path $ScriptRoot "Windows Kits\\10\\Include\\{sdk_version}\\cppwinrt"
) -join ";\"

$env:LIB = @(
    Join-Path $ScriptRoot "VC\\Tools\\MSVC\\{msvc_version}\\lib\\{target}"
    Join-Path $ScriptRoot "Windows Kits\\10\\Lib\\{sdk_version}\\ucrt\\{target}"
    Join-Path $ScriptRoot "Windows Kits\\10\\Lib\\{sdk_version}\\um\\{target}"
) -join ";\"

Write-Host "Visual Studio 2022 {target} environment configured" -ForegroundColor Green
"""
            (OUTPUT_DIR / f"setup_{target}.ps1").write_text(ps_content)

    def run(self):
        """Main execution flow"""
        print(f"Host Architecture: {self.host}")
        print(f"Target Architectures: {', '.join(self.targets)}")
        print(f"Installation Directory: {OUTPUT_DIR.resolve()}")
        print("Note: License agreement is automatically accepted.")
        print("-" * 40)

        print("Starting Visual Studio installation...")

        # Get manifests
        main_manifest = self.get_manifest()
        vs_manifest = self.get_vs_manifest(main_manifest)

        # Parse versions
        packages, msvc_versions, sdk_versions = self.parse_available_versions(
            vs_manifest
        )
        msvc_ver, sdk_ver, msvc_pid, sdk_pid = self.select_versions(
            msvc_versions, sdk_versions
        )

        print(f"Downloading MSVC v{msvc_ver} and Windows SDK v{sdk_ver}")

        # Handle license
        self.accept_license(main_manifest)

        # Setup
        self.create_directories()

        # Download components
        self.download_msvc(packages, msvc_ver)
        self.download_sdk(packages, sdk_pid)

        # Setup environment
        self.setup_environment()

        # Summary
        print(f"Total downloaded: {self.downloader.total_bytes >> 20} MB")
        print("Done!")


def clean_directories():
    """Clean downloads and msvc output directories"""
    import shutil

    print("Cleaning directories...")

    # Remove downloads directory
    if DOWNLOADS_DIR.exists():
        print(f"Removing {DOWNLOADS_DIR}...")
        shutil.rmtree(DOWNLOADS_DIR)
        print(f"✓ {DOWNLOADS_DIR} removed")
    else:
        print(f"✓ {DOWNLOADS_DIR} does not exist")

    # Remove output directory
    if OUTPUT_DIR.exists():
        print(f"Removing {OUTPUT_DIR}...")
        shutil.rmtree(OUTPUT_DIR)
        print(f"✓ {OUTPUT_DIR} removed")
    else:
        print(f"✓ {OUTPUT_DIR} does not exist")

    print("Clean completed!")


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="Portable MSVC installer")
    parser.add_argument(
        "--show-versions",
        action="store_true",
        help="Show available MSVC and Windows SDK versions",
    )
    parser.add_argument(
        "--accept-license",
        action="store_true",
        default=True,
        help="Automatically accept license (Default: True)",
    )
    parser.add_argument("--msvc-version", help="Get specific MSVC version")
    parser.add_argument("--sdk-version", help="Get specific Windows SDK version")
    parser.add_argument("--preview", action="store_true", help="Use preview channel")
    parser.add_argument(
        "--target",
        default=DEFAULT_TARGET,
        help=f"Target architectures, comma separated ({','.join(ALL_TARGETS)})",
    )
    parser.add_argument(
        "--host", default=DEFAULT_HOST, choices=ALL_HOSTS, help="Host architecture"
    )
    parser.add_argument(
        "--clean", action="store_true", help="Clean downloads and msvc folders"
    )

    args = parser.parse_args()

    # Handle clean command
    if args.clean:
        clean_directories()
        return

    installer = VSInstaller(args)
    installer.run()


if __name__ == "__main__":
    main()
