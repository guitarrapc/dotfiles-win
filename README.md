# dotfiles-win

## Prerequisites

* Enable Windows Developer Mode to allow Symlink without UAC Admin Escalation, also allow PowerShell Script execution.

## Run

You have two options to link your dotfiles:

### (Recommended) scoop install [DotfilesLinker](https://github.com/guitarrapc/DotfilesLinker) or [dotfileslinker-go](https://github.com/guitarrapc/dotfileslinker-go).

DotfilesLinker is C# version, and dotfileslinker-go is Go version. You can choose any of them and works the same.

```shell
# C# DotfilesLinker
$ scoop bucket add guitarrapc https://github.com/guitarrapc/scoop-bucket.git
$ scoop install dotfileslinker
$ dotfileslinker

# Go dotfileslinker-go
$ scoop bucket add guitarrapc https://github.com/guitarrapc/scoop-bucket.git
$ scoop install dotfileslinker-go
$ dotfileslinker
```

### Run `./install.ps1` to setup symlink

This script will not be maintained, but you can still use it to setup your dotfiles.

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

## Codex skills

`HOME/.agents/skills` contains the user-level Codex skills. The repository-root
`dotfiles_link_dirs` selects each skill directory for linking to
`~/.agents/skills/<skill-name>` as a whole, so `SKILL.md` remains a regular file.

Use a version of DotfilesLinker or dotfileslinker-go that supports
`dotfiles_link_dirs`; older binaries and the legacy install scripts do not
apply this setting. From this repository root, preview and then apply:

```shell
dotfileslinker --dry-run --force
dotfileslinker --force
```

`--force` is needed when replacing existing directories containing file-level
links. It replaces existing destinations, so preserve any local-only files first.
