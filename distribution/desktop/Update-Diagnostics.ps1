# Update diagnostics are structured facts, never excerpts from logs or messages.
function New-UpdateDetail([string]$TargetVersion='unknown') {
    if ($TargetVersion -cnotmatch '^\d+\.\d+\.\d+$') { $TargetVersion='unknown' }
    return [pscustomobject]@{targetVersion=$TargetVersion;stage='worker';component='desktop';reason='unknown';httpStatus=0;exitCode=0;systemCode=0;source='';line=0;pluginFailures=@();matlabIdentifier='';startupSignals=@();environment=[pscustomobject]@{matlabVersion='unknown';windowsVersion=[Environment]::OSVersion.Version.ToString();powershellVersion=$PSVersionTable.PSVersion.ToString();architecture=$(if([Environment]::Is64BitProcess){'x64'}else{'x86'});freeDiskMB=-1}}
}
function Read-MatlabStartupSignals([string]$Log) {
    # Inspect only a bounded local tail. Return fixed labels, never log text.
    try {
        $stream=[IO.File]::Open($Log,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
        try {
            $null=$stream.Seek([math]::Max(0,$stream.Length-65536),[IO.SeekOrigin]::Begin)
            $reader=New-Object IO.StreamReader($stream); $tail=$reader.ReadToEnd(); $reader.Dispose()
        } finally { $stream.Dispose() }
        $patterns=[ordered]@{'license-failure'='License checkout failed|License Manager Error|Unable to check out a license';'matlab-crash'='MATLAB crash dump|Segmentation violation|Fatal Internal Error';'missing-library'='specified module could not be found|cannot open shared object file';'invalid-mex'='Invalid MEX-file';'missing-validation-function'="Unrecognized function or variable 'validate_desktop_update'|Undefined function.*validate_desktop_update";'out-of-memory'='Out of memory|Not enough memory'}
        foreach ($key in $patterns.Keys) { if ($tail -match $patterns[$key]) { Write-Output $key } }
    } catch { }
}
function Set-UpdateStage($Detail,[string]$Stage,[string]$Component='desktop') {
    if ($Detail) { $Detail.stage=$Stage; $Detail.component=$Component; $Detail.reason='unknown' }
}
function Get-UpdateFailureDetail($ErrorRecord,$Detail) {
    # Only numeric OS/HTTP codes and predefined categories leave this process.
    $exception=$ErrorRecord.Exception
    for ($i=0;$exception -and $i -lt 8;$i++) {
        if ($exception.HResult) { $Detail.systemCode=[long]$exception.HResult }
        if ($exception.Response -and $exception.Response.StatusCode) { $Detail.httpStatus=[int]$exception.Response.StatusCode; $Detail.reason='http' }
        if ($exception -is [Net.WebException]) {
            switch ($exception.Status.ToString()) {
                'Timeout' { $Detail.reason='timeout' }
                'TrustFailure' { $Detail.reason='tls' }
                'SecureChannelFailure' { $Detail.reason='tls' }
                'NameResolutionFailure' { $Detail.reason='network' }
                'ConnectFailure' { $Detail.reason='network' }
            }
        }
        if ($exception -is [UnauthorizedAccessException]) { $Detail.reason='access-denied' }
        if ($exception -is [IO.PathTooLongException]) { $Detail.reason='path-too-long' }
        if ($exception -is [IO.InvalidDataException]) { $Detail.reason='archive-invalid' }
        switch ($exception.HResult -band 65535) { 112 { $Detail.reason='disk-full' }; 32 { $Detail.reason='file-in-use' } }
        $exception=$exception.InnerException
    }
    $name=[IO.Path]::GetFileName($ErrorRecord.InvocationInfo.ScriptName)
    if ($name -cin @('Desktop-Common.ps1','Install-EEGLAB.ps1','Apply-DesktopUpdate.ps1','Update-Launch.ps1','Complete-DesktopSetup.ps1')) {
        $Detail.source=$name; $Detail.line=[int]$ErrorRecord.InvocationInfo.ScriptLineNumber
    }
    return $Detail
}
function Test-UpdateDetail($Detail,$Catalog) {
    try {
        $keys=@('component','environment','exitCode','httpStatus','line','matlabIdentifier','pluginFailures','reason','source','stage','startupSignals','systemCode','targetVersion')
        if (@(Compare-Object @($Detail.PSObject.Properties.Name | Sort-Object) $keys).Count) { return $false }
        if ($Detail.targetVersion -cnotmatch '^(unknown|\d+\.\d+\.\d+)$' -or $Detail.targetVersion.Length -gt 32) { return $false }
        if ($Detail.stage -cnotin @('check','download','integrity','extract','install','startup','validation','practice','activate','worker')) { return $false }
        if ($Detail.reason -cnotin @('unknown','network','http','tls','timeout','hash-mismatch','archive-invalid','access-denied','disk-full','path-too-long','file-in-use','matlab-launch','matlab-exit','validation-failed','metadata-invalid','source-missing')) { return $false }
        if ($Detail.component -cnotin $Catalog.components) { return $false }
        if ($Detail.matlabIdentifier -cne '' -and $Detail.matlabIdentifier -cnotin $Catalog.identifiers) { return $false }
        if ($Detail.startupSignals -isnot [Array] -or $Detail.startupSignals.Count -gt 6) { return $false }
        foreach($signal in $Detail.startupSignals) { if($signal -cnotin @('license-failure','matlab-crash','missing-library','invalid-mex','missing-validation-function','out-of-memory')){return $false} }
        $e=$Detail.environment
        if (@(Compare-Object @($e.PSObject.Properties.Name | Sort-Object) @('architecture','freeDiskMB','matlabVersion','powershellVersion','windowsVersion')).Count) { return $false }
        foreach($key in @('matlabVersion','windowsVersion','powershellVersion')) { if($e.$key -cnotmatch '^(unknown|\d+(\.\d+){1,4})$' -or $e.$key.Length -gt 40){return $false} }
        if($e.architecture -cnotin @('x64','x86','arm64','unknown') -or $e.freeDiskMB -isnot [ValueType] -or $e.freeDiskMB -is [bool] -or $e.freeDiskMB -ne [math]::Floor($e.freeDiskMB) -or $e.freeDiskMB -lt -1 -or $e.freeDiskMB -gt 1000000000){return $false}
        foreach ($key in @('httpStatus','exitCode','systemCode','line')) {
            $n=$Detail.$key
            if ($n -isnot [ValueType] -or $n -is [bool] -or $n -ne [math]::Floor($n)) { return $false }
        }
        if (($Detail.httpStatus -ne 0 -and ($Detail.httpStatus -lt 100 -or $Detail.httpStatus -gt 599)) -or $Detail.exitCode -lt -2147483648 -or $Detail.exitCode -gt 2147483647 -or $Detail.systemCode -lt -2147483648 -or $Detail.systemCode -gt 2147483647 -or $Detail.line -lt 0 -or $Detail.line -gt 1000000) { return $false }
        if ($Detail.source -cnotin @('','Desktop-Common.ps1','Install-EEGLAB.ps1','Apply-DesktopUpdate.ps1','Update-Launch.ps1','Complete-DesktopSetup.ps1')) { return $false }
        if ($Detail.pluginFailures -isnot [Array] -or $Detail.pluginFailures.Count -gt 60) { return $false }
        foreach ($p in $Detail.pluginFailures) {
            if (@(Compare-Object @($p.PSObject.Properties.Name | Sort-Object) @('component','reason')).Count -or $p.component -cnotin $Catalog.components -or $p.reason -cnotin @('missing','unregistered','startup','version')) { return $false }
        }
        return $true
    } catch { return $false }
}
function Start-UpdateReportSender([string]$HomeRoot,[string]$VersionRoot) {
    if (-not (Test-ReportingConsent $HomeRoot)) { return }
    try {
        $worker=Join-Path $PSScriptRoot 'Reporting-Worker.ps1'
        $arguments='-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$worker+'" -HomeRoot "'+$HomeRoot+'" -VersionRoot "'+$VersionRoot+'" -Once'
        Start-Process -FilePath (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe') -ArgumentList $arguments -WindowStyle Hidden | Out-Null
    } catch { } # Queued reports retry on the next normal launch.
}
