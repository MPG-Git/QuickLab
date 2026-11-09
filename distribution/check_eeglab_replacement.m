function report = check_eeglab_replacement()
% CHECK_EEGLAB_REPLACEMENT Inspect plugin coverage and the active core path.
% This checks files and startup state, not all algorithms or dependencies.
root = fileparts(mfilename('fullpath'));
manifest = jsondecode(fileread(fullfile(root,'manifest.json')));
core = fullfile(root,'eeglab2026.1.0');
assert(exist(fullfile(root,'COMPLETE.json'),'file') == 2,'Incomplete installation.');
report.core = which('eeglab');
report.expectedCore = fullfile(core,'eeglab.m');
report.correctCore = strcmpi(report.core,report.expectedCore);
report.plugins = manifest.plugins;
missing = {};
for k = 1:numel(manifest.plugins)
    if iscell(manifest.plugins), p = manifest.plugins{k};
    else, p = manifest.plugins(k); end
    folder = fullfile(core,'plugins',p.folder);
    if ~isfolder(folder), missing{end+1} = p.name; end %#ok<AGROW>
end
report.missing = missing;
global PLUGINLIST;
report.startup = PLUGINLIST;
report.startupFailures = [];
report.mwfAvailable = ~isempty(which('mwf_process'));
report.fieldtripRoot = which('ft_defaults');
report.notRegistered = {};
for k = 1:numel(manifest.plugins)
    if iscell(manifest.plugins), p = manifest.plugins{k};
    else, p = manifest.plugins(k); end
    if isempty(PLUGINLIST) || ~any(strcmp({PLUGINLIST.foldername},p.folder))
        report.notRegistered{end+1} = p.name;
    end
end
fprintf('Expected core: %s\nActive core: %s\n',report.expectedCore,report.core);
fprintf('Plugin folders: %d/%d present.\n',numel(manifest.plugins)-numel(missing),numel(manifest.plugins));
if ~isempty(PLUGINLIST) && isfield(PLUGINLIST,'status')
    failed = strcmp({PLUGINLIST.status},'error');
    report.startupFailures = PLUGINLIST(failed);
    if any(failed), disp(PLUGINLIST(failed)); end
end
assert(report.correctCore,'A different EEGLAB installation is active.');
assert(isempty(missing),'Some inventoried plugins are missing.');
assert(isempty(report.notRegistered),'Some inventoried plugins were not registered at startup.');
assert(isempty(report.startupFailures),'Some plugins failed during startup.');
assert(report.mwfAvailable,'The supplemental MWF dependency is not on the path.');
assert(strcmpi(report.fieldtripRoot,fullfile(core,'plugins','Fieldtrip-lite250523','ft_defaults.m')), ...
    'FieldTrip is shadowed by another toolbox. Use the supplied launcher.');
end
