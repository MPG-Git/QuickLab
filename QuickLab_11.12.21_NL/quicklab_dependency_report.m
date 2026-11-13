function report = quicklab_dependency_report(fig,showDialog)
% Check every active QuickLab menu's directly called functions.
% This is a dependency check, not certification of every scientific workflow.
if nargin<1, fig=findall(groot,'Tag','EEGLAB'); end
if nargin<2, showDialog=true; end
menu=findall(fig,'Type','uimenu','Tag','quicklab_menu');
assert(isscalar(menu),'QuickLab:MissingMenu','Start EEGLAB with one QuickLab installation.');
items=findall(menu,'Type','uimenu'); names={'save_corrmappath','quicklab_controls','runica'};
for k=1:numel(items)
    callback=get(items(k),'Callback');
    if ~ischar(callback), continue; end
    tokens=regexp(callback,'(?<![A-Za-z0-9_])([A-Za-z]\w*)\s*\(','tokens');
    for j=1:numel(tokens)
        name=tokens{j}{1};
        if ~any(strcmp(name,{'EEG','ALLEEG','UGO'})), names{end+1}=name; end %#ok<AGROW>
    end
end
names=unique(names); missing=names(cellfun(@(name)isempty(which(name)),names));
report=struct('functions',{names},'missingFunctions',{missing}, ...
    'binicaAvailable',~isempty(which('ica_windows.exe')), ...
    'signalToolbox',license('test','Signal_Toolbox'), ...
    'statisticsToolbox',license('test','Statistics_Toolbox'), ...
    'parallelToolbox',license('test','Distrib_Computing_Toolbox'));
fprintf('QuickLab: %d/%d menu functions found. Windows BINICA: %d.\n',numel(names)-numel(missing),numel(names),report.binicaAvailable);
if showDialog
    lines={sprintf('%d/%d menu functions found.',numel(names)-numel(missing),numel(names)), ...
        sprintf('Windows BINICA available: %d',report.binicaAvailable), ...
        sprintf('Signal / Statistics / Parallel toolbox licenses: %d / %d / %d',report.signalToolbox,report.statisticsToolbox,report.parallelToolbox), ...
        'Specialized methods may require licensed MATLAB toolboxes or compatible GPU hardware.'};
    if ~isempty(missing), lines{end+1}=['Missing: ' strjoin(missing,', ')]; end
    msgbox(lines,'QuickLab setup');
end
end
