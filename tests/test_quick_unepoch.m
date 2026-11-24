function tests=test_quick_unepoch
tests=functiontests(localfunctions);
end
function setupOnce(tc)
tc.TestData.Path=path;
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'QuickLab_11.12.21_NL'),'-begin');
end
function teardownOnce(tc)
path(tc.TestData.Path);
end
function e=fixture(channels,points,trials)
if nargin<1, channels=4; points=100; trials=3; end
e=eeg_emptyset; e.nbchan=channels; e.pnts=points; e.trials=trials; e.srate=500;
e.xmin=-.1; e.xmax=e.xmin+(points-1)/e.srate; e.times=(0:points-1)*2-100;
e.data=reshape(single(1:channels*points*trials),channels,points,trials);
e.setname='Synthetic epochs'; e.filename='original.set'; e.datfile='original.fdt';
e.event=struct('type',{},'latency',{},'epoch',{},'urevent',{});
e.urevent=struct('type',{},'latency',{});
for k=1:trials
    e.event(k)=struct('type','X','latency',(k-1)*points+1,'epoch',k,'urevent',k);
    e.urevent(k)=struct('type','X','latency',1000*k);
    e.epoch(k).event=k;
end
end
function testTwoOutputsAndTiming(tc)
e=fixture(29,2047,35); before=e; [out,com]=quick_unepoch(e);
tc.verifyEqual(out.data,reshape(e.data,29,2047*35)); tc.verifyEqual(e,before);
tc.verifyEqual([out.trials out.pnts out.xmin],[1 2047*35 0]);
tc.verifyEqual(out.xmax,(2047*35-1)/500); tc.verifyEqual(out.times,(0:2047*35-1)*2,'AbsTol',1e-8);
tc.verifyEqual(com,'EEG = quick_unepoch(EEG);'); tc.verifyEmpty(out.epoch);
tc.verifyEmpty(out.filename); tc.verifyEqual(out.saved,'no');
end
function testEventsAndBoundaryPlacement(tc)
e=fixture; out=quick_unepoch(e); b=eeg_findboundaries(out);
tc.verifyEqual([out.event(b).latency],[100.5 200.5]);
tc.verifyTrue(all(isnan([out.event(b).duration])));
events=out.event(setdiff(1:numel(out.event),b));
tc.verifyEqual({events.type},{'X','X','X'});
tc.verifyEqual([events.latency],[1 101 201]); tc.verifyEqual([events.urevent],[1 2 3]);
tc.verifyEqual(out.urevent,e.urevent); tc.verifyFalse(isfield(out.event,'epoch'));
end
function testNoEventsAndSingleEpoch(tc)
e=fixture; e.event=[]; e.urevent=[]; e.epoch=[];
out=quick_unepoch(e); tc.verifyEqual(numel(eeg_findboundaries(out)),2);
e=fixture(4,100,1); out=quick_unepoch(e);
tc.verifyEmpty(out.epoch); tc.verifyEmpty(eeg_findboundaries(out)); tc.verifyEqual(out.xmin,0);
end
function testContinuousIsExactNoOp(tc)
e=quick_unepoch(fixture); [out,com]=quick_unepoch(e);
tc.verifyEqual(out,e); tc.verifyEmpty(com);
end
function testICAAndRejectionState(tc)
e=fixture; e.icaweights=eye(4); e.icasphere=eye(4); e.icawinv=eye(4); e.icachansind=1:4;
e.icaact=e.data; e.reject.gcompreject=[0 1 0 0]; e.reject.rejmanual=[0 1 0];
e.specdata=ones(4,10,3); out=quick_unepoch(e);
tc.verifyEqual(out.icaweights,e.icaweights); tc.verifyEqual(out.icachansind,1:4);
if ~isempty(out.icaact), tc.verifyEqual(out.icaact,reshape(e.data,4,300)); end
tc.verifyEqual(out.reject.gcompreject,e.reject.gcompreject); tc.verifyEmpty(out.reject.rejmanual);
tc.verifyEqual(out.etc.quicklab_unepoch.epochRejection.rejmanual,[0 1 0]); tc.verifyEmpty(out.specdata);
end
function testInvalidDimensions(tc)
e=fixture; e.pnts=99; tc.verifyError(@()quick_unepoch(e),'QuickLab:InvalidEpochs');
e=fixture; e.data=[]; tc.verifyError(@()quick_unepoch(e),'QuickLab:NoData');
end
function testSaveReload(tc)
folder=tempname; mkdir(folder); cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
e=quick_unepoch(fixture); pop_saveset(e,'filename','continuous.set','filepath',folder,'savemode','onefile');
out=pop_loadset('filename','continuous.set','filepath',folder);
tc.verifyEqual(out.data,e.data); tc.verifyEqual(out.times,e.times);
tc.verifyEqual([out.event.latency],[e.event.latency]); tc.verifyEqual(out.urevent,e.urevent);
end
