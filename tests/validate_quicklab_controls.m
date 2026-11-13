function validate_quicklab_controls(folder)
% Integration test in an isolated running EEGLAB session, synthetic data only.
assert(~isfolder(folder),'Use a fresh fixture folder.'); mkdir(folder);
empty=fullfile(folder,'empty'); mkdir(empty);
e=eeg_emptyset; rng(32,'twister'); e.data=single(randn(4,1000)); e.nbchan=4;
e.pnts=1000; e.trials=1; e.srate=250; e.xmax=999/250;
e.setname='Synthetic controls A';
a=pop_saveset(e,'filename','A.set','filepath',folder);
e.data=e.data*2; e.setname='Synthetic controls B';
pop_saveset(e,'filename','B.set','filepath',folder);
assignin('base','ALLEEG',[]); assignin('base','CURRENTSET',0); assignin('base','EEG',a);
fig=findall(groot,'Tag','EEGLAB'); assert(isscalar(fig));
quicklab_controls(fig); quicklab_controls(fig,'refresh');
assert(numel(findall(fig,'Tag','quicklab_controls'))==1);
before=pwd;
% Real callbacks, including redraw listeners and previous/next boundary states.
next=findall(fig,'Tag','LoadDown'); callback=get(next,'Callback'); callback(next,[]);
e=evalin('base','EEG'); assert(strcmp(e.filename,'B.set'));
assert(strcmp(get(next,'Enable'),'off'));
previous=findall(fig,'Tag','LoadUp'); callback=get(previous,'Callback'); callback(previous,[]);
e=evalin('base','EEG'); assert(strcmp(e.filename,'A.set'));
assert(strcmp(get(previous,'Enable'),'off'));
% Unsaved changes survive navigation in ALLEEG.
e.data=e.data+3; e.saved='no'; assignin('base','EEG',e);
quicklab_controls(fig,'next'); all=evalin('base','ALLEEG');
assert(any(arrayfun(@(x)isequal(x.data,e.data),all)));
quicklab_controls(fig,'folder',empty);
assert(strcmp(get(next,'Enable'),'off'));
assert(strcmp(get(findall(fig,'Tag','LoadFileList2'),'Enable'),'off'));
quicklab_controls(fig,'folder',0); % cancellation
quicklab_controls(fig,'folder',folder);
set(findall(fig,'Tag','SAVETEXT2'),'String','_copy');
saveButton=findall(fig,'Tag','SAVEASBUTTON2'); callback=get(saveButton,'Callback'); callback(saveButton,[]);
e=evalin('base','EEG'); assert(strcmp(e.filename,'B_copy.set'));
loaded=pop_loadset('filename','B_copy.set','filepath',folder); assert(isequal(loaded.data,e.data));
assert(strcmp(before,pwd));
evalin('base','eeglab redraw;');
assert(contains(get(findall(fig,'Tag','quicklab_rank'),'String'),'Rank: 4/4'));
report=quicklab_dependency_report(fig,false);
assert(numel(report.functions)>25 && isempty(report.missingFunctions));
fprintf('PASS: controls attach/redraw, save/reload, folder/cancel/empty, previous/next and unsaved dataset retention.\n');
end
