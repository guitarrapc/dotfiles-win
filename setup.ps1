# use mklink + Developer mode on Windows10 can avoid admin elevate issue.

Set-StrictMode -Version Latest

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
    Write-Host "  [x] $message" -ForegroundColor Red
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
    Get-ChildItem -File -Filter ".*" -Force | Where-Object Name -notin @(".gitignore") |
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

if ((GetOs) -ne "windows") {
    PrintError -message "Please run on Windows."
    exit 1
}

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (!$currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
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