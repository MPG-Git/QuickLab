function outputs=quicklab_reference_compare(eeg,rows)
% Create independent REST, FieldTrip Infinity and Average copies, then compare.
outputs=[];
if nargin<2
    [rows,ok]=listdlg('ListString',{eeg.chanlocs.labels},'SelectionMode','multiple', ...
        'PromptString',{'Select scalp EEG channels with the same original reference.', ...
        'Requires head-centered EEGLAB XYZ locations; exclude EOG/ECG/other sensors.'}, ...
        'Name','REST / Infinity / Average','ListSize',[480 300]);
    if ~ok, return; end
end
[rest,model]=quick_rest_reference(eeg,'rest',rows);
infinity=quick_rest_reference(eeg,'infinity',rows,model);
average=quick_rest_reference(eeg,'average',rows);
assert(max(abs(rest.data(:)-infinity.data(:)))<1e-6*max(1,max(abs(rest.data(:)))), ...
    'QuickLab:RESTAgreement','REST and FieldTrip did not agree with the same leadfield.');
outputs=[rest infinity average];
for k=1:3, quicklab_publish(outputs(k)); end
plotDifference(infinity,average);
end
