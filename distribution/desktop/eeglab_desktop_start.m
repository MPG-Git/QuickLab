% Launch script: assignments must live in MATLAB's base workspace for menus.
eeglab_desktop_ready = false;
try
    [ALLEEG, EEG, CURRENTSET, ALLCOM] = start_eeglab_replacement;
    % EEGLAB clears functions during startup; attach the monitor afterwards.
    try, eeglab_diagnostics('init'); catch, end
    check_eeglab_replacement;
    eeglab_desktop_ready = true;
    eeglab_desktop_window = findall(groot,'Type','figure','Tag','EEGLAB');
    if numel(eeglab_desktop_window) == 1
        desktopRoot=fileparts(mfilename('fullpath'));
        desktopRelease=jsondecode(fileread(fullfile(desktopRoot,'setup','desktop','release.json')));
        desktopUpdates=uimenu(eeglab_desktop_window,'Label',['Updates (' desktopRelease.version ')'],'Tag','mpg_updates');
        uimenu(desktopUpdates,'Label','Check for updates','Tag','mpg_check_updates', ...
            'Callback',@(src,event) checkDesktopUpdates(desktopRoot));
        uimenu(eeglab_desktop_window,'Label','Practice data','Tag','mpg_practice', ...
            'Callback','eeglab_practice;');
        uimenu(eeglab_desktop_window,'Label','Get error report','Tag','mpg_error_report', ...
            'Callback','eeglab_diagnostics(''export'');');
        uimenu(eeglab_desktop_window,'Label','Error reporting settings','Tag','mpg_error_settings', ...
            'Callback','eeglab_diagnostics(''settings'');');
    end
    fprintf('EEGLAB is ready. You can use your usual menus or click Practice data.\n');
    try, eeglab_diagnostics('offer'); catch, end
catch eeglab_desktop_error
    try, eeglab_diagnostics('capture',eeglab_desktop_error,'startup'); catch, end
    disp(getReport(eeglab_desktop_error,'extended','hyperlinks','off'));
    errordlg({'EEGLAB could not finish opening.', ...
        'Please send Matt a picture of this message.', '', eeglab_desktop_error.message}, ...
        'EEGLAB needs help');
end

function checkDesktopUpdates(versionRoot)
% Start the installed controller without closing or changing this session.
% Read the active version so an older open session checks the current updater.
try
    managedHome=fileparts(fileparts(versionRoot));
    state=jsondecode(fileread(fullfile(managedHome,'state.json')));
    activeRoot=char(System.IO.Path.GetFullPath(state.current.path));
    expectedRoot=[char(System.IO.Path.GetFullPath(fullfile(managedHome,'versions'))) filesep];
    assert(startsWith(lower(activeRoot),lower(expectedRoot)),'Invalid managed installation path.');
    info=System.Diagnostics.ProcessStartInfo();
    info.FileName=fullfile(getenv('WINDIR'),'System32','WindowsPowerShell','v1.0','powershell.exe');
    info.Arguments=sprintf('-NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%s" -HomeRoot "%s" -NoOpen', ...
        fullfile(activeRoot,'setup','desktop','Update-Launch.ps1'),managedHome);
    info.UseShellExecute=false; info.CreateNoWindow=true;
    System.Diagnostics.Process.Start(info);
catch exception
    errordlg({'The update check could not open.','Save your work, close MATLAB, and use the EEGLAB 2026 desktop shortcut.',exception.message},'EEGLAB update check');
end
end
