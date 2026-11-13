function EEG = quick_highpass(EEG,cutoff)
% QUICK_HIGHPASS Apply the high-pass filter selected in QuickLab's menu.
EEG = pop_eegfiltnew(EEG,'locutoff',cutoff,'plotfreqz',1);
end
