param([string]$OutputDirectory = (Join-Path $env:TEMP ('eeglab-update-tests-' + [guid]::NewGuid().ToString('N'))))
$ErrorActionPreference='Stop'
$desktopSource=Split-Path -Parent $PSScriptRoot
. (Join-Path $desktopSource 'Desktop-Common.ps1')
Add-Type -AssemblyName System.IO.Compression
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$passed=New-Object 'Collections.Generic.List[string]'
function Check([bool]$condition,[string]$message) { if(-not $condition){throw $message}; $passed.Add($message) }
function Must-Fail([scriptblock]$action,[string]$message) { $failed=$false; try { & $action | Out-Null } catch { $failed=$true }; Check $failed $message }
$state=[pscustomobject]@{schemaVersion=1;matlabExe='C:\unused\matlab.exe';cache=$OutputDirectory;current=[pscustomobject]@{version='1.0.0';path=$OutputDirectory};previous=$null;holdThroughVersion='0.0.0';deferredVersion='';deferredUntilUtc=''}
function Make-Release([string]$version,[bool]$preview=$false) {
    $tag='eeglab-desktop-v'+$version
    return [pscustomobject]@{draft=$false;prerelease=$preview;tag_name=$tag;assets=@([pscustomobject]@{name='EEGLAB2026-Update.zip';state='uploaded';digest=('sha256:'+('a'*64));browser_download_url=('https://github.com/MPG-Git/QuickLab/releases/download/'+$tag+'/EEGLAB2026-Update.zip')})}
}
$script:releases=@((Make-Release '1.0.2'),(Make-Release '1.0.10'),(Make-Release '2.0.0' $true))
function Invoke-RestMethod { return $script:releases }
$chosen=Get-DesktopUpdate $state
Check ($chosen.version -eq '1.0.10') 'Newest stable semantic version selected; preview ignored'
$state.holdThroughVersion='1.0.10'
Check ($null -eq (Get-DesktopUpdate $state)) 'Rolled-back release is not immediately offered again'
$state.holdThroughVersion='0.0.0'
$bad=Make-Release '2.0.0'; $bad.assets[0].browser_download_url='https://example.org/package.zip'; $script:releases=@($bad)
Check ($null -eq (Get-DesktopUpdate $state)) 'Release asset outside this repository rejected'
$bad=Make-Release '2.0.0'; $bad.assets[0].digest=$null; $script:releases=@($bad)
Check ($null -eq (Get-DesktopUpdate $state)) 'Release without publisher-provided digest rejected'

$zipPath=Join-Path $OutputDirectory 'valid-update.zip'
$zip=[IO.Compression.ZipFile]::Open($zipPath,[IO.Compression.ZipArchiveMode]::Create)
$entry=$zip.CreateEntry('desktop/release.json'); $writer=New-Object IO.StreamWriter($entry.Open())
$writer.Write('{"schemaVersion":1,"version":"1.0.1","tag":"eeglab-desktop-v1.0.1"}'); $writer.Dispose();$zip.Dispose()
$script:downloadFixture=$zipPath
function Invoke-WebRequest { param($Uri,$OutFile,$TimeoutSec,[switch]$UseBasicParsing); Copy-Item -LiteralPath $script:downloadFixture -Destination $OutFile }
$update=[pscustomobject]@{version='1.0.1';tag='eeglab-desktop-v1.0.1';url='fixture';sha256=(Get-FileHash $zipPath).Hash}
$source=Get-DesktopUpdateSource $OutputDirectory $update
Check (Test-Path -LiteralPath (Join-Path $source 'desktop\release.json')) 'Valid update archive verified and extracted'
$update.sha256='0'*64
Must-Fail { Get-DesktopUpdateSource $OutputDirectory $update } 'Corrupt download rejected before extraction'
$update.sha256=(Get-FileHash $zipPath).Hash; $update.version='1.0.2'
Must-Fail { Get-DesktopUpdateSource $OutputDirectory $update } 'Mismatched release metadata rejected'
$escapeZip=Join-Path $OutputDirectory 'escape.zip'
$zip=[IO.Compression.ZipFile]::Open($escapeZip,[IO.Compression.ZipArchiveMode]::Create); $entry=$zip.CreateEntry('../escaped.txt');$writer=New-Object IO.StreamWriter($entry.Open());$writer.Write('must not escape');$writer.Dispose();$zip.Dispose()
$script:downloadFixture=$escapeZip;$update.sha256=(Get-FileHash $escapeZip).Hash
Must-Fail { Get-DesktopUpdateSource $OutputDirectory $update } 'Archive path traversal rejected'

$homeRoot=Join-Path $OutputDirectory 'managed'; [IO.Directory]::CreateDirectory($homeRoot) | Out-Null
$old=Join-Path $homeRoot 'versions\old';$new=Join-Path $homeRoot 'versions\new'
foreach($dir in @($old,$new)){[IO.Directory]::CreateDirectory($dir)|Out-Null;[IO.File]::WriteAllText((Join-Path $dir 'desktop_validation.json'),'{"status":"PASS"}')}
[IO.File]::WriteAllText((Join-Path $old 'recording-sentinel.txt'),'unchanged')
$state.current=[pscustomobject]@{version='1.0.1';path=$new}; $state.previous=[pscustomobject]@{version='1.0.0';path=$old}
Save-DesktopState $homeRoot $state
$state=Undo-DesktopUpdate $homeRoot $state
$stored=Read-DesktopState $homeRoot
Check ($stored.current.path -eq $old -and $stored.holdThroughVersion -eq '1.0.1') 'Rollback selects the previous validated version and holds the rejected release'
Check ((Get-Content -Raw (Join-Path $old 'recording-sentinel.txt')) -eq 'unchanged') 'Rollback leaves existing files untouched'
$lock=Open-DesktopLock $homeRoot
try { Must-Fail { Open-DesktopLock $homeRoot } 'Concurrent install or launch rejected' } finally { $lock.Dispose() }

# Exercise the real launch controller with a simulated offline API and a
# recorded launch instead of opening MATLAB during this contract test.
$controller=Join-Path $OutputDirectory 'controller';[IO.Directory]::CreateDirectory($controller)|Out-Null
Copy-Item -LiteralPath (Join-Path $desktopSource 'Update-Launch.ps1') -Destination $controller
$common=Get-Content -Raw -LiteralPath (Join-Path $desktopSource 'Desktop-Common.ps1')
$common += @'

function Get-DesktopUpdate($State) { throw 'Simulated offline network' }
function Start-DesktopMatlab($State,[string]$Mode) { [IO.File]::WriteAllText((Join-Path $HomeRoot 'launch-observed.txt'),$State.current.version + ':' + $Mode) }
'@
[IO.File]::WriteAllText((Join-Path $controller 'Desktop-Common.ps1'),$common)
& (Join-Path $controller 'Update-Launch.ps1') -HomeRoot $homeRoot -Mode practice
Check ((Get-Content -Raw (Join-Path $homeRoot 'launch-observed.txt')) -eq '1.0.0:practice') 'Offline launch opens the installed version and preserves practice mode'

# Small package fixtures exercise activation/failed validation without
# rerunning every third-party scientific algorithm in the contract suite.
$fixture=Join-Path $OutputDirectory 'package';[IO.Directory]::CreateDirectory((Join-Path $fixture 'desktop'))|Out-Null
[IO.File]::WriteAllText((Join-Path $fixture 'desktop\release.json'),'{"schemaVersion":1,"version":"1.0.2","tag":"eeglab-desktop-v1.0.2"}')
[IO.File]::WriteAllText((Join-Path $fixture 'manifest.json'),'{}')
[IO.File]::WriteAllText((Join-Path $fixture 'Install-EEGLAB.ps1'),'param($Destination,$Cache); [IO.Directory]::CreateDirectory($Destination) | Out-Null')
foreach($name in @('eeglab_desktop_start.m','eeglab_practice.m','eeglab_diagnostics.m','diagnostic-sources.json','validate_desktop_update.m')){[IO.File]::WriteAllText((Join-Path $fixture ('desktop\'+$name)),'% test fixture')}
$fakeMatlab=Join-Path $OutputDirectory 'matlab.exe';[IO.File]::WriteAllText($fakeMatlab,'fixture only; never executed')
$before=(Get-FileHash -LiteralPath (Join-Path $homeRoot 'state.json')).Hash
function Test-DesktopCandidate { param($Folder,$MatlabExe); throw 'Simulated MATLAB validation failure' }
Must-Fail { Install-DesktopVersion -HomeRoot $homeRoot -Source $fixture -MatlabExe $fakeMatlab -Cache $OutputDirectory } 'Failed MATLAB validation blocks activation'
Check ((Get-FileHash -LiteralPath (Join-Path $homeRoot 'state.json')).Hash -eq $before) 'Failed update leaves the active state byte-for-byte unchanged'
function Test-DesktopCandidate { param($Folder,$MatlabExe); [IO.File]::WriteAllText((Join-Path $Folder 'desktop_validation.json'),'{"status":"PASS"}') }
$next=Install-DesktopVersion -HomeRoot $homeRoot -Source $fixture -MatlabExe $fakeMatlab -Cache $OutputDirectory
Check ($next.current.version -eq '1.0.2' -and $next.previous.version -eq '1.0.0') 'Validated update activates and retains the previous version'
Check ((Get-Content -Raw (Join-Path $old 'recording-sentinel.txt')) -eq 'unchanged') 'Successful update leaves old-version files untouched'
$passed | ForEach-Object { Write-Output ('PASS: '+$_) }
[pscustomobject]@{passed=$passed.Count;checks=@($passed)} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'results.json') -Encoding UTF8
