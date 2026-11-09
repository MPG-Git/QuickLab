$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.IO.Compression.FileSystem

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
    $arguments = '-desktop -sd "' + $folder + '" -logfile "' + $log + '" -r "' + $command + '"'
    Write-Output 'Opening MATLAB and EEGLAB. This can take a minute...'
    Start-Process -FilePath $State.matlabExe -ArgumentList $arguments -WorkingDirectory $folder -WindowStyle Normal | Out-Null
}
function Test-DesktopCandidate([string]$Folder,[string]$MatlabExe) {
    $log = Join-Path $Folder 'setup-validation.log'
    Write-Output 'Checking the installation in MATLAB. Practice windows may open briefly...'
    $arguments = '-wait -sd "' + $Folder + '" -logfile "' + $log + '" -batch "validate_desktop_update"'
    $process = Start-Process -FilePath $MatlabExe -ArgumentList $arguments -WorkingDirectory $Folder -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddMinutes(10)
    while (-not $process.WaitForExit(250)) {
        if ('Windows.Forms.Application' -as [type]) { [Windows.Forms.Application]::DoEvents() }
        if ([DateTime]::UtcNow -gt $deadline) { $process.Kill(); throw "MATLAB validation timed out. The earlier version is unchanged. Details: $log" }
    }
    $resultFile = Join-Path $Folder 'desktop_validation.json'
    if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $resultFile)) { throw "MATLAB could not validate the update. The earlier version is unchanged. Details: $log" }
    $result = Get-Content -Raw -LiteralPath $resultFile | ConvertFrom-Json
    if ($result.status -ne 'PASS') { throw "The update did not pass its practice checks. Details: $log" }
}
function Install-DesktopVersion([string]$HomeRoot,[string]$Source,[string]$MatlabExe,[string]$Cache) {
    $MatlabExe = [IO.Path]::GetFullPath($MatlabExe)
    if (-not (Test-Path -LiteralPath $MatlabExe -PathType Leaf) -or [IO.Path]::GetFileName($MatlabExe) -ne 'matlab.exe') { throw 'Please select the installed matlab.exe application.' }
    $release = Get-Content -Raw -LiteralPath (Join-Path $Source 'desktop\release.json') | ConvertFrom-Json
    Assert-DesktopRelease $release
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
    & (Join-Path $Source 'Install-EEGLAB.ps1') -Destination $candidate -Cache $Cache | ForEach-Object { Write-Host $_ }
    $setup = Join-Path $candidate 'setup'
    Copy-Item -LiteralPath $Source -Destination $setup -Recurse
    foreach ($name in 'eeglab_desktop_start.m','eeglab_practice.m','validate_desktop_update.m') {
        Copy-Item -LiteralPath (Join-Path $Source ('desktop\' + $name)) -Destination (Join-Path $candidate $name)
    }
    Test-DesktopCandidate $candidate $MatlabExe | ForEach-Object { Write-Host $_ }
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
function Get-DesktopUpdate($State) {
    $headers = @{'User-Agent'='MPG-EEGLAB-Launcher';Accept='application/vnd.github+json'}
    $releases = Invoke-RestMethod -Uri 'https://api.github.com/repos/MPG-Git/QuickLab/releases?per_page=30' -Headers $headers -TimeoutSec 5
    $eligible = @()
    foreach ($release in $releases) {
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
function Get-DesktopUpdateSource([string]$HomeRoot,$Update) {
    $folder = Join-Path $HomeRoot ('updates\' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($folder) | Out-Null
    $archive = Join-Path $folder 'update.zip'
    Invoke-WebRequest -UseBasicParsing -Uri $Update.url -OutFile $archive -TimeoutSec 180
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $Update.sha256) { throw 'The update download failed its integrity check.' }
    $source = Join-Path $folder 'payload'
    [IO.Directory]::CreateDirectory($source) | Out-Null
    $zip = [IO.Compression.ZipFile]::OpenRead($archive)
    try {
        foreach ($entry in $zip.Entries) {
            if ($entry.FullName.EndsWith('/')) { continue }
            $path = [IO.Path]::GetFullPath((Join-Path $source $entry.FullName))
            if (-not $path.StartsWith($source + '\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid update archive path.' }
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path)) | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$path,$false)
        }
    } finally { $zip.Dispose() }
    $release = Get-Content -Raw -LiteralPath (Join-Path $source 'desktop\release.json') | ConvertFrom-Json
    Assert-DesktopRelease $release
    if ($release.version -ne $Update.version -or $release.tag -ne $Update.tag) { throw 'The update package does not match its release.' }
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
