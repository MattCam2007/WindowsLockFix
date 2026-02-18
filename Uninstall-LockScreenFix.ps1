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

$cleanup = Read-Host "Remove install directory $installDir ? (y/n)"
if ($cleanup -eq 'y') {
    Remove-Item -Recurse -Force $installDir -ErrorAction SilentlyContinue
    Write-Host "Removed $installDir" -ForegroundColor Yellow
}

Write-Host "Uninstall complete. Display is back to normal Windows behaviour." -ForegroundColor Cyan
