param([Parameter(Mandatory=$true)][string]$HomeRoot,[ValidateSet('open','practice','rollback')][string]$Mode='open')
$ErrorActionPreference = 'Stop'
try {
    $homePath = [IO.Path]::GetFullPath($HomeRoot)
    $state = Get-Content -Raw -LiteralPath (Join-Path $homePath 'state.json') | ConvertFrom-Json
    $versionPath = [IO.Path]::GetFullPath($state.current.path)
    if (-not $versionPath.StartsWith((Join-Path $homePath 'versions') + '\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid managed installation path.' }
    & (Join-Path $versionPath 'setup\desktop\Update-Launch.ps1') -HomeRoot $homePath -Mode $Mode
} catch {
    Add-Type -AssemblyName System.Windows.Forms
    [Windows.Forms.MessageBox]::Show("EEGLAB could not open. Please send Matt this message:`n`n$($_.Exception.Message)",'EEGLAB needs help') | Out-Null
    exit 1
}
