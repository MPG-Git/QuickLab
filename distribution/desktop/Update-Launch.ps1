param([Parameter(Mandatory=$true)][string]$HomeRoot,[ValidateSet('open','practice','rollback')][string]$Mode='open',[switch]$NoOpen)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Desktop-Common.ps1')
Add-Type -AssemblyName System.Windows.Forms
try { $lock = Open-DesktopLock $HomeRoot }
catch { Show-DesktopMessage 'Another EEGLAB update or launch is in progress. Please wait for it to finish, then try again.' 'EEGLAB update check' | Out-Null; return }
try {
    $state = Read-DesktopState $HomeRoot
    if (-not $state) { throw 'The installation is incomplete. Please run the setup application.' }
    if ($Mode -eq 'rollback') {
        try { $state = Undo-DesktopUpdate $HomeRoot $state }
        catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message,'EEGLAB previous version') | Out-Null }
        Start-DesktopMatlab $state 'open'
        return
    }
    $update = $null; $checked=$false
    do {
    $retry=$false
    try { $update = Invoke-DesktopUpdateCheck $HomeRoot $state; $checked=$true } catch {
        if (Get-Command Write-DesktopDiagnostic -ErrorAction SilentlyContinue) {
            $detail=New-UpdateDetail; Set-UpdateStage $detail 'check'; $detail=Get-UpdateFailureDetail $_ $detail
            if ($_.Exception.Data['updateDetail']) { $detail=$_.Exception.Data['updateDetail'] }
            Write-DesktopDiagnostic $HomeRoot $state.current.path 'update' 20 $detail
            Start-UpdateReportSender $HomeRoot $state.current.path
        }
        [IO.File]::AppendAllText((Join-Path $HomeRoot 'update-check.log'),[DateTime]::UtcNow.ToString('o') + ' Update check unavailable.' + [Environment]::NewLine)
        $cancel='Cancel: open your installed version.'
        if ($NoOpen) { $cancel='Cancel: continue working in your current session.' }
        $retry=(Show-DesktopMessage "Could not check for EEGLAB updates.`nInstalled version: $($state.current.version).`n`nCheck your internet connection, then click Retry.`n$cancel`n`nWe will check again next time." 'EEGLAB update check' 'RetryCancel') -eq 'Retry'
    }
    } while ($retry)
    # No means this launch only. Ignore legacy day-long deferrals; preserve
    # holdThroughVersion in selection so rollback is still respected.
    if ($update) {
        $answer = Show-DesktopMessage (Get-DesktopUpdatePrompt $state $update -NoOpen:$NoOpen) ('EEGLAB update to '+$update.version) 'YesNo'
        if ($answer -eq 'Yes') {
            $progress = New-Object Windows.Forms.Form
            $progress.Text = 'Updating EEGLAB'; $progress.Width=620; $progress.Height=210; $progress.StartPosition='CenterScreen'; $progress.ControlBox=$false
            $label = New-Object Windows.Forms.Label
            $label.Text="Installing EEGLAB Desktop $($update.version).`nMATLAB practice windows may open briefly.`nPlease keep this window open."
            $label.Font=New-Object Drawing.Font('Segoe UI',14); $label.Dock='Fill'; $label.Padding=New-Object Windows.Forms.Padding(20)
            $progress.Controls.Add($label); $progress.Show(); [Windows.Forms.Application]::DoEvents()
            try {
                $job = Join-Path $HomeRoot ('update-job-' + [guid]::NewGuid().ToString('N'))
                $descriptor = $job + '.json'
                $update | ConvertTo-Json | Set-Content -LiteralPath $descriptor -Encoding UTF8
                $workerScript = Join-Path $PSScriptRoot 'Apply-DesktopUpdate.ps1'
                $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $workerScript + '" -HomeRoot "' + $HomeRoot + '" -DescriptorPath "' + $descriptor + '"'
                $worker = Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput ($job + '.log') -RedirectStandardError ($job + '.error.log')
                # Windows PowerShell can otherwise lose ExitCode after a
                # redirected child exits, reporting a successful update as failed.
                $null=$worker.Handle
                while (-not $worker.WaitForExit(100)) { [Windows.Forms.Application]::DoEvents() }
                if ($worker.ExitCode -ne 0) { throw ('Update validation failed. Details: ' + $job + '.error.log') }
                $state = Read-DesktopState $HomeRoot
                if ($NoOpen) { $progress.Hide(); Show-DesktopMessage "EEGLAB Desktop $($state.current.version) is installed.`n`nSave your work, close MATLAB, and double-click EEGLAB 2026 to use it.`nYour current session has not changed." 'EEGLAB update complete' | Out-Null }
            } catch {
                # The worker queues the detailed failure before it exits. If it
                # could not start or died before capture, record a fallback.
                $recorded=$descriptor -and (Test-Path -LiteralPath ($descriptor+'.reported'))
                if (-not $recorded -and (Get-Command Write-DesktopDiagnostic -ErrorAction SilentlyContinue)) {
                    $detail=Get-UpdateFailureDetail $_ (New-UpdateDetail $update.version)
                    if ($worker -and $worker.HasExited) { $detail.exitCode=[int]$worker.ExitCode }
                    $recorded=Write-DesktopDiagnostic $HomeRoot $state.current.path 'update' 21 $detail -PassThru
                    Start-UpdateReportSender $HomeRoot $state.current.path
                }
                [IO.File]::AppendAllText((Join-Path $HomeRoot 'update-check.log'),[DateTime]::UtcNow.ToString('o') + ' ' + $_.Exception.Message + [Environment]::NewLine)
                $reportMessage='Automatic reporting is off. You can turn it on in Error reporting settings.'
                if (Test-ReportingConsent $HomeRoot) {
                    $reportMessage='Technical update details will be sent automatically. If offline, reporting will retry when you next open EEGLAB.'
                    if (-not $recorded) { $reportMessage='The automatic report could not be saved. Please tell Matt the update failed.' }
                }
                $retained='Your previous version will open.'
                if ($NoOpen) { $retained='Your current session and installed version are unchanged.' }
                Show-DesktopMessage ("The update could not finish. $retained`n`n"+$reportMessage) 'EEGLAB update needs help' | Out-Null
                $state = Read-DesktopState $HomeRoot
            } finally { $progress.Close(); $progress.Dispose() }
        }
    } elseif ($NoOpen -and $checked) {
        $hold=''
        if ([version]$state.holdThroughVersion -gt [version]$state.current.version) { $hold="`nVersion $($state.holdThroughVersion) is held after a rollback." }
        Show-DesktopMessage "Installed: EEGLAB Desktop $($state.current.version).`nNo newer eligible update is available.$hold" 'EEGLAB update check' | Out-Null
    }
    if (-not $NoOpen) { Start-DesktopMatlab $state $Mode }
} finally { $lock.Dispose() }
