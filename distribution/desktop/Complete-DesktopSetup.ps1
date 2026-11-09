[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$MatlabExe,
    [Parameter(Mandatory=$true)][string]$LauncherExe,
    [string]$Destination = (Join-Path $env:LOCALAPPDATA 'MPG\EEGLAB'),
    [string]$Cache = (Join-Path $env:LOCALAPPDATA 'EEGLAB-download-cache'),
    [string]$Desktop = [Environment]::GetFolderPath('Desktop'),
    [switch]$NoOpen
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'Desktop-Common.ps1')
$homeRoot = [IO.Path]::GetFullPath($Destination)
$lock = Open-DesktopLock $homeRoot
try {
    $state = Install-DesktopVersion -HomeRoot $homeRoot -Source (Split-Path -Parent $PSScriptRoot) -MatlabExe $MatlabExe -Cache $Cache
    $launcherPath = Join-Path $homeRoot 'EEGLABLauncher.exe'
    if (-not (Test-Path -LiteralPath $launcherPath)) { Copy-Item -LiteralPath $LauncherExe -Destination $launcherPath }
    $shim = Join-Path $homeRoot 'Launch-EEGLAB.ps1'
    if (-not (Test-Path -LiteralPath $shim)) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Launch-EEGLAB.ps1') -Destination $shim }
    New-DesktopShortcuts -HomeRoot $homeRoot -Desktop $Desktop -MatlabExe $MatlabExe
    Write-Output 'Installed. Use EEGLAB 2026 or EEGLAB Practice on your desktop.'
    if (-not $NoOpen) { Start-DesktopMatlab $state 'open' }
    Write-Output ('SETUP_COMPLETE=' + $state.current.path)
} finally { $lock.Dispose() }
