# Download-GitHubAsset.ps1
param(
    [Parameter(Mandatory=$false)]
    [string]$Repository,
    
    [Parameter(Mandatory=$false)]
    [string]$Tag = "",
    
    [Parameter(Mandatory=$false)]
    [string]$FilePattern,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".",
    
    [Parameter(Mandatory=$false)]
    [string]$GithubToken = ""
)

# Enable debugging by setting the environment variable DEBUG=1
# Example: $env:DEBUG=1
function Write-DebugLog {
    param([string]$Message)
    if ($env:DEBUG -in @('1', 'true', 'y', 'yes')) {
        Write-Host "DEBUG: $Message" -ForegroundColor Yellow
    }
}

function Download-GitHubAsset {
    param(
        [Parameter(Mandatory=$false)]
        [string]$Repository,
        
        [Parameter(Mandatory=$false)]
        [string]$Tag = "",

        [Parameter(Mandatory=$false)]
        [string]$FilePattern,

        [Parameter(Mandatory=$false)]
        [string]$OutputPath = ".",

        [Parameter(Mandatory=$false)]
        [string]$GithubToken = ""
    )

    Write-DebugLog "Starting Download-GitHubAsset"
    Write-DebugLog "FilePattern: $FilePattern"

    # Create output directory if it doesn't exist
    if (-not (Test-Path $OutputPath)) {
        Write-DebugLog "Creating output directory: $OutputPath"
        New-Item -ItemType Directory -Path $OutputPath | Out-Null
    }

    try {
        $rawOutput = & "$PSScriptRoot\Get-GitHubRelease.ps1" -Repository $Repository -Tag $Tag -GithubToken $GithubToken
        Write-DebugLog "Raw output type: $($rawOutput.GetType().Name)"
        
        # Parse JSON if string output
        if ($rawOutput -is [string]) {
            $assets = $rawOutput | ConvertFrom-Json
        } else {
            $assets = $rawOutput
        }
        
        Write-DebugLog "Parsed assets count: $($assets.Count)"
        Write-DebugLog "First asset: $($assets[0] | ConvertTo-Json)"

        # Use regex match on parsed objects
        $matchedAsset = $assets | Where-Object { 
            Write-DebugLog "Checking asset: $($_.filename)"
            $matched = $_.filename -match $FilePattern
            Write-DebugLog "Match result: $matched"
            $matched
        } | Select-Object -First 1

        Write-DebugLog "Asset search completed"
        if (-not $matchedAsset) {
            throw "No asset matching pattern '$FilePattern' found"
        }

        Write-DebugLog "Downloading asset: $($matchedAsset.filename)"
        # Construct output file path
        $outputFile = Join-Path $OutputPath $matchedAsset.filename

        # Download file
        $webClient = New-Object System.Net.WebClient
        if ($GithubToken) {
            $webClient.Headers.Add('Authorization', "token $GithubToken")
        }
        $webClient.DownloadFile($matchedAsset.url, $outputFile)

        Write-DebugLog "Successfully downloaded to: $outputFile"
        return $outputFile

    } catch {
        Write-Error "Failed to download asset: $_"
        throw
    }
}

# Execute if script is run directly (not sourced)
# Example: .\Download-GitHubAsset.ps1 -Repository "neovim/neovim" -FilePattern "nvim-win64\.zip$" -OutputPath "."
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $Repository -or -not $FilePattern) {
        Write-Host "Usage: .\Download-GitHubAsset.ps1 -Repository <owner/repo> -FilePattern <pattern> [-Tag <tag>] [-OutputPath <path>] [-GithubToken <token>]"
        Write-Host ""
        Write-Host "Examples:"
        Write-Host "  .\Download-GitHubAsset.ps1 -Repository 'neovim/neovim' -FilePattern 'nvim-win64\.zip$' -OutputPath '.'"
        Write-Host "  .\Download-GitHubAsset.ps1 -Repository 'microsoft/windows-terminal' -FilePattern '\.msixbundle$' -Tag 'v1.16.10261.0'"
        exit 1
    }
    Download-GitHubAsset -Repository $Repository -Tag $Tag -FilePattern $FilePattern -OutputPath $OutputPath -GithubToken $GithubToken
}
