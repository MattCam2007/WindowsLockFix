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

# --- Log rotation: keep log under 1 MB, rotate to .log.old ---
$maxLogSize = 1MB
if (Test-Path $logFile) {
    $logSize = (Get-Item $logFile).Length
    if ($logSize -gt $maxLogSize) {
        $oldLog = "$logFile.old"
        Move-Item -Path $logFile -Destination $oldLog -Force
    }
}

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp  $Message" | Out-File -FilePath $logFile -Append -Encoding utf8
}

# --- Verify DisplaySwitch.exe exists ---
if (-not (Test-Path $displaySwitch)) {
    Write-Log "ERROR: DisplaySwitch.exe not found at $displaySwitch"
    exit 1
}

switch ($Action) {
    "lock" {
        Write-Log "Lock event detected — switching to Clone/Mirror mode"
        & $displaySwitch /clone
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            Write-Log "WARNING: DisplaySwitch.exe exited with code $LASTEXITCODE"
        }
    }
    "unlock" {
        # Delay to let the Windows desktop compositor finish the unlock transition.
        # Without this, the extend command can conflict with the unlock animation.
        # If switching feels sluggish or fails on your system, you can adjust this
        # value directly in this script. See README for details.
        Start-Sleep -Milliseconds 1500
        Write-Log "Unlock event detected — switching to Extend mode"
        & $displaySwitch /extend
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            Write-Log "WARNING: DisplaySwitch.exe exited with code $LASTEXITCODE"
        }
    }
}

Write-Log "Done — Action: $Action"
