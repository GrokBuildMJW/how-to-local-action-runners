#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$InstallDir = $(if ($env:RUNNER_DIR) { $env:RUNNER_DIR } else { 'C:\actions-runner' })
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Emit([string]$K, [string]$V) { Write-Output ('{0}={1}' -f $K, $V) }
function Decide([string]$D, [string]$Reason = '') {
    if ($Reason) { Write-Output ('DECISION={0} reason={1}' -f $D, $Reason) }
    else { Write-Output ('DECISION={0}' -f $D) }
    if ($D -eq 'BLOCK') { exit 2 }
    exit 0
}

$os = [System.Environment]::OSVersion.Platform
Emit 'os' $(if ($os -eq 'Win32NT') { 'windows' } else { "$os" })
Emit 'arch' $env:PROCESSOR_ARCHITECTURE
Emit 'dedicated' $(if ($env:DEDICATED_RUNNER -eq '1') { '1' } else { '0' })
Emit 'install_dir' $InstallDir

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
Emit 'elevated' $(if ($admin) { 'true' } else { 'false' })

if ($os -ne 'Win32NT') { Decide 'BLOCK' 'not_windows' }
if (-not $admin) { Decide 'BLOCK' 'not_elevated' }
if ($env:DEDICATED_RUNNER -ne '1') { Decide 'SKIP' 'not_dedicated_host' }

$listeners = @(Get-Process -Name 'Runner.Listener' -ErrorAction SilentlyContinue)
Emit 'listeners' "$($listeners.Count)"
$already = Test-Path (Join-Path $InstallDir '.runner')
Emit 'already_configured' $(if ($already) { 'true' } else { 'false' })

if ($already -and $listeners.Count -ge 1 -and $env:FORCE -ne '1') {
    Decide 'SKIP' 'already_configured'
}
if ($listeners.Count -ge 1 -and -not $already) {
    Decide 'BLOCK' 'listener_conflict'
}
if ($listeners.Count -ge 2) {
    Decide 'BLOCK' 'listener_conflict'
}

Decide 'APPLY'
