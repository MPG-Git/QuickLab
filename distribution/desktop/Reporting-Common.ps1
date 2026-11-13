$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Update-Diagnostics.ps1')
function Read-ReportingCatalog([string]$VersionRoot) {
    $file=Join-Path $PSScriptRoot 'diagnostic-sources.json'
    if (-not (Test-Path -LiteralPath $file)) { $file=Join-Path $VersionRoot 'diagnostic-sources.json' }
    return Get-Content -Raw -LiteralPath $file | ConvertFrom-Json
}

function Test-ReportingConsent([string]$HomeRoot) {
    try {
        $p=Get-Content -Raw -LiteralPath (Join-Path $HomeRoot 'reporting\preferences.json') | ConvertFrom-Json
        return ($p.enabled -is [bool] -and $p.enabled -and $p.privacyVersion -eq 1)
    } catch { return $false }
}
function Test-TechnicalReport($Report,$Catalog) {
    try {
        if ($Report.release -cne $Catalog.release) {
            $Catalog=@($Catalog.previous | Where-Object {$_.release -ceq $Report.release}) | Select-Object -First 1
            if (-not $Catalog) { return $false }
        }
        $expected=@('context','errorCode','eventId','frames','matlabRelease','observedAt','release','schemaVersion')
        if ($Report.schemaVersion -eq 2) { $expected+=@('update'); $expected=@($expected | Sort-Object) }
        if (@(Compare-Object @($Report.PSObject.Properties.Name | Sort-Object) $expected).Count) { return $false }
        if ($Report.schemaVersion -notin @(1,2) -or $Report.release -cne $Catalog.release) { return $false }
        if ($Report.eventId -cnotmatch '^[a-f0-9]{32}$' -or $Report.observedAt -cnotmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$' -or ($Report.matlabRelease -cnotmatch '^\d{4}[ab]$' -and -not ($Report.schemaVersion -eq 2 -and $Report.matlabRelease -ceq 'unknown'))) { return $false }
        if ($Report.schemaVersion -eq 2 -and ($Report.context -cnotin @('update','validation') -or -not (Test-UpdateDetail $Report.update $Catalog))) { return $false }
        if ($Report.context -cnotin @('startup','practice','runtime','update','validation')) { return $false }
        if ($Report.errorCode -isnot [ValueType] -or $Report.errorCode -lt 0 -or $Report.errorCode -gt 22 -or $Report.errorCode -ne [math]::Floor($Report.errorCode)) { return $false }
        if ($Report.frames -isnot [Array] -or $Report.frames.Count -gt 8) { return $false }
        foreach ($frame in $Report.frames) {
            if (@(Compare-Object @($frame.PSObject.Properties.Name | Sort-Object) @('line','sourceId')).Count) { return $false }
            if ($frame.sourceId -cnotmatch '^[a-f0-9]{32}$' -or -not $Catalog.sources.PSObject.Properties['s'+$frame.sourceId]) { return $false }
            if ($frame.line -isnot [ValueType] -or $frame.line -lt 1 -or $frame.line -gt 1000000 -or $frame.line -ne [math]::Floor($frame.line)) { return $false }
        }
        return $true
    } catch { return $false }
}
function Write-DesktopDiagnostic([string]$HomeRoot,[string]$VersionRoot,[string]$Context,[int]$Code,$Detail=$null,[switch]$PassThru) {
    try {
        if ($Context -cnotin @('update','validation') -or $Code -notin @(20,21,22)) { return }
        $catalog=Read-ReportingCatalog $VersionRoot
        $release=(Get-Content -Raw -LiteralPath (Join-Path $VersionRoot 'diagnostic-sources.json') | ConvertFrom-Json).release
        $validation=$null
        try { $validation=Get-Content -Raw -LiteralPath (Join-Path $VersionRoot 'desktop_validation.json') | ConvertFrom-Json } catch { }
        $matlabRelease='unknown'; if ($validation.matlab -match '\(R(\d{4}[ab])\b') { $matlabRelease=$Matches[1] }
        $r=[pscustomobject]@{schemaVersion=1;eventId=[guid]::NewGuid().ToString('N');observedAt=[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ');release=$release;matlabRelease=$matlabRelease;context=$Context;errorCode=$Code;frames=@()}
        if ($Detail) {
            if ($validation.matlab -match '^(\d+(\.\d+){1,4})') { $Detail.environment.matlabVersion=$Matches[1] }
            try { $drive=New-Object IO.DriveInfo([IO.Path]::GetPathRoot($VersionRoot)); $Detail.environment.freeDiskMB=[math]::Floor($drive.AvailableFreeSpace/1MB) } catch { }
            $r.schemaVersion=2; $r | Add-Member -NotePropertyName update -NotePropertyValue $Detail
        }
        if (-not (Test-TechnicalReport $r $catalog)) { return }
        $targets=@('history'); if (Test-ReportingConsent $HomeRoot) { $targets+='queue' }
        foreach ($target in $targets) {
            $folder=Join-Path $HomeRoot ('reporting\'+$target); [IO.Directory]::CreateDirectory($folder) | Out-Null
            $files=@(Get-ChildItem -LiteralPath $folder -Filter 'report-*.json' -File | Sort-Object LastWriteTimeUtc)
            for ($i=0;$i -lt $files.Count;$i++) {
                if ($i -lt $files.Count-99 -or $files[$i].LastWriteTimeUtc -lt [DateTime]::UtcNow.AddDays(-30)) { Remove-Item -LiteralPath $files[$i].FullName }
            }
            $file=Join-Path $folder ('report-'+$r.eventId+'.json'); $tmp=$file+'.tmp'
            [IO.File]::WriteAllText($tmp,($r | ConvertTo-Json -Depth 8 -Compress),(New-Object Text.UTF8Encoding($false)))
            [IO.File]::Move($tmp,$file)
        }
        if ($PassThru) { return $r.eventId }
    } catch { } # Never interrupt startup or the updater.
}
function Send-TechnicalReportBatch([string]$HomeRoot,[string]$VersionRoot) {
    if (-not (Test-ReportingConsent $HomeRoot)) { return 0 }
    $lock=$null
    try {
        $lock=[IO.File]::Open((Join-Path $HomeRoot 'reporting\sender.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
        return Send-TechnicalReportBatchUnlocked $HomeRoot $VersionRoot
    } catch { return 0 } finally { if ($lock) { $lock.Dispose() } }
}
function Send-TechnicalReportBatchUnlocked([string]$HomeRoot,[string]$VersionRoot) {
    $sent=0
    if (-not (Test-ReportingConsent $HomeRoot)) { return $sent }
    $config=Get-Content -Raw -LiteralPath (Join-Path $VersionRoot 'setup\desktop\reporting.json') | ConvertFrom-Json
    # Only the release-pinned Supabase endpoint is eligible. Redirects are forbidden.
    if ($config.endpoint -cnotmatch '^https://[a-z0-9]{20}\.supabase\.co/functions/v1/eeglab-reports/report$' -or $config.privacyVersion -ne 1) { return $sent }
    $catalog=Read-ReportingCatalog $VersionRoot
    $queue=Join-Path $HomeRoot 'reporting\queue'
    if (-not (Test-Path -LiteralPath $queue)) { return $sent }
    foreach ($file in @(Get-ChildItem -LiteralPath $queue -Filter 'report-*.json' -File | Sort-Object LastWriteTimeUtc | Select-Object -First 10)) {
        if (-not (Test-ReportingConsent $HomeRoot)) { break }
        if ($file.LastWriteTimeUtc -lt [DateTime]::UtcNow.AddDays(-30)) { Remove-Item -LiteralPath $file.FullName; continue }
        if ($file.Length -gt 8192) { continue }
        try {
            $report=Get-Content -Raw -LiteralPath $file.FullName | ConvertFrom-Json
            if (-not (Test-TechnicalReport $report $catalog)) { continue }
            $body=$report | ConvertTo-Json -Depth 5 -Compress
            $response=Invoke-RestMethod -Method Post -Uri $config.endpoint -ContentType 'application/json' -Body ([Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 10 -MaximumRedirection 0
            if ($response.accepted -is [bool] -and $response.accepted) { Remove-Item -LiteralPath $file.FullName; $sent++ }
            else { break }
        } catch { break } # Offline, throttled or unavailable: leave the queue for retry.
    }
    return $sent
}
