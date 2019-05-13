# use mklink + Developer mode on Windows10 can avoid admin elevate issue.

function AnswerIsYes($answer) {
    return $answer -eq "y"
}
function AskConfirmation($message) {
    PrintQuestion -message "$message (y/n) "
    $result = Read-Host
    return $result
}

function Execute($command, $message) {
    Invoke-Expression -Command "$command" > $null
    PrintResult -success $? -message $message
}

function GetOs() {
    $os = "windows"
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        if ($PSVersionTable.OS -match "Darwin") {
            $os = "osx"
        }
        elseif ($PSVersionTable.OS -match "Linux") {
            $os = "linux"
        }
        else {
            $os = "windows"
        }
    }
    return $os
}

function PrintResult([bool]$success, $message) {
    if ($success) {
        PrintSuccess -message $message
    }
    else {
        PrintError -message $message
        exit 1
    }
}

function PrintError($message) {
    Write-Host "  [✖] $message" -ForegroundColor Red
}

function PrintQuestion($message) {
    Write-Host "  [?] $message" -ForegroundColor Yellow -NoNewline
}

function PrintSuccess($message) {
    Write-Host "  [✔] $message" -ForegroundColor Green
}

function ReadLink($path) {
    return (Get-Item -LiteralPath $path).Target
}
function main() {
    Set-StrictMode -Version Latest
    if (GetOs -ne "windows") {
        PrintError -message "Please run on Windows."
        exit 1
    }
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
        if (Test-Path "$targetFile") {
            if ((ReadLink -path $targetFile) -ne $sourceFile) {
                $answer = AskConfirmation -message "'$targetFile' already exists, do you want to overwrite it?"
                if (AnswerIsYes -answer $answer) {
                    Remove-Item -LiteralPath "$targetFile" -Force > $null
                    Execute -command "cmd.exe /c mklink '$targetFile' '$sourceFile'" -message "$targetFile → $sourceFile"
                }
                else {
                    PrintError -message "$targetFile → $sourceFile"
                }
            }
            else {
                PrintSuccess -message "$targetFile → $sourceFile"
            }
        }
        else {
            Execute -command "cmd.exe /c mklink '$targetFile' '$sourceFile'" -message "$targetFile → $sourceFile"
        }
    }

    # home
    Get-ChildItem -LiteralPath home -Directory -Force | 
    ForEach-Object {
        $dir_root = $_.FullName

        # create folder tree
        $targetFolder = $dir_root.Replace("/home", "").Replace("\home", "").Replace($current, $env:UserProfile)
        if (!(Test-Path -LiteralPath "$targetFolder")) {
            mkdir -LiteralPath "$targetFolder" -Force
        }
        Get-ChildItem -LiteralPath $dir_root -Directory -Recurse |
        ForEach-Object {
            $targetFolder = $dir_root.Replace("/home", "").Replace("\home", "").Replace($current, $env:UserProfile)
            if (!(Test-Path -LiteralPath "$targetFolder")) {
                mkdir -LiteralPath "$targetFolder" -Force
            }
        }

        # synlink files
        Get-ChildItem -LiteralPath $dir_root -File -Force -Recurse |
        ForEach-Object {
            $sourceFile = $_.FullName
            $targetFile = $sourceFile.Replace("/home", "").Replace("\home", "").Replace($current, $env:UserProfile)
            if (Test-Path -Path $targetFile) {
                if ((ReadLink -path "$targetFile") -ne $sourceFile) {
                    $answer = AskConfirmation -message "'$targetFile' already exists, do you want to overwrite it?"
                    if (AnswerIsYes -answer $answer) {
                        Remove-Item -LiteralPath "$targetFile" -Force > $null
                        Execute -command "cmd.exe /c mklink '$targetFile' '$sourceFile'" -message "$targetFile → $sourceFile"
                    }
                    else {
                        PrintError -message "$targetFile → $sourceFile"
                    }
                }
                else {
                    PrintSuccess -message "$targetFile → $sourceFile"
                }
            }
            else {
                Execute -command "cmd.exe /c mklink '$targetFile' '$sourceFile'" -message "$targetFile → $sourceFile"
            }
        }
    }
}

main