function quicklab_menu_state(fig,alleeg,eeg,current)
% Reflect data prerequisites in the familiar menus, including on core redraw.
if nargin<2
    alleeg=evalin('base','ALLEEG'); eeg=evalin('base','EEG'); current=evalin('base','CURRENTSET');
end
menu=findall(fig,'Tag','quicklab_menu'); if ~isscalar(menu), return; end
one=isstruct(eeg) && isscalar(eeg) && isfield(eeg,'data') && ~isempty(eeg.data) && numel(current)<=1;
ica=one && ~isempty(eeg.icaweights) && ~isempty(eeg.icasphere);
count=0;
if isstruct(alleeg) && isfield(alleeg,'data'), count=sum(arrayfun(@(x)~isempty(x.data),alleeg)); end
items=[findall(menu,'Type','uimenu'); findall(fig,'Tag','quicklab_core_editor')];
for k=1:numel(items)
    if ~isempty(get(items(k),'Children')), continue; end
    callback=get(items(k),'Callback'); enabled=true;
    if ischar(callback)
        enabled=one;
        if contains(callback,'save_corrmappath'), enabled=true; end
        if contains(callback,'plotDifference(')
            enabled=count>=2;
            set(items(k),'Visible',flag(enabled));
        elseif contains(callback,'pop_viewprops_erp(')
            enabled=ica && eeg.trials>1;
        elseif any(contains(callback,{'quick_IClabel(', 'pop_viewprops_', 'print_ICA(', ...
                'print_RejComponents(', 'save_corrmaps(', 'quick_corrmap(', 'quick_dipfit('})) ...
                && ~contains(callback,'quick_PCA(')
            enabled=ica;
        elseif contains(callback,'pop_eegplot_w2old(EEG, 2')
            enabled=ica;
        elseif contains(callback,'''n-1''')
            enabled=ica && size(eeg.icaweights,1)>1;
        end
    end
    userdata='study:on'; if ~enabled, userdata=[userdata ' enable:off']; end
    set(items(k),'UserData',userdata,'Enable',flag(enabled));
end
% Parent menus stay reachable, even when the current selection is a STUDY.
groups=items(arrayfun(@(x)~isempty(get(x,'Children')),items));
set(groups,'UserData','study:on','Enable','on');
end

function value=flag(condition)
if condition, value='on'; else, value='off'; end
end
