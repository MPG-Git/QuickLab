function result=quicklab_component_controls(fig,action,varargin)
% Keep component-window actions attached to the plotted decomposition.
result=[];
if strcmp(action,'attach')
    setappdata(fig,'quicklab_component_source',varargin{1});
    labels={'Clear Values','Select All','Plot Component Scroll','Save CorrMaps', ...
        'Reject & N-1 PCA','Remove Components','Add Comps to Rej list','Cancel'};
    actions={'clear','all','scroll','corrmaps','pca','remove','store','close'};
    for k=1:numel(labels)
        button=findall(fig,'Style','pushbutton','String',labels{k});
        if isempty(button), continue; end
        set(button, ...
            'Callback',@(src,~) invoke(fig,getappdata(src,'componentAction')));
        setappdata(button,'componentAction',actions{k});
    end
    boxes=findall(fig,'Style','checkbox');
    for k=1:numel(boxes), set(boxes(k),'Callback',@(~,~) colors(fig)); end
    colors(fig);
    return;
end
boxes=findall(fig,'Style','checkbox');
if ismember(action,{'clear','all'})
    set(boxes,'Value',strcmp(action,'all')); colors(fig); return;
end
if strcmp(action,'close'), delete(fig); return; end
e=getappdata(fig,'quicklab_component_source');
for k=1:numel(boxes)
    index=str2double(get(boxes(k),'Tag'));
    assert(isfinite(index) && index==fix(index) && index>=1 && index<=size(e.icaweights,1), ...
        'QuickLab:ComponentIndex','Invalid component selection.');
    e.reject.gcompreject(index)=logical(get(boxes(k),'Value'));
end
selected=find(e.reject.gcompreject);
switch action
    case 'scroll'
        pop_eegplot_w3(e,0,2,1,1);
    case 'corrmaps'
        save_corrmaps(e);
    case {'remove','pca'}
        remaining=size(e.icaweights,1)-numel(selected);
        assert(remaining>=1,'QuickLab:AllComponents','Keep at least one component.');
        if strcmp(action,'pca'), assert(remaining>=2,'QuickLab:TooFewComponents','N-1 PCA requires at least two remaining components.'); end
        if ~isempty(selected), e=pop_subcomp(e,selected,0); end
        if strcmp(action,'pca'), e=quick_PCA(e,remaining-1,[],0); end
        e.saved='no'; quicklab_publish(e); delete(fig);
    case 'store'
        e.saved='no'; quicklab_publish(e); delete(fig);
    otherwise
        error('QuickLab:InvalidAction','Unknown component action.');
end
result=e;
end

function colors(fig)
boxes=findall(fig,'Style','checkbox');
for k=1:numel(boxes)
    color=[.75 1 .75]; if get(boxes(k),'Value'), color=[1 .5 .5]; end
    set(findall(fig,'Tag',['comp' get(boxes(k),'Tag')]),'BackgroundColor',color);
end
end

function invoke(fig,action)
try
    quicklab_component_controls(fig,action);
catch problem
    if exist('eeglab_diagnostics','file'), eeglab_diagnostics('capture',problem,'runtime'); end
    errordlg(problem.message,'QuickLab components');
end
end
