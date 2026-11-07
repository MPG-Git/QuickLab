function tests = test_plotDifference
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.TestData.previousPath = path;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'QuickLab_11.12.21_NL'),'-begin');
assert(strcmp(which('plotDifference'), fullfile(root,'QuickLab_11.12.21_NL','plotDifference.m')));
tc.TestData.folder = tempname;
mkdir(tc.TestData.folder);
end

function teardownOnce(tc)
rmdir(tc.TestData.folder, 's');
path(tc.TestData.previousPath);
end

function e = fixture(trials)
if nargin == 0, trials = 2; end
e = eeg_emptyset;
e.nbchan = 3; e.pnts = 100; e.trials = trials; e.srate = 100;
e.xmin = -0.1; e.xmax = 0.89; e.times = -100:10:890;
e.data = reshape(sin((1:300*trials)/7),3,100,trials);
e.chanlocs = struct('labels', {'Cz','Pz','Fz'});
e.event = struct('type', 'stimulus', 'latency', 11, 'epoch', 1, 'urevent', 1);
e.setname = 'Infinity'; e.ref = 'Infinity';
end

function testKnownAverageReference(tc)
a = fixture; b = a;
% Known common reference term across every channel, including nonzero DC.
offset = reshape(2+sin((1:200)/13),1,100,2);
a.data = bsxfun(@minus,a.data,mean(a.data,1)) + repmat(offset,3,1,1);
b.data = bsxfun(@minus,a.data,mean(a.data,1)); b.ref = 'averef';
before = [a b];
r = plotDifference(before,[1 2],false);
tc.verifyEqual(r.rmsDifference, repmat(sqrt(mean(offset(:).^2)),3,1), 'AbsTol',1e-12);
tc.verifyEqual(r.meanDifference, repmat(mean(offset(:)),3,1), 'AbsTol',1e-12);
tc.verifyEqual(r.maxAbsDifference, repmat(max(abs(offset(:))),3,1), 'AbsTol',1e-12);
tc.verifyEqual(before,[a b]);
tc.verifyTrue(contains(r.names{2},'Average'));
end

function testReorderedChannels(tc)
a = fixture; b = a;
b.data = b.data([3 1 2],:,:); b.chanlocs = b.chanlocs([3 1 2]);
r = plotDifference([a b],[1 2],false);
tc.verifyEqual(r.overallRMS,0);
tc.verifyEqual(r.secondChannelOrder,[2 3 1]);
end

function testContinuousAndSign(tc)
a = fixture(1); b = a; b.data = a.data + 7;
r = plotDifference([a b],[2 1],false);
tc.verifyEqual(r.meanDifference,7*ones(3,1),'AbsTol',1e-12);
tc.verifyEqual(r.samplesPerChannel,100);
end

function testLastOccupiedSlots(tc)
a = fixture; b = a; b.data = a.data + 2;
hole = eeg_emptyset; all = [hole a hole b hole];
r = plotDifference(all,[],false);
tc.verifyEqual(r.indices,[4 2]);
tc.verifyEqual(r.overallRMS,2,'AbsTol',1e-12);
tc.verifyEqual(r.meanDifference,2*ones(3,1),'AbsTol',1e-12);
end

function testLegacyTwoDatasetAPI(tc)
a = fixture; b = a; a.data = a.data+4;
% Different optional fields must not break the historical two-struct API.
b.customMetadata = 'not in A';
r = plotDifference(a,b,false);
tc.verifyEqual(r.meanDifference,4*ones(3,1),'AbsTol',1e-12);
tc.verifyEqual(r.overallRMS,4,'AbsTol',1e-12);
end

function testSinglePrecisionSubtraction(tc)
a = fixture; b = a;
a.data = single(a.data); b.data = single(b.data+0.5);
r = plotDifference([a b],[1 2],false);
expected = double(a.data)-double(b.data);
tc.verifyEqual(r.overallRMS,sqrt(mean(expected(:).^2)),'AbsTol',1e-12);
end

function testBadSelections(tc)
a = fixture;
tc.verifyError(@() plotDifference(a,[],false),'QuickLab:Datasets');
tc.verifyError(@() plotDifference([a a],[1 1],false),'QuickLab:Selection');
tc.verifyError(@() plotDifference([a a],[1 3],false),'QuickLab:Selection');
end

function testSamplingMismatch(tc)
a = fixture; b = a; b.srate = 200;
tc.verifyError(@() plotDifference([a b],[1 2],false),'QuickLab:TimingMismatch');
b = a; b.trials = 1;
tc.verifyError(@() plotDifference([a b],[1 2],false),'QuickLab:TimingMismatch');
b = a; b.xmin = 0;
tc.verifyError(@() plotDifference([a b],[1 2],false),'QuickLab:TimingMismatch');
b = a; b.times(10) = b.times(10)+1;
tc.verifyError(@() plotDifference([a b],[1 2],false),'QuickLab:TimingMismatch');
end

function testChannelsMismatch(tc)
a = fixture; b = a; b.chanlocs(1).labels = 'Oz';
tc.verifyError(@() plotDifference([a b],[1 2],false),'QuickLab:ChannelMismatch');
b.chanlocs(1).labels = 'Pz';
tc.verifyError(@() plotDifference([a b],[1 2],false),'QuickLab:ChannelMismatch');
b.chanlocs(1).labels = '';
tc.verifyError(@() plotDifference([a b],[1 2],false),'QuickLab:ChannelMismatch');
end

function testEventAndEpochMismatch(tc)
a = fixture; b = a; b.event.latency = 12;
tc.verifyError(@() plotDifference([a b],[1 2],false),'QuickLab:EventMismatch');
b = a; b.event.urevent = 2;
tc.verifyError(@() plotDifference([a b],[1 2],false),'QuickLab:EventMismatch');
b = a; b.event = [];
tc.verifyError(@() plotDifference([a b],[1 2],false),'QuickLab:EventMismatch');
b = a; a.epoch = struct('eventurevent',{1,2}); b.epoch = struct('eventurevent',{2,1});
tc.verifyError(@() plotDifference([a b],[1 2],false),'QuickLab:EventMismatch');
a.event = []; b.event = [];
tc.verifyError(@() plotDifference([a b],[1 2],false),'QuickLab:EventMismatch');
end

function testNonfiniteAndWrongShape(tc)
a = fixture; b = a; b.data(1) = NaN;
tc.verifyError(@() plotDifference([a b],[1 2],false),'QuickLab:Data');
b = a; b.data = reshape(b.data,3,50,4);
tc.verifyError(@() plotDifference([a b],[1 2],false),'QuickLab:Data');
end

function testFlattenedEpochStorage(tc)
a = fixture; b = a; b.data = reshape(b.data,3,[]);
r = plotDifference([a b],[1 2],false);
tc.verifyEqual(r.overallRMS,0);
end

function testNumericEventType(tc)
a = fixture; a.event.type = 1; b = a; b.event.type = '1';
r = plotDifference([a b],[1 2],false);
tc.verifyEqual(r.overallRMS,0);
end

function testExternalFdt(tc)
a = fixture;
a.data = single(a.data);
b = a; b.filepath = tc.TestData.folder; b.filename = 'external.set'; b.data = 'external.fdt';
fid = fopen(fullfile(b.filepath,b.data),'w','ieee-le');
fwrite(fid,a.data,'single'); fclose(fid);
r = plotDifference([a b],[1 2],false);
tc.verifyEqual(r.overallRMS,0);
end

function testInSetFile(tc)
a = fixture; EEG = a; %#ok<NASGU>
save(fullfile(tc.TestData.folder,'embedded.set'),'EEG','-mat');
b = a; b.filepath = tc.TestData.folder; b.filename = 'embedded.set'; b.data = 'in set file';
r = plotDifference([a b],[1 2],false);
tc.verifyEqual(r.overallRMS,0);
end

function testPlotsPreserveDCAndZeroSpacing(tc)
a = fixture; b = a;
before = [a b];
[r, figs] = plotDifference(before,[1 2]);
cleanup = onCleanup(@() close(figs)); %#ok<NASGU>
tc.verifyEqual(numel(figs),3);
tc.verifyEqual(r.overallRMS,0);
tc.verifyEqual(before,[a b]);
for k = 1:2
    g = get(figs(k),'UserData');
    tc.verifyEqual(g.submean,'off');
    tc.verifyGreaterThan(g.spacing,0);
    tc.verifyEmpty(g.command);
end
end

function testMenuWiring(tc)
fig = figure('Visible','off'); cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
uimenu(fig,'Label','Plot');
s.no_check = ''; c.store_and_hist = '';
eegplugin_QuickLab(fig,s,c);
old = findall(fig,'Type','uimenu','Label','Plot Last Files Data Differences');
picker = findall(fig,'Type','uimenu','Label','Compare Datasets (Infinity / Average...)');
tc.verifyNumElements(old,1); tc.verifyNumElements(picker,1);
tc.verifyEqual(get(old,'Callback'),'plotDifference(ALLEEG);');
tc.verifyEqual(get(picker,'Callback'),'plotDifference(ALLEEG, ''select'');');
end
