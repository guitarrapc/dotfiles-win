# use mklink + Developer mode on Windows10 can avoid admin elevate issue.

Set-StrictMode -Version Latest
$current = $(PWD).Path

# dotfiles
Get-ChildItem -File -Filter ".*" -Force | 
    ForEach-Object { 
        cmd.exe /c mklink "$env:UserProfile\$($_.name)" $_.FullName 
        if ($?) {
            "$targetFile → $sourceFile"
        }
    }

# folder
Get-ChildItem -Directory -Exclude exclude, wsl,.git -Force | 
    ForEach-Object {
        $dir_root = $_.FullName

        # create folder tree
        $targetFolder = $dir_root.Replace($current, $env:UserProfile)
        if (!(Test-Path -Path $targetFolder)) {
            mkdir -Path $targetFolder
        }
        Get-ChildItem -LiteralPath $dir_root -Directory -Recurse |
            ForEach-Object {
                $targetFolder = $dir_root.Replace($current, $env:UserProfile)
                if (!(Test-Path -Path $targetFolder)) {
                    mkdir -Path $targetFolder
                }
            }

        # synlink files
        Get-ChildItem -LiteralPath $dir_root -File -Force -Recurse |
            ForEach-Object {
                $sourceFile = $_.FullName
                $targetFile = $sourceFile.Replace($current, $env:UserProfile)
                if (!(Test-Path -Path $targetFile)) {
                    cmd.exe /c mklink "$targetFile" "$sourceFile"
                    if ($?) {
                        "$targetFile → $sourceFile"
                    }
                }
            }
    }
