# Uninstall-LockScreenFix.ps1
# Removes the scheduled tasks and optionally cleans up install files

#Requires -RunAsAdministrator

$task1Name = "LockScreenFix - On Lock"
$task2Name = "LockScreenFix - On Unlock"
$installDir = "$env:LOCALAPPDATA\LockScreenFix"

foreach ($taskName in @($task1Name, $task2Name)) {
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host "Removed task: $taskName" -ForegroundColor Yellow
    } else {
        Write-Host "Task not found (already removed?): $taskName" -ForegroundColor Gray
    }
}

# --- Revert audit policy if the installer enabled it ---
$auditFlagFile = "$installDir\audit_enabled_by_installer.flag"
if (Test-Path $auditFlagFile) {
    Write-Host "Reverting audit policy change made during install..." -ForegroundColor Yellow
    & auditpol /set /subcategory:"Other Logon/Logoff Events" /success:disable 2>&1 | Out-Null
    Remove-Item $auditFlagFile -Force -ErrorAction SilentlyContinue
    Write-Host "Audit policy reverted for Other Logon/Logoff Events" -ForegroundColor Yellow
} else {
    Write-Host "Audit policy was not changed by installer - leaving as-is" -ForegroundColor Gray
}

$cleanup = Read-Host "Remove install directory $installDir ? (y/n)"
if ($cleanup -eq 'y') {
    Remove-Item -Recurse -Force $installDir -ErrorAction SilentlyContinue
    Write-Host "Removed $installDir" -ForegroundColor Yellow
}

Write-Host "Uninstall complete. Display is back to normal Windows behaviour." -ForegroundColor Cyan
