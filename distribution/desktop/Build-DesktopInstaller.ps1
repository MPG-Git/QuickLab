[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
$source = Split-Path -Parent $PSScriptRoot
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$output = [IO.Path]::GetFullPath($OutputDirectory)
$zipPath = Join-Path $output 'SetupPayload.zip'
if (Test-Path -LiteralPath $zipPath) { throw 'Choose a fresh output directory.' }
$zip = [IO.Compression.ZipFile]::Open($zipPath,[IO.Compression.ZipArchiveMode]::Create)
try {
    $files = @('Install-EEGLAB.ps1','manifest.json','README.md','VALIDATION.md','PLUGIN_INVENTORY.md','start_eeglab_replacement.m','check_eeglab_replacement.m','run_replacement_examples.m','desktop/Complete-DesktopSetup.ps1','desktop/eeglab_desktop_start.m','desktop/eeglab_practice.m','desktop/release.json','desktop/Launch-EEGLAB.ps1','desktop/Desktop-Common.ps1','desktop/Update-Launch.ps1','desktop/validate_desktop_update.m')
    $files += 'desktop/Apply-DesktopUpdate.ps1'
    $files += 'desktop/UPDATING.md'
    $files += @('desktop/Reporting-Common.ps1','desktop/Reporting-Worker.ps1','desktop/reporting.json','desktop/diagnostic-sources.json','desktop/eeglab_diagnostics.m','desktop/REPORTING.md')
    foreach ($file in $files) { [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,(Join-Path $source $file),$file) | Out-Null }
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,(Join-Path (Split-Path -Parent $source) 'LICENSE'),'LICENSE') | Out-Null
} finally { $zip.Dispose() }
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$exe = Join-Path $output 'EEGLAB2026-Setup.exe'
& $compiler /nologo /target:winexe /platform:anycpu /optimize+ /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll ("/resource:$zipPath,SetupPayload.zip") ("/out:$exe") (Join-Path $PSScriptRoot 'Setup.cs')
if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed.' }
Copy-Item -LiteralPath $zipPath -Destination (Join-Path $output 'EEGLAB2026-Update.zip')
Get-FileHash -LiteralPath $exe -Algorithm SHA256
