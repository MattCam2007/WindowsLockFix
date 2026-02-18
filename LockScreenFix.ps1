# LockScreenFix.ps1
# Switches display mode to Mirror on lock, Extend on unlock
# Triggered by Windows Task Scheduler lock/unlock events
# Usage: LockScreenFix.ps1 -Action lock|unlock

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("lock","unlock")]
    [string]$Action
)

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

# --- SetDisplayConfig P/Invoke ---
# Calls the Win32 CCD API directly instead of DisplaySwitch.exe.
# DisplaySwitch.exe is a GUI app that fails silently when the desktop is
# transitioning (lock/unlock), because the secure desktop is active.
# Direct API calls work regardless of which desktop is active.
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class DisplayConfig {
    [DllImport("user32.dll")]
    public static extern int SetDisplayConfig(
        uint numPathArrayElements,
        IntPtr pathArray,
        uint numModeInfoArrayElements,
        IntPtr modeInfoArray,
        uint flags
    );

    // SDC_TOPOLOGY_CLONE  = 0x00000002
    // SDC_TOPOLOGY_EXTEND = 0x00000004
    // SDC_APPLY           = 0x00000080
    public static int SetClone() {
        return SetDisplayConfig(0, IntPtr.Zero, 0, IntPtr.Zero, 0x00000082);
    }

    public static int SetExtend() {
        return SetDisplayConfig(0, IntPtr.Zero, 0, IntPtr.Zero, 0x00000084);
    }
}
"@

switch ($Action) {
    "lock" {
        Write-Log "Lock event detected - switching to Clone/Mirror mode"
        $result = [DisplayConfig]::SetClone()
        if ($result -ne 0) {
            Write-Log "ERROR: SetDisplayConfig(Clone) failed with code $result"
        }
    }
    "unlock" {
        # Delay to let the Windows desktop compositor finish the unlock transition.
        # Without this, the extend command can conflict with the unlock animation.
        # If switching feels sluggish or fails on your system, you can adjust this
        # value directly in this script. See README for details.
        Start-Sleep -Milliseconds 1500
        Write-Log "Unlock event detected - switching to Extend mode"
        $result = [DisplayConfig]::SetExtend()
        if ($result -ne 0) {
            Write-Log "ERROR: SetDisplayConfig(Extend) failed with code $result"
        }
    }
}

Write-Log "Done - Action: $Action (result: $result)"
