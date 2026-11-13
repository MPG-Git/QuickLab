function test_update_validation(outputRoot)
% Exercise the actual candidate failure handler, without recordings or network.
source=fileparts(fileparts(mfilename('fullpath')));
root=fullfile(outputRoot,'managed','versions','fixture'); mkdir(root);
mkdir(fullfile(root,'setup','desktop'));
for name={'validate_desktop_update.m','eeglab_diagnostics.m','diagnostic-sources.json'}
    copyfile(fullfile(source,name{1}),root);
end
copyfile(fullfile(source,'reporting.json'),fullfile(root,'setup','desktop'));
writeText(fullfile(root,'start_eeglab_replacement.m'),sprintf(['function varargout=start_eeglab_replacement\n' ...
    'error(''MATLAB:badsubscript'',''%%s'',''PRIVATE Jane C:/Users/Jane/subject.set token=SECRET'');\nend\n']));
writeText(fullfile(root,'manifest.json'),' {"plugins":[{"name":"QuickLab","folder":"QuickLabMPG1.0.0","version":"1.0.0"}]}');
% Observe the detached sender invocation, never send a test to the internet.
writeText(fullfile(root,'setup','desktop','Reporting-Worker.ps1'), ...
    'param($HomeRoot,$VersionRoot,[switch]$Once); if($Once){[IO.File]::WriteAllText((Join-Path $VersionRoot ''sender-once.txt''),''PASS'')}');
addpath(root,'-begin'); cleanup=onCleanup(@() finish(root)); %#ok<NASGU>
clear start_eeglab_replacement validate_desktop_update eeglab_diagnostics;
eeglab_diagnostics('init',root); eeglab_diagnostics('stop'); eeglab_diagnostics('consent',true);
failed=false;
try, validate_desktop_update; catch exception, failed=strcmp(exception.identifier,'MATLAB:badsubscript'); end
assert(failed,'The original validation error must still escape.');
history=fullfile(outputRoot,'managed','reporting','history');
queue=fullfile(outputRoot,'managed','reporting','queue');
files=dir(fullfile(history,'report-*.json')); assert(numel(files)==1);
text=fileread(fullfile(history,files(1).name)); r=jsondecode(text);
assert(r.schemaVersion==2 && strcmp(r.context,'validation') && r.errorCode==1);
assert(strcmp(r.update.stage,'startup') && strcmp(r.update.pluginFailures.component,'QuickLab'));
assert(strcmp(r.update.pluginFailures.reason,'missing') && numel(r.frames)>=1);
assert(~contains(text,'PRIVATE') && ~contains(text,'Jane') && ~contains(text,'SECRET') && ~contains(text,root));
assert(numel(dir(fullfile(queue,'report-*.json')))==1);
deadline=tic;
while ~isfile(fullfile(root,'sender-once.txt')) && toc(deadline)<10, pause(.1); end
assert(isfile(fullfile(root,'sender-once.txt')),'Candidate did not start the independent sender.');
report=eeglab_diagnostics('export',false); assert(contains(fileread(report),'Plugin check: QuickLab | missing'));
eeglab_diagnostics('consent',false); assert(isempty(dir(fullfile(queue,'report-*.json'))));
% EEGLAB catches plugin errors internally. Preserve their safe underlying stack
% rather than reporting only the generic subsequent inventory assertion.
plugin=fullfile(root,'eeglab2026.1.0','plugins','QuickLabMPG1.0.0'); mkdir(plugin); addpath(plugin,'-begin');
writeText(fullfile(plugin,'eegplugin_QuickLab.m'),sprintf('function eegplugin_QuickLab\nerror(''MATLAB:UndefinedFunction'',''%%s'',''PRIVATE token=SECRET'');\nend\n'));
writeText(fullfile(root,'start_eeglab_replacement.m'),sprintf(['function [a,b,c,d]=start_eeglab_replacement\n' ...
    'global PLUGINLIST; PLUGINLIST=struct(''foldername'',''QuickLabMPG1.0.0'',''version'',''1.0.0'',''status'',''error'');\n' ...
    'try, eegplugin_QuickLab; catch, end\na=[]; b=[]; c=[]; d=[];\nend\n']));
writeText(fullfile(root,'check_eeglab_replacement.m'),sprintf('function r=check_eeglab_replacement\nerror(''EEGLAB:VersionMetadata'',''Generic inventory failure'');\nend\n'));
clear start_eeglab_replacement check_eeglab_replacement eegplugin_QuickLab;
try, validate_desktop_update; catch exception, assert(strcmp(exception.identifier,'EEGLAB:VersionMetadata')); end
files=dir(fullfile(history,'report-*.json')); found=false;
for k=1:numel(files)
    r=jsondecode(fileread(fullfile(history,files(k).name)));
    if r.errorCode==2
        assert(strcmp(r.update.matlabIdentifier,'MATLAB:UndefinedFunction') && strcmp(r.update.pluginFailures.reason,'startup') && numel(r.frames)>=1); found=true;
    end
end
assert(found,'Underlying plugin-hook failure was lost.');
rmpath(plugin); clear eegplugin_QuickLab check_eeglab_replacement;
writeText(fullfile(outputRoot,'PASS.txt'),'PASS: failed validation captured precise cause, plugin, safe stack; sender started; export and opt-out worked.');
disp('PASS: failed MATLAB candidate reports details before activation.');
end
function writeText(file,text)
fid=fopen(file,'w'); assert(fid>=0); c=onCleanup(@() fclose(fid)); fprintf(fid,'%s',text);
end
function finish(root)
eeglab_diagnostics('stop'); rmpath(root);
clear start_eeglab_replacement validate_desktop_update eeglab_diagnostics;
end
