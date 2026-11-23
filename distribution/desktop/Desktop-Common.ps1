$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.IO.Compression.FileSystem
$reportingHelpers=Join-Path $PSScriptRoot 'Reporting-Common.ps1'
if (Test-Path -LiteralPath $reportingHelpers) { . $reportingHelpers }

function Open-DesktopLock([string]$HomeRoot) {
    [IO.Directory]::CreateDirectory($HomeRoot) | Out-Null
    try { return [IO.File]::Open((Join-Path $HomeRoot 'setup.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None) }
    catch { throw 'Another EEGLAB update or launch is already in progress. Please wait a moment and try again.' }
}
function Read-DesktopState([string]$HomeRoot) {
    $file = Join-Path $HomeRoot 'state.json'
    if (Test-Path -LiteralPath $file) { return Get-Content -Raw -LiteralPath $file | ConvertFrom-Json }
    return $null
}
function Save-DesktopState([string]$HomeRoot, $State) {
    $file = Join-Path $HomeRoot 'state.json'
    $temp = Join-Path $HomeRoot ('state-' + [guid]::NewGuid().ToString('N') + '.tmp')
    $json = $State | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText($temp,$json,(New-Object Text.UTF8Encoding($false)))
    if (Test-Path -LiteralPath $file) {
        $backup = Join-Path $HomeRoot ('state-backup-' + [guid]::NewGuid().ToString('N') + '.json')
        [IO.File]::Replace($temp,$file,$backup)
    }
    else { [IO.File]::Move($temp,$file) }
}
function Assert-DesktopRelease($Release) {
    if ($Release.schemaVersion -ne 1 -or $Release.version -notmatch '^\d+\.\d+\.\d+$' -or $Release.tag -ne ('eeglab-desktop-v' + $Release.version)) { throw 'Unsupported EEGLAB update package.' }
}
function Start-DesktopMatlab($State,[string]$Mode='open') {
    if (-not (Test-Path -LiteralPath $State.matlabExe)) { throw 'MATLAB has moved or was removed. Run the setup application to select MATLAB again.' }
    $folder = $State.current.path
    $command = 'eeglab_desktop_start'
    if ($Mode -eq 'practice') { $command += '; if exist(''eeglab_desktop_ready'',''var'') && eeglab_desktop_ready, eeglab_practice; end' }
    $logs = Join-Path $folder 'logs'
    [IO.Directory]::CreateDirectory($logs) | Out-Null
    $log = Join-Path $logs ($Mode + '-' + [DateTime]::Now.ToString('yyyyMMdd-HHmmssfff') + '.log')
    $arguments = '-wait -desktop -sd "' + $folder + '" -logfile "' + $log + '" -r "' + $command + '"'
    Write-Output 'Opening MATLAB and EEGLAB. This can take a minute...'
    $matlabProcess=Start-Process -FilePath $State.matlabExe -ArgumentList $arguments -WorkingDirectory $folder -WindowStyle Normal -PassThru
    $reportingWorker=Join-Path $folder 'setup\desktop\Reporting-Worker.ps1'
    if (Test-Path -LiteralPath $reportingWorker) {
        $managedHome=Split-Path -Parent (Split-Path -Parent $folder)
        $workerArgs='-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$reportingWorker+'" -HomeRoot "'+$managedHome+'" -VersionRoot "'+$folder+'" -MatlabProcessId '+$matlabProcess.Id
        try { Start-Process -FilePath (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe') -ArgumentList $workerArgs -WindowStyle Hidden | Out-Null } catch { }
    }
}
function Test-DesktopCandidate([string]$Folder,[string]$MatlabExe,$Diagnostic=$null) {
    Set-UpdateStage $Diagnostic 'validation'
    $log = Join-Path $Folder 'setup-validation.log'
    Write-Output 'Checking the installation in MATLAB. Practice windows may open briefly...'
    $arguments = '-wait -sd "' + $Folder + '" -logfile "' + $log + '" -batch "validate_desktop_update"'
    try { $process = Start-Process -FilePath $MatlabExe -ArgumentList $arguments -WorkingDirectory $Folder -WindowStyle Hidden -PassThru }
    catch { if ($Diagnostic) { $Diagnostic.reason='matlab-launch' }; throw }
    $null=$process.Handle
    $deadline = [DateTime]::UtcNow.AddMinutes(10)
    while (-not $process.WaitForExit(250)) {
        if ('Windows.Forms.Application' -as [type]) { [Windows.Forms.Application]::DoEvents() }
        if ([DateTime]::UtcNow -gt $deadline) { $process.Kill(); if ($Diagnostic) { $Diagnostic.reason='timeout' }; throw "MATLAB validation timed out. The earlier version is unchanged. Details: $log" }
    }
    $resultFile = Join-Path $Folder 'desktop_validation.json'
    if ($Diagnostic) { $Diagnostic.exitCode=[int]$process.ExitCode; $Diagnostic.startupSignals=@(Read-MatlabStartupSignals $log) }
    if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $resultFile)) { if ($Diagnostic) { $Diagnostic.reason='matlab-exit' }; throw "MATLAB could not validate the update. The earlier version is unchanged. Details: $log" }
    $result = Get-Content -Raw -LiteralPath $resultFile | ConvertFrom-Json
    if ($result.status -ne 'PASS') { throw "The update did not pass its practice checks. Details: $log" }
}
function Install-DesktopVersion([string]$HomeRoot,[string]$Source,[string]$MatlabExe,[string]$Cache,$Diagnostic=$null) {
    Set-UpdateStage $Diagnostic 'install'
    $MatlabExe = [IO.Path]::GetFullPath($MatlabExe)
    if (-not (Test-Path -LiteralPath $MatlabExe -PathType Leaf) -or [IO.Path]::GetFileName($MatlabExe) -ne 'matlab.exe') { throw 'Please select the installed matlab.exe application.' }
    $release = Get-Content -Raw -LiteralPath (Join-Path $Source 'desktop\release.json') | ConvertFrom-Json
    Assert-DesktopRelease $release
    if ($Diagnostic) { $Diagnostic.targetVersion=$release.version }
    $manifestHash = (Get-FileHash -LiteralPath (Join-Path $Source 'manifest.json') -Algorithm SHA256).Hash
    $state = Read-DesktopState $HomeRoot
    if ($state -and $state.current.version -eq $release.version -and $state.current.manifestSHA256 -eq $manifestHash -and (Test-Path -LiteralPath (Join-Path $state.current.path 'desktop_validation.json'))) {
        $state.matlabExe = $MatlabExe
        Save-DesktopState $HomeRoot $state
        return $state
    }
    $versions = Join-Path $HomeRoot 'versions'
    [IO.Directory]::CreateDirectory($versions) | Out-Null
    $candidate = Join-Path $versions ($release.version + '-' + [guid]::NewGuid().ToString('N').Substring(0,8))
    & (Join-Path $Source 'Install-EEGLAB.ps1') -Destination $candidate -Cache $Cache -Diagnostic $Diagnostic | ForEach-Object { Write-Host $_ }
    Set-UpdateStage $Diagnostic 'install'
    $setup = Join-Path $candidate 'setup'
    Copy-Item -LiteralPath $Source -Destination $setup -Recurse
    foreach ($name in 'eeglab_desktop_start.m','eeglab_practice.m','eeglab_diagnostics.m','diagnostic-sources.json','validate_desktop_update.m') {
        Copy-Item -LiteralPath (Join-Path $Source ('desktop\' + $name)) -Destination (Join-Path $candidate $name)
    }
    Test-DesktopCandidate $candidate $MatlabExe -Diagnostic $Diagnostic | ForEach-Object { Write-Host $_ }
    Set-UpdateStage $Diagnostic 'activate'
    $previous = $null
    if ($state) { $previous = $state.current }
    $state = [pscustomobject]@{
        schemaVersion=1; matlabExe=$MatlabExe; cache=[IO.Path]::GetFullPath($Cache)
        current=[pscustomobject]@{version=$release.version;tag=$release.tag;path=$candidate;manifestSHA256=$manifestHash}
        previous=$previous; holdThroughVersion='0.0.0'; deferredVersion=''; deferredUntilUtc=''
    }
    Save-DesktopState $HomeRoot $state
    return $state
}
function New-DesktopShortcuts([string]$HomeRoot,[string]$Desktop,[string]$MatlabExe) {
    [IO.Directory]::CreateDirectory($Desktop) | Out-Null
    $shell = New-Object -ComObject WScript.Shell
    foreach ($pair in @(@('EEGLAB 2026','open'),@('EEGLAB Practice','practice'),@('EEGLAB Previous Version','rollback'))) {
        $linkPath = Join-Path $Desktop ($pair[0] + '.lnk')
        if ((Test-Path -LiteralPath $linkPath) -and $shell.CreateShortcut($linkPath).Description -ne 'MPG EEGLAB desktop launcher') { $linkPath = Join-Path $Desktop ($pair[0] + ' MPG.lnk') }
        $link = $shell.CreateShortcut($linkPath)
        $link.TargetPath = Join-Path $HomeRoot 'EEGLABLauncher.exe'
        $link.Arguments = '--launch --home "' + $HomeRoot + '" --mode ' + $pair[1]
        $link.WorkingDirectory = $HomeRoot
        $link.Description = 'MPG EEGLAB desktop launcher'
        $link.IconLocation = $MatlabExe + ',0'
        $link.Save()
    }
}
function Select-DesktopUpdate($State,$Releases) {
    $eligible = @()
    foreach ($release in $Releases) {
        if ($release.draft -or $release.prerelease -or $release.tag_name -notmatch '^eeglab-desktop-v(\d+\.\d+\.\d+)$') { continue }
        $version = $Matches[1]
        if ([version]$version -le [version]$State.current.version -or [version]$version -le [version]$State.holdThroughVersion) { continue }
        $assets = @($release.assets | Where-Object { $_.name -eq 'EEGLAB2026-Update.zip' -and $_.state -eq 'uploaded' })
        if ($assets.Count -ne 1) { continue }
        $asset = $assets[0]
        if ($asset.digest -notmatch '^sha256:([a-fA-F0-9]{64})$') { continue }
        $digest = $Matches[1]
        $expectedUrl = 'https://github.com/MPG-Git/QuickLab/releases/download/' + $release.tag_name + '/EEGLAB2026-Update.zip'
        if ($asset.browser_download_url -ne $expectedUrl) { continue }
        $eligible += [pscustomobject]@{version=$version;tag=$release.tag_name;url=$expectedUrl;sha256=$digest}
    }
    return $eligible | Sort-Object { [version]$_.version } -Descending | Select-Object -First 1
}
function Get-DesktopUpdate($State) {
    $headers = @{'User-Agent'='MPG-EEGLAB-Launcher';Accept='application/vnd.github+json';'Cache-Control'='no-cache'}
    $api='https://api.github.com/repos/MPG-Git/QuickLab/releases?per_page=100'
    # A second HTTPS route avoids the shared-IP REST API rate limit. The
    # publisher uploads this descriptor with the exact tested ZIP's hash.
    $channel='https://github.com/MPG-Git/QuickLab/releases/latest/download/desktop-update.json'
    $lastFailure=$null
    foreach ($route in @($api,$channel,$api)) {
        try {
            $response=Invoke-RestMethod -Uri $route -Headers $headers -TimeoutSec 12
            if ($route -eq $channel) {
                Assert-DesktopRelease $response
                $expected='https://github.com/MPG-Git/QuickLab/releases/download/'+$response.tag+'/EEGLAB2026-Update.zip'
                if ($response.url -cne $expected -or $response.sha256 -cnotmatch '^[a-fA-F0-9]{64}$') { throw 'Invalid update channel metadata.' }
                $response=@([pscustomobject]@{draft=$false;prerelease=$false;tag_name=$response.tag;assets=@([pscustomobject]@{name='EEGLAB2026-Update.zip';state='uploaded';digest=('sha256:'+$response.sha256);browser_download_url=$response.url})})
            } elseif ($null -eq $response -or @($response | Where-Object { -not $_.PSObject.Properties['tag_name'] }).Count) {
                throw 'Invalid update release list.'
            }
            return Select-DesktopUpdate $State $response
        } catch { $lastFailure=$_ }
    }
    throw $lastFailure
}
function Get-DesktopUpdatePrompt($State,$Update,[switch]$NoOpen) {
    $action='Update and open EEGLAB?'
    $after='Yes: install and check the update first.'
    if ($NoOpen) { $action='Install this update?'; $after='After installation, save your work, close MATLAB, and open the EEGLAB 2026 shortcut.' }
    return "EEGLAB Desktop $($Update.version) is available.`nYour installed version: $($State.current.version).`n`n$action`n`n$after`nNo: keep your current version and ask again next time."
}
function Show-DesktopMessage([string]$Text,[string]$Title,[string]$Buttons='OK') {
    return [Windows.Forms.MessageBox]::Show($Text,$Title,[Windows.Forms.MessageBoxButtons]$Buttons,[Windows.Forms.MessageBoxIcon]::Information)
}
function Invoke-DesktopUpdateCheck([string]$HomeRoot,$State) {
    # Network I/O runs outside the UI thread. Bound the worker too: DNS and
    # proxy failures can exceed an HTTP client's nominal timeout.
    $resultPath=Join-Path $HomeRoot ('update-check-'+[guid]::NewGuid().ToString('N')+'.json')
    $progress=New-Object Windows.Forms.Form
    $progress.Text='Checking EEGLAB updates'; $progress.Width=560; $progress.Height=170; $progress.StartPosition='CenterScreen'; $progress.ControlBox=$false
    $label=New-Object Windows.Forms.Label
    $label.Text="Installed: EEGLAB Desktop $($State.current.version).`nChecking for a newer tested version..."
    $label.Font=New-Object Drawing.Font('Segoe UI',13); $label.Dock='Fill'; $label.Padding=New-Object Windows.Forms.Padding(18)
    $progress.Controls.Add($label); $progress.Show(); [Windows.Forms.Application]::DoEvents()
    try {
        $script=Join-Path $PSScriptRoot 'Check-DesktopUpdate.ps1'
        $arguments='-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$script+'" -HomeRoot "'+$HomeRoot+'" -ResultPath "'+$resultPath+'"'
        $worker=Start-Process -FilePath (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe') -ArgumentList $arguments -WindowStyle Hidden -PassThru
        $null=$worker.Handle
        $deadline=[DateTime]::UtcNow.AddSeconds(60)
        while (-not $worker.WaitForExit(100)) {
            [Windows.Forms.Application]::DoEvents()
            if ([DateTime]::UtcNow -gt $deadline) { $worker.Kill(); throw [TimeoutException]::new('The update check timed out.') }
        }
        if ($worker.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $resultPath)) { throw 'The update checker could not finish.' }
        $result=Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
        if ($result.status -eq 'unavailable') {
            $failure=[Exception]::new('The update servers could not be reached.')
            $failure.Data['updateDetail']=$result.detail
            throw $failure
        }
        if ($result.status -ne 'checked') { throw 'Invalid update check result.' }
        return $result.update
    } finally { $progress.Close(); $progress.Dispose() }
}
function Get-DesktopUpdateSource([string]$HomeRoot,$Update,$Diagnostic=$null) {
    Set-UpdateStage $Diagnostic 'download'
    $folder = Join-Path $HomeRoot ('updates\' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($folder) | Out-Null
    $archive = Join-Path $folder 'update.zip'
    Invoke-WebRequest -UseBasicParsing -Uri $Update.url -OutFile $archive -TimeoutSec 180
    Set-UpdateStage $Diagnostic 'integrity'
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $Update.sha256) { if ($Diagnostic) { $Diagnostic.reason='hash-mismatch' }; throw 'The update download failed its integrity check.' }
    Set-UpdateStage $Diagnostic 'extract'
    $source = Join-Path $folder 'payload'
    [IO.Directory]::CreateDirectory($source) | Out-Null
    $zip = [IO.Compression.ZipFile]::OpenRead($archive)
    try {
        foreach ($entry in $zip.Entries) {
            if ($entry.FullName.EndsWith('/')) { continue }
            $path = [IO.Path]::GetFullPath((Join-Path $source $entry.FullName))
            if (-not $path.StartsWith($source + '\',[StringComparison]::OrdinalIgnoreCase)) { if ($Diagnostic) { $Diagnostic.reason='archive-invalid' }; throw 'Invalid update archive path.' }
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path)) | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$path,$false)
        }
    } finally { $zip.Dispose() }
    $release = Get-Content -Raw -LiteralPath (Join-Path $source 'desktop\release.json') | ConvertFrom-Json
    try { Assert-DesktopRelease $release
        if ($release.version -ne $Update.version -or $release.tag -ne $Update.tag) { throw 'The update package does not match its release.' }
    } catch { if ($Diagnostic) { $Diagnostic.reason='metadata-invalid' }; throw }
    return $source
}
function Undo-DesktopUpdate([string]$HomeRoot,$State) {
    if (-not $State.previous -or -not (Test-Path -LiteralPath (Join-Path $State.previous.path 'desktop_validation.json'))) { throw 'There is no earlier validated version to open yet.' }
    $old = $State.current
    $State.current = $State.previous
    $State.previous = $old
    if ([version]$old.version -gt [version]$State.holdThroughVersion) { $State.holdThroughVersion = $old.version }
    Save-DesktopState $HomeRoot $State
    return $State
}
