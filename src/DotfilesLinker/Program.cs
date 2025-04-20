// DotfilesLinker – top‑level statements / Native AOT
// build: dotnet publish -c Release -r win-x64 /p:PublishAot=true /p:PublishSingleFile=true

using System.Diagnostics;
using System.Security.Principal;
using Microsoft.Win32;

// コマンドライン解析
string? force = args.FirstOrDefault(a => a.StartsWith("--force=", StringComparison.OrdinalIgnoreCase))?.Split('=', 2)[1];

// 事前チェック（OS / 権限 / 開発者モード）
if (!OperatingSystem.IsWindows())
    ExitError("Please run on Windows.");

SetXdgConfigHomeIfNeeded();

bool devMode = IsDeveloperMode();
bool isAdmin = IsAdministrator();

if (!(devMode || isAdmin))
{
    WriteWarning("Detected non‑elevated execution. Creating symbolic links requires Admin privilege unless Developer Mode is enabled. Proceed with UAC? (y/n) ");
    if (!string.Equals(Console.ReadLine(), "y", StringComparison.OrdinalIgnoreCase))
        ExitError("Canceled.");

    RelaunchElevated(args);
    return;   // ここで親プロセスは終了
}

// 本処理
try
{
    Run();
    WriteSuccess("All operations completed.");
}
catch (Exception ex)
{
    ExitError(ex.Message);
}

void Run()
{
    string repoRoot = Directory.GetCurrentDirectory();
    string userHome = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);

    // --- dotfiles ---------------------------------------------
    var ignores = LoadIgnoreList(Path.Combine(repoRoot, ".dotfiles_ignore"));
    foreach (string src in Directory.EnumerateFiles(repoRoot, ".*", SearchOption.TopDirectoryOnly)
                                   .Where(p => !ignores.Contains(Path.GetFileName(p))))
    {
        string dst = Path.Combine(userHome, Path.GetFileName(src));
        LinkFile(src, dst);
    }

    // --- home/{…} ---------------------------------------------
    string homeRoot = Path.Combine(repoRoot, "home");
    if (Directory.Exists(homeRoot))
    {
        foreach (string src in Directory.EnumerateFiles(homeRoot, "*", SearchOption.AllDirectories))
        {
            string rel = Path.GetRelativePath(homeRoot, src);
            string dst = Path.Combine(userHome, rel);

            Directory.CreateDirectory(Path.GetDirectoryName(dst)!);
            LinkFile(src, dst);
        }
    }
}

void LinkFile(string source, string target)
{
    bool needOverwrite = false;

    if (File.Exists(target) || Directory.Exists(target))
    {
        string? linkTarget = new FileInfo(target).LinkTarget; // null → 通常ファイル
        bool sameLink = !string.IsNullOrEmpty(linkTarget) && PathEquals(linkTarget, source);

        if (!sameLink)
        {
            if (!Confirm($"'{target}' already exists, overwrite?"))
            {
                WriteError($"'{target}' → '{source}'");
                return;
            }
            needOverwrite = true;
        }
        else
        {
            WriteSuccess($"'{target}' → '{source}'");
            return;
        }
    }

    if (needOverwrite)
    {
        if (File.Exists(target)) File.Delete(target);
        else if (Directory.Exists(target)) Directory.Delete(target);
    }

    // ディレクトリ・ファイルどちらも対応
    if (Directory.Exists(source))
        Directory.CreateSymbolicLink(target, source);
    else
        File.CreateSymbolicLink(target, source);

    WriteSuccess($"'{target}' → '{source}'");
}

bool Confirm(string msg)
{
    if (!string.IsNullOrEmpty(force))
        return force.Equals("y", StringComparison.OrdinalIgnoreCase);

    Console.ForegroundColor = ConsoleColor.Yellow;
    Console.Write($"[?] {msg} ");
    Console.ResetColor();
    return string.Equals(Console.ReadLine(), "y", StringComparison.OrdinalIgnoreCase);
}

bool IsAdministrator()
{
    using var id = WindowsIdentity.GetCurrent();
    bool admin = new WindowsPrincipal(id).IsInRole(WindowsBuiltInRole.Administrator);
    Console.WriteLine(admin
        ? "[o] Script is executed with Admin privilege."
        : "[!] Script is executed without Admin privilege.");
    return admin;
}

bool IsDeveloperMode()
{
    const string keyPath = @"SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock";
    const string valueName = "AllowDevelopmentWithoutDevLicense";

    bool enabled = (Registry.LocalMachine.OpenSubKey(keyPath)
                       ?.GetValue(valueName) as int? ?? 0) == 1;

    if (enabled)
        WriteSuccess("Great, Windows Developer Mode is enabled.");
    else
        WriteWarning("Windows Developer Mode is disabled. Enabling it avoids symlink restrictions.");

    return enabled;
}

HashSet<string> LoadIgnoreList(string file) =>
    File.Exists(file)
        ? File.ReadAllLines(file).Where(l => !string.IsNullOrWhiteSpace(l))
            .ToHashSet(StringComparer.OrdinalIgnoreCase)
        : new(StringComparer.OrdinalIgnoreCase);

void RelaunchElevated(string[] originalArgs)
{
    var psi = new ProcessStartInfo
    {
        FileName = Environment.ProcessPath,
        Arguments = string.Join(' ', originalArgs.Select(a => $"\"{a}\"")),
        UseShellExecute = true,
        Verb = "runas"   // UAC prompt
    };
    Process.Start(psi)?.WaitForExit();
}

void SetXdgConfigHomeIfNeeded()
{
    if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("XDG_CONFIG_HOME")))
    {
        string path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".config");
        Environment.SetEnvironmentVariable("XDG_CONFIG_HOME", path, EnvironmentVariableTarget.User);
    }
}

static bool PathEquals(string a, string b) =>
    string.Equals(Path.GetFullPath(a), Path.GetFullPath(b), StringComparison.OrdinalIgnoreCase);

// ── pretty printing helpers ──────────────────────────────────
void WriteSuccess(string msg) => WriteColored("[o] ", msg, ConsoleColor.Green);
void WriteError(string msg) => WriteColored("[x] ", msg, ConsoleColor.Red);
void WriteWarning(string msg) => WriteColored("[!] ", msg, ConsoleColor.Cyan);

void WriteColored(string prefix, string msg, ConsoleColor color)
{
    Console.ForegroundColor = color;
    Console.WriteLine($"{prefix}{msg}");
    Console.ResetColor();
}

void ExitError(string message)
{
    WriteError(message);
    Environment.Exit(1);
}
