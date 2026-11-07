function generate_quicklab_data(destination)
% Recreate the bundled illustrative potentials, not a REST reconstruction.
if nargin<1, destination=fullfile(fileparts(mfilename('fullpath')),'data'); end
assert(~isfolder(destination),'Choose a new destination'); mkdir(destination);
E=eeg_emptyset; E.nbchan=3; E.pnts=1000; E.trials=1; E.srate=250;
E.xmin=0; E.xmax=3.996; E.times=(0:999)*4;
t=(0:999)/250; common=2+sin(2*pi*2*t);
signals=[sin(2*pi*10*t);sin(2*pi*15*t);sin(2*pi*20*t)];
E.data=signals-mean(signals,1)+common;
E.chanlocs=struct('labels',{'Cz','Pz','Fz'}); E.event=struct('type','stim','latency',251,'duration',0);
E.setname='Synthetic Infinity (illustrative)'; E.ref='Infinity'; E.subject='synthetic';
E.comments='Generated test potentials in microvolts. Not recorded EEG and not a REST estimate.';
E=eeg_checkset(E,'eventconsistency');
pop_saveset(E,'filename','synthetic_infinity.set','filepath',destination,'savemode','onefile');
demo_portable_set(fullfile(destination,'synthetic_infinity.set'));
E.data=E.data-mean(E.data,1); E.ref='averef'; E.setname='Synthetic Average';
pop_saveset(E,'filename','synthetic_average.set','filepath',destination,'savemode','onefile');
demo_portable_set(fullfile(destination,'synthetic_average.set'));
end
