param([Parameter(Mandatory=$true)][string]$HomeRoot,[Parameter(Mandatory=$true)][string]$DescriptorPath)
# Internal worker. The launch controller holds the installation lock.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Desktop-Common.ps1')
$state=Read-DesktopState $HomeRoot
$update=Get-Content -Raw -LiteralPath $DescriptorPath | ConvertFrom-Json
$detail=New-UpdateDetail $update.version
try {
    $source=Get-DesktopUpdateSource $HomeRoot $update -Diagnostic $detail
    $state=Install-DesktopVersion -HomeRoot $HomeRoot -Source $source -MatlabExe $state.matlabExe -Cache $state.cache -Diagnostic $detail
    Write-Output ('UPDATE_COMPLETE=' + $state.current.version)
} catch {
    $detail=Get-UpdateFailureDetail $_ $detail
    $reportId=Write-DesktopDiagnostic $HomeRoot $state.current.path 'update' 21 $detail -PassThru
    if ($reportId) { try { [IO.File]::WriteAllText(($DescriptorPath+'.reported'),$reportId) } catch { } }
    Start-UpdateReportSender $HomeRoot $state.current.path
    throw
}
