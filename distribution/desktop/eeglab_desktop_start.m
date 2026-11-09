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
