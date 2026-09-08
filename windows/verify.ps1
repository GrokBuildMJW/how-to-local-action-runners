#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$InstallDir = $(if ($env:RUNNER_DIR) { $env:RUNNER_DIR } else { 'C:\actions-runner' })
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$fail = 0
function Ok([string]$M) { Write-Output "ok: $M" }
function Bad([string]$M) { Write-Error "FAIL: $M"; $script:fail = 1 }

if (Test-Path (Join-Path $InstallDir '.runner')) { Ok "registration $InstallDir\.runner" } else { Bad "missing $InstallDir\.runner" }
if (Test-Path (Join-Path $InstallDir 'config.cmd')) { Ok 'runner binaries' } else { Bad 'missing config.cmd' }

$listeners = @(Get-Process -Name 'Runner.Listener' -ErrorAction SilentlyContinue)
if ($listeners.Count -eq 1) { Ok 'exactly one Runner.Listener' } else { Bad "expected 1 Runner.Listener, have $($listeners.Count)" }

$git = Join-Path $InstallDir 'externals\git\cmd\git.exe'
if (Test-Path $git) {
    Ok "MinGit $(& $git --version)"
} else {
    Bad "missing $git"
}

$pol = (Get-ExecutionPolicy -List | Where-Object { $_.Scope -eq 'LocalMachine' }).ExecutionPolicy
if ("$pol" -eq 'RemoteSigned') { Ok 'LocalMachine RemoteSigned' } else { Bad "LocalMachine ExecutionPolicy is $pol, want RemoteSigned" }

$svcFile = Join-Path $InstallDir '.service'
if (Test-Path $svcFile) {
    $svcName = $null
    foreach ($line in Get-Content $svcFile) {
        if ($line -match '^name=(.+)$') { $svcName = $Matches[1] }
    }
    if ($svcName) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq 'Running') { Ok "service $svcName Running" } else { Bad "service $svcName not Running" }
    } else {
        Bad '.service has no name='
    }
} else {
    Bad 'missing .service'
}

$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$gitCmd = Join-Path $InstallDir 'externals\git\cmd'
if ($machinePath -like "*$gitCmd*") { Ok 'git cmd on Machine PATH' } else { Bad 'git cmd not on Machine PATH' }

if ($fail -ne 0) {
    Write-Output 'VERIFY_FAIL'
    exit 1
}
Write-Output 'VERIFY_OK'
