function quicklab_controls(fig,action,varargin)
% QUICKLAB_CONTROLS Plugin-owned save and folder controls for stock EEGLAB.
% Loading retains the current dataset in ALLEEG; it never changes directory.
% Optional folder/index arguments allow reproducible noninteractive tests.
if nargin < 2, action = 'attach'; end
if ~isgraphics(fig,'figure'), return; end
if strcmp(action,'attach')
    if ~isempty(findall(fig,'Tag','quicklab_controls')), return; end
    % Keep the Golden Old main-window layout without replacing EEGLAB core.
    children = findall(fig,'Type','uicontrol');
    for k=1:numel(children)
        tag = get(children(k),'Tag');
        if ~isempty(regexp(tag,'^(mainwin|win|val)\d+$','once'))
            units = get(children(k),'Units'); set(children(k),'Units','normalized');
            pos = get(children(k),'Position'); pos([2 4]) = [.10+.88*pos(2) .88*pos(4)];
            set(children(k),'Position',pos,'Units',units);
        end
    end
    panel = uipanel(fig,'Tag','quicklab_controls','Units','normalized', ...
        'Position',[.025 .035 .95 .075],'BorderType','none','BackgroundColor',get(fig,'Color'));
    make(panel,'text','SAVETITLE2','Adds to name',[.01 .2 .12 .6],[]);
    make(panel,'pushbutton','SAVEASBUTTON2','Save (+)',[.14 .2 .11 .65],@(~,~) invoke(fig,'save'));
    make(panel,'edit','SAVETEXT2','New',[.27 .2 .11 .65],[]);
    make(panel,'pushbutton','LoadDir2','Load Folder',[.40 .2 .12 .65],@(~,~) invoke(fig,'folder'));
    make(panel,'popupmenu','LoadFileList2',{'Choose a folder'},[.54 .2 .31 .65],@(~,~) invoke(fig,'select'));
    make(panel,'pushbutton','LoadUp','<',[.87 .2 .05 .65],@(~,~) invoke(fig,'previous'));
    make(panel,'pushbutton','LoadDown','>',[.94 .2 .05 .65],@(~,~) invoke(fig,'next'));
    set(findall(panel,'Tag','LoadUp'),'TooltipString','Previous .set file in this folder');
    set(findall(panel,'Tag','LoadDown'),'TooltipString','Next .set file in this folder');
    % The old core used a separate filepath line and left room for FFT images.
    make(fig,'text','quicklab_folder','Filepath: none',[.05 .755 .89 .035],[]);
    set(findall(fig,'Tag','quicklab_folder'),'FontName','Courier New','FontSize',10);
    for k=2:12
        set(findall(fig,'Tag',sprintf('win%d',k)),'Units','normalized','Position',[.05 .71-(k-2)*.054 .30 .035]);
        set(findall(fig,'Tag',sprintf('val%d',k)),'Units','normalized','Position',[.34 .71-(k-2)*.054 .15 .035]);
    end
    set(findall(fig,'Tag','win1'),'Units','normalized','Position',[.05 .81 .89 .035]);
    setappdata(fig,'quicklab_file_state',struct('folder','','names',{{}},'index',0));
    title = findall(fig,'Tag','win0');
    if isscalar(title)
        listener = addlistener(title,'String','PostSet',@(~,~) quicklab_controls(fig,'refresh'));
        setappdata(panel,'redrawListener',listener);
    end
    ica = findall(fig,'Tag','val11');
    if isscalar(ica)
        listener = addlistener(ica,'String','PostSet',@(~,~) rankLabel(fig));
        setappdata(panel,'rankListener',listener);
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
[alleeg,eeg,current] = workspace;
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
set(findall(fig,'Tag','SAVETEXT2'),'Enable',onoff(~isempty(eeg.data)));
set(findall(fig,'Tag','LoadFileList2'),'Visible',onoff(~isempty(state.names)));
set(findall(fig,'Tag','LoadUp'),'Visible',onoff(numel(state.names)>1));
set(findall(fig,'Tag','LoadDown'),'Visible',onoff(numel(state.names)>1));
folder = eeg.filepath; if isempty(folder), folder = 'none'; end
set(findall(fig,'Tag','quicklab_folder'),'String',['Filepath: ' folder], ...
    'TooltipString',eeg.filepath,'Visible',onoff(~isempty(eeg.data)));
label = '';
if isnumeric(eeg.data) && ~isempty(eeg.data)
    ica = 'No'; if ~isempty(eeg.icaweights), ica = num2str(size(eeg.icaweights,1)); end
    try
        n = quicklab_data_rank(eeg.data);
        label = sprintf('%s; Rank (%d)',ica,n);
    catch
        label = [ica '; Rank unavailable'];
    end
end
setappdata(fig,'quicklab_rank_label',label); rankLabel(fig);
quicklab_menu_state(fig,alleeg,eeg,current);
quicklab_preview(fig,eeg);
end

function rankLabel(fig)
label = getappdata(fig,'quicklab_rank_label');
target = findall(fig,'Tag','val11');
if ~isempty(label) && isscalar(target) && ~isequal(get(target,'String'),label)
    set(target,'String',label,'TooltipString', ...
        'ICA component count; centered covariance rank of all samples (EEGLAB tolerance 1e-7 uV^2).');
end
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
if strcmp(style,'text')
    if isgraphics(panel,'figure'), color=get(panel,'Color'); else, color=get(panel,'BackgroundColor'); end
    args = [args {'HorizontalAlignment','left','BackgroundColor',color}];
end
if ~isempty(callback), args = [args {'Callback',callback}]; end
uicontrol(args{:});
end

function value = onoff(condition)
if condition, value = 'on'; else, value = 'off'; end
end
