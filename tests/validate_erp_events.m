function validate_erp_events
% Selecting event A must exclude the twenty B epochs in the actual ERP image.
folder=fullfile(fileparts(which('eegplugin_QuickLab')),'examples','synthetic','data');
e=pop_loadset('filename','synthetic_rank3.set','filepath',folder);
e=quick_PCA(e,[],'runica',0);
e.data=reshape(e.data,4,50,40); e.pnts=50; e.trials=40;
e.xmax=49/e.srate; e.times=(0:49)*1000/e.srate; e.icaact=[]; e.event=[]; e.epoch=[];
for k=1:40
    kind='A'; if mod(k,2)==0, kind='B'; end
    e.event(k).type=kind; e.event(k).latency=(k-1)*50+1+mod(k,10); e.event(k).epoch=k;
end
e=eeg_checkset(e,'eventconsistency');
before=findall(groot,'Type','figure');
pop_viewprops_erp(e,0,1,{},{},1,'',[],struct('channels',1,'eventTypes',{{'A'}}));
imgs=findall(gcf,'Type','image'); assert(~isempty(imgs));
sizes=arrayfun(@(x) size(get(x,'CData'),1),imgs); assert(any(sizes==11));
delete(setdiff(findall(groot,'Type','figure'),before));
fprintf('PASS: ERP event selector excludes unmatched epochs and plots selected event latencies.\n');
end
