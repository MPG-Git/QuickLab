function eeglab_practice()
% Run known-answer examples without typing commands or altering loaded EEG.
root = fileparts(mfilename('fullpath'));
try
    resultsRoot = fullfile(root,'practice_results');
    if ~isfolder(resultsRoot), mkdir(resultsRoot); end
    output = tempname(resultsRoot);
    run_replacement_examples(output);
    winopen(output);
    msgbox({'Both practice examples passed.', ...
        'The results folder is open. QuickLab contains the comparison pictures.', ...
        'Your own recordings were not used or changed.'}, ...
        'Practice completed','help');
catch exception
    try, eeglab_diagnostics('capture',exception,'practice'); catch, end
    disp(getReport(exception,'extended','hyperlinks','off'));
    errordlg({'The practice check did not finish.', ...
        'Please send Matt a picture of this message.', '', exception.message}, ...
        'Practice needs help');
end
end
