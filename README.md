dotfiles-win

## Preprequisites

* Enable Windows Developer Mode to allow Symlink without UAC Admin Escalation, also allow PowerShell Script execution.

## Run

* `./install.ps1` to setup symlink

```shell
PS> .\install.ps1
Windows Developer mode is Enabled.
  [o] C:\Users\guitarrapc\.gitconfig → C:\git\guitarrapc\dotfiles-win\.gitconfig
  [o] C:\Users\guitarrapc\.gitignore_global → C:\git\guitarrapc\dotfiles-win\.gitignore_global
  [o] C:\Users\guitarrapc\.profile → C:\git\guitarrapc\dotfiles-win\.profile
  [o] C:\Users\guitarrapc\.wslconfig → C:\git\guitarrapc\dotfiles-win\.wslconfig
  [o] C:\Users\guitarrapc\.docker\daemon.json → C:\git\guitarrapc\dotfiles-win\home\.docker\daemon.json
  [o] C:\Users\guitarrapc\.ssh\config → C:\git\guitarrapc\dotfiles-win\home\.ssh\config
  [o] C:\Users\guitarrapc\AppData\Roaming\Code\User\settings.json → C:\git\guitarrapc\dotfiles-win\home\AppData\Roaming\Code\User\settings.json
```
