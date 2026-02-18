using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;

class LockScreenFix
{
    [DllImport("user32.dll")]
    static extern int SetDisplayConfig(
        uint numPathArrayElements,
        IntPtr pathArray,
        uint numModeInfoArrayElements,
        IntPtr modeInfoArray,
        uint flags
    );

    // SDC_TOPOLOGY_CLONE  = 0x00000002
    // SDC_TOPOLOGY_EXTEND = 0x00000004
    // SDC_APPLY           = 0x00000080
    const uint SDC_CLONE  = 0x00000082;
    const uint SDC_EXTEND = 0x00000084;

    // Unlock delay in milliseconds. The Windows desktop compositor needs time
    // to finish the unlock transition before we switch display modes.
    // If extending feels too slow, try 250. If it fails sometimes, try 750.
    // See README for details.
    const int UnlockDelayMs = 500;

    static void Main(string[] args)
    {
        if (args.Length == 0) return;

        string logDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "LockScreenFix");
        string logFile = Path.Combine(logDir, "lockscreenfix.log");

        string action = args[0].ToLower();
        int result;

        switch (action)
        {
            case "lock":
                result = SetDisplayConfig(0, IntPtr.Zero, 0, IntPtr.Zero, SDC_CLONE);
                break;
            case "unlock":
                Thread.Sleep(UnlockDelayMs);
                result = SetDisplayConfig(0, IntPtr.Zero, 0, IntPtr.Zero, SDC_EXTEND);
                break;
            default:
                return;
        }

        try
        {
            Directory.CreateDirectory(logDir);

            // Log rotation: if log exceeds 1 MB, rotate to .old
            if (File.Exists(logFile))
            {
                var info = new FileInfo(logFile);
                if (info.Length > 1024 * 1024)
                {
                    File.Copy(logFile, logFile + ".old", true);
                    File.Delete(logFile);
                }
            }

            string timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
            string line = string.Format("{0}  {1} (result: {2}){3}",
                timestamp, action, result, Environment.NewLine);
            File.AppendAllText(logFile, line);
        }
        catch
        {
            // Logging failure should not prevent display switching
        }
    }
}
