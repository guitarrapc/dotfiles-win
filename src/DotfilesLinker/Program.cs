// DotfilesLinker: PowerShell スクリプトを純 .NET に移植したネイティブ AOT 版
// build: dotnet publish -c Release -r win-x64 /p:PublishSingleFile=true
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Security.Principal;
using Microsoft.Win32;

namespace DotfilesLinker;

internal static class Program
{
    private static string? _force; // "y" or "n"

    /*-----------------------------------------------------------
     * Entry
     *----------------------------------------------------------*/
    public static int Main(string[] args)
    {
        // --- parse --force=y|n -------------
        _force = args.FirstOrDefault(a => a.StartsWith("--force="))
                     ?.Split('=', 2)[1];

        // --- guardrails --------------------
        if (!OperatingSystem.IsWindows())
            return ExitError("Please run on Windows.");

        SetXdgConfigHomeIfNeeded();

        var devMode = IsDeveloperMode();
        var isAdmin = IsAdministrator();

        if (!(devMode || isAdmin))
        {
            WriteWarning("[!] Detected non‑elevated execution. Creating symbolic links requires Admin privilege unless Developer Mode is enabled. Proceed with UAC? (y/n) ");
            var ans = Console.ReadLine();
            if (string.Equals(ans, "y", StringComparison.OrdinalIgnoreCase))
            {
                RelaunchElevated(args);
                return 0;
            }
            return ExitError("Canceled.");
        }

        try
        {
            Run();
            WriteSuccess("All operations completed.");
            return 0;
        }
        catch (Exception ex)
        {
            return ExitError(ex.Message);
        }
    }

    /*-----------------------------------------------------------
     * Core
     *----------------------------------------------------------*/
    private static void Run()
    {
        var repoRoot = Directory.GetCurrentDirectory();
        var userHome = Environment.GetFolderPath(
                           Environment.SpecialFolder.UserProfile);

        // ---- dot‑files  -------------------
        var ignores = LoadIgnoreList(Path.Combine(repoRoot, ".dotfiles_ignore"));

        foreach (var src in Directory.EnumerateFiles(repoRoot, ".*",
                     SearchOption.TopDirectoryOnly)
                     .Where(p => !ignores.Contains(Path.GetFileName(p))))
        {
            var dst = Path.Combine(userHome, Path.GetFileName(src));
            LinkFile(src, dst);
        }

        // ---- home/{…}  --------------------
        var homeRoot = Path.Combine(repoRoot, "home");
        if (Directory.Exists(homeRoot))
        {
            foreach (var src in Directory.EnumerateFiles(homeRoot, "*",
                         SearchOption.AllDirectories))
            {
                var rel = Path.GetRelativePath(homeRoot, src);
                var dst = Path.Combine(userHome, rel);

                Directory.CreateDirectory(Path.GetDirectoryName(dst)!);
                LinkFile(src, dst);
            }
        }
    }

    /*-----------------------------------------------------------
     * Helpers
     *----------------------------------------------------------*/
    private static void LinkFile(string source, string target)
    {
        bool NeedOverwrite()
        {
            if (!File.Exists(target) && !Directory.Exists(target))
                return true;                               // まだ無い

            var linkTarget = new FileInfo(target).LinkTarget;
            // シンボリックリンクで元と同じなら何もしない
            if (!string.IsNullOrEmpty(linkTarget) && PathEquals(linkTarget, source))
                return false;

            // ファイル or 異なるリンク → 上書き確認
            if (!Confirm($"'{target}' already exists, overwrite?"))
            {
                WriteError($"'{target}' → '{source}'");
                return false;
            }
            if (File.Exists(target) || Directory.Exists(target))
                File.Delete(target);
            return true;
        }

        if (!NeedOverwrite()) return;

        // ディレクトリかファイルかで API を分ける
        if (Directory.Exists(source))
            Directory.CreateSymbolicLink(target, source);
        else
            File.CreateSymbolicLink(target, source);

        WriteSuccess($"'{target}' ➜ '{source}'");
    }

    private static bool PathEquals(string a, string b) => string.Equals(Path.GetFullPath(a), Path.GetFullPath(b), StringComparison.OrdinalIgnoreCase);

    private static bool Confirm(string msg)
    {
        if (!string.IsNullOrEmpty(_force))
            return _force.Equals("y", StringComparison.OrdinalIgnoreCase);

        Console.ForegroundColor = ConsoleColor.Yellow;
        Console.Write($"[?] {msg} ");
        Console.ResetColor();
        var ans = Console.ReadLine();
        return ans?.Equals("y", StringComparison.OrdinalIgnoreCase) == true;
    }

    private static bool IsAdministrator()
    {
        using var id = WindowsIdentity.GetCurrent();
        var admin = new WindowsPrincipal(id).IsInRole(WindowsBuiltInRole.Administrator);
        Console.WriteLine(admin
            ? "[o] Script is executed with Admin privilege."
            : "[!] Script is executed without Admin privilege.");
        return admin;
    }

    private static bool IsDeveloperMode()
    {
        const string keyPath =
            @"SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock";
        const string valueName = "AllowDevelopmentWithoutDevLicense";
        var enabled = Registry.LocalMachine.OpenSubKey(keyPath)?.GetValue(valueName) as int? == 1;

        if (enabled)
            WriteSuccess("Great, Windows Developer Mode is enabled.");
        else
            WriteWarning("Windows Developer Mode is disabled. " +
                         "Enabling it avoids symlink restrictions.");

        return enabled;
    }

    private static HashSet<string> LoadIgnoreList(string file)
        => File.Exists(file)
           ? File.ReadAllLines(file)
                 .Where(l => !string.IsNullOrWhiteSpace(l))
                 .ToHashSet(StringComparer.OrdinalIgnoreCase)
           : new HashSet<string>(StringComparer.OrdinalIgnoreCase);

    private static void RelaunchElevated(string[] args)
    {
        var psi = new ProcessStartInfo
        {
            FileName = Environment.ProcessPath,
            Arguments = string.Join(' ', args),
            UseShellExecute = true,
            Verb = "runas" // UAC prompt
        };
        Process.Start(psi)?.WaitForExit();
    }

    private static void SetXdgConfigHomeIfNeeded()
    {
        var current = Environment.GetEnvironmentVariable("XDG_CONFIG_HOME");
        if (string.IsNullOrEmpty(current))
        {
            var path = Path.Combine(
                Environment.GetFolderPath(
                    Environment.SpecialFolder.UserProfile), ".config");
            Environment.SetEnvironmentVariable(
                "XDG_CONFIG_HOME", path, EnvironmentVariableTarget.User);
        }
    }

    /*-----------------------------------------------------------
     * Pretty printing
     *----------------------------------------------------------*/
    private static void WriteSuccess(string msg) => WriteColored("[o] ", msg,
        ConsoleColor.Green);
    private static void WriteError(string msg)  => WriteColored("[x] ", msg,
        ConsoleColor.Red);
    private static void WriteWarning(string msg) => WriteColored("[!] ", msg,
        ConsoleColor.Cyan);

    private static void WriteColored(string prefix, string msg,
                                     ConsoleColor color)
    {
        Console.ForegroundColor = color;
        Console.WriteLine($"{prefix}{msg}");
        Console.ResetColor();
    }

    private static int ExitError(string message)
    {
        WriteError(message);
        return 1;
    }
}
