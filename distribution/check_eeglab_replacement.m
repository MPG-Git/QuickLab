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
report.quicklab = quicklab_dependency_report(findall(groot,'Tag','EEGLAB'),false);
assert(isempty(report.quicklab.missingFunctions),'QuickLab menu dependencies are missing.');
assert(report.quicklab.binicaAvailable,'The bundled Windows BINICA executable is missing.');
report.fieldtripRoot = which('ft_defaults');
report.fieldtripInitializers = which('ft_defaults','-all');
if ischar(report.fieldtripInitializers), report.fieldtripInitializers = {report.fieldtripInitializers}; end
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
assert(numel(report.fieldtripInitializers)==1, ...
    'Multiple FieldTrip startup functions are active. Use the supplied launcher.');
% Catch absent/misparsed version metadata before an update becomes active.
for k = 1:numel(manifest.plugins)
    if iscell(manifest.plugins), p = manifest.plugins{k}; else, p = manifest.plugins(k); end
    registered = PLUGINLIST(strcmp({PLUGINLIST.foldername},p.folder));
    expected = p.version;
    if strcmp(p.name,'Neurolode'), expected = '1.7.0'; end
    assert(strcmp(registered.version,expected), ...
        'EEGLAB:VersionMetadata','Incorrect registered version for %s.',p.name);
end
quicklab = PLUGINLIST(strcmp({PLUGINLIST.foldername},'QuickLabMPG1.1.0'));
assert(strcmp(quicklab.plugin,'QuickLabMPG'), ...
    'The lab QuickLab edition must have a distinct plugin catalog identity.');
end
