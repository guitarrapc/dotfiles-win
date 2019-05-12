# use mklink + Developer mode on Windows10 can avoid admin elevate issue.

Set-StrictMode -Version Latest
$current = $(Get-Location).Path

# dotfiles
Get-ChildItem -File -Filter ".*" -Force | 
ForEach-Object { 
    cmd.exe /c mklink "$env:UserProfile\$($_.name)" $_.FullName 
    if ($?) {
        "$targetFile → $sourceFile"
    }
}

# home
Get-ChildItem -LiteralPath home -Directory -Force | 
ForEach-Object {
    $dir_root = $_.FullName

    # create folder tree
    $targetFolder = $dir_root.Replace("/home", "").Replace("\home", "").Replace($current, $env:UserProfile)
    if (!(Test-Path -Path $targetFolder)) {
        mkdir -Path $targetFolder
    }
    Get-ChildItem -LiteralPath $dir_root -Directory -Recurse |
    ForEach-Object {
        $targetFolder = $dir_root.Replace("/home", "").Replace("\home", "").Replace($current, $env:UserProfile)
        if (!(Test-Path -Path $targetFolder)) {
            mkdir -Path $targetFolder
        }
    }

    # synlink files
    Get-ChildItem -LiteralPath $dir_root -File -Force -Recurse |
    ForEach-Object {
        $sourceFile = $_.FullName
        $targetFile = $sourceFile.Replace("/home", "").Replace("\home", "").Replace($current, $env:UserProfile)
        if (!(Test-Path -Path $targetFile)) {
            cmd.exe /c mklink "$targetFile" "$sourceFile"
            if ($?) {
                "$targetFile → $sourceFile"
            }
        }
    }
}
