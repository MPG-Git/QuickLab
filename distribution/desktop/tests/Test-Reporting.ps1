param([string]$OutputDirectory=(Join-Path $env:TEMP ('eeglab-report-tests-'+[guid]::NewGuid().ToString('N'))))
$ErrorActionPreference='Stop'
$helpers=Join-Path $OutputDirectory 'helpers'; [IO.Directory]::CreateDirectory($helpers) | Out-Null
foreach($name in @('Reporting-Common.ps1','Update-Diagnostics.ps1')) { Copy-Item -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) $name) -Destination $helpers }
. (Join-Path $helpers 'Reporting-Common.ps1')
$passed=New-Object 'Collections.Generic.List[string]'
function Check([bool]$ok,[string]$name){if(-not $ok){throw $name};$passed.Add($name)}
$homeRoot=Join-Path $OutputDirectory 'managed';$versionRoot=Join-Path $homeRoot 'versions\fixture';$reportRoot=Join-Path $homeRoot 'reporting';$queue=Join-Path $reportRoot 'queue'
[IO.Directory]::CreateDirectory((Join-Path $versionRoot 'setup\desktop')) | Out-Null
[IO.Directory]::CreateDirectory($queue) | Out-Null
$sourceId='a'*32
$catalog=[pscustomobject]@{release='1.1.0';components=@('desktop','EEGLAB','QuickLab');sources=[pscustomobject]@{('s'+$sourceId)='eeglab2026.1.0/example.m'}}
$catalog | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $versionRoot 'diagnostic-sources.json') -Encoding UTF8
@{endpoint=('https://'+('a'*20)+'.supabase.co/functions/v1/eeglab-reports/report');privacyVersion=1} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $versionRoot 'setup\desktop\reporting.json') -Encoding UTF8
@{matlab='23.2 (R2023b) Update 3'} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $versionRoot 'desktop_validation.json')
$report=[pscustomobject]@{schemaVersion=1;eventId='b'*32;observedAt=[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ');release='1.1.0';matlabRelease='2023b';context='runtime';errorCode=1;frames=@([pscustomobject]@{sourceId=$sourceId;line=42})}
Check (Test-TechnicalReport $report $catalog) 'Known technical record accepted'
$report | Add-Member -NotePropertyName message -NotePropertyValue 'PRIVATE EEG PARTICIPANT'
Check (-not (Test-TechnicalReport $report $catalog)) 'Free-text personal field rejected'
$report.PSObject.Properties.Remove('message')
$report.frames[0].sourceId='c'*32
Check (-not (Test-TechnicalReport $report $catalog)) 'Uncataloged source rejected'
$report.frames[0].sourceId=$sourceId
$file=Join-Path $queue ('report-'+$report.eventId+'.json')
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $file
$script:calls=0;$script:offline=$false
function Invoke-RestMethod { param($Method,$Uri,$ContentType,$Body,$TimeoutSec,$MaximumRedirection); $script:calls++; $script:lastBody=[Text.Encoding]::UTF8.GetString($Body); if($script:offline){throw 'Offline'}; return [pscustomobject]@{accepted=$true} }
Check ((Send-TechnicalReportBatch $homeRoot $versionRoot) -eq 0 -and $script:calls -eq 0) 'No consent means no network request'
@{enabled=$true;privacyVersion=1} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $reportRoot 'preferences.json')
$script:offline=$true
Check ((Send-TechnicalReportBatch $homeRoot $versionRoot) -eq 0 -and (Test-Path -LiteralPath $file)) 'Offline upload retains the report'
$script:offline=$false
Check ((Send-TechnicalReportBatch $homeRoot $versionRoot) -eq 1 -and -not (Test-Path -LiteralPath $file)) 'Acknowledged upload removes only the queued copy'
Write-DesktopDiagnostic $homeRoot $versionRoot 'update' 21
Check (@(Get-ChildItem -LiteralPath $queue -Filter 'report-*.json').Count -eq 1) 'Updater failures recorded without exception text'
@{enabled=$false;privacyVersion=1} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $reportRoot 'preferences.json')
$before=$script:calls
Check ((Send-TechnicalReportBatch $homeRoot $versionRoot) -eq 0 -and $before -eq $script:calls) 'Consent withdrawal stops delivery'
Write-DesktopDiagnostic $homeRoot $versionRoot 'update' 20
Check (@(Get-ChildItem -LiteralPath (Join-Path $reportRoot 'history') -Filter 'report-*.json').Count -eq 2) 'Local technical history remains available without automatic reporting'
$detail=New-UpdateDetail '1.2.1'; Set-UpdateStage $detail 'extract' 'QuickLab'
try { throw [IO.PathTooLongException]::new('PRIVATE participant C:\Users\Jane\recording.set token=SECRET') } catch { $detail=Get-UpdateFailureDetail $_ $detail }
Check ($detail.reason -eq 'path-too-long' -and $detail.systemCode -ne 0) 'Native error classified without message parsing'
@{matlab='26.2 (R2026b Prerelease)'} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $versionRoot 'desktop_validation.json')
@{enabled=$true;privacyVersion=1} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $reportRoot 'preferences.json')
Write-DesktopDiagnostic $homeRoot $versionRoot 'update' 21 $detail
$records=@(Get-ChildItem $queue -Filter 'report-*.json' | ForEach-Object { Get-Content -Raw $_.FullName | ConvertFrom-Json })
$detailed=@($records | Where-Object schemaVersion -eq 2)[0]
Check ($detailed.matlabRelease -eq '2026b' -and $detailed.update.component -eq 'QuickLab' -and (Test-TechnicalReport $detailed $catalog)) 'Prerelease MATLAB and structured update cause recorded'
$script:offline=$true; $null=Send-TechnicalReportBatch $homeRoot $versionRoot
Check ((Get-ChildItem $queue -Filter 'report-*.json').Count -eq 2) 'Detailed update failures survive offline delivery'
$script:offline=$false; $null=Send-TechnicalReportBatch $homeRoot $versionRoot
Check ($script:lastBody -notmatch 'PRIVATE|Jane|SECRET|recording.set' -and (Get-ChildItem $queue -Filter 'report-*.json').Count -eq 0) 'Detailed payload sent without personal text, paths or secrets'
$detailed.update | Add-Member -NotePropertyName rawLog -NotePropertyValue 'PRIVATE'
Check (-not (Test-TechnicalReport $detailed $catalog)) 'Unexpected nested log field rejected'
$detailed.update.PSObject.Properties.Remove('rawLog'); $detailed.update.component='Patient Jane'
Check (-not (Test-TechnicalReport $detailed $catalog)) 'Unknown component rejected before upload'
$detailed.update.component='QuickLab'; $detailed.update.pluginFailures=@([pscustomobject]@{component='QuickLab';reason='startup'})
Check (Test-TechnicalReport $detailed $catalog) 'Known plugin startup failure accepted'
Remove-Item -LiteralPath (Join-Path $versionRoot 'desktop_validation.json')
Write-DesktopDiagnostic $homeRoot $versionRoot 'update' 21 $detail
$unknown=Get-Content -Raw (Get-ChildItem $queue -Filter 'report-*.json')[0].FullName | ConvertFrom-Json
Check ($unknown.matlabRelease -eq 'unknown' -and (Test-TechnicalReport $unknown $catalog)) 'Missing MATLAB validation metadata does not drop an update report'
$startupLog=Join-Path $OutputDirectory 'synthetic-startup.log'
[IO.File]::WriteAllText($startupLog,'PRIVATE Jane C:\Users\Jane. License checkout failed. License Manager Error -9. token=SECRET')
$signals=@(Read-MatlabStartupSignals $startupLog)
Check ($signals.Count -eq 1 -and $signals[0] -ceq 'license-failure') 'MATLAB licensing failure identified without transmitting log text'
@{passed=$passed.Count;checks=@($passed)} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'results.json')
Write-Output ('PASS: '+$passed.Count+' PowerShell reporting checks')
