function report = quicklab_setup_report
% QUICKLAB_SETUP_REPORT Inspect EEGLAB paths and plugin folders without changes.
% Run from the extracted QuickLab repository root, before or after EEGLAB.
% No plugins are executed, installed, moved, disabled, or downloaded.
% Returned paths describe this computer; review them before sharing the report.

report.MATLABVersion = version;
report.MATLABRelease = version('-release');
report.CurrentFolder = pwd;
report.Issues = {};
names = {'eeglab','eegplugin_QuickLab','plotDifference', ...
    'eegplugin_Neurolode','eegplugin_dipfit','eegplugin_erpsource'};
report.Functions = struct('Name', names, 'Files', repmat({{}},1,numel(names)));
fprintf('\nEEGLAB / QuickLab setup report (read-only)\nMATLAB: %s\n', report.MATLABVersion);
for k = 1:numel(names)
    files = which(names{k}, '-all');
    if isempty(files), files = {}; elseif ischar(files), files = {files}; end
    report.Functions(k).Files = files;
    fprintf('\n%s: %d definition(s) visible on the MATLAB path\n', names{k},numel(files));
    for j = 1:numel(files)
        if j == 1, marker = 'ACTIVE'; else, marker = 'other '; end
        fprintf('  %s: %s\n',marker,files{j});
    end
    if numel(files)>1
        report.Issues{end+1} = sprintf('Multiple definitions are visible for %s.',names{k}); %#ok<AGROW>
    end
end
files = report.Functions(1).Files;
if isempty(files)
    report.Issues{end+1} = 'No EEGLAB entry point is currently visible. Start from your chosen EEGLAB root folder.';
end
roots = cellfun(@fileparts,files,'UniformOutput',false);
keys = string(roots); if ispc, keys = lower(keys); end
[~,keep] = unique(keys,'stable'); roots = roots(keep);
report.EEGLABRoots = roots;
rootColumn = {}; folderColumn = {}; hookColumn = {};
for k = 1:numel(roots)
    % Match EEGLAB's plugin directory level, including hooks directly in plugins.
    direct = dir(fullfile(roots{k},'plugins','eegplugin*.m'));
    nested = dir(fullfile(roots{k},'plugins','*','eegplugin*.m'));
    hits = [direct; nested]; hits = hits(~[hits.isdir]);
    for j = 1:numel(hits)
        rootColumn{end+1,1} = roots{k}; %#ok<AGROW>
        folderColumn{end+1,1} = hits(j).folder; %#ok<AGROW>
        hookColumn{end+1,1} = hits(j).name; %#ok<AGROW>
    end
    if ~isempty(hits)
        hooks = lower(string({hits.name}));
        [uniqueHooks,~,group] = unique(hooks);
        counts = accumarray(group(:),1);
        for j = find(counts>1)'
            report.Issues{end+1} = sprintf('%d plugin files named %s exist under %s/plugins.', ...
                counts(j),uniqueHooks(j),roots{k}); %#ok<AGROW>
        end
    end
end
report.PluginFolders = table(string(rootColumn),string(folderColumn),string(hookColumn), ...
    'VariableNames',{'EEGLABRoot','Folder','EntryPoint'});
fprintf('\nPlugin entry points found in the visible EEGLAB installations:\n');
for k = 1:height(report.PluginFolders)
    fprintf('  %s\n',fullfile(report.PluginFolders.Folder(k),report.PluginFolders.EntryPoint(k)));
end
fprintf('\nFindings:\n');
if isempty(report.Issues)
    fprintf('  No duplicates detected in these paths/folders. This is not a plugin runtime test.\n');
else
    for k = 1:numel(report.Issues), fprintf('  - %s\n',report.Issues{k}); end
end
fprintf('Folders listed here are installed candidates, not proof that they loaded successfully.\n');
fprintf('Keep one EEGLAB root and one copy of each plugin; see SETUP_TROUBLESHOOTING.md.\n');
end
