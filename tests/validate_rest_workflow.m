function validate_rest_workflow(output)
addpath(fullfile(fileparts(which('eegplugin_QuickLab')),'examples','synthetic'));
run_rest_demo(output);
e=pop_loadset('filename','synthetic_original.set','filepath',output);
r=pop_loadset('filename','synthetic_REST.set','filepath',output); model=r.etc.quicklab_reference.sharedModel;
if exist('dong_getleadfield','file')==2
    xyz=model.xyz./vecnorm(model.xyz,2,2); xyz=[-xyz(:,2) xyz(:,1) xyz(:,3)]; geom=e;
    for k=1:8, geom.chanlocs(k).X=xyz(k,1); geom.chanlocs(k).Y=xyz(k,2); geom.chanlocs(k).Z=xyz(k,3); end
    official=dong_getleadfield(geom,1:8).'; assert(norm(official-model.G,'fro')<1e-12*norm(model.G,'fro'));
    native=dong_rest_refer(e.data-mean(e.data,1),official.'); assert(max(abs(native(:)-r.data(:)))<1e-6);
end
e.data(9,:)=123; e.nbchan=9; e.chanlocs(9)=e.chanlocs(1); e.chanlocs(9).labels='EOG'; e.chanlocs(9).type='EOG';
e.data=reshape(e.data,9,250,4); e.pnts=250; e.trials=4;
e.xmax=(e.pnts-1)/e.srate; e.times=(0:e.pnts-1)/e.srate*1000;
e.icaweights=eye(8); e.icasphere=eye(8); e.icawinv=eye(8); e.icachansind=1:8; e.etc.ic_classification=struct('old',true);
before=e;
rest=quick_rest_reference(e,'rest',1:8,model); inf=quick_rest_reference(e,'infinity',1:8,model);
assert(isequaln(e,before) && all(rest.data(9,:,:)==123,'all'));
assert(isequal(size(rest.data),[9 250 4]) && max(abs(rest.data(:)-inf.data(:)))<1e-6);
assert(isempty(rest.icaweights) && ~isfield(rest.etc,'ic_classification'));
assert(strcmp(rest.ref,'REST') && strcmp(rest.chanlocs(9).ref,e.chanlocs(9).ref));
bad=e; bad.data(1)=NaN; fails(@() quick_rest_reference(bad,'rest',1:8,model),'QuickLab:NonfiniteData');
bad=e; bad.chanlocs(2).ref='different'; fails(@() quick_rest_reference(bad,'rest',1:8,model),'QuickLab:MixedReference');
bad=e; bad.chanlocs(1).X=[]; fails(@() quick_rest_reference(bad,'rest',1:8,model),'QuickLab:ReferenceLocations');
fails(@() quick_rest_reference(e,'rest',8:-1:1,model),'QuickLab:ReferenceModelMismatch');
badmodel=model; badmodel.G(1)=0; fails(@() quick_rest_reference(e,'infinity',1:8,badmodel),'QuickLab:ReferenceModelMismatch');
if evalin('base','exist(''ALLEEG'',''var'')')
    figures=findall(groot,'Type','figure'); original=evalin('base','EEG');
    variants=quicklab_reference_compare(e,1:8);
    assert(numel(variants)==3 && strcmp(evalin('base','EEG.ref'),'average'));
    retained=evalin('base','ALLEEG'); assert(any(arrayfun(@(x)isequaln(x.data,original.data),retained)));
    delete(setdiff(findall(groot,'Type','figure'),figures));
end
fprintf('PASS: shared leadfield, native REST / FieldTrip, known truth, epochs, excluded EOG, stale ICA cleanup and invalid-input guards.\n');
end

function fails(action,id)
try, action(); catch problem, assert(strcmp(problem.identifier,id),'Unexpected error: %s',problem.identifier); return; end
error('Expected %s.',id);
end
