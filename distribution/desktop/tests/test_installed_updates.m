function test_installed_updates(versionRoot,outputRoot)
% Real managed startup with the remote plugin catalog disabled; exercise the
% installed menu's process launch against a harmless isolated controller.
versionRoot=char(System.IO.Path.GetFullPath(versionRoot));
outputRoot=char(System.IO.Path.GetFullPath(outputRoot));
mkdir(outputRoot);
originalProfile=getenv('USERPROFILE'); originalFolder=pwd;
profile=fullfile(outputRoot,'profile'); mkdir(profile);
core=fullfile(versionRoot,'eeglab2026.1.0');
options=fileread(fullfile(core,'functions','adminfunc','eeg_options.m'));
writeText(fullfile(profile,'eeg_options.m'),[options newline 'option_checkversion = 0;' newline]);
setenv('USERPROFILE',profile);
cleanup=onCleanup(@() finish(originalProfile,originalFolder)); %#ok<NASGU>
managedHome=fileparts(fileparts(versionRoot));
assert(contains(managedHome,'Release Upgrade Test'),'Use an isolated test installation.');
preferences=fullfile(managedHome,'reporting','preferences.json');
if ~isfolder(fileparts(preferences)), mkdir(fileparts(preferences)); end
writeText(preferences,'{"enabled":false,"privacyVersion":1}');
cd(versionRoot); addpath(versionRoot);
evalin('base','eeglab_desktop_start;');
assert(evalin('base','eeglab_desktop_ready'),'Managed startup failed.');
report=check_eeglab_replacement;
assert(isempty(report.notRegistered) && isempty(report.startupFailures));
global PLUGINLIST;
for name={'Biosig','Fieldtrip-lite','Fileio','PICARD','spm'}
    assert(any(strcmpi({PLUGINLIST.plugin},name{1})),['Offline registration failed: ' name{1}]);
end
assert(numel(PLUGINLIST)==54,'Expected 53 inventoried plugins plus EEG-BIDS.');
menu=findall(groot,'Tag','mpg_updates'); callbackMenu=findall(groot,'Tag','mpg_check_updates');
release=jsondecode(fileread(fullfile(versionRoot,'setup','desktop','release.json')));
assert(numel(menu)==1 && strcmp(get(menu,'Label'),['Updates (' release.version ')']));
assert(numel(callbackMenu)==1 && strcmp(get(callbackMenu,'Label'),'Check for updates'));
fprintf('PASS: real managed startup registers all 54 plugins without the remote catalog and displays Updates (%s).\n',release.version);

statePath=fullfile(managedHome,'state.json'); originalState=fileread(statePath);
restoreState=onCleanup(@() writeText(statePath,originalState)); %#ok<NASGU>
state=jsondecode(originalState);
mock=fullfile(managedHome,'versions','menu-callback-fixture','setup','desktop'); mkdir(mock);
observed=fullfile(outputRoot,'callback.json');
script=sprintf(['param($HomeRoot,[switch]$NoOpen)\n' ...
    '[IO.File]::WriteAllText(''%s'',(@{home=$HomeRoot;noOpen=[bool]$NoOpen}|ConvertTo-Json))\n'],strrep(observed,'''',''''''));
writeText(fullfile(mock,'Update-Launch.ps1'),script);
state.current.path=fileparts(fileparts(mock)); writeText(statePath,jsonencode(state));
evalin('base','EEG.comments = ''unsaved updater test sentinel'';');
before=evalin('base','EEG');
callback=get(callbackMenu,'Callback'); callback(callbackMenu,[]);
deadline=tic;
while ~isfile(observed) && toc(deadline)<15, pause(.1); end
assert(isfile(observed),'The actual menu did not launch its checker.');
result=jsondecode(fileread(observed));
assert(result.noOpen && strcmp(result.home,managedHome));
assert(isequaln(before,evalin('base','EEG')),'Checking updates changed the working dataset.');
fprintf('PASS: actual menu launches the active version controller with NoOpen and retains unsaved EEG.\n');
end
function writeText(file,text)
fid=fopen(file,'w','n','UTF-8'); assert(fid>=0); cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',text);
end
function finish(profile,folder)
try, eeglab_diagnostics('stop'); catch, end
close('all','force'); setenv('USERPROFILE',profile); cd(folder);
end
