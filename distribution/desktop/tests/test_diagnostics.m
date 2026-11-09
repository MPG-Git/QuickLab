function test_diagnostics(outputRoot)
% Real MATLAB privacy, consent, bounded local history, and manual export tests.
source=fileparts(fileparts(mfilename('fullpath')));
root=fullfile(outputRoot,'managed','versions','fixture'); mkdir(root); mkdir(fullfile(root,'setup','desktop'));
copyfile(fullfile(source,'eeglab_diagnostics.m'),root);
copyfile(fullfile(source,'diagnostic-sources.json'),root);
copyfile(fullfile(source,'reporting.json'),fullfile(root,'setup','desktop'));
addpath(root,'-begin'); cleanup=onCleanup(@() cleanupTest(root)); %#ok<NASGU>
catalog=jsondecode(fileread(fullfile(root,'diagnostic-sources.json')));
exception=struct('identifier','MATLAB:badsubscript','message','PRIVATE Jane EEG password secret', ...
    'stack',struct('file',fullfile(root,'eeglab_diagnostics.m'),'name','PRIVATE-name','line',42));
r=eeglab_diagnostics('record',exception,'runtime',root,catalog);
encoded=jsonencode(r);
assert(~contains(encoded,'PRIVATE') && ~contains(encoded,'secret') && ~contains(encoded,root));
assert(r.errorCode==1 && numel(r.frames)==1);
exception.identifier='Patient:Jane'; exception.stack.file=fullfile(outputRoot,'Jane.set');
r=eeglab_diagnostics('record',exception,'runtime',root,catalog);
assert(r.errorCode==0 && isempty(r.frames));
eeglab_diagnostics('init',root); eeglab_diagnostics('stop');
eeglab_diagnostics('consent',false);
eeglab_diagnostics('capture',exception,'runtime');
history=fullfile(outputRoot,'managed','reporting','history'); queue=fullfile(outputRoot,'managed','reporting','queue');
assert(numel(dir(fullfile(history,'report-*.json')))==1 && isempty(dir(fullfile(queue,'report-*.json'))));
eeglab_diagnostics('consent',true);
eeglab_diagnostics('capture',exception,'practice');
assert(numel(dir(fullfile(queue,'report-*.json')))==1);
eeglab_diagnostics('consent',false);
assert(isempty(dir(fullfile(queue,'report-*.json'))));
for k=1:102, eeglab_diagnostics('capture',exception,'runtime'); end
assert(numel(dir(fullfile(history,'report-*.json')))==100);
export=eeglab_diagnostics('export',false); text=fileread(export);
assert(~contains(text,'PRIVATE') && ~contains(text,'Jane') && ~contains(text,root));
assert(contains(text,'error code 0'));
fid=fopen(fullfile(outputRoot,'PASS.txt'),'w'); fprintf(fid,'PASS: MATLAB diagnostics privacy, consent, queue, history cap and export'); fclose(fid);
disp('PASS: MATLAB diagnostics privacy, consent, queue, history cap and export');
end
function cleanupTest(root)
eeglab_diagnostics('stop'); rmpath(root); clear eeglab_diagnostics;
end
