function metrics=run_rest_demo(output)
% Known-truth REST reconstruction, independently checked against FieldTrip.
% Run with the desktop distribution's REST, FieldTrip and DIPFIT dependencies.
if nargin<1, output=fullfile(fileparts(mfilename('fullpath')),'rest_output'); end
assert(~exist(output,'file'),'Choose a new output folder.'); mkdir(output);
e=eeg_emptyset; e.nbchan=8; e.srate=250; e.pnts=1000; e.trials=1; e.xmin=0; e.xmax=999/250;
xyz=[1 0 .3; .6 .7 .6; 0 1 .3; -.7 .5 .6; -1 0 .3; -.5 -.8 .6; 0 -1 .3; .7 -.4 .9];
for k=1:8
    e.chanlocs(k).labels=sprintf('E%d',k); e.chanlocs(k).X=xyz(k,1);
    e.chanlocs(k).Y=xyz(k,2); e.chanlocs(k).Z=xyz(k,3); e.chanlocs(k).type='EEG'; e.chanlocs(k).ref='E1';
end
e.chanlocs=convertlocs(e.chanlocs,'cart2all'); e.data=zeros(8,1000); e.ref='E1'; e.setname='Synthetic shared-leadfield EEG';
[~,model]=quick_rest_reference(e,'rest'); G=model.G;
[~,D,V]=svd(G-mean(G,1),'econ'); V=V(:,diag(D)>.05);
[~,index]=max(abs(mean(G,1)*V)); topography=G*V(:,index); topography=topography/max(abs(topography));
t=(0:999)/250; truth=topography*(10*sin(2*pi*10*t)+3*cos(2*pi*4*t));
e.data=truth-truth(1,:);
rest=quick_rest_reference(e,'rest',1:8,model);
infinity=quick_rest_reference(e,'infinity',1:8,model);
average=quick_rest_reference(e,'average',1:8);
truthError=max(abs(rest.data(:)-truth(:))); agreement=max(abs(rest.data(:)-infinity.data(:)));
delta=infinity.data-average.data; rmsDifference=sqrt(mean(delta(:).^2));
assert(truthError<1e-6 && agreement<1e-6 && rmsDifference>.01,'REST known-truth check failed.');
metrics=table(truthError,agreement,rmsDifference,'VariableNames',{'TruthMaxError_uV','REST_FieldTripMaxError_uV','Infinity_AverageRMS_uV'});
writetable(metrics,fullfile(output,'rest_metrics.csv'));
pop_saveset(e,'filename','synthetic_original.set','filepath',output,'savemode','onefile');
pop_saveset(rest,'filename','synthetic_REST.set','filepath',output,'savemode','onefile');
pop_saveset(infinity,'filename','synthetic_FieldTrip_Infinity.set','filepath',output,'savemode','onefile');
pop_saveset(average,'filename','synthetic_Average.set','filepath',output,'savemode','onefile');
for name={'synthetic_original.set','synthetic_REST.set','synthetic_FieldTrip_Infinity.set','synthetic_Average.set'}
    demo_portable_set(fullfile(output,name{1}));
end
f=figure('Visible','off'); cleanup=onCleanup(@() delete(f)); %#ok<NASGU>
subplot(2,1,1); plot(t,rest.data(2,:),t,infinity.data(2,:),'--',t,average.data(2,:),':');
legend('REST','FieldTrip Infinity','Average'); ylabel('microvolts'); title('Synthetic E2: one shared leadfield');
subplot(2,1,2); plot(t,rest.data(2,:)-infinity.data(2,:)); xlabel('Seconds'); ylabel('REST minus FieldTrip (microvolts)');
exportgraphics(f,fullfile(output,'rest_comparison.png'),'Resolution',120);
fid=fopen(fullfile(output,'PASS.txt'),'w'); fprintf(fid,'PASS: known-truth recovery and independent REST / FieldTrip comparison.\n'); fclose(fid);
disp(metrics);
end
