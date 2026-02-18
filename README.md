# WindowsLockFix

Automatically mirrors/clones your display across all monitors when Windows locks, so the lock screen wallpaper appears on every screen. Switches back to extended display mode on unlock.

## How it works

When you press Win+L (or your screen locks automatically), Windows Task Scheduler fires a compiled executable via Security Event ID 4800. The executable calls the Win32 `SetDisplayConfig` API directly to switch all displays to clone/mirror mode. On unlock (Event ID 4801), it waits briefly for the desktop compositor to settle, then calls the same API to restore extended mode.

The executable is compiled from C# source during installation using the .NET Framework compiler. It calls the Win32 API via P/Invoke rather than shelling out to `DisplaySwitch.exe`, because that GUI executable fails silently during desktop transitions (the lock/unlock switches to the secure desktop). The compiled `.exe` also eliminates PowerShell startup overhead, making the switch near-instant.

## Requirements

- Windows 10 or 11
- .NET Framework 4.x (included with Windows)
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
- Compile `LockScreenFix.cs` into a native `.exe`
- Copy it to `%LOCALAPPDATA%\LockScreenFix\`
- Register two scheduled tasks (one for lock, one for unlock)
- Enable the required Windows audit policy if it isn't already configured

## Uninstallation

Open PowerShell **as Administrator** and run:

```powershell
.\Uninstall-LockScreenFix.ps1
```

This removes the scheduled tasks and optionally deletes the install directory. If the installer enabled the audit policy, the uninstaller will revert that change.

## Adjusting the unlock delay

The executable waits 500 ms after unlock before switching back to extended mode. This delay gives the Windows desktop compositor time to finish the unlock transition. Without it, the display switch can fail silently.

To change the delay, edit `LockScreenFix.cs`, find this line:

```csharp
const int UnlockDelayMs = 500;
```

- **If extending fails sometimes:** Try `750` or `1000`.
- **If it feels laggy:** Try `250`.

Then re-run `.\Install-LockScreenFix.ps1` as Administrator to recompile and reinstall.

## Logging

Logs are written to `%LOCALAPPDATA%\LockScreenFix\lockscreenfix.log`.

A result code of `0` means success. Any other value indicates a Win32 error from `SetDisplayConfig`.

### Log size limit

The log file is automatically rotated when it exceeds **1 MB**. On rotation, the current file is copied to `lockscreenfix.log.old` and a fresh log starts. Only one backup is kept, so the maximum disk usage is approximately **2 MB** (the active log plus the `.old` file).

### Changing the log size limit

The 1 MB threshold is hardcoded in `LockScreenFix.cs`. To change it, find this line:

```csharp
if (info.Length > 1024 * 1024)
```

Replace `1024 * 1024` (1 MB) with the desired size in bytes. For example:

- **512 KB:** `512 * 1024`
- **5 MB:** `5 * 1024 * 1024`

Then re-run `.\Install-LockScreenFix.ps1` as Administrator to recompile and reinstall.

## Security notes

**XML task registration:** The installer embeds your username, domain, and exe path directly into the scheduled task XML. If any of these values contain the characters `<`, `>`, or `&`, installation will fail with an error message. This is uncommon but can occur with certain Active Directory configurations.

## Files

| File | Purpose |
|---|---|
| `LockScreenFix.cs` | C# source (compiled to .exe during install) |
| `Install-LockScreenFix.ps1` | One-time installer (run as admin) |
| `Uninstall-LockScreenFix.ps1` | Uninstaller (run as admin) |
