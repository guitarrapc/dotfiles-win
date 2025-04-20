dotfiles-win

# Preprequisites

* Enable Windows Developer Mode to allow Symlink without UAC Admin Escalation, also allow PowerShell Script execution.

# Run

There are three ways to run dotfiles linker, PowerShell and C# and C# AOT.

## PowerShell

* `./install.ps1` to setup symlink

```shell
PS> .\install.ps1
Great, Windows Developer mode is Enabled.
  [o] 'C:\Users\guitarrapc\.dotfiles_ignore' 竊・'D:\github\guitarrapc\dotfiles-win\.dotfiles_ignore'
  [o] 'C:\Users\guitarrapc\.textlintrc.json' 竊・'D:\github\guitarrapc\dotfiles-win\.textlintrc.json'
  [o] 'C:\Users\guitarrapc\.wslconfig' 竊・'D:\github\guitarrapc\dotfiles-win\.wslconfig'
  [o] 'C:\Users\guitarrapc\.config\git\config' 竊・'D:\github\guitarrapc\dotfiles-win\home\.config\git\config'
  [o] 'C:\Users\guitarrapc\.config\git\ignore' 竊・'D:\github\guitarrapc\dotfiles-win\home\.config\git\ignore'
  [o] 'C:\Users\guitarrapc\.docker\daemon.json' 竊・'D:\github\guitarrapc\dotfiles-win\home\.docker\daemon.json'
  [o] 'C:\Users\guitarrapc\.ssh\config' 竊・'D:\github\guitarrapc\dotfiles-win\home\.ssh\config'
  [o] 'C:\Users\guitarrapc\.ssh\conf.d\aws.conf' 竊・'D:\github\guitarrapc\dotfiles-win\home\.ssh\conf.d\aws.conf'
  [o] 'C:\Users\guitarrapc\.ssh\conf.d\github.conf' 竊・'D:\github\guitarrapc\dotfiles-win\home\.ssh\conf.d\github.conf'
  [o] 'C:\Users\guitarrapc\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json' 竊・'D:\github\guitarrapc\dotfiles-win\home\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
  [o] 'C:\Users\guitarrapc\AppData\Roaming\Code\User\settings.json' 竊・'D:\github\guitarrapc\dotfiles-win\home\AppData\Roaming\Code\User\settings.json'
  [o] 'C:\Users\guitarrapc\Documents\PowerShell\Microsoft.PowerShell_profile.ps1' 竊・'D:\github\guitarrapc\dotfiles-win\home\Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
  [o] 'C:\Users\guitarrapc\Documents\Visual Studio 2022\Templates\ItemTemplates\CSharp\Code\1033\Class\Class.cs' 竊・'D:\github\guitarrapc\dotfiles-win\home\Documents\Visual Studio 2022\Templates\ItemTemplates\CSharp\Code\1033\Class\Class.cs'
  [o] 'C:\Users\guitarrapc\Documents\Visual Studio 2022\Templates\ItemTemplates\CSharp\Code\1033\Class\Class.vstemplate' 竊・'D:\github\guitarrapc\dotfiles-win\home\Documents\Visual Studio 2022\Templates\ItemTemplates\CSharp\Code\1033\Class\Class.vstemplate'
  [o] 'C:\Users\guitarrapc\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1' 竊・'D:\github\guitarrapc\dotfiles-win\home\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'
  [o] 'C:\Users\guitarrapc\scoop\apps\vscode\current\data\user-data\User\settings.json' 竊・'D:\github\guitarrapc\dotfiles-win\home\scoop\apps\vscode\current\data\user-data\User\settings.json'
```

## C# (artifact)

```shell
あとで書く
```

## C# (Self-compile)

Prepare .NET 9.0 SDK.

```shell
PS> dotnet run --project ./src/DotfilesLinker/DotfilesLinker.csproj
[o] Great, Windows Developer Mode is enabled.
[!] Script is executed without Admin privilege.
[o] 'C:\Users\guitarrapc\.dotfiles_ignore' → 'D:\github\guitarrapc\dotfiles-win\.dotfiles_ignore'
[o] 'C:\Users\guitarrapc\.textlintrc.json' → 'D:\github\guitarrapc\dotfiles-win\.textlintrc.json'
[o] 'C:\Users\guitarrapc\.wslconfig' → 'D:\github\guitarrapc\dotfiles-win\.wslconfig'
[o] 'C:\Users\guitarrapc\.docker\daemon.json' → 'D:\github\guitarrapc\dotfiles-win\home\.docker\daemon.json'
[o] 'C:\Users\guitarrapc\.ssh\config' → 'D:\github\guitarrapc\dotfiles-win\home\.ssh\config'
[o] 'C:\Users\guitarrapc\.config\git\config' → 'D:\github\guitarrapc\dotfiles-win\home\.config\git\config'
[o] 'C:\Users\guitarrapc\.config\git\ignore' → 'D:\github\guitarrapc\dotfiles-win\home\.config\git\ignore'
[o] 'C:\Users\guitarrapc\.ssh\conf.d\aws.conf' → 'D:\github\guitarrapc\dotfiles-win\home\.ssh\conf.d\aws.conf'
[o] 'C:\Users\guitarrapc\.ssh\conf.d\github.conf' → 'D:\github\guitarrapc\dotfiles-win\home\.ssh\conf.d\github.conf'
[o] 'C:\Users\guitarrapc\Documents\PowerShell\Microsoft.PowerShell_profile.ps1' → 'D:\github\guitarrapc\dotfiles-win\home\Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
[o] 'C:\Users\guitarrapc\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1' → 'D:\github\guitarrapc\dotfiles-win\home\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'
[o] 'C:\Users\guitarrapc\AppData\Roaming\Code\User\settings.json' → 'D:\github\guitarrapc\dotfiles-win\home\AppData\Roaming\Code\User\settings.json'
[o] 'C:\Users\guitarrapc\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json' → 'D:\github\guitarrapc\dotfiles-win\home\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
[o] 'C:\Users\guitarrapc\scoop\apps\vscode\current\data\user-data\User\settings.json' → 'D:\github\guitarrapc\dotfiles-win\home\scoop\apps\vscode\current\data\user-data\User\settings.json'
[o] 'C:\Users\guitarrapc\Documents\Visual Studio 2022\Templates\ItemTemplates\CSharp\Code\1033\Class\Class.cs' → 'D:\github\guitarrapc\dotfiles-win\home\Documents\Visual Studio 2022\Templates\ItemTemplates\CSharp\Code\1033\Class\Class.cs'
[o] 'C:\Users\guitarrapc\Documents\Visual Studio 2022\Templates\ItemTemplates\CSharp\Code\1033\Class\Class.vstemplate' → 'D:\github\guitarrapc\dotfiles-win\home\Documents\Visual Studio 2022\Templates\ItemTemplates\CSharp\Code\1033\Class\Class.vstemplate'
[o] All operations completed.
```

## C# AOT (Self-compile)

Prepare .NET 9.0 SDK and C++ compiler.

```shell
PS> dotnet publish
PS> ./src/DotfilesLinker/bin/Release/net8.0/win-x64/publish/DotfilesLinker.exe
[o] Great, Windows Developer Mode is enabled.
[!] Script is executed without Admin privilege.
[o] 'C:\Users\guitarrapc\.dotfiles_ignore' → 'D:\github\guitarrapc\dotfiles-win\.dotfiles_ignore'
[o] 'C:\Users\guitarrapc\.textlintrc.json' → 'D:\github\guitarrapc\dotfiles-win\.textlintrc.json'
[o] 'C:\Users\guitarrapc\.wslconfig' → 'D:\github\guitarrapc\dotfiles-win\.wslconfig'
[o] 'C:\Users\guitarrapc\.docker\daemon.json' → 'D:\github\guitarrapc\dotfiles-win\home\.docker\daemon.json'
[o] 'C:\Users\guitarrapc\.ssh\config' → 'D:\github\guitarrapc\dotfiles-win\home\.ssh\config'
[o] 'C:\Users\guitarrapc\.config\git\config' → 'D:\github\guitarrapc\dotfiles-win\home\.config\git\config'
[o] 'C:\Users\guitarrapc\.config\git\ignore' → 'D:\github\guitarrapc\dotfiles-win\home\.config\git\ignore'
[o] 'C:\Users\guitarrapc\.ssh\conf.d\aws.conf' → 'D:\github\guitarrapc\dotfiles-win\home\.ssh\conf.d\aws.conf'
[o] 'C:\Users\guitarrapc\.ssh\conf.d\github.conf' → 'D:\github\guitarrapc\dotfiles-win\home\.ssh\conf.d\github.conf'
[o] 'C:\Users\guitarrapc\Documents\PowerShell\Microsoft.PowerShell_profile.ps1' → 'D:\github\guitarrapc\dotfiles-win\home\Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
[o] 'C:\Users\guitarrapc\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1' → 'D:\github\guitarrapc\dotfiles-win\home\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'
[o] 'C:\Users\guitarrapc\AppData\Roaming\Code\User\settings.json' → 'D:\github\guitarrapc\dotfiles-win\home\AppData\Roaming\Code\User\settings.json'
[o] 'C:\Users\guitarrapc\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json' → 'D:\github\guitarrapc\dotfiles-win\home\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
[o] 'C:\Users\guitarrapc\scoop\apps\vscode\current\data\user-data\User\settings.json' → 'D:\github\guitarrapc\dotfiles-win\home\scoop\apps\vscode\current\data\user-data\User\settings.json'
[o] 'C:\Users\guitarrapc\Documents\Visual Studio 2022\Templates\ItemTemplates\CSharp\Code\1033\Class\Class.cs' → 'D:\github\guitarrapc\dotfiles-win\home\Documents\Visual Studio 2022\Templates\ItemTemplates\CSharp\Code\1033\Class\Class.cs'
[o] 'C:\Users\guitarrapc\Documents\Visual Studio 2022\Templates\ItemTemplates\CSharp\Code\1033\Class\Class.vstemplate' → 'D:\github\guitarrapc\dotfiles-win\home\Documents\Visual Studio 2022\Templates\ItemTemplates\CSharp\Code\1033\Class\Class.vstemplate'
[o] All operations completed.
```
