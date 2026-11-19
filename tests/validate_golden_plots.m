function validate_golden_plots(output)
% Exercise actual restored callbacks, including two open windows/current EEG.
mkdir(output); source=fullfile(fileparts(which('eegplugin_QuickLab')),'examples','synthetic','data');
e=pop_loadset('filename','synthetic_rank3.set','filepath',source);
e=pop_saveset(e,'filename','first.set','filepath',output,'savemode','onefile');
other=e; other.data=other.data+10; other=pop_saveset(other,'filename','second.set','filepath',output,'savemode','onefile');
quicklab_publish(other); originalBase=evalin('base','EEG'); originalCwd=pwd;
before=findall(groot,'Type','figure'); pop_eegplot_w3(e,1,2,1,1); fig=setdiff(findall(groot,'Type','figure'),before); assert(isscalar(fig));
assert(strcmp(get(findall(fig,'Tag','plotICLABEL'),'Enable'),'off'));
assert(contains(get(findall(fig,'Tag','quicklab_editor_info'),'String'),'ICA - Rank: No / 3'));
g=get(fig,'UserData'); g.winrej=[1 10 .5 .5 .5 zeros(1,e.nbchan)]; set(fig,'UserData',g);
set(findall(fig,'Tag','SaveNowText'),'String','_marked'); invoke(findall(fig,'Tag','SaveNowButton'));
saved=pop_loadset('filename','first_marked.set','filepath',output);
assert(isequal(saved.chanrej,g.winrej) && isequal(saved.data,e.data));
assert(isequaln(originalBase,evalin('base','EEG')),'Saving an editor must not change another active dataset.');
quicklab_editor(fig,'folder',0); assert(strcmp(pwd,originalCwd));
quicklab_editor(fig,'folder',output); names=getappdata(fig,'editorFiles'); index=find(strcmp(names,'second.set'));
set(findall(fig,'Tag','FolderList'),'Value',index+1); invoke(findall(fig,'Tag','FolderList'));
assert(isgraphics(fig)); kept=get(fig,'UserData'); assert(isequal(kept.winrej,g.winrej));
assert(isequal(evalin('base','EEG.data'),other.data) && strcmp(pwd,originalCwd));
invoke(findall(fig,'Tag','SaveButton')); assert(isequal(evalin('base','EEG.data'),e.data));
current=evalin('base','EEG'); invoke(findall(fig,'Tag','EditorClose'));
assert(~isgraphics(fig) && isequaln(current,evalin('base','EEG')));
delete(setdiff(findall(groot,'Type','figure'),before));
e=quick_PCA(e,[],[],0); e=pop_iclabel(e,'default');
pop_viewprops2_par(e,0,[],[1 3],{'freqrange',[2 40]});
figs=setdiff(findall(groot,'Type','figure'),before); fig=figs(arrayfun(@(f)isappdata(f,'quicklab_component_source'),figs)); assert(isscalar(fig));
invoke(findall(fig,'String','Select All')); invoke(findall(fig,'String','Clear Values'));
assert(all(cell2mat(get(findall(fig,'Style','checkbox'),'Value'))==0));
invoke(findall(fig,'String','Plot Component Scroll')); scroll=gcf; scrollState=get(scroll,'UserData');
assert(scrollState.EEG.plotchannels==0 && isequal(scrollState.EEG.data,e.data));
quicklab_editor(scroll,'close');
previous=findall(groot,'Type','figure'); button=findall(fig,'Tag','comp1'); cb=get(button,'Callback'); cb{1}(button,[],cb{2:end});
details=setdiff(findall(groot,'Type','figure'),previous); assert(~isempty(details)); delete(details);
set(findall(fig,'Style','checkbox','Tag','3'),'Value',1);
quicklab_publish(other); invoke(findall(fig,'String','Add Comps to Rej list'));
stored=evalin('base','EEG'); assert(isequal(stored.reject.gcompreject,logical([0 0 1])) && isequal(stored.data,e.data));
ep=e; ep.data=reshape(ep.data(:,1:floor(ep.pnts/20)*20),ep.nbchan,[],20); ep.trials=20; ep.pnts=size(ep.data,2);
ep.xmax=(ep.pnts-1)/ep.srate; ep.times=(0:ep.pnts-1)/ep.srate*1000; ep.event=[]; ep.epoch=[]; ep.icaact=[];
pop_viewprops_erp(ep,0,1:3,{'freqrange',[2 40]},{},1,'',[],struct('channels',1,'eventTypes',[]));
figs=setdiff(findall(groot,'Type','figure'),before); fig=figs(arrayfun(@(f)isappdata(f,'quicklab_component_source'),figs)); assert(isscalar(fig));
set(findall(fig,'Style','checkbox','Tag','2'),'Value',1);
expected=pop_subcomp(ep,2,0); invoke(findall(fig,'String','Remove Components'));
actual=evalin('base','EEG'); assert(max(abs(actual.data(:)-expected.data(:)))<1e-5);
pop_viewprops2_par(e,0,[],1:3,{'freqrange',[2 40]});
figs=setdiff(findall(groot,'Type','figure'),before); fig=figs(arrayfun(@(f)isappdata(f,'quicklab_component_source'),figs));
invoke(findall(fig,'String','Reject & N-1 PCA')); assert(size(evalin('base','EEG.icaweights'),1)==2);
quick_spectra(e,40,2,'AVG'); f=gcf; assert(isa(get(findall(f,'Tag','save'),'Callback'),'function_handle'));
quicklab_publish(other); quicklab_save_figure(f,e,fullfile(output,'firstFFT.jpg')); assert(isfile(fullfile(output,'firstFFT.jpg')));
delete(setdiff(findall(groot,'Type','figure'),before));
% Epoched editor uses the same controls and closes without reloading.
e.data=reshape(e.data(:,1:floor(e.pnts/4)*4),e.nbchan,[],4); e.trials=4; e.pnts=size(e.data,2); e.xmax=(e.pnts-1)/e.srate; e.event=[]; e.icaact=[];
pop_eegplot_w3(e,1,2,1,1); f=gcf; assert(contains(get(findall(f,'Tag','quicklab_editor_info'),'String'),'Epochs-Events: 4 / 0'));
assert(strcmp(get(findall(f,'Tag','plotICLABEL'),'Enable'),'on')); invoke(findall(f,'Tag','EditorClose'));
fprintf('PASS: Golden editor save, retained marks, folder navigation, close, component selection/removal and FFT export callbacks.\n');
end

function invoke(h)
assert(isscalar(h)); cb=get(h,'Callback'); cb(h,[]);
end
