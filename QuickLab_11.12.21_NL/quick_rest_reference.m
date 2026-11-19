function [out,model]=quick_rest_reference(eeg,method,rows,model)
% REST / FieldTrip Infinity / Average with one explicitly selected montage.
% [out,model]=quick_rest_reference(eeg,'rest',rows);
% infinity=quick_rest_reference(eeg,'infinity',rows,model);
% Coordinates must be head-centered EEGLAB XYZ (nose +X, left +Y).
% The standard REST three-sphere model projects electrodes to its unit scalp.
% Uses the installed original REST solver; no participant data are embedded.
if nargin<3, rows=1:eeg.nbchan; end
if nargin<4, model=[]; end
assert(ismember(method,{'rest','infinity','average'}),'QuickLab:ReferenceMethod','Choose rest, infinity or average.');
assert(isnumeric(eeg.data) && ~isempty(eeg.data),'QuickLab:NoData','Load EEG data first.');
assert(numel(rows)>=4 && numel(unique(rows))==numel(rows) && all(rows>=1 & rows<=eeg.nbchan & rows==fix(rows)), ...
    'QuickLab:ReferenceChannels','Select at least four distinct scalp channels.');
rows=rows(:)'; loc=eeg.chanlocs(rows); labels={loc.labels};
assert(numel(unique(lower(string(labels))))==numel(labels),'QuickLab:ReferenceLabels','Channel labels must be unique.');
assert(all(isfield(loc,{'X','Y','Z'})) && all(arrayfun(@(l) ...
    isnumeric(l.X) && isscalar(l.X) && isnumeric(l.Y) && isscalar(l.Y) && isnumeric(l.Z) && isscalar(l.Z),loc)), ...
    'QuickLab:ReferenceLocations','Selected channels need scalar XYZ locations.');
xyz=[[loc.X]' [loc.Y]' [loc.Z]'];
assert(isequal(size(xyz),[numel(rows) 3]) && all(isfinite(xyz(:))) && all(vecnorm(xyz,2,2)>0), ...
    'QuickLab:ReferenceLocations','Selected channels need finite, nonzero head-centered XYZ locations.');
assert(size(unique(xyz,'rows'),1)==numel(rows) && rank(xyz-mean(xyz,1))==3, ...
    'QuickLab:ReferenceLocations','Duplicate or coplanar electrode locations: check the montage.');
if isfield(loc,'ref')
    refs=string({loc.ref}); refs=refs(strlength(refs)>0);
    assert(numel(unique(refs))<=1,'QuickLab:MixedReference','Selected channels must share the same original reference.');
end
x=reshape(double(eeg.data(rows,:,:)),numel(rows),[]);
assert(all(isfinite(x(:))),'QuickLab:NonfiniteData','Selected data contain NaN or Inf.');
directions=xyz./vecnorm(xyz,2,2);
if ~strcmp(method,'average')
    assert(exist('dong_calc_leadfield3','file')==2 && exist('pop_refrefinf','file')==2 && ...
        exist('eeglab2fieldtrip','file')==2 && exist('ft_preprocessing','file')==2, ...
        'QuickLab:RESTDependency','Install REST, REST_fieldtrip, DIPFIT and FieldTrip (included in the lab desktop build).');
    restRoot=fileparts(which('dong_calc_leadfield3'));
    if isempty(model)
        dipoles=load(fullfile(restRoot,'corti869-3000dipoles.dat'),'-ascii');
        assert(isequal(size(dipoles),[3000 3]),'QuickLab:RESTSources','Unexpected REST source model.');
        orientation=dipoles./vecnorm(dipoles,2,2); orientation(2601:3000,:)=repmat([0 0 1],400,1);
        head=struct('type','concentricspheres','o',[0 0 0],'r',[.87 .92 1], ...
            'cond',[1 .0125 1],'tissue',{{'brain','skull','scalp'}});
        G=dong_calc_leadfield3([-directions(:,2) directions(:,1) directions(:,3)],dipoles,orientation,head);
        rmax=max(vecnorm(dipoles,2,2)); if rmax>=.87, dipoles=dipoles*(.869/rmax); end
        sm=struct('pos',85*dipoles,'unit','mm','coordsys','ras','label',{labels(:)}, ...
            'inside',true(3000,1),'leadfield',{num2cell(G,1).'},'leadfielddimord','{pos}_chan_ori');
        fit=struct('coordformat','spherical','coord_transform',[0 0 0 0 0 -pi/2 1 1 1], ...
            'chansel',1:numel(rows),'sourcemodel',sm);
        model=struct('labels',{labels},'xyz',xyz,'G',G,'dipfit',fit);
    end
    assert(isequal(model.labels,labels) && isequal(model.xyz,xyz) && size(model.G,1)==numel(rows), ...
        'QuickLab:ReferenceModelMismatch','The shared leadfield must match channel order and coordinates exactly.');
    G=model.G;
    assert(isequal(cat(2,model.dipfit.sourcemodel.leadfield{:}),G), ...
        'QuickLab:ReferenceModelMismatch','REST and FieldTrip must receive identical leadfield values.');
    assert(all(isfinite(G(:))) && norm(mean(G,1))>1e-10*norm(G,'fro') && any(svd(G-mean(G,1))>.05), ...
        'QuickLab:ReferenceLeadfield','Invalid, centered or incorrectly scaled infinity leadfield.');
end
average=x-mean(x,1);
switch method
    case 'average'
        y=average; ref='average';
    case 'rest'
        oldPath=path; cleanup=onCleanup(@() path(oldPath)); %#ok<NASGU>
        addpath(restRoot,'-begin');
        assert(strcmp(which('rest_refer'),fullfile(restRoot,'rest_refer.m')), ...
            'QuickLab:RESTDependency','The original REST implementation is not available.');
        y=rest_refer(average,G.'); ref='REST';
    case 'infinity'
        work=eeg_emptyset; work.nbchan=numel(rows); work.data=x; work.pnts=size(x,2); work.trials=1;
        work.srate=eeg.srate; work.xmin=0; work.xmax=(work.pnts-1)/work.srate;
        work.chanlocs=loc;
        for k=1:numel(rows)
            work.chanlocs(k).X=85*directions(k,1); work.chanlocs(k).Y=85*directions(k,2); work.chanlocs(k).Z=85*directions(k,3);
            work.chanlocs(k).type='EEG';
        end
        work.dipfit=model.dipfit;
        work=pop_refrefinf(work,'infinity'); y=double(work.data); ref='Infinity';
end
assert(isequal(size(y),size(x)) && all(isfinite(y(:))),'QuickLab:ReferenceOutput','Referencing produced invalid samples.');
delta=y-average; residual=delta-mean(delta,1);
assert(norm(residual,'fro')<=1e-6*max(norm(x,'fro'),eps),'QuickLab:ReferenceOutput','Between-channel voltages unexpectedly changed.');
out=eeg; out.data=double(out.data); out.data(rows,:,:)=reshape(y,numel(rows),eeg.pnts,eeg.trials);
[out.chanlocs(rows).ref]=deal(ref); if ismember(1,rows), out.ref=ref; end
for field={'icaact','icawinv','icasphere','icaweights','icachansind','specdata','specicaact','icasplinefile','dipfit','roi','stats','mybadcomp','comprej'}
    if isfield(out,field{1}), out.(field{1})=[]; end
end
if isfield(out.reject,'gcompreject'), out.reject.gcompreject=[]; end
if isstruct(out.reject)
    for field=fieldnames(out.reject)'
        if startsWith(field{1},'ic'), out.reject.(field{1})=[]; end
    end
end
if isempty(out.etc), out.etc=struct; end
stale=intersect(fieldnames(out.etc),{'ic_classification','icaweights_beforerms','icasphere_beforerms','oldicaweights','oldicasphere','oldicachansind'});
if ~isempty(stale), out.etc=rmfield(out.etc,stale); end
out.etc.quicklab_reference=struct('method',method,'rows',rows,'labels',{labels}, ...
    'previousReference',eeg.ref,'model','REST1.2-three-sphere','pinvTolerance',.05);
if strcmp(method,'average'), out.etc.quicklab_reference.model='none'; else, out.etc.quicklab_reference.sharedModel=model; end
out.setname=[eeg.setname ' ' ref]; out.filename=''; out.saved='no';
end
