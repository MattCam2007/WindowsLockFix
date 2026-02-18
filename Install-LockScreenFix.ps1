# Install-LockScreenFix.ps1
# Run this ONCE as Administrator to register the lock/unlock scheduled tasks
# After running, you can delete this installer script if you like.

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

# --- Config ---
$scriptName    = "LockScreenFix.ps1"
$installDir    = "$env:LOCALAPPDATA\LockScreenFix"
$scriptDest    = "$installDir\$scriptName"
$task1Name     = "LockScreenFix - On Lock"
$task2Name     = "LockScreenFix - On Unlock"

# PowerShell executable
$psExe = "$PSHOME\powershell.exe"
if (-not (Test-Path $psExe)) {
    # Try PowerShell 7 if classic isn't found
    $psExe = (Get-Command pwsh -ErrorAction SilentlyContinue)?.Source
    if (-not $psExe) {
        throw "Could not locate powershell.exe or pwsh.exe"
    }
}

# --- Copy worker script to install dir ---
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir | Out-Null
}

$sourceScript = Join-Path $PSScriptRoot $scriptName
if (-not (Test-Path $sourceScript)) {
    # Try same folder as this installer
    $sourceScript = Join-Path (Split-Path $MyInvocation.MyCommand.Path) $scriptName
}
if (-not (Test-Path $sourceScript)) {
    throw "Cannot find $scriptName — make sure it's in the same folder as this installer."
}

Copy-Item $sourceScript $scriptDest -Force
Write-Host "Copied $scriptName to $installDir" -ForegroundColor Green

# --- Build task arguments ---
$lockArgs   = "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptDest`" -Action lock"
$unlockArgs = "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptDest`" -Action unlock"

# --- Remove old tasks if they exist ---
foreach ($taskName in @($task1Name, $task2Name)) {
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host "Removed existing task: $taskName" -ForegroundColor Yellow
    }
}

# --- Task 1: On Lock (Event ID 4800 — workstation locked) ---
$lockTriggerXml = @"
<QueryList>
  <Query Id="0" Path="Security">
    <Select Path="Security">*[System[EventID=4800]]</Select>
  </Query>
</QueryList>
"@

$lockTrigger  = New-ScheduledTaskTrigger -AtLogOn  # placeholder, we'll use event trigger via XML below
$lockAction   = New-ScheduledTaskAction -Execute $psExe -Argument $lockArgs
$taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 1)
$taskPrincipal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited

# Register with event-based trigger using Register-ScheduledTask XML approach
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
      <Command>$psExe</Command>
      <Arguments>$lockArgs</Arguments>
    </Exec>
  </Actions>
</Task>
"@

# --- Task 2: On Unlock (Event ID 4801 — workstation unlocked) ---
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
      <Command>$psExe</Command>
      <Arguments>$unlockArgs</Arguments>
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
