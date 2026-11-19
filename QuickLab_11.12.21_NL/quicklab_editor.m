function result = quicklab_editor(fig,action,varargin)
% Familiar Golden Old editor controls, bound to this window's dataset.
% Folder navigation opens another window, retaining this window's edits.
if nargin<2, action='attach'; end
result=[];
if ~isgraphics(fig,'figure'), return; end
g=get(fig,'UserData');
if ~isstruct(g) || ~isfield(g,'EEG'), return; end
switch action
    case 'attach'
        if ~isempty(findall(fig,'Tag','quicklab_editor_info')), return; end
        % Leave the existing right-hand processing controls in their positions.
        for tag={'eegaxis','backeeg'}
            ax=findall(fig,'Tag',tag{1});
            if isscalar(ax)
                set(ax,'Units','normalized'); p=get(ax,'Position');
                p(4)=min(p(4),.89-p(2)); set(ax,'Position',p);
            end
        end
        uicontrol(fig,'Style','text','Tag','quicklab_editor_info','Units','normalized', ...
            'Position',[.04 .95 .86 .035],'HorizontalAlignment','left', ...
            'BackgroundColor',get(fig,'Color'),'FontSize',10);
        uicontrol(fig,'Style','text','String','Load File From This Folder','Units','normalized', ...
            'Position',[.04 .91 .21 .035],'HorizontalAlignment','left','BackgroundColor',get(fig,'Color'));
        uicontrol(fig,'Style','popupmenu','Tag','FolderList','Units','normalized', ...
            'Position',[.25 .91 .48 .035],'String',{'Select a dataset'}, ...
            'Callback',@(~,~) invoke(fig,'load'));
        uicontrol(fig,'Style','pushbutton','String','Load Folder','Tag','EditorLoadFolder', ...
            'Units','normalized','Position',[.75 .91 .14 .035],'Callback',@(~,~) invoke(fig,'folder'));
        set(findall(fig,'Tag','SaveNowButton'),'String','Save File with Text','Callback',@(~,~) invoke(fig,'save'));
        set(findall(fig,'Tag','SaveNowText'),'TooltipString','Text to add to the filename; an empty value asks before replacing a file');
        set(findall(fig,'Tag','SaveButton'),'Callback',@(~,~) invoke(fig,'store'));
        set(findall(fig,'String','CLOSE'),'Tag','EditorClose','Callback',@(~,~) invoke(fig,'close'));
        set(fig,'CloseRequestFcn',@(~,~) invoke(fig,'close'));
        set(findall(fig,'Tag','AcceptAndSave'),'Label','Store marks and close','Callback',@(~,~) invoke(fig,'storeclose'));
        set(findall(fig,'Tag','plotFFT'),'String','FFT(avg)','Callback',@(~,~) invoke(fig,'spectra'));
        set(findall(fig,'Tag','plotICLABEL'),'String','IClabel','Callback',@(~,~) invoke(fig,'iclabel'));
        menu=uimenu(fig,'Label','QuickLab','Tag','EditorQuickLab');
        uimenu(menu,'Label','Save File with Text','Callback',@(~,~) invoke(fig,'save'));
        uimenu(menu,'Label','Store Marks to EEGLAB','Callback',@(~,~) invoke(fig,'store'));
        uimenu(menu,'Label','Load Folder','Callback',@(~,~) invoke(fig,'folder'));
        uimenu(menu,'Label','Quick Plot Channel Spectra - AVG ref','Callback',@(~,~) invoke(fig,'spectra'));
        uimenu(menu,'Label','Quick IClabel & Viewprops+ plot','Tag','EditorICLabel','Callback',@(~,~) invoke(fig,'iclabel'));
        quicklab_editor(fig,'refresh');
    case 'refresh'
        e=g.EEG; ica='No'; if ~isempty(e.icaweights), ica=num2str(size(e.icaweights,1)); end
        ref=e.ref; if ~ischar(ref), ref=mat2str(ref); end
        label=sprintf('Chans - Ref: %d / %s     Frames - Rate: %d / %g Hz     Epochs-Events: %d / %d     [Start End]: [%g %g]     ICA - Rank: %s / %d', ...
            e.nbchan,ref,e.pnts,e.srate,e.trials,numel(e.event),e.xmin,e.xmax,ica,quicklab_data_rank(e.data));
        set(findall(fig,'Tag','quicklab_editor_info'),'String',label);
        enabled='off'; if ~isempty(e.icaweights), enabled='on'; end
        set(findall(fig,'Tag','plotICLABEL'),'Enable',enabled); set(findall(fig,'Tag','EditorICLabel'),'Enable',enabled);
        set(findall(fig,'Tag','SWITCH'),'Enable',enabled);
        folder=getappdata(fig,'editorFolder');
        if isempty(folder), folder=e.filepath; end
        files=dir(fullfile(folder,'*.set')); names={files.name};
        if isempty(folder) || ~isfolder(folder), names={}; end
        [~,order]=sort(lower(string(names))); names=names(order);
        setappdata(fig,'editorFolder',folder); setappdata(fig,'editorFiles',names);
        set(findall(fig,'Tag','FolderList'),'String',[{'Select a dataset (opens another window)'} names],'Value',1);
    case 'folder'
        if isempty(varargin), folder=uigetdir(getappdata(fig,'editorFolder'),'Choose a folder containing .set files'); else, folder=varargin{1}; end
        if isequal(folder,0), return; end
        assert(isfolder(folder),'QuickLab:MissingFolder','This folder is no longer available.');
        setappdata(fig,'editorFolder',folder); quicklab_editor(fig,'refresh');
    case 'load'
        index=get(findall(fig,'Tag','FolderList'),'Value')-1;
        if ~isempty(varargin), index=varargin{1}; end
        names=getappdata(fig,'editorFiles');
        if index<1 || index>numel(names), return; end
        result=pop_loadset('filename',names{index},'filepath',getappdata(fig,'editorFolder'));
        quicklab_publish(result); pop_eegplot_w3(result,1,2,1,1);
        set(findall(fig,'Tag','FolderList'),'Value',1);
    case 'save'
        result=snapshot(g);
        result=quick_eegsave(result,get(findall(fig,'Tag','SaveNowText'),'String'));
        g.EEG=result; set(fig,'UserData',g); quicklab_editor(fig,'refresh');
    case 'store'
        result=snapshot(g); result.saved='no'; quicklab_publish(result);
    case 'storeclose'
        quicklab_editor(fig,'store'); quicklab_editor(fig,'close');
    case 'spectra'
        quick_spectra(g.EEG,40,2,'AVG');
    case 'iclabel'
        assert(~isempty(g.EEG.icaweights),'QuickLab:NoICA','Run ICA before displaying components.');
        % Viewprops uses its own snapshot; never merge into an arbitrary open scroll.
        quick_IClabel(g.EEG);
    case 'close'
        if isfield(g,'children'), delete(g.children(isgraphics(g.children,'figure'))); end
        delete(fig);
    otherwise
        error('QuickLab:InvalidAction','Unknown editor action.');
end
end

function e=snapshot(g)
e=g.EEG;
if e.plotchannels==1
    e.chanrej=g.winrej; e.comprej=g.winrej_pc;
    ch=g.eloc_file; pc=g.eloc_file_pc;
else
    e.chanrej=g.winrej_ch; e.comprej=g.winrej;
    ch=g.eloc_file_ch; pc=g.eloc_file;
end
e.mybadchan=[]; e.mybadcomp=[];
if isfield(ch,'badchan'), e.mybadchan=find([ch.badchan]); end
if isfield(pc,'badchan'), e.mybadcomp=find([pc.badchan]); end
if ~isempty(e.icaweights)
    e.reject.gcompreject=false(1,size(e.icaweights,1)); e.reject.gcompreject(e.mybadcomp)=true;
end
end

function invoke(fig,action)
try
    quicklab_editor(fig,action);
catch problem
    if exist('eeglab_diagnostics','file'), eeglab_diagnostics('capture',problem,'runtime'); end
    errordlg(problem.message,'QuickLab editor');
end
end
