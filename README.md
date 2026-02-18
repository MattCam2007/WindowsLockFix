# WindowsLockFix

Automatically mirrors/clones your display across all monitors when Windows locks, so the lock screen wallpaper appears on every screen. Switches back to extended display mode on unlock.

## How it works

When you press Win+L (or your screen locks automatically), Windows Task Scheduler fires the worker script via Security Event ID 4800. The script calls the built-in `DisplaySwitch.exe /clone` to mirror all displays. On unlock (Event ID 4801), it waits briefly for the desktop compositor to settle, then calls `DisplaySwitch.exe /extend` to restore your multi-monitor layout.

## Requirements

- Windows 10 or 11 (uses built-in `DisplaySwitch.exe`)
- PowerShell 5.1+ (included with Windows) or PowerShell 7+
- Administrator privileges (for installation only)
- Multiple monitors

## Installation

1. Download or clone this repository
2. Open PowerShell **as Administrator**
3. Run:

```powershell
.\Install-LockScreenFix.ps1
```

4. Lock your screen with **Win+L** to test

The installer will:
- Copy the worker script to `%LOCALAPPDATA%\LockScreenFix\`
- Register two scheduled tasks (one for lock, one for unlock)
- Enable the required Windows audit policy if it isn't already configured

## Uninstallation

Open PowerShell **as Administrator** and run:

```powershell
.\Uninstall-LockScreenFix.ps1
```

This removes the scheduled tasks and optionally deletes the install directory. If the installer enabled the audit policy, the uninstaller will revert that change.

## Adjusting the unlock delay

The worker script waits 1500 ms after unlock before switching back to extended mode. This delay gives the Windows desktop compositor time to finish the unlock transition. Without it, the display switch can conflict with the unlock animation and fail silently.

If switching feels sluggish or doesn't work reliably on your system, you can adjust this value. Open the installed script at:

```
%LOCALAPPDATA%\LockScreenFix\LockScreenFix.ps1
```

Find this line and change the number:

```powershell
Start-Sleep -Milliseconds 1500
```

- **Slower system or docking station?** Try `2000` or `2500`.
- **Fast system and it feels laggy?** Try `1000` or `750`.

## Logging

Logs are written to `%LOCALAPPDATA%\LockScreenFix\lockscreenfix.log`. The log file is automatically rotated when it exceeds 1 MB (old entries move to `lockscreenfix.log.old`).

## Security notes

**Execution policy:** The scheduled tasks run PowerShell with `-ExecutionPolicy Bypass` so the worker script executes regardless of the system's execution policy setting. This is standard practice for scheduled tasks but means the installed script at `%LOCALAPPDATA%\LockScreenFix\LockScreenFix.ps1` will run without policy checks. The tasks run at the user's own privilege level (not elevated), so the blast radius is limited to your user account. Do not modify the installed script to run untrusted code.

**XML task registration:** The installer embeds your username, domain, and PowerShell path directly into the scheduled task XML. If any of these values contain the characters `<`, `>`, or `&`, installation will fail with an error message. This is uncommon but can occur with certain Active Directory configurations.

## Files

| File | Purpose |
|---|---|
| `LockScreenFix.ps1` | Worker script (runs on each lock/unlock) |
| `Install-LockScreenFix.ps1` | One-time installer (run as admin) |
| `Uninstall-LockScreenFix.ps1` | Uninstaller (run as admin) |
