# Install-LockScreenFix.ps1
# Run this ONCE as Administrator to register the lock/unlock scheduled tasks
# After running, you can delete this installer script if you like.

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

# --- Config ---
$sourceName    = "LockScreenFix.cs"
$exeName       = "LockScreenFix.exe"
$installDir    = "$env:LOCALAPPDATA\LockScreenFix"
$sourceDest    = "$installDir\$sourceName"
$exeDest       = "$installDir\$exeName"
$task1Name     = "LockScreenFix - On Lock"
$task2Name     = "LockScreenFix - On Unlock"

# --- Locate .NET Framework C# compiler ---
$cscPath = Join-Path ([System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()) "csc.exe"
if (-not (Test-Path $cscPath)) {
    throw "Could not find .NET Framework C# compiler (csc.exe). .NET Framework 4.x is required."
}

# --- Find source file ---
$sourceFile = Join-Path $PSScriptRoot $sourceName
if (-not (Test-Path $sourceFile)) {
    $sourceFile = Join-Path (Split-Path $MyInvocation.MyCommand.Path) $sourceName
}
if (-not (Test-Path $sourceFile)) {
    throw "Cannot find $sourceName - make sure it's in the same folder as this installer."
}

# --- Copy source and compile ---
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir | Out-Null
}

Copy-Item $sourceFile $sourceDest -Force

Write-Host "Compiling $exeName..." -ForegroundColor Gray
& $cscPath /nologo /target:winexe /out:$exeDest $sourceDest 2>&1 | ForEach-Object {
    Write-Host "  $_" -ForegroundColor Gray
}
if ($LASTEXITCODE -ne 0) {
    throw "Failed to compile $exeName"
}
Write-Host "Compiled $exeName to $installDir" -ForegroundColor Green

# --- Ensure audit policy generates lock/unlock events (4800/4801) ---
# Event IDs 4800 and 4801 require "Other Logon/Logoff Events" success auditing.
# Without this, the scheduled tasks will never trigger.
$auditFlagFile = "$installDir\audit_enabled_by_installer.flag"
$auditOutput = & auditpol /get /subcategory:"Other Logon/Logoff Events" 2>&1 | Out-String

if ($auditOutput -notmatch "Success") {
    Write-Host "Enabling audit policy for lock/unlock events (required for Event IDs 4800/4801)..." -ForegroundColor Yellow
    & auditpol /set /subcategory:"Other Logon/Logoff Events" /success:enable | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to enable audit policy. Lock/unlock events will not be generated."
    }
    # Flag that we enabled this so the uninstaller can revert it
    "Enabled by LockScreenFix installer on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File $auditFlagFile -Encoding utf8
    Write-Host "Audit policy enabled for Other Logon/Logoff Events" -ForegroundColor Green
} else {
    Write-Host "Audit policy already configured for lock/unlock events" -ForegroundColor Green
}

# --- Validate values are safe to embed in XML ---
# Usernames, domains, or paths containing <, >, or & will produce malformed task XML.
$userId = "$env:USERDOMAIN\$env:USERNAME"
foreach ($val in @($userId, $exeDest)) {
    if ($val -match '[<>&]') {
        throw "Cannot register scheduled tasks: a value contains XML-unsafe characters (<, >, &): '$val'. See README for details."
    }
}

# --- Remove old tasks if they exist ---
foreach ($taskName in @($task1Name, $task2Name)) {
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host "Removed existing task: $taskName" -ForegroundColor Yellow
    }
}

# --- Task 1: On Lock (Event ID 4800 - workstation locked) ---
$lockTaskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Switches display to Clone mode when workstation locks so lock screen appears on all monitors</Description>
    <Author>LockScreenFix</Author>
  </RegistrationInfo>
  <Triggers>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Security"&gt;&lt;Select Path="Security"&gt;*[System[EventID=4800]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$env:USERDOMAIN\$env:USERNAME</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT1M</ExecutionTimeLimit>
    <Enabled>true</Enabled>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>$exeDest</Command>
      <Arguments>lock</Arguments>
    </Exec>
  </Actions>
</Task>
"@

# --- Task 2: On Unlock (Event ID 4801 - workstation unlocked) ---
$unlockTaskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Switches display back to Extend mode when workstation unlocks</Description>
    <Author>LockScreenFix</Author>
  </RegistrationInfo>
  <Triggers>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Security"&gt;&lt;Select Path="Security"&gt;*[System[EventID=4801]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$env:USERDOMAIN\$env:USERNAME</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT1M</ExecutionTimeLimit>
    <Enabled>true</Enabled>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>$exeDest</Command>
      <Arguments>unlock</Arguments>
    </Exec>
  </Actions>
</Task>
"@

# Register both tasks
Register-ScheduledTask -TaskName $task1Name -Xml $lockTaskXml -Force | Out-Null
Write-Host "Registered task: $task1Name" -ForegroundColor Green

Register-ScheduledTask -TaskName $task2Name -Xml $unlockTaskXml -Force | Out-Null
Write-Host "Registered task: $task2Name" -ForegroundColor Green

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Cyan
Write-Host "Lock your screen with Win+L to test. Both monitors should now show the lock screen." -ForegroundColor Cyan
Write-Host ""
Write-Host "Log file will appear at: $installDir\lockscreenfix.log" -ForegroundColor Gray
Write-Host "To uninstall, run: Uninstall-LockScreenFix.ps1" -ForegroundColor Gray
