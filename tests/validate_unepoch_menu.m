function validate_unepoch_menu(output)
% Exercise the real QuickLab menu and original REST GUI callbacks.
assert(~isfolder(output),'Choose a fresh output directory.'); mkdir(output);
plugin=fileparts(which('eegplugin_QuickLab')); addpath(fullfile(plugin,'examples','synthetic'));
run_unepoch_demo(fullfile(output,'example'));
e=pop_loadset('filename','synthetic_epoched.set','filepath',fullfile(output,'example'));
original=e; assignin('base','ALLEEG',e); assignin('base','EEG',e); assignin('base','CURRENTSET',1);
evalin('base','eeglab redraw;');
main=findall(groot,'Tag','EEGLAB'); menu=findall(main,'Type','uimenu','Label','UN-Epoch (Back to Continuous)');
assert(isscalar(menu) && strcmp(get(menu,'Enable'),'on'));
callback=get(menu,'Callback'); evalin('base',callback);
out=evalin('base','EEG'); all=evalin('base','ALLEEG');
assert(out.trials==1 && out.pnts==1000 && evalin('base','CURRENTSET')==2);
assert(isequaln(all(1).data,original.data) && all(1).trials==4);
assert(contains(out.history,'quick_unepoch'));
evalin('base',callback); assert(numel(evalin('base','ALLEEG'))==2,'Continuous no-op created another dataset.');

% Supply the same leadfield to the original REST GUI that the example uses.
ref=pop_loadset('filename','synthetic_REST.set','filepath',fullfile(plugin,'examples','synthetic','rest_example'));
model=ref.etc.quicklab_reference.sharedModel; leadfield=model.G.';
file=fullfile(output,'synthetic_leadfield.txt'); save(file,'leadfield','-ascii','-double');
for data={original,out}
    e=data{1}; assignin('base','EEG',e);
    gui=pop_REST_reref; cleanup=onCleanup(@()closeFigure(gui));
    h=guidata(gui); h.cfg.SelectChanns.chanlist=1:8; h.cfg.InputLeadfieldDir=file; h.cfg.OrigReferFlag=1;
    guidata(gui,h);
    pop_REST_reref('Run_pushbutton3_Callback',gui,[],h);
    h=guidata(gui); expected=quick_rest_reference(e,'rest',1:8,model);
    assert(isequal(size(h.cfg.REST_EEG),size(e.data)),'Native REST GUI did not return the expected shape.');
    assert(max(abs(h.cfg.REST_EEG(:)-expected.data(:)))<1e-6,'Native REST GUI differs from the known solver.');
    clear cleanup;
end
assignin('base','EEG',out); evalin('base','eeglab redraw;');
fprintf('PASS: actual unepoch menu, retained original, continuous no-op and original REST GUI on both epoched and continuous data.\n');
end
function closeFigure(fig)
if isgraphics(fig), delete(fig); end
end
