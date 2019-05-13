# use mklink + Developer mode on Windows10 can avoid admin elevate issue.
function main() {
    Set-StrictMode -Version Latest

    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (!$currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $me = $MyInvocation.MyCommand
        $myDefinition = (Get-Command $me).Definition
        $myfunction = "function $me { $myDefinition }"

        $cd = (Get-Location).Path
        $commands = "Set-Location $cd; $myfunction; Write-Host 'Running $me'; $me; Pause"
        $bytes = [System.Text.Encoding]::Unicode.GetBytes($commands)
        $encode = [Convert]::ToBase64String($bytes)
        $argumentList = "-NoProfile", "-EncodedCommand", $encode

        Write-Warning "Detected you are not runnning with Admin Priviledge."
        $proceed = Read-Host "Required elevated priviledge to add exlusion to Windows Defender. Do you proceed? (y/n)"
        if ($proceed -ceq "y") {
            $p = Start-Process -Verb RunAs powershell.exe -ArgumentList $argumentList -Wait -PassThru
            return $p.ExitCode
        }
        else {
            Write-Host "Cancel evelated."
            return 1
        }
    }

    $current = $(Get-Location).Path

    # dotfiles
    Get-ChildItem -File -Filter ".*" -Force | 
    ForEach-Object { 
        $sourceFile = $_.FullName
        $targetFile = "$env:UserProfile\$($_.name)"
        cmd.exe /c mklink $targetFile $sourceFile
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
}

main