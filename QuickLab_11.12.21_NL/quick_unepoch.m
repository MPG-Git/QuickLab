function [EEG,com] = quick_unepoch(EEG)
% QUICK_UNEPOCH Concatenate retained epochs, marking every discontinuity.
% [EEG,com] = quick_unepoch(EEG) supports the historical two-output menu call.
% Samples stay in stored epoch order. This cannot recover discarded samples,
% gaps, or the original recording timeline; boundary durations are unknown.
com = '';
assert(isstruct(EEG) && isscalar(EEG) && isnumeric(EEG.data) && ~isempty(EEG.data), ...
    'QuickLab:NoData','Load an EEG dataset before converting to continuous data.');
assert(isscalar(EEG.srate) && isfinite(EEG.srate) && EEG.srate>0 && ndims(EEG.data)<=3 && ...
    isequal([size(EEG.data,1) size(EEG.data,2) size(EEG.data,3)], ...
    [EEG.nbchan EEG.pnts EEG.trials]), ...
    'QuickLab:InvalidEpochs','Dataset dimensions or sampling rate are inconsistent.');
if EEG.trials==1 && isempty(EEG.epoch) && ~isfield(EEG.event,'epoch')
    fprintf('Nothing done. Dataset is already continuous.\n');
    return;
end

trials=EEG.trials; points=EEG.pnts;
provenance=struct('trials',trials,'pointsPerEpoch',points,'epochStartSeconds',EEG.xmin, ...
    'epochEndSeconds',EEG.xmax,'epochRejection',EEG.reject, ...
    'note','Retained epochs concatenated in stored order; original gaps are unknown.');
EEG.data=reshape(EEG.data,EEG.nbchan,points*trials);
if ~isempty(EEG.icaact)
    assert(numel(EEG.icaact)==size(EEG.icaact,1)*points*trials, ...
        'QuickLab:InvalidEpochs','ICA activation dimensions do not match the epochs.');
    EEG.icaact=reshape(EEG.icaact,size(EEG.icaact,1),points*trials);
end
% EEGLAB event latencies already count samples across the stored epochs.
% Preserve all event types (including X) and their original urevent links.
if isfield(EEG.event,'epoch'), EEG.event=rmfield(EEG.event,'epoch'); end
boundaryType=eeg_boundarytype(EEG);
for k=1:trials-1
    % A boundary lies BETWEEN the last sample of one epoch and the next.
    EEG.event(end+1).type=boundaryType;
    EEG.event(end).latency=k*points+.5;
    EEG.event(end).duration=NaN;
end
EEG.trials=1; EEG.pnts=points*trials; EEG.epoch=[];
EEG.xmin=0; EEG.xmax=(EEG.pnts-1)/EEG.srate;
EEG.times=(0:EEG.pnts-1)/EEG.srate*1000;
% Epoch rejection arrays and cached spectra no longer describe this shape.
marks=[];
if isfield(EEG.reject,'gcompreject'), marks=EEG.reject.gcompreject; end
EEG.reject=struct('gcompreject',marks);
EEG.specdata=[]; EEG.specicaact=[];
if isempty(EEG.etc), EEG.etc=struct; end
EEG.etc.quicklab_unepoch=provenance;
EEG.setname=[EEG.setname ' continuous']; EEG.filename=''; EEG.datfile=''; EEG.saved='no';
EEG=eeg_checkset(EEG,'eventconsistency');
com='EEG = quick_unepoch(EEG);';
end
