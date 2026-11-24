function metrics=run_unepoch_demo(output)
% Reproducible epoched-to-continuous conversion, including REST agreement.
if nargin<1, output=fullfile(fileparts(mfilename('fullpath')),'unepoch_output'); end
assert(~exist(output,'file'),'Choose a new output folder.'); mkdir(output);
source=fullfile(fileparts(mfilename('fullpath')),'rest_example');
e=pop_loadset('filename','synthetic_original.set','filepath',source);
r=pop_loadset('filename','synthetic_REST.set','filepath',source);
e.data=reshape(e.data,8,250,4); e.pnts=250; e.trials=4; e.xmin=0; e.xmax=249/e.srate;
e.times=(0:249)/e.srate*1000;
e.event=struct('type',{},'latency',{},'epoch',{},'urevent',{});
e.urevent=struct('type',{},'latency',{});
for k=1:4
    e.event(k)=struct('type','X','latency',(k-1)*250+1,'epoch',k,'urevent',k);
    e.urevent(k)=struct('type','X','latency',(k-1)*500+1);
end
e=eeg_checkset(e,'eventconsistency'); e.setname='Synthetic unepoch practice';
[continuous,com]=quick_unepoch(e); assert(~isempty(com));
model=r.etc.quicklab_reference.sharedModel;
epochedRest=quick_rest_reference(e,'rest',1:8,model);
continuousRest=quick_rest_reference(continuous,'rest',1:8,model);
error=max(abs(epochedRest.data(:)-continuousRest.data(:)));
b=eeg_findboundaries(continuous);
assert(isequal(continuous.data,reshape(e.data,8,1000)) && ...
    isequal([continuous.event(b).latency],[250.5 500.5 750.5]) && error<1e-6);
metrics=table(4,1,1000,3,continuous.xmax,error,'VariableNames', ...
    {'InputEpochs','OutputEpochs','OutputSamples','BoundaryCount','LastSampleSeconds','RESTMaxDifference_uV'});
writetable(metrics,fullfile(output,'unepoch_metrics.csv'));
pop_saveset(e,'filename','synthetic_epoched.set','filepath',output,'savemode','onefile');
pop_saveset(continuous,'filename','synthetic_continuous.set','filepath',output,'savemode','onefile');
pop_saveset(continuousRest,'filename','synthetic_continuous_REST.set','filepath',output,'savemode','onefile');
for name={'synthetic_epoched.set','synthetic_continuous.set','synthetic_continuous_REST.set'}
    demo_portable_set(fullfile(output,name{1}));
end
f=figure('Visible','off'); cleanup=onCleanup(@()delete(f)); %#ok<NASGU>
plot(continuous.times/1000,continuous.data(2,:)); hold on;
for at=[continuous.event(b).latency], xline((at-1)/continuous.srate,'--'); end
xlabel('Seconds in concatenated data'); ylabel('Synthetic E2 (microvolts)');
title('Four retained epochs; dashed lines mark discontinuities');
exportgraphics(f,fullfile(output,'unepoch_boundaries.png'),'Resolution',120);
fid=fopen(fullfile(output,'PASS.txt'),'w'); assert(fid>=0);
fprintf(fid,'PASS: samples, timing, boundary markers and epoched/continuous REST agreement.\n'); fclose(fid);
disp(metrics);
end
