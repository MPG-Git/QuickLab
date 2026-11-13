param([string]$OutputDirectory=(Join-Path $env:TEMP ('eeglab-update-failures-'+[guid]::NewGuid().ToString('N'))))
$ErrorActionPreference='Stop'
$source=Split-Path -Parent $PSScriptRoot
$controller=Join-Path $OutputDirectory 'controller'
$homeRoot=Join-Path $OutputDirectory 'managed'
$versionRoot=Join-Path $homeRoot 'versions\old'
foreach($dir in @($controller,(Join-Path $versionRoot 'setup\desktop'))) { [IO.Directory]::CreateDirectory($dir) | Out-Null }
foreach($name in @('Desktop-Common.ps1','Reporting-Common.ps1','Update-Diagnostics.ps1','Reporting-Worker.ps1','Apply-DesktopUpdate.ps1','diagnostic-sources.json')) { Copy-Item -LiteralPath (Join-Path $source $name) -Destination $controller }
Copy-Item -LiteralPath (Join-Path $source 'diagnostic-sources.json') -Destination $versionRoot
@{matlab='26.2 (R2026b Prerelease)'} | ConvertTo-Json | Set-Content (Join-Path $versionRoot 'desktop_validation.json')
@{endpoint='';privacyVersion=1} | ConvertTo-Json | Set-Content (Join-Path $versionRoot 'setup\desktop\reporting.json')
$state=@{current=@{path=$versionRoot;version='1.2.1'};matlabExe='unused';cache=$OutputDirectory}
$state | ConvertTo-Json | Set-Content (Join-Path $homeRoot 'state.json')
$before=(Get-FileHash (Join-Path $homeRoot 'state.json')).Hash
$descriptor=Join-Path $OutputDirectory 'update.json'
@{version='1.2.2';url='https://example.invalid/test-only';sha256=('a'*64)} | ConvertTo-Json | Set-Content $descriptor
# A child process executes the actual worker, catches the failure, and exits.
# Only the transport is replaced; no network request or MATLAB is necessary.
Add-Content (Join-Path $controller 'Desktop-Common.ps1') @'
function Invoke-WebRequest { throw [UnauthorizedAccessException]::new('PRIVATE C:\Users\Jane\recording.set password=SECRET') }
'@
$worker=Join-Path $controller 'Apply-DesktopUpdate.ps1'
$arguments='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$worker+'" -HomeRoot "'+$homeRoot+'" -DescriptorPath "'+$descriptor+'"'
$process=Start-Process -FilePath (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe') -ArgumentList $arguments -WindowStyle Hidden -PassThru -Wait -RedirectStandardError (Join-Path $OutputDirectory 'expected-error.log') -RedirectStandardOutput (Join-Path $OutputDirectory 'worker.log')
if($process.ExitCode -eq 0){throw 'Failed worker reported success'}
$files=@(Get-ChildItem (Join-Path $homeRoot 'reporting\history') -Filter 'report-*.json')
if($files.Count -ne 1){throw 'Worker did not capture exactly one report'}
if(-not (Test-Path -LiteralPath ($descriptor+'.reported'))){throw 'Worker did not confirm that its report was saved'}
$json=Get-Content -Raw $files[0].FullName; $report=$json | ConvertFrom-Json
if($report.schemaVersion -ne 2 -or $report.update.stage -ne 'download' -or $report.update.reason -ne 'access-denied' -or $report.update.targetVersion -ne '1.2.2'){throw 'Failure details lost'}
if($json -match 'PRIVATE|Jane|recording.set|SECRET'){throw 'Sensitive text escaped'}
if(Test-Path (Join-Path $homeRoot 'reporting\queue')){throw 'No consent must not queue uploads'}
if((Get-FileHash (Join-Path $homeRoot 'state.json')).Hash -ne $before){throw 'Failed update changed active version'}
Write-Output 'PASS: actual failed worker records detailed cause, preserves active installation and honors opt-out; no private error text is serialized.'
