#requires -version 5.1
# use mklink + Developer mode on Windows10 (and higher) can avoid admin elevate issue.

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, HelpMessage="Force to overwrite existing files.")]
    [ValidateSet("y", "n")]
    [string]$Force
)

Set-StrictMode -Version Latest

function IsDeveloperMode() {
    $val = $(Get-ItemPropertyValue registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock -Name AllowDevelopmentWithoutDevLicense)
    if ($val -eq 1) {
        Write-Host "Great, Windows Developer mode is Enabled."
    } else {
        Write-Host "Windows Developer mode is Disabled, I recommend enable developer mode to avoid symlink restriction." -ForegroundColor Red
    }

    return $val -eq 1
}
function IsEscalated() {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $val = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($val) {
        Write-Host "Script is executed in escalation."
    } else {
        Write-Host "Script is executed in non-escalation."
    }
    return $val
}

function AnswerIsYes($answer) {
    return $answer -eq "y"
}
function AskConfirmation($message) {
    if ($Force -ne "") {
        return $Force
    }
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
    Write-Host "  [x] $message" -ForegroundColor Red
}

function PrintWarning($message) {
    Write-Host "  [!] $message" -ForegroundColor Cyan
}

function PrintQuestion($message) {
    Write-Host "  [?] $message" -ForegroundColor Yellow -NoNewline
}

function PrintSuccess($message) {
    Write-Host "  [o] $message" -ForegroundColor Green
}

function ReadLink($path) {
    return (Get-Item -LiteralPath $path).Target
}

function main() {
    $current = $(Get-Location).Path

    # dotfiles
    $files = Get-ChildItem -File -Filter ".*" -Force | Where-Object Name -notin $(Get-Content .dotfiles_ignore)
    foreach ($file in $files) {
        $sourceFile = $file.FullName
        $targetFile = "$env:UserProfile\$($file.name)"
        if (Test-Path "$targetFile") {
            if ((ReadLink -path $targetFile) -ne "$sourceFile") {
                $answer = AskConfirmation -message "'$targetFile' already exists, do you want to overwrite it?"
                if (AnswerIsYes -answer $answer) {
                    Remove-Item -LiteralPath "$targetFile" -Force > $null
                    Execute -command "cmd.exe /c mklink '$targetFile' '$sourceFile'" -message "'$targetFile' → '$sourceFile'"
                }
                else {
                    PrintError -message "'$targetFile' → '$sourceFile'"
                }
            }
            else {
                PrintSuccess -message "'$targetFile' → '$sourceFile'"
            }
        }
        else {
            Execute -command "cmd.exe /c mklink '$targetFile' '$sourceFile'" -message "'$targetFile' → '$sourceFile'"
        }
    }

    # home
    $files = Get-ChildItem -LiteralPath HOME -Directory -Force
    foreach ($file in $files) {
        $dir_root = $file.FullName

        $dirFiles = Get-ChildItem -LiteralPath "$dir_root" -File -Force -Recurse
        foreach ($dirFile in $dirFiles) {
            $sourceFile = $dirFile.FullName
            $targetFile = $sourceFile.Replace("/HOME", "").Replace("\HOME", "").Replace($current, $env:UserProfile)
            $parentDir = [System.IO.Path]::GetDirectoryName("$targetFile");

            # create folder tree
            if (!(Test-Path -Path "$parentDir"))
            {
                mkdir -Path "$parentDir" -Force > $null
            }

            # synbolic link file
            if (Test-Path -Path "$targetFile") {
                if ((ReadLink -path "$targetFile") -ne "$sourceFile") {
                    $answer = AskConfirmation -message "'$targetFile' already exists, do you want to overwrite it?"
                    if (AnswerIsYes -answer $answer) {
                        Remove-Item -LiteralPath "$targetFile" -Force > $null
                        Execute -command "cmd.exe /c mklink '$targetFile' '$sourceFile'" -message "'$targetFile' → '$sourceFile'"
                    }
                    else {
                        PrintError -message "'$targetFile' → '$sourceFile'"
                    }
                }
                else {
                    PrintSuccess -message "'$targetFile' → '$sourceFile'"
                }
            }
            else {
                Execute -command "cmd.exe /c mklink '$targetFile' '$sourceFile'" -message "$targetFile → $sourceFile"
            }
        }
    }
}

if ((GetOs) -ne "windows") {
    PrintError -message "Please run on Windows."
    exit 1
}

# set XDG_CONFIG_HOME
if ([string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable("XDG_CONFIG_HOME"))) {
    [Environment]::SetEnvironmentVariable("XDG_CONFIG_HOME", "${env:HOME}/.config", [EnvironmentVariableTarget]::User)
}

if (!(IsDeveloperMode -or IsEscalated)) {
    $myfunction = $MyInvocation.InvocationName
    $cd = (Get-Location).Path
    $commands = "Set-Location $cd; $myfunction; Pause"
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($commands)
    $encode = [Convert]::ToBase64String($bytes)
    $argumentList = "-NoProfile", "-ExecutionPolicy RemoteSigned", "-EncodedCommand", $encode

    Write-Warning "Detected you are not runnning with Admin Priviledge."
    $proceed = Read-Host "Required elevated priviledge to make symlink on current Windows. Do you proceed? (y/n)"
    if ($proceed -ceq "y") {
        $p = Start-Process -Verb RunAs powershell.exe -ArgumentList $argumentList -Wait -PassThru
        exit $p.ExitCode
    }
    else {
        Write-Host "Cancel evelated."
        exit 1
    }
}

main
