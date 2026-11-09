param([Parameter(Mandatory=$true)][string]$HomeRoot,[Parameter(Mandatory=$true)][string]$DescriptorPath)
# Internal worker. The launch controller holds the installation lock.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Desktop-Common.ps1')
$state=Read-DesktopState $HomeRoot
$update=Get-Content -Raw -LiteralPath $DescriptorPath | ConvertFrom-Json
$source=Get-DesktopUpdateSource $HomeRoot $update
$state=Install-DesktopVersion -HomeRoot $HomeRoot -Source $source -MatlabExe $state.matlabExe -Cache $state.cache
Write-Output ('UPDATE_COMPLETE=' + $state.current.version)
