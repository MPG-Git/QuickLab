function results = run_ica_demo(outputFolder)
% RUN_ICA_DEMO Known-rank synthetic ICA; no participant recordings are used.
assert(~isfolder(outputFolder),'Choose a new output folder.'); mkdir(outputFolder);
rng(72,'twister'); sources=rand(4,2000)-.5;
sources=sign(sources).*sources.^2;
e=eeg_emptyset; e.nbchan=4; e.pnts=2000; e.trials=1; e.srate=250;
e.xmin=0; e.xmax=1999/250; e.times=(0:1999)*4;
e.data=single((eye(4)+.1*randn(4))*sources*40);
e.data=e.data-mean(e.data,1); e.ref='average';
e.chanlocs=struct('labels',{'Fz','Cz','P3','P4'},'theta',{0,0,-135,135},'radius',{.25,0,.35,.35});
e.chanlocs=convertlocs(e.chanlocs,'topo2all');
e.setname='Synthetic average reference - expected rank 3';
e=pop_saveset(e,'filename','synthetic_rank3.set','filepath',outputFolder);
algorithms={'runica'};
if ispc && ~isempty(which('ica_windows.exe')), algorithms{end+1}='binica'; end
results=struct('algorithm',{},'channels',{},'rank',{},'components',{},'relativeReconstructionError',{});
for k=1:numel(algorithms)
    solved=quick_PCA(e,[],algorithms{k},0);
    activation=solved.icaweights*solved.icasphere*double(e.data);
    residual=norm(solved.icawinv*activation-double(e.data),'fro')/norm(double(e.data),'fro');
    assert(size(solved.icaweights,1)==3 && residual<1e-5,'Synthetic ICA result differs from its known rank.');
    pop_saveset(solved,'filename',['synthetic_' algorithms{k} '.set'],'filepath',outputFolder);
    results(k)=struct('algorithm',algorithms{k},'channels',4,'rank',3,'components',3,'relativeReconstructionError',residual);
end
writetable(struct2table(results),fullfile(outputFolder,'ica_metrics.csv'));
fprintf('PASS: synthetic ICA, 4 channels, rank 3, 3 components; reconstruction error below 1e-5.\n');
end
