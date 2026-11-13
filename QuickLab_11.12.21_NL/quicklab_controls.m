function quicklab_controls(fig,action,varargin)
% QUICKLAB_CONTROLS Plugin-owned save and folder controls for stock EEGLAB.
% Loading retains the current dataset in ALLEEG; it never changes directory.
% Optional folder/index arguments allow reproducible noninteractive tests.
if nargin < 2, action = 'attach'; end
if ~isgraphics(fig,'figure'), return; end
if strcmp(action,'attach')
    if ~isempty(findall(fig,'Tag','quicklab_controls')), return; end
    % Reserve the bottom of the window, once, without editing EEGLAB core.
    children = findall(fig,'Type','uicontrol');
    for k=1:numel(children)
        tag = get(children(k),'Tag');
        if ~isempty(regexp(tag,'^(mainwin|win|val)\d+$','once'))
            units = get(children(k),'Units'); set(children(k),'Units','normalized');
            pos = get(children(k),'Position'); pos([2 4]) = [.21+.77*pos(2) .77*pos(4)];
            set(children(k),'Position',pos,'Units',units);
        end
    end
    panel = uipanel(fig,'Tag','quicklab_controls','Units','normalized', ...
        'Position',[.025 .025 .95 .19],'Title','QuickLab files','BackgroundColor',get(fig,'Color'));
    make(panel,'text','SAVETITLE2','Add to filename',[.01 .59 .17 .25],[]);
    make(panel,'edit','SAVETEXT2','New',[.18 .59 .16 .29],[]);
    make(panel,'pushbutton','SAVEASBUTTON2','Save (+)',[.36 .59 .16 .3],@(~,~) invoke(fig,'save'));
    make(panel,'pushbutton','LoadDir2','Load Folder',[.54 .59 .18 .3],@(~,~) invoke(fig,'folder'));
    make(panel,'pushbutton','LoadUp','Previous',[.74 .59 .12 .3],@(~,~) invoke(fig,'previous'));
    make(panel,'pushbutton','LoadDown','Next',[.87 .59 .12 .3],@(~,~) invoke(fig,'next'));
    make(panel,'popupmenu','LoadFileList2',{'Choose a folder'},[.01 .28 .62 .25],@(~,~) invoke(fig,'select'));
    make(panel,'text','quicklab_rank','Rank: no dataset',[.65 .28 .34 .25],[]);
    make(panel,'text','quicklab_folder','Folder: none',[.01 .02 .98 .23],[]);
    setappdata(fig,'quicklab_file_state',struct('folder','','names',{{}},'index',0));
    title = findall(fig,'Tag','win0');
    if isscalar(title)
        listener = addlistener(title,'String','PostSet',@(~,~) quicklab_controls(fig,'refresh'));
        setappdata(panel,'redrawListener',listener);
    end
    quicklab_controls(fig,'refresh');
    return;
end
if isempty(findall(fig,'Tag','quicklab_controls')), return; end
if strcmp(action,'refresh')
    refresh(fig); return;
end
state = getappdata(fig,'quicklab_file_state');
switch action
    case 'folder'
        if isempty(varargin)
            start = state.folder; if isempty(start), start = pwd; end
            folder = uigetdir(start,'Choose a folder containing EEGLAB .set files');
        else, folder = varargin{1}; end
        if isequal(folder,0), return; end
        if ~isfolder(folder), error('QuickLab:MissingFolder','This folder is no longer available.'); end
        state.folder = folder; setappdata(fig,'quicklab_file_state',state);
        refresh(fig,false);
    case 'save'
        [alleeg,eeg,current] = workspace;
        eeg = quick_eegsave(eeg,get(findall(fig,'Tag','SAVETEXT2'),'String'));
        saved = eeg.saved;
        [alleeg,eeg,current] = eeg_store(alleeg,eeg,current);
        eeg.saved = saved; alleeg(current).saved = saved;
        publish(alleeg,eeg,current); refresh(fig);
    case {'select','previous','next'}
        if isempty(state.names), return; end
        if strcmp(action,'select')
            index = get(findall(fig,'Tag','LoadFileList2'),'Value')-1;
            if ~isempty(varargin), index = varargin{1}; end
        elseif strcmp(action,'previous'), index = state.index-1;
        else, index = state.index+1; end
        if index < 1 || index > numel(state.names), return; end
        [alleeg,eeg,current] = workspace;
        % Load first: a missing/corrupt file must not alter the current data.
        next = pop_loadset('filename',state.names{index},'filepath',state.folder);
        if ~isempty(eeg.data)
            saved = eeg.saved;
            [alleeg,~,retained] = eeg_store(alleeg,eeg,current);
            alleeg(retained).saved = saved;
        end
        [alleeg,next,current] = eeg_store(alleeg,next,0);
        publish(alleeg,next,current); refresh(fig);
    otherwise
        error('QuickLab:InvalidAction','Unknown QuickLab file action.');
end
end

function invoke(fig,action)
try
    quicklab_controls(fig,action);
catch problem
    if exist('eeglab_diagnostics','file'), eeglab_diagnostics('capture',problem,'runtime'); end
    errordlg(problem.message,'QuickLab files');
end
end

function refresh(fig,followDataset)
if nargin < 2, followDataset = true; end
[~,eeg,~] = workspace;
state = getappdata(fig,'quicklab_file_state');
if followDataset && ~isempty(eeg.filepath) && isfolder(eeg.filepath)
    state.folder = eeg.filepath;
end
state.names = {};
if ~isempty(state.folder) && isfolder(state.folder)
    files = dir(fullfile(state.folder,'*'));
    names = {files(~[files.isdir]).name};
    state.names = names(~cellfun('isempty',regexpi(names,'\.set$','once')));
    [~,order] = sort(lower(string(state.names))); state.names = state.names(order);
end
state.index = 0;
if strcmpi(state.folder,eeg.filepath)
    index = find(strcmpi(state.names,eeg.filename),1);
    if ~isempty(index), state.index = index; end
end
setappdata(fig,'quicklab_file_state',state);
hint = 'Select a dataset';
if isempty(state.names), hint = 'No .set files - choose a folder'; end
set(findall(fig,'Tag','LoadFileList2'),'String',[{hint} state.names],'Value',state.index+1,'Enable',onoff(~isempty(state.names)));
set(findall(fig,'Tag','LoadUp'),'Enable',onoff(state.index>1));
set(findall(fig,'Tag','LoadDown'),'Enable',onoff(state.index<numel(state.names)));
set(findall(fig,'Tag','SAVEASBUTTON2'),'Enable',onoff(~isempty(eeg.data)));
set(findall(fig,'Tag','quicklab_folder'),'String',['Folder: ' state.folder],'TooltipString',state.folder);
label = 'Rank: no dataset';
if isnumeric(eeg.data) && ~isempty(eeg.data)
    try
        n = quicklab_data_rank(eeg.data);
        label = sprintf('Rank: %d/%d | ICs: %d',n,size(eeg.data,1),size(eeg.icaweights,1));
    catch
        label = 'Rank: unavailable (check data)';
    end
end
set(findall(fig,'Tag','quicklab_rank'),'String',label,'TooltipString', ...
    'Centered covariance rank estimate (EEGLAB tolerance 1e-7 uV^2); ICs = existing ICA components.');
end

function [alleeg,eeg,current] = workspace
alleeg = []; eeg = eeg_emptyset; current = 0;
if evalin('base','exist(''EEG'',''var'')'), eeg = evalin('base','EEG'); end
if evalin('base','exist(''ALLEEG'',''var'')'), alleeg = evalin('base','ALLEEG'); end
if evalin('base','exist(''CURRENTSET'',''var'')'), current = evalin('base','CURRENTSET'); end
if ~isstruct(eeg) || ~isscalar(eeg) || ~isfield(eeg,'data'), eeg = eeg_emptyset; current = 0; end
end

function publish(alleeg,eeg,current)
assignin('base','ALLEEG',alleeg); assignin('base','EEG',eeg); assignin('base','CURRENTSET',current);
evalin('base','eeglab redraw;');
end

function make(panel,style,tag,label,pos,callback)
args = {'Parent',panel,'Style',style,'Tag',tag,'String',label,'Units','normalized', ...
    'Position',pos,'FontSize',10};
if strcmp(style,'text'), args = [args {'HorizontalAlignment','left','BackgroundColor',get(panel,'BackgroundColor')}]; end
if ~isempty(callback), args = [args {'Callback',callback}]; end
uicontrol(args{:});
end

function value = onoff(condition)
if condition, value = 'on'; else, value = 'off'; end
end
