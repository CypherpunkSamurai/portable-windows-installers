# Get-GitHubRelease.ps1
param(
    [Parameter(Mandatory=$false)]
    [string]$Repository,
    
    [Parameter(Mandatory=$false)]
    [string]$Tag = "",

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

function Get-GitHubRelease {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Repository,
        
        [Parameter(Mandatory=$false)]
        [string]$Tag = "",

        [Parameter(Mandatory=$false)]
        [string]$GithubToken = ""
    )

    Write-DebugLog "Starting Get-GitHubRelease for repository: $Repository, Tag: $($Tag -eq '' ? 'latest' : $Tag)"

    # Construct the API URL
    $apiBaseUrl = "https://api.github.com/repos/$Repository/releases"
    Write-DebugLog "Base API URL: $apiBaseUrl"

    # Prepare headers
    $headers = @{
        "Accept" = "application/vnd.github.v3+json"
        "User-Agent" = "PowerShell Script"
    }
    if ($GithubToken) {
        $headers["Authorization"] = "Bearer $GithubToken"
        Write-DebugLog "Using GitHub token for authentication"
    }
    Write-DebugLog "Headers configured: $($headers.Keys -join ', ')"

    try {
        if ($Tag -eq "") {
            Write-DebugLog "Fetching all releases to find latest"
            $apiUrl = $apiBaseUrl
            Write-DebugLog "Making API request to: $apiUrl"
            $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get -Verbose:($env:DEBUG -eq "1")
            
            Write-DebugLog "Received $($response.Count) releases"
            if ($response.Count -eq 0) {
                Write-Error "No releases found for repository $Repository"
                return $null
            }
            $release = $response[0]
            Write-DebugLog "Selected latest release: $($release.tag_name)"
        } else {
            $apiUrl = "$apiBaseUrl/tags/$Tag"
            Write-DebugLog "Making API request to: $apiUrl"
            $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get -Verbose:($env:DEBUG -eq "1")
            $release = $response
            Write-DebugLog "Retrieved release for tag: $($release.tag_name)"
        }

        Write-DebugLog "Processing release data"
        Write-DebugLog "Release name: $($release.name)"
        Write-DebugLog "Release tag: $($release.tag_name)"
        Write-DebugLog "Is prerelease: $($release.prerelease)"
        Write-DebugLog "Asset count: $($release.assets.Count)"

        # Create custom output object
        $releaseInfo = [PSCustomObject]@{
            TagName = $release.tag_name
            Name = $release.name
            IsPrerelease = $release.prerelease
            PublishedAt = $release.published_at
            Assets = @()
        }

        # Process each asset
        foreach ($asset in $release.assets) {
            Write-DebugLog "Processing asset: $($asset.name)"
            $assetInfo = [PSCustomObject]@{
                Name = $asset.name
                Size = $asset.size
                DownloadUrl = $asset.browser_download_url
                ContentType = $asset.content_type
                CreatedAt = $asset.created_at
                UpdatedAt = $asset.updated_at
            }
            $releaseInfo.Assets += $assetInfo
        }

        Write-DebugLog "Successfully processed release information"
        return $releaseInfo
    }
    catch {
        Write-DebugLog "Error occurred during API request"
        Write-DebugLog "Exception type: $($_.Exception.GetType().Name)"
        
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode.value__
            $statusDescription = $_.Exception.Response.StatusDescription
            Write-DebugLog "Status code: $statusCode"
            Write-DebugLog "Status description: $statusDescription"
            
            # Try to get response body for more error details
            try {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $reader.BaseStream.Position = 0
                $reader.DiscardBufferedData()
                $responseBody = $reader.ReadToEnd()
                Write-DebugLog "Response body: $responseBody"
            }
            catch {
                Write-DebugLog "Could not read response body: $_"
            }
        }
        
        $errorMessage = if ($_.ErrorDetails.Message) {
            try {
                $errorJson = $_.ErrorDetails.Message | ConvertFrom-Json
                $errorJson.message
            } catch {
                $_.ErrorDetails.Message
            }
        } else {
            $_.Exception.Message
        }
        
        Write-DebugLog "Final error message: $errorMessage"
        Write-Error "Error fetching release information: $errorMessage"
        return $null
    }
}

# Convert the release object to JSON response
function ConvertTo-JsonResponse {
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Release
    )

    $assets = $Release.Assets | ForEach-Object {
        @{
            filename = $_.Name
            url = $_.DownloadUrl
        }
    }

    return $assets | ConvertTo-Json -Depth 10
}


# Execute if script is run directly (not sourced)
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $Repository) {
        Write-Host "Usage: Get-GitHubRelease.ps1 -Repository <owner/repo> [-Tag <tag>] [-GithubToken <token>]"
        Write-Host ""
        Write-Host "Examples:"
        Write-Host "  .\Get-GitHubRelease.ps1 -Repository neovim/neovim"
        Write-Host "  .\Get-GitHubRelease.ps1 -Repository neovim/neovim -Tag nightly"
        Write-Host "  .\Get-GitHubRelease.ps1 -Repository neovim/neovim -Tag stable -GithubToken xyz123"
        exit 1
    }
    $release = Get-GitHubRelease -Repository $Repository -Tag $Tag -GithubToken $GithubToken
    if ($release) {
        ConvertTo-JsonResponse -Release $release
    }
}

# Export-ModuleMember -Function Get-GitHubRelease, ConvertTo-JsonResponse