#Requires -RunAsAdministrator
#Requires -Version 5.1
# One-shot Windows self-hosted runner. Idempotent. See APPLY.md.
[CmdletBinding()]
param(
    [string]$Token = $env:RUNNER_TOKEN,
    [string]$GitHubUrl = $(if ($env:GITHUB_URL) { $env:GITHUB_URL } else { '' }),
    [string]$RunnerName = $(if ($env:RUNNER_NAME) { $env:RUNNER_NAME } else { $env:COMPUTERNAME }),
    [string]$Labels = $(if ($env:RUNNER_LABELS) { $env:RUNNER_LABELS } else { '' }),
    [string]$InstallDir = $(if ($env:RUNNER_DIR) { $env:RUNNER_DIR } else { 'C:\actions-runner' })
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if ($env:DEDICATED_RUNNER -ne '1') {
    throw 'set DEDICATED_RUNNER=1 (this is a dedicated CI host)'
}

$Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$PinsFile = Join-Path $Root 'pins.env'
if (-not (Test-Path $PinsFile)) { throw "missing $PinsFile" }
Get-Content $PinsFile | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
    $k, $v = $_.Split('=', 2)
    Set-Variable -Name $k.Trim() -Value $v.Trim() -Scope Script
}

Write-Output '=== preflight ==='
$preflight = Join-Path $PSScriptRoot 'preflight.ps1'
# Separate process so preflight's `exit` cannot terminate this installer.
$pre = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $preflight -InstallDir $InstallDir
$preCode = $LASTEXITCODE
$pre | ForEach-Object { Write-Output $_ }
$decisionLine = ($pre | Where-Object { $_ -like 'DECISION=*' } | Select-Object -Last 1)
$decision = ''
if ($decisionLine -match '^DECISION=(\S+)') { $decision = $Matches[1] }
if ($decision -eq 'SKIP' -and $env:FORCE -ne '1') {
    Write-Output 'preflight SKIP; nothing to do'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'verify.ps1') -InstallDir $InstallDir
    exit 0
}
if ($decision -eq 'BLOCK' -or $preCode -eq 2) { exit 2 }

if (-not (Test-Path (Join-Path $InstallDir '.runner'))) {
    if (-not $Token) { throw 'set -Token / RUNNER_TOKEN' }
    if (-not $GitHubUrl) { throw 'set -GitHubUrl / GITHUB_URL' }
}

function Add-MachinePath([string]$Directory) {
    $current = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $parts = @($current -split ';' | Where-Object { $_ })
    if ($parts -notcontains $Directory) {
        [Environment]::SetEnvironmentVariable('Path', (($parts + $Directory) -join ';'), 'Machine')
    }
    if ($env:Path -notlike ('*' + $Directory + '*')) {
        $env:Path = $Directory + ';' + $env:Path
    }
}

Write-Output '=== policy / keep-awake ==='
try {
    Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force
} catch {
    Write-Output "Set-ExecutionPolicy warning: $($_.Exception.Message)"
}
$pol = (Get-ExecutionPolicy -List | Where-Object { $_.Scope -eq 'LocalMachine' }).ExecutionPolicy
if ("$pol" -ne 'RemoteSigned') {
    throw "LocalMachine execution policy is $pol, expected RemoteSigned"
}
powercfg /change standby-timeout-ac 0 | Out-Null
powercfg /change hibernate-timeout-ac 0 | Out-Null
powercfg /change disk-timeout-ac 0 | Out-Null
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' `
    -Name LongPathsEnabled -PropertyType DWord -Value 1 -Force | Out-Null
netsh interface 6to4 set state disabled | Out-Null
netsh interface isatap set state disabled | Out-Null
netsh interface teredo set state disabled | Out-Null

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Set-Location $InstallDir

if (-not $RUNNER_VERSION) { throw 'pins.env did not set RUNNER_VERSION' }
$arch = $env:PROCESSOR_ARCHITECTURE
if ($arch -eq 'ARM64') {
    $pkg = "actions-runner-win-arm64-$RUNNER_VERSION.zip"
    $sum = $RUNNER_SHA256_WIN_ARM64
} else {
    $pkg = "actions-runner-win-x64-$RUNNER_VERSION.zip"
    $sum = $RUNNER_SHA256_WIN_X64
}

if (-not (Test-Path (Join-Path $InstallDir 'config.cmd'))) {
    Write-Output "=== download $pkg ==="
    $url = "https://github.com/actions/runner/releases/download/v$RUNNER_VERSION/$pkg"
    $zip = Join-Path $env:TEMP $pkg
    Invoke-WebRequest -Uri $url -OutFile $zip
    $hash = (Get-FileHash -Path $zip -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne $sum.ToLowerInvariant()) {
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
        throw "runner zip SHA256 mismatch: $hash"
    }
    Expand-Archive -Path $zip -DestinationPath $InstallDir -Force
    Remove-Item $zip -Force
}

$gitRoot = Join-Path $InstallDir 'externals\git'
$gitCmd = Join-Path $gitRoot 'cmd'
$gitExe = Join-Path $gitCmd 'git.exe'
if (-not (Test-Path $gitExe)) {
    Write-Output "=== MinGit $MINGIT_VERSION ==="
    $minGitZip = Join-Path $env:TEMP "MinGit-$MINGIT_VERSION-64-bit.zip"
    Invoke-WebRequest -Uri $MINGIT_URL -OutFile $minGitZip
    $hash = (Get-FileHash -Path $minGitZip -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne $MINGIT_SHA256.ToLowerInvariant()) {
        Remove-Item $minGitZip -Force -ErrorAction SilentlyContinue
        throw "MinGit SHA256 mismatch: $hash"
    }
    New-Item -ItemType Directory -Force -Path $gitRoot | Out-Null
    Expand-Archive -Path $minGitZip -DestinationPath $gitRoot -Force
    Remove-Item $minGitZip -Force
}
if (-not (Test-Path $gitExe)) { throw "git.exe missing at $gitExe" }
Add-MachinePath $gitCmd

$configCmd = Join-Path $InstallDir 'config.cmd'
if (-not (Test-Path (Join-Path $InstallDir '.runner'))) {
    Write-Output "=== config.cmd --name $RunnerName ==="
    $cfgArgs = @(
        '--url', $GitHubUrl,
        '--token', $Token,
        '--name', $RunnerName,
        '--work', '_work',
        '--unattended',
        '--runasservice'
    )
    if ($Labels) { $cfgArgs += @('--labels', $Labels) }
    if ($env:FORCE -eq '1') { $cfgArgs += '--replace' }
    $cfg = Start-Process -FilePath $configCmd -ArgumentList $cfgArgs -Wait -PassThru -NoNewWindow
    if ($cfg.ExitCode -ne 0) { throw "config.cmd exited $($cfg.ExitCode)" }
} else {
    Write-Output 'already configured; skip config.cmd'
}

$svcCmd = Join-Path $InstallDir 'svc.cmd'
Write-Output '=== svc.cmd install/start ==='
$install = Start-Process -FilePath $svcCmd -ArgumentList 'install' -Wait -PassThru -NoNewWindow
Write-Output "svc install exit $($install.ExitCode)"
$start = Start-Process -FilePath $svcCmd -ArgumentList 'start' -Wait -PassThru -NoNewWindow
Write-Output "svc start exit $($start.ExitCode)"

$svcName = $null
$svcFile = Join-Path $InstallDir '.service'
if (Test-Path $svcFile) {
    foreach ($line in Get-Content $svcFile) {
        if ($line -match '^name=(.+)$') { $svcName = $Matches[1] }
    }
}
if ($svcName) {
    sc.exe failure $svcName reset= 86400 actions= restart/5000/restart/15000/restart/30000 | Out-Null
}

Write-Output '=== verify ==='
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'verify.ps1') -InstallDir $InstallDir
if ($LASTEXITCODE -ne 0) { throw 'verify failed' }
Write-Output 'INSTALL_OK'
