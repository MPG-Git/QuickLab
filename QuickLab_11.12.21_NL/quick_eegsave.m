function EEG = quick_eegsave(EEG,suffix)
% QUICK_EEGSAVE Save a suffixed copy; ask before replacing an existing file.
% Original QuickLab: Copyright (C) 2021 Ugo Bruzadin Nunes, GPL-2.0-or-later.
if nargin < 2, suffix = 'sv'; end
if isempty(EEG.data), error('QuickLab:NoData','Load a dataset before saving.'); end
[filename,folder] = quicklab_save_target(EEG,suffix);
if isempty(folder) || ~isfolder(folder)
    [filename,folder] = uiputfile('*.set','Save EEG dataset',filename);
    if isequal(filename,0), return; end
else
    [~,stem] = fileparts(filename);
    if isfile(fullfile(folder,filename)) || isfile(fullfile(folder,[stem '.fdt']))
        answer = questdlg(sprintf('Replace the existing dataset %s?',filename), ...
            'Save dataset','Replace','Cancel','Cancel');
        if ~strcmp(answer,'Replace'), return; end
    end
end
EEG = pop_saveset(EEG,'filename',filename,'filepath',folder);
end
