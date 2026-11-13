function tests = test_quicklab_workflows
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.TestData.Path=path;
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'QuickLab_11.12.21_NL'),'-begin');
tc.TestData.Folder=tempname; mkdir(tc.TestData.Folder);
end

function teardownOnce(tc)
path(tc.TestData.Path);
folder=char(java.io.File(tc.TestData.Folder).getCanonicalPath());
temporary=char(java.io.File(tempdir).getCanonicalPath());
assert(startsWith([folder filesep],[temporary filesep],'IgnoreCase',ispc));
rmdir(folder,'s');
end

function eeg = fixture(channels,samples)
if nargin<1,channels=4;end
if nargin<2,samples=2000;end
rng(61,'twister'); x=rand(channels,samples)-.5;
% Independent non-Gaussian sources mixed by a well-conditioned matrix.
x=sign(x).*abs(x).^2;
eeg=eeg_emptyset; eeg.data=single((eye(channels)+.1*randn(channels))*x*40);
eeg.nbchan=channels; eeg.pnts=samples; eeg.trials=1;
eeg.srate=250; eeg.xmin=0; eeg.xmax=(samples-1)/250;
eeg.times=(0:samples-1)*4; eeg.setname='Synthetic workflow check';
end

function testAverageRank(tc)
e=fixture(29,6000); e.data=e.data-mean(e.data,1);
tc.verifyEqual(quicklab_data_rank(e.data),28);
end

function testInterpolatedAverageRank25(tc)
e=fixture(26,6000);
x=[e.data; e.data(1:3,:)]; x=x-mean(x,1);
[n,info]=quicklab_data_rank(x);
tc.verifyEqual(n,25); tc.verifyEqual(info.channels,29);
end

function testAllSamplesAndCenteredDC(tc)
rng(19,'twister'); x=[randn(2,10000) zeros(2,10000);zeros(1,10000) randn(1,10000)]+1e6;
tc.verifyEqual(quicklab_data_rank(x),3);
tc.verifyEqual(quicklab_data_rank(ones(3,100)),0);
tc.verifyError(@()quicklab_data_rank([1 NaN;2 3]),'QuickLab:InvalidData');
end

function testRealMatlabICA(tc)
e=fixture; before=e.data; e=quick_PCA(e,[],'runica',0);
tc.verifyEqual(size(e.icaweights*e.icasphere),[4 4]);
tc.verifyTrue(all(isfinite(e.icaweights(:))));
tc.verifyEqual(e.data,before); tc.verifyEqual(e.etc.quicklab_ica.algorithm,'runica');
end

function testAverageMatlabICA(tc)
e=fixture; e.data=e.data-mean(e.data,1); before=e.data;
e=quick_PCA(e,[],'runica',0);
tc.verifyEqual(size(e.icaweights*e.icasphere),[3 4]);
tc.verifyEqual(e.data,before);
activations=(e.icaweights*e.icasphere)*double(e.data);
tc.verifyLessThan(norm(e.icawinv*activations-double(e.data),'fro')/norm(double(e.data),'fro'),1e-5);
end

function testRealWindowsBINICA(tc)
tc.assumeTrue(ispc && ~isempty(which('ica_windows.exe')),'Requires the desktop BINICA dependency.');
e=fixture(26,3000); e.data=[e.data;e.data(1:3,:)]; e.nbchan=29;
e.data=e.data-mean(e.data,1); before=e.data;
folder=pwd; e=quick_PCA(e,[],'binica',0);
tc.verifyEqual(pwd,folder); tc.verifyEqual(size(e.icaweights*e.icasphere),[25 29]);
tc.verifyEqual(e.data,before);
tc.verifyTrue(all(isfinite(e.icaweights(:))));
activations=(e.icaweights*e.icasphere)*double(e.data);
tc.verifyLessThan(norm(e.icawinv*activations-double(e.data),'fro')/norm(double(e.data),'fro'),1e-5);
end

function testComponentRequestsAndNminus1(tc)
e=fixture; e=quick_PCA(e,3,[],0); e.icaact=[];
e.reject.gcompreject=[true false false]; before=e.data;
e=quick_PCA(e,'n-1',[],0);
tc.verifyEqual(size(e.icaweights,1),2);
tc.verifyEqual(e.data,before,'Marked components must not be silently removed.');
tc.verifyError(@()quick_PCA(e,5,[],0),'QuickLab:InvalidComponents');
tc.verifyError(@()quick_PCA(e,NaN,[],0),'QuickLab:InvalidComponents');
end

function testSaveReloadAndInvalidSuffix(tc)
e=fixture; e.filepath=tc.TestData.Folder; e.filename='source.set';
e=quick_eegsave(e,'_processed');
tc.verifyEqual(e.filename,'source_processed.set');
loaded=pop_loadset('filename',e.filename,'filepath',e.filepath);
tc.verifyEqual(loaded.data,e.data);
tc.verifyError(@()quicklab_save_target(e,'../bad'),'QuickLab:InvalidSuffix');
e.filename=''; e.setname='New dataset';
tc.verifyEqual(quicklab_save_target(e,'_ICA'),'New dataset_ICA.set');
end

function testHighpassActuallyRemovesLowFrequencies(tc)
e=fixture(2,10000); t=(0:e.pnts-1)/e.srate;
e.data=repmat(sin(2*pi*t)+sin(2*pi*30*t),2,1);
old=findall(groot,'Type','figure');
e=quick_highpass(e,10);
new=setdiff(findall(groot,'Type','figure'),old); delete(new);
keep=1001:9000; y=double(e.data(1,keep));
low=abs(sum(y.*exp(-2i*pi*t(keep)))); high=abs(sum(y.*exp(-2i*pi*30*t(keep))));
tc.verifyLessThan(low/high,.02);
end
