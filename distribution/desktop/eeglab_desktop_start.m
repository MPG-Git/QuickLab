% Launch script: assignments must live in MATLAB's base workspace for menus.
eeglab_desktop_ready = false;
try
    [ALLEEG, EEG, CURRENTSET, ALLCOM] = start_eeglab_replacement;
    check_eeglab_replacement;
    eeglab_desktop_ready = true;
    eeglab_desktop_window = findall(groot,'Type','figure','Tag','EEGLAB');
    if numel(eeglab_desktop_window) == 1
        uimenu(eeglab_desktop_window,'Label','Practice data','Tag','mpg_practice', ...
            'Callback','eeglab_practice;');
    end
    fprintf('EEGLAB is ready. You can use your usual menus or click Practice data.\n');
catch eeglab_desktop_error
    disp(getReport(eeglab_desktop_error,'extended','hyperlinks','off'));
    errordlg({'EEGLAB could not finish opening.', ...
        'Please send Matt a picture of this message.', '', eeglab_desktop_error.message}, ...
        'EEGLAB needs help');
end
