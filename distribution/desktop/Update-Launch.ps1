param([Parameter(Mandatory=$true)][string]$HomeRoot,[ValidateSet('open','practice','rollback')][string]$Mode='open')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Desktop-Common.ps1')
Add-Type -AssemblyName System.Windows.Forms
$lock = Open-DesktopLock $HomeRoot
try {
    $state = Read-DesktopState $HomeRoot
    if (-not $state) { throw 'The installation is incomplete. Please run the setup application.' }
    if ($Mode -eq 'rollback') {
        try { $state = Undo-DesktopUpdate $HomeRoot $state }
        catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message,'EEGLAB previous version') | Out-Null }
        Start-DesktopMatlab $state 'open'
        return
    }
    $update = $null
    try { $update = Get-DesktopUpdate $state } catch {
        if (Get-Command Write-DesktopDiagnostic -ErrorAction SilentlyContinue) {
            $detail=New-UpdateDetail; Set-UpdateStage $detail 'check'; $detail=Get-UpdateFailureDetail $_ $detail
            Write-DesktopDiagnostic $HomeRoot $state.current.path 'update' 20 $detail
            Start-UpdateReportSender $HomeRoot $state.current.path
        }
        [IO.File]::AppendAllText((Join-Path $HomeRoot 'update-check.log'),[DateTime]::UtcNow.ToString('o') + ' Update check unavailable.' + [Environment]::NewLine)
    }
    $deferred = $update -and $state.deferredVersion -eq $update.version -and $state.deferredUntilUtc -and [DateTime]::Parse($state.deferredUntilUtc).ToUniversalTime() -gt [DateTime]::UtcNow
    if ($update -and -not $deferred) {
        $answer = [Windows.Forms.MessageBox]::Show("A tested EEGLAB update is available.`n`nUpdate and open EEGLAB?`n`nYes: install and check the update first.`nNo: open your current version.",'EEGLAB update',[Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Information)
        if ($answer -eq [Windows.Forms.DialogResult]::Yes) {
            $progress = New-Object Windows.Forms.Form
            $progress.Text = 'Updating EEGLAB'; $progress.Width=620; $progress.Height=210; $progress.StartPosition='CenterScreen'; $progress.ControlBox=$false
            $label = New-Object Windows.Forms.Label
            $label.Text="Downloading and checking your update.`nMATLAB practice windows may open briefly.`nPlease keep this window open."
            $label.Font=New-Object Drawing.Font('Segoe UI',14); $label.Dock='Fill'; $label.Padding=New-Object Windows.Forms.Padding(20)
            $progress.Controls.Add($label); $progress.Show(); [Windows.Forms.Application]::DoEvents()
            try {
                $job = Join-Path $HomeRoot ('update-job-' + [guid]::NewGuid().ToString('N'))
                $descriptor = $job + '.json'
                $update | ConvertTo-Json | Set-Content -LiteralPath $descriptor -Encoding UTF8
                $workerScript = Join-Path $PSScriptRoot 'Apply-DesktopUpdate.ps1'
                $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $workerScript + '" -HomeRoot "' + $HomeRoot + '" -DescriptorPath "' + $descriptor + '"'
                $worker = Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput ($job + '.log') -RedirectStandardError ($job + '.error.log')
                while (-not $worker.WaitForExit(100)) { [Windows.Forms.Application]::DoEvents() }
                if ($worker.ExitCode -ne 0) { throw ('Update validation failed. Details: ' + $job + '.error.log') }
                $state = Read-DesktopState $HomeRoot
            } catch {
                # The worker queues the detailed failure before it exits. If it
                # could not start, record that failure here as well.
                if (-not $worker -and (Get-Command Write-DesktopDiagnostic -ErrorAction SilentlyContinue)) {
                    $detail=Get-UpdateFailureDetail $_ (New-UpdateDetail $update.version)
                    Write-DesktopDiagnostic $HomeRoot $state.current.path 'update' 21 $detail
                    Start-UpdateReportSender $HomeRoot $state.current.path
                }
                [IO.File]::AppendAllText((Join-Path $HomeRoot 'update-check.log'),[DateTime]::UtcNow.ToString('o') + ' ' + $_.Exception.Message + [Environment]::NewLine)
                $reportMessage='Automatic reporting is off. You can turn it on in Error reporting settings.'
                if (Test-ReportingConsent $HomeRoot) { $reportMessage='Technical update details will be sent automatically. If offline, reporting will retry when you next open EEGLAB.' }
                [Windows.Forms.MessageBox]::Show("The update could not finish. Your previous version will open.`n`n"+$reportMessage,'EEGLAB update needs help') | Out-Null
                $state = Read-DesktopState $HomeRoot
            } finally { $progress.Close(); $progress.Dispose() }
        } else {
            $state.deferredVersion=$update.version; $state.deferredUntilUtc=[DateTime]::UtcNow.AddDays(1).ToString('o')
            Save-DesktopState $HomeRoot $state
        }
    }
    Start-DesktopMatlab $state $Mode
} finally { $lock.Dispose() }
