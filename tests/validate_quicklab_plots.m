function validate_quicklab_plots
% Open the familiar QuickLab scroll and component displays with synthetic EEG.
folder=fullfile(fileparts(which('eegplugin_QuickLab')),'examples','synthetic','data');
e=pop_loadset('filename','synthetic_rank3.set','filepath',folder);
e=quick_PCA(e,[],[],0);
before=findall(groot,'Type','figure');
pop_eegplot_w3(e,1,2,1,1);
figs=setdiff(findall(groot,'Type','figure'),before); assert(~isempty(figs));
for tag={'SaveNowButton','SWITCH','Rejection','Display','ClearMarks'}
    assert(~isempty(findall(figs,'Tag',tag{1})),['Missing familiar scroll control: ' tag{1}]);
end
% Delete test figures directly so their Accept/Save close callbacks do not run.
delete(figs);
e=quick_IClabel(e);
assert(size(e.etc.ic_classification.ICLabel.classifications,1)==3);
figs=setdiff(findall(groot,'Type','figure'),before); assert(~isempty(figs));
delete(figs);
fprintf('PASS: QuickLab scroll save/mode/mark controls and three-component ICLabel/Viewprops plots.\n');
end
