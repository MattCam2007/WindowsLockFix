# LockScreenFix.ps1
# Switches display mode to Mirror on lock, Extend on unlock
# Triggered by Windows Task Scheduler lock/unlock events
# Usage: LockScreenFix.ps1 -Action lock|unlock

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("lock","unlock")]
    [string]$Action
)

# Path to DisplaySwitch.exe - built into Windows, no dependencies needed
$displaySwitch = "$env:SystemRoot\System32\DisplaySwitch.exe"

$logFile = "$env:LOCALAPPDATA\LockScreenFix\lockscreenfix.log"
$logDir  = Split-Path $logFile

if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp  $Message" | Out-File -FilePath $logFile -Append -Encoding utf8
}

switch ($Action) {
    "lock" {
        Write-Log "Lock event detected — switching to Clone/Mirror mode"
        & $displaySwitch /clone
    }
    "unlock" {
        # Small delay to let Windows settle before switching back
        Start-Sleep -Milliseconds 1500
        Write-Log "Unlock event detected — switching to Extend mode"
        & $displaySwitch /extend
    }
}

Write-Log "Done — Action: $Action"
