function [EEG,com] = quick_dotloc(EEG)

%mybadcomps = find(EEG.reject.gcompreject);   %stores the Id of the components to be rejected

[EEG,com] = quick_HM94(EEG);

[EEG,com] = quick_epoch(EEG,0.600,2.648);

%[EEG,com] = quick_bss2(EEG);

[EEG,com] = quick_PCA(EEG,[],[],0);

EEG = quick_eegsave(EEG,'Hm92Ep6ICA');

%eeglab redraw
end