<#
.SYNOPSIS
Creates a portable Elixir installation with Erlang and Mix

.PARAMETER InstallPath
The directory where Elixir and Erlang will be installed (default: .\elixir-portable)

.PARAMETER UnifiedDistro
Extract both Erlang and Elixir to the same folder instead of separate subdirectories
#>

param(
    [string]$InstallPath = ".\elixir-portable",
    [switch]$UnifiedDistro = $true
)

$ErrorActionPreference = 'Stop'

# Create installation directory
if ([System.IO.Path]::IsPathRooted($InstallPath)) {
    $ResolvedPath = $InstallPath
} else {
    $ResolvedPath = Join-Path (Get-Location) $InstallPath
}

if (-not (Test-Path $ResolvedPath)) {
    $ResolvedPath = New-Item -ItemType Directory -Path $ResolvedPath -Force | Select-Object -ExpandProperty FullName
} else {
    $ResolvedPath = (Get-Item $ResolvedPath).FullName
}

Write-Host "Installing portable Elixir to: $ResolvedPath" -ForegroundColor Green
if ($UnifiedDistro) {
    Write-Host "Using unified distribution (single folder)" -ForegroundColor Yellow
}

# Set extraction paths based on UnifiedDistro flag
if ($UnifiedDistro) {
    $erlangPath = $ResolvedPath
    $elixirPath = $ResolvedPath
} else {
    $erlangPath = Join-Path $ResolvedPath "erlang"
    $elixirPath = Join-Path $ResolvedPath "elixir"
}

# Check if installation already exists and is valid
if (Test-Path $erlangPath) {
    $existingErlang = Get-ChildItem -Path $erlangPath -Recurse -File -Name "erl.exe" | Select-Object -First 1
    if ($existingErlang) {
        Write-Host "Found existing Erlang installation" -ForegroundColor Yellow
        $erlangBinPath = Split-Path (Join-Path $erlangPath $existingErlang) -Parent
        
        $elixirBatPath = if ($UnifiedDistro) { 
            Join-Path $elixirPath "bin\elixir.bat" 
        } else { 
            Join-Path $elixirPath "bin\elixir.bat" 
        }
        
        if (Test-Path $elixirBatPath) {
            Write-Host "Found existing Elixir installation" -ForegroundColor Yellow
            $elixirBinPath = Split-Path $elixirBatPath -Parent
            
            # Jump to activation script creation
            $skipInstallation = $true
        }
    }
}

# Function to download and extract zip files
function Download-And-Extract {
    param($Url, $Destination, $ExtractTo)
    
    Write-Host "Downloading: $Url" -ForegroundColor Yellow
    $tempFile = [System.IO.Path]::GetTempFileName() + ".zip"
    
    try {
        Invoke-WebRequest -Uri $Url -OutFile $tempFile -UseBasicParsing
        Write-Host "Extracting to: $ExtractTo" -ForegroundColor Yellow
        Expand-Archive -Path $tempFile -DestinationPath $ExtractTo -Force
    }
    finally {
        if (Test-Path $tempFile) {
            Remove-Item $tempFile
        }
    }
}

if (-not $skipInstallation) {
    # Parse Elixir version and compatible Erlang version
    Write-Host "Fetching latest Elixir version..." -ForegroundColor Cyan
    $elixirPage = Invoke-WebRequest -Uri "https://elixir-lang.org/install.html" -UseBasicParsing

    # Extract Elixir version and compatible Erlang version
    $elixirMatches = [regex]::Matches($elixirPage.Content, 'Elixir (\d+\.\d+\.\d+) on Erlang (\d+)')
    if ($elixirMatches.Count -eq 0) {
        throw "Could not parse Elixir versions from install page"
    }

    # Use the first (latest) version
    $compatibleElixir = $elixirMatches[0].Groups[1].Value
    $erlangMajor = $elixirMatches[0].Groups[2].Value

    Write-Host "Found Elixir version: $compatibleElixir for Erlang $erlangMajor" -ForegroundColor Green

    # Get Erlang releases from GitHub API
    Write-Host "Fetching Erlang/OTP releases..." -ForegroundColor Cyan
    $erlangApiUrl = "https://api.github.com/repos/erlang/otp/releases"
    $erlangReleases = Invoke-RestMethod -Uri $erlangApiUrl -UseBasicParsing

    # Find latest release for the required major version
    $targetRelease = $erlangReleases | Where-Object { 
        $_.tag_name -match "^OTP-$erlangMajor\." -and -not $_.prerelease 
    } | Select-Object -First 1

    if (-not $targetRelease) {
        throw "Could not find Erlang/OTP release for major version $erlangMajor"
    }

    $erlangVersion = $targetRelease.tag_name -replace '^OTP-', ''
    $erlangAsset = $targetRelease.assets | Where-Object { $_.name -match "otp_win64_.*\.zip$" }

    if (-not $erlangAsset) {
        throw "Could not find Windows 64-bit asset for Erlang $erlangVersion"
    }

    $erlangUrl = $erlangAsset.browser_download_url
    Write-Host "Found Erlang/OTP version: $erlangVersion" -ForegroundColor Green

    # Construct Elixir download URL
    $elixirUrl = "https://github.com/elixir-lang/elixir/releases/download/v$compatibleElixir/elixir-otp-$erlangMajor.zip"

    # Create subdirectories if not unified
    if (-not $UnifiedDistro) {
        New-Item -ItemType Directory -Path $erlangPath -Force | Out-Null
        New-Item -ItemType Directory -Path $elixirPath -Force | Out-Null
    }

    # Download and extract Erlang
    Write-Host "`nInstalling Erlang/OTP $erlangVersion..." -ForegroundColor Cyan
    Download-And-Extract -Url $erlangUrl -Destination $erlangPath -ExtractTo $erlangPath

    # Download and extract Elixir
    Write-Host "`nInstalling Elixir $compatibleElixir..." -ForegroundColor Cyan
    Download-And-Extract -Url $elixirUrl -Destination $elixirPath -ExtractTo $elixirPath

    # Find Erlang bin directory
    $erlangBin = Get-ChildItem -Path $erlangPath -Recurse -Directory -Name "bin" | 
        Where-Object { Test-Path (Join-Path $erlangPath $_ "erl.exe") } |
        Select-Object -First 1

    if (-not $erlangBin) {
        throw "Could not find Erlang bin directory with erl.exe"
    }

    $erlangBinPath = Join-Path $erlangPath $erlangBin
    $elixirBinPath = Join-Path $elixirPath "bin"

    # Verify Elixir binaries exist
    if (-not (Test-Path (Join-Path $elixirBinPath "elixir.bat"))) {
        throw "Could not find elixir.bat in $elixirBinPath"
    }

    if (-not (Test-Path (Join-Path $elixirBinPath "mix.bat"))) {
        throw "Could not find mix.bat in $elixirBinPath"
    }
}

# Create activation script
$activateScript = @"
@echo off
REM Portable Elixir Environment Activation Script
REM Generated on 2025-07-29 10:04:20

set "ERLANG_HOME=$erlangBinPath"
set "ELIXIR_HOME=$elixirBinPath"
set "PATH=%ELIXIR_HOME%;%ERLANG_HOME%;%PATH%"

echo ========================================================================
echo Portable Elixir Environment Activated
echo ========================================================================
echo Erlang/OTP: $(if ($erlangVersion) { $erlangVersion } else { 'Existing' })
echo Elixir:     $(if ($compatibleElixir) { $compatibleElixir } else { 'Existing' })
echo Distribution: $(if ($UnifiedDistro) { 'Unified' } else { 'Separate' })
echo.
echo Erlang Home: %ERLANG_HOME%
echo Elixir Home: %ELIXIR_HOME%
echo.
echo Available commands: elixir, elixirc, mix, iex, erl
echo ========================================================================

cmd /k
"@

$activateScriptPath = Join-Path $ResolvedPath "activate.bat"
$activateScript | Out-File -FilePath $activateScriptPath -Encoding ASCII

# Create PowerShell activation script
$activatePsScript = @"
# Portable Elixir Environment Activation Script (PowerShell)
# Generated on 2025-07-29 10:04:20

`$env:ERLANG_HOME = "$erlangBinPath"
`$env:ELIXIR_HOME = "$elixirBinPath"
`$env:PATH = "`$env:ELIXIR_HOME;`$env:ERLANG_HOME;`$env:PATH"

Write-Host "========================================================================" -ForegroundColor Green
Write-Host "Portable Elixir Environment Activated" -ForegroundColor Green
Write-Host "========================================================================" -ForegroundColor Green
Write-Host "Erlang/OTP: $(if ($erlangVersion) { $erlangVersion } else { 'Existing' })" -ForegroundColor Yellow
Write-Host "Elixir:     $(if ($compatibleElixir) { $compatibleElixir } else { 'Existing' })" -ForegroundColor Yellow
Write-Host "Distribution: $(if ($UnifiedDistro) { 'Unified' } else { 'Separate' })" -ForegroundColor Yellow
Write-Host ""
Write-Host "Erlang Home: `$env:ERLANG_HOME" -ForegroundColor Cyan
Write-Host "Elixir Home: `$env:ELIXIR_HOME" -ForegroundColor Cyan
Write-Host ""
Write-Host "Available commands: elixir, elixirc, mix, iex, erl" -ForegroundColor White
Write-Host "========================================================================" -ForegroundColor Green
"@

$activatePsScriptPath = Join-Path $ResolvedPath "activate.ps1"
$activatePsScript | Out-File -FilePath $activatePsScriptPath -Encoding UTF8

Write-Host "`n========================================================================" -ForegroundColor Green
Write-Host "Portable Elixir Installation Complete!" -ForegroundColor Green
Write-Host "========================================================================" -ForegroundColor Green
Write-Host "Installation Path: $ResolvedPath" -ForegroundColor Yellow
Write-Host "Distribution Type: $(if ($UnifiedDistro) { 'Unified (single folder)' } else { 'Separate (erlang/elixir folders)' })" -ForegroundColor Yellow
Write-Host ""
Write-Host "To activate:" -ForegroundColor Cyan
Write-Host "  CMD:        $activateScriptPath" -ForegroundColor White
Write-Host "  PowerShell: . '$activatePsScriptPath'" -ForegroundColor White
Write-Host "========================================================================" -ForegroundColor Green
