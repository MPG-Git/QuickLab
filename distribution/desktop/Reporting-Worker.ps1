param([Parameter(Mandatory=$true)][string]$HomeRoot,[Parameter(Mandatory=$true)][string]$VersionRoot,[int]$MatlabProcessId,[switch]$Once)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
. (Join-Path $PSScriptRoot 'Reporting-Common.ps1')
try {
    $folder=Join-Path $HomeRoot 'reporting'; [IO.Directory]::CreateDirectory($folder) | Out-Null
    if ($Once) { $null=Send-TechnicalReportBatch $HomeRoot $VersionRoot; return }
    $process=Get-Process -Id $MatlabProcessId -ErrorAction Stop
    while (-not $process.HasExited) {
        try { $null=Send-TechnicalReportBatch $HomeRoot $VersionRoot } catch { }
        $null=$process.WaitForExit(60000)
    }
    try { $null=Send-TechnicalReportBatch $HomeRoot $VersionRoot } catch { }
} catch { }
