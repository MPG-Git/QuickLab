<#
.SYNOPSIS
Build a separate EEGLAB 2026.1.0 installation with the 53-plugin inventory.
.EXAMPLE
powershell -File .\Install-EEGLAB.ps1 -Destination C:\EEGLAB_2026_New
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Destination,
    [string]$Cache = (Join-Path $env:LOCALAPPDATA 'EEGLAB-download-cache'),
    $Diagnostic=$null
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.IO.Compression.FileSystem
. (Join-Path $PSScriptRoot 'desktop\Update-Diagnostics.ps1')
$manifestPath = Join-Path $PSScriptRoot 'manifest.json'
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$target = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $target) {
    throw 'Destination already exists. Choose a new empty destination; existing installations are never overwritten.'
}
New-Item -ItemType Directory -Path $target | Out-Null
New-Item -ItemType Directory -Path $Cache -Force | Out-Null
$Cache = [IO.Path]::GetFullPath($Cache)

function Get-VerifiedArchive($item, [string]$cacheName) {
    Set-UpdateStage $Diagnostic 'download' $item.name
    $legacyPath = Join-Path $Cache $cacheName
    if ((Test-Path -LiteralPath $legacyPath) -and (Get-FileHash -LiteralPath $legacyPath -Algorithm SHA256).Hash -eq $item.sha256) { return $legacyPath }
    $zipPath = Join-Path $Cache ($item.name + '-' + $item.sha256 + '.zip')
    if (-not (Test-Path -LiteralPath $zipPath)) {
        Write-Host "Downloading $($item.name) $($item.version)..."
        $partial = $zipPath + '.' + [guid]::NewGuid().ToString('N') + '.partial'
        Invoke-WebRequest -UseBasicParsing -Uri $item.url -OutFile $partial -TimeoutSec 180
        Set-UpdateStage $Diagnostic 'integrity' $item.name
        if ((Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash -ne $item.sha256) { if ($Diagnostic) { $Diagnostic.reason='hash-mismatch' }; throw "Checksum mismatch for $($item.name). The current installation has not been changed." }
        Move-Item -LiteralPath $partial -Destination $zipPath
    }
    if ((Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash -ne $item.sha256) {
        if ($Diagnostic) { $Diagnostic.stage='integrity'; $Diagnostic.reason='hash-mismatch' }
        throw "Checksum mismatch: $zipPath. The upstream archive may have changed; do not use this incomplete installation."
    }
    return $zipPath
}

function Expand-SelectedArchive([string]$zipPath, [string]$prefix, [string]$destination, [switch]$Core, [switch]$SyntheticOnly, [switch]$FileioWithFieldTrip, [switch]$Binica) {
    if ($Diagnostic) { $Diagnostic.stage='extract'; $Diagnostic.reason='unknown' }
    $fullDestination = [IO.Path]::GetFullPath($destination)
    $boundary = $fullDestination.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    [IO.Directory]::CreateDirectory($fullDestination) | Out-Null
    $zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
    $count = 0
    try {
        foreach ($entry in $zip.Entries) {
            $name = $entry.FullName.Replace('\','/')
            if (-not $name.StartsWith($prefix, [StringComparison]::Ordinal)) { continue }
            $relative = $name.Substring($prefix.Length)
            if (-not $relative -or $relative.EndsWith('/') -or $relative.StartsWith('__MACOSX/')) { continue }
            # Replace the four bundled plugins from the pinned plugin archives.
            # EEG-BIDS remains as supplied by the official EEGLAB distribution.
            if ($Core -and $relative -match '^plugins/' -and $relative -notmatch '^plugins/EEG-BIDS/') { continue }
            # Legacy QuickLab recordings have no synthetic-data provenance.
            if ($SyntheticOnly -and $relative -match '\.(set|fdt)$' -and $relative -notmatch '^examples/synthetic/') { continue }
            # Fileio's standalone bootstrap duplicates FieldTrip's initializer.
            # This bundle always supplies the full FieldTrip-lite initializer.
            # Keep every Fileio reader/writer; do not disable FieldTrip warnings.
            if ($FileioWithFieldTrip -and $relative -eq 'ft_defaults.m') { continue }
            # Keep the Windows runtime, corresponding source/build files and
            # license. Do not distribute upstream example EEG recordings.
            if ($Binica -and $relative -notmatch '^(ica_windows\.exe|libopenblas\.dll|License\.txt|README\.md|readme\.txt|Makefile[^/]*|src/.*|include/.*)$') { continue }
            $path = [IO.Path]::GetFullPath((Join-Path $fullDestination $relative))
            if (-not $path.StartsWith($boundary, [StringComparison]::OrdinalIgnoreCase)) {
                if ($Diagnostic) { $Diagnostic.reason='archive-invalid' }
                throw "Archive entry escapes its destination: $name"
            }
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path)) | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $path, $false)
            $count++
        }
    } finally { $zip.Dispose() }
    if ($count -eq 0) { if ($Diagnostic) { $Diagnostic.reason='source-missing' }; throw "No files extracted from $zipPath with prefix $prefix" }
    return $count
}

# A failed build has no COMPLETE.json marker and must not be used.
$core = Join-Path $target 'eeglab2026.1.0'
$archive = Get-VerifiedArchive $manifest.base 'eeglab2026.1.0.zip'
$null = Expand-SelectedArchive $archive $manifest.base.archive_root $core -Core
# Keep the rank disagreement visible but remove the incorrect OS diagnosis.
$icaFile = Join-Path $core 'functions\popfunc\pop_runica.m'
$icaText = [IO.File]::ReadAllText($icaFile)
$rankMessage = 'Warning: fixing rank computation inconsistency (%d vs %d) most likely because running under Linux 64-bit Matlab, taking the minimum'
if ($icaText.Split(@($rankMessage),[StringSplitOptions]::None).Length -ne 2) { throw 'Review upstream ICA rank message before updating this patch.' }
[IO.File]::WriteAllText($icaFile,$icaText.Replace($rankMessage,'Note: data rank estimates differ (%d vs %d); EEGLAB uses the smaller estimate.'),(New-Object Text.UTF8Encoding($false)))
$installed = @()
foreach ($plugin in $manifest.plugins) {
    $archive = Get-VerifiedArchive $plugin ($plugin.name + '.zip')
    $folder = Join-Path (Join-Path $core 'plugins') $plugin.folder
    $fileioWithFieldTrip = $plugin.name -eq 'Fileio' -and @($manifest.plugins | Where-Object { $_.name -eq 'Fieldtrip-lite' }).Count -eq 1
    $count = Expand-SelectedArchive $archive $plugin.archive_root $folder -SyntheticOnly:($plugin.name -eq 'QuickLab') -FileioWithFieldTrip:$fileioWithFieldTrip
    if ($plugin.name -eq 'EYE-EEG') {
        # The official 1.0.1 archive labels its hook "1.01"; normalize only
        # that known metadata spelling, with a guard against upstream changes.
        $hook = Join-Path $folder 'eegplugin_eye_eeg.m'
        $text = [IO.File]::ReadAllText($hook)
        $old = "vers = 'eye_eeg_v1.01';"
        if ($plugin.version -ne '1.0.1' -or $text.Split(@($old),[StringSplitOptions]::None).Length -ne 2) { throw 'Review EYE-EEG version metadata for this archive.' }
        [IO.File]::WriteAllText($hook,$text.Replace($old,"vers = '1.0.1';"),(New-Object Text.UTF8Encoding($false)))
    }
    $installed += [pscustomobject]@{name=$plugin.name;version=$plugin.version;files=$count;sha256=$plugin.sha256}
    Write-Host "Installed $($plugin.name) $($plugin.version) ($count files)"
}
foreach ($dependency in $manifest.dependencies) {
    $archive = Get-VerifiedArchive $dependency ($dependency.name + '.zip')
    $folder = Join-Path (Join-Path $target 'dependencies') $dependency.folder
    $null = Expand-SelectedArchive $archive $dependency.archive_root $folder -Binica:($dependency.name -eq 'BINICA')
    Write-Host "Installed supplemental dependency $($dependency.name)"
}
Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $target 'manifest.json')
foreach ($file in 'start_eeglab_replacement.m','check_eeglab_replacement.m','run_replacement_examples.m','README.md','VALIDATION.md','PLUGIN_INVENTORY.md','VERSION_AUDIT.md') {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $target $file)
}
$installed | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $target 'COMPLETE.json') -Encoding UTF8
Write-Host "Installed $($installed.Count) inventoried plugins plus bundled EEG-BIDS."
Write-Host "In a new MATLAB session, change to $target and run start_eeglab_replacement."
Write-Host 'Download/install success is not a claim that every plugin workflow has been tested.'
