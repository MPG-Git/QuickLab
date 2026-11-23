param([Parameter(Mandatory=$true)][string]$HomeRoot,[Parameter(Mandatory=$true)][string]$ResultPath)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Desktop-Common.ps1')
try {
    $state=Read-DesktopState $HomeRoot
    if (-not $state) { throw 'The managed installation is missing.' }
    $result=[pscustomobject]@{status='checked';update=(Get-DesktopUpdate $state)}
} catch {
    $detail=New-UpdateDetail; Set-UpdateStage $detail 'check'
    $result=[pscustomobject]@{status='unavailable';detail=(Get-UpdateFailureDetail $_ $detail)}
}
[IO.File]::WriteAllText($ResultPath,($result | ConvertTo-Json -Depth 8),(New-Object Text.UTF8Encoding($false)))
