param([string]$OutputDirectory=(Join-Path $env:TEMP ('eeglab-discovery-'+[guid]::NewGuid().ToString('N'))))
$ErrorActionPreference='Stop'
$desktopSource=Split-Path -Parent $PSScriptRoot
. (Join-Path $desktopSource 'Desktop-Common.ps1')
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$passed=New-Object 'Collections.Generic.List[string]'
function Check($condition,$message) { if(-not $condition){throw $message}; $passed.Add($message); Write-Output "PASS: $message" }
function Must-Fail($action,$message) { $failed=$false; try { & $action | Out-Null } catch { $failed=$true }; Check $failed $message }
function Release($version) {
    return [pscustomobject]@{draft=$false;prerelease=$false;tag_name=('eeglab-desktop-v'+$version);assets=@([pscustomobject]@{name='EEGLAB2026-Update.zip';state='uploaded';digest=('sha256:'+('a'*64));browser_download_url=('https://github.com/MPG-Git/QuickLab/releases/download/eeglab-desktop-v'+$version+'/EEGLAB2026-Update.zip')})}
}
$state=[pscustomobject]@{current=[pscustomobject]@{version='1.4.0';path=$OutputDirectory};holdThroughVersion='0.0.0';deferredVersion='1.4.1';deferredUntilUtc='2099-01-01T00:00:00Z'}
$script:responses=@(); $script:calls=@()
function Invoke-RestMethod {
    param($Uri,$Headers,$TimeoutSec)
    $script:calls+=@{uri=$Uri;timeout=$TimeoutSec;headers=$Headers}
    $response=$script:responses[$script:calls.Count-1]
    if($response -is [Exception]){throw $response}
    return $response
}
function Route($responses) { $script:responses=$responses; $script:calls=@() }
$channel=[pscustomobject]@{schemaVersion=1;version='1.4.1';tag='eeglab-desktop-v1.4.1';url='https://github.com/MPG-Git/QuickLab/releases/download/eeglab-desktop-v1.4.1/EEGLAB2026-Update.zip';sha256=('a'*64)}
Route @((Release '1.4.1'))
Check ((Get-DesktopUpdate $state).version -eq '1.4.1') 'Normal API discovers update despite stale legacy deferral'
Check ($script:calls.Count -eq 1 -and $script:calls[0].timeout -eq 12 -and $script:calls[0].headers['Cache-Control'] -eq 'no-cache') 'Successful check is bounded and does not request cached responses'
$state.current.version='1.4.1'
Route @((Release '1.4.2'))
$future=Get-DesktopUpdate $state
$futurePrompt=Get-DesktopUpdatePrompt $state $future
Check ($future.version -eq '1.4.2' -and $futurePrompt.Contains('1.4.1') -and $futurePrompt.Contains('1.4.2')) 'Installed 1.4.1 offers a later release and names both versions without a new installer'
$state.current.version='1.4.0'
Route @([Exception]::new('API rate limited'),$channel)
Check ((Get-DesktopUpdate $state).version -eq '1.4.1' -and $script:calls.Count -eq 2 -and $script:calls[1].uri -like 'https://github.com/*') 'API failure falls back to published HTTPS descriptor without API credentials'
Route @([TimeoutException]::new('timeout'),[Exception]::new('missing descriptor'),(Release '1.4.1'))
Check ((Get-DesktopUpdate $state).version -eq '1.4.1' -and $script:calls.Count -eq 3) 'Transient failure recovers on bounded API retry'
Route @([Exception]::new('offline'),[Exception]::new('offline'),[Exception]::new('offline'))
Must-Fail { Get-DesktopUpdate $state } 'Total network failure is distinguishable from up-to-date'
Check ($script:calls.Count -eq 3) 'Automatic network attempts are bounded'
foreach($change in @('url','sha256','tag','schemaVersion')) {
    $bad=$channel | ConvertTo-Json | ConvertFrom-Json
    switch($change) { 'url' {$bad.url='https://example.invalid/update.zip'} 'sha256' {$bad.sha256=''} 'tag' {$bad.tag='eeglab-desktop-v2.0.0'} 'schemaVersion' {$bad.schemaVersion=99} }
    Route @([Exception]::new('API failed'),$bad,[Exception]::new('API failed'))
    Must-Fail { Get-DesktopUpdate $state } "Invalid fallback $change cannot authorize installation"
}
$state.holdThroughVersion='1.4.1'
Route @([Exception]::new('API failed'),$channel)
Check ($null -eq (Get-DesktopUpdate $state)) 'Fallback respects explicit rollback hold'
Route @((Release '1.4.2'))
Check ((Get-DesktopUpdate $state).version -eq '1.4.2') 'Newer update is offered after rollback of an earlier release'
$state.holdThroughVersion='0.0.0'
$prompt=Get-DesktopUpdatePrompt $state $channel
Check ($prompt.Contains('1.4.0') -and $prompt.Contains('1.4.1')) 'Offer names both installed and available versions'
Check ((Get-DesktopUpdatePrompt $state $channel -NoOpen).Contains('save your work')) 'In-session offer explains save and restart without closing data'

# Execute the real launch controller with transport and dialog seams only.
$controller=Join-Path $OutputDirectory 'controller'; $managed=Join-Path $OutputDirectory 'managed'
foreach($dir in @($controller,$managed)){[IO.Directory]::CreateDirectory($dir)|Out-Null}
Copy-Item (Join-Path $desktopSource 'Update-Launch.ps1') $controller
$common=Get-Content -Raw (Join-Path $desktopSource 'Desktop-Common.ps1')
$common+=@'

function Invoke-DesktopUpdateCheck($HomeRoot,$State) {
    $script:checkCalls++
    if($script:testCase -in @('offline','retry') -and $script:checkCalls -eq 1){throw 'simulated offline'}
    if($script:testCase -eq 'current'){return $null}
    return [pscustomobject]@{version='1.4.1'}
}
function Show-DesktopMessage($Text,$Title,$Buttons='OK') {
    $script:messages+=@{text=$Text;title=$Title;buttons=$Buttons}
    if($Buttons -eq 'RetryCancel'){if($script:testCase -eq 'retry'){return 'Retry'};return 'Cancel'}
    if($script:testCase -eq 'accept' -and $Buttons -eq 'YesNo'){return 'Yes'}
    return 'No'
}
function Start-DesktopMatlab($State,$Mode) { $script:launched+=@($State.current.version+':'+$Mode) }
'@
[IO.File]::WriteAllText((Join-Path $controller 'Desktop-Common.ps1'),$common)
$apply=@'
param($HomeRoot,$DescriptorPath)
$state=Get-Content -Raw (Join-Path $HomeRoot 'state.json') | ConvertFrom-Json
$update=Get-Content -Raw $DescriptorPath | ConvertFrom-Json
$state.current.version=$update.version
$state | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $HomeRoot 'state.json')
'@
[IO.File]::WriteAllText((Join-Path $controller 'Apply-DesktopUpdate.ps1'),$apply)
Save-DesktopState $managed $state
$before=(Get-FileHash (Join-Path $managed 'state.json')).Hash
function Run-Controller($case,[switch]$NoOpen) {
    $script:testCase=$case; $script:checkCalls=0; $script:messages=@(); $script:launched=@()
    . (Join-Path $controller 'Update-Launch.ps1') -HomeRoot $managed -Mode practice -NoOpen:$NoOpen
    return @{calls=$script:checkCalls;messages=$script:messages;launched=$script:launched}
}
$r=Run-Controller available
Check ($r.messages.Count -eq 1 -and $r.messages[0].text.Contains('1.4.1') -and $r.launched[0] -eq '1.4.0:practice') 'Actual controller offers despite legacy day-long deferral and No opens installed practice mode'
$r=Run-Controller available
Check ($r.messages.Count -eq 1) 'Declining offers the update again on the next launch'
Check ((Get-FileHash (Join-Path $managed 'state.json')).Hash -eq $before) 'Declining does not change installation state'
$r=Run-Controller offline
Check ($r.messages[0].buttons -eq 'RetryCancel' -and $r.messages[0].text.Contains('1.4.0') -and $r.launched.Count -eq 1) 'Offline check gives visible Retry/Cancel and still allows the installed version'
$r=Run-Controller retry
Check ($r.calls -eq 2 -and $r.messages.Count -eq 2 -and $r.messages[1].text.Contains('1.4.1')) 'Retry after failed check discovers and offers the update'
$r=Run-Controller available -NoOpen
Check ($r.launched.Count -eq 0 -and $r.messages[0].text.Contains('save your work')) 'Manual check preserves the running session'
$r=Run-Controller current -NoOpen
Check ($r.launched.Count -eq 0 -and $r.messages[0].text.Contains('No newer eligible')) 'Manual up-to-date check explicitly reports installed version'
$r=Run-Controller offline -NoOpen
Check ($r.launched.Count -eq 0 -and $r.messages[0].text.Contains('continue working')) 'Offline manual check returns to current MATLAB session'
$r=Run-Controller accept -NoOpen
Check ($r.launched.Count -eq 0 -and $r.messages[-1].text.Contains('1.4.1 is installed')) 'Accepted manual update runs child worker and explains restart without opening MATLAB'
Save-DesktopState $managed $state
$r=Run-Controller accept
Check ($r.launched.Count -eq 1 -and $r.launched[0] -eq '1.4.1:practice') 'Accepted launcher update runs child worker then opens the new version'
Save-DesktopState $managed $state

# Real child checker: prove cross-process results and privacy on failure.
$workerDir=Join-Path $OutputDirectory 'worker'; [IO.Directory]::CreateDirectory($workerDir)|Out-Null
foreach($name in @('Check-DesktopUpdate.ps1','Desktop-Common.ps1','Reporting-Common.ps1','Update-Diagnostics.ps1')){Copy-Item (Join-Path $desktopSource $name) $workerDir}
$workerCommon=Get-Content -Raw (Join-Path $workerDir 'Desktop-Common.ps1')
foreach($workerCase in @('success','failure')) {
    $mock="`nfunction Get-DesktopUpdate { return [pscustomobject]@{version='1.4.1'} }"
    if($workerCase -eq 'failure'){$mock="`nfunction Get-DesktopUpdate { throw [TimeoutException]::new('PRIVATE C:\Users\Jane\recording.set') }"}
    [IO.File]::WriteAllText((Join-Path $workerDir 'Desktop-Common.ps1'),$workerCommon+$mock)
    $resultPath=Join-Path $OutputDirectory ($workerCase+'.json')
    & (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe') -NoProfile -ExecutionPolicy Bypass -File (Join-Path $workerDir 'Check-DesktopUpdate.ps1') -HomeRoot $managed -ResultPath $resultPath
    if($LASTEXITCODE -ne 0){throw 'Checker worker failed'}
    $json=Get-Content -Raw $resultPath; $result=$json | ConvertFrom-Json
    if($workerCase -eq 'success'){Check ($result.status -eq 'checked' -and $result.update.version -eq '1.4.1') 'Real checker child returns an available update'}
    else {Check ($result.status -eq 'unavailable' -and $result.detail.reason -eq 'timeout' -and $json -notmatch 'PRIVATE|Jane|recording.set') 'Real checker child returns structured timeout without private text'}
}
[pscustomobject]@{passed=$passed.Count;checks=@($passed)} | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $OutputDirectory 'results.json')
