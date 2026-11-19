function quicklab_publish(next)
% Retain the active dataset, then add the result as a new EEGLAB dataset.
alleeg=evalin('base','ALLEEG'); current=evalin('base','CURRENTSET'); eeg=evalin('base','EEG');
if isstruct(eeg) && isscalar(eeg) && ~isempty(eeg.data)
    saved=eeg.saved; [alleeg,~,index]=eeg_store(alleeg,eeg,current); alleeg(index).saved=saved;
end
[alleeg,next,current]=eeg_store(alleeg,next,0);
assignin('base','ALLEEG',alleeg); assignin('base','EEG',next); assignin('base','CURRENTSET',current);
evalin('base','eeglab redraw;');
end
