# Check if running as administrator
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

# Self-elevate if not already running as administrator
if (-not (Test-Admin)) {
    Write-Host "Elevating privileges to modify system settings..." -ForegroundColor Yellow
    $scriptPath = $MyInvocation.MyCommand.Path
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
    exit
}

# Now running with elevated privileges
Write-Host "Running with administrator privileges" -ForegroundColor Green

# Modify registry to enable long paths
try {
    Write-Host "Disabling Windows PATH length limit..." -ForegroundColor Cyan
    
    # Create/modify the registry key that controls path length limitations
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
    Set-ItemProperty -Path $regPath -Name "LongPathsEnabled" -Value 1 -Type DWord -Force
    
    Write-Host "SUCCESS: Windows PATH length limit (260 characters) has been disabled." -ForegroundColor Green
    Write-Host "Applications that support long paths can now use paths exceeding 260 characters." -ForegroundColor Green
    Write-Host "Note: Some applications may still have their own path length restrictions." -ForegroundColor Yellow
}
catch {
    Write-Host "ERROR: Failed to modify registry: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`nPress any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
