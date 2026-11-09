function validate_desktop_update()
% Validate a staged installation before changing the user's active version.
root = fileparts(mfilename('fullpath'));
closeCleanup = onCleanup(@() close('all','force')); %#ok<NASGU>
[ALLEEG,EEG,CURRENTSET,ALLCOM] = start_eeglab_replacement; %#ok<ASGLU>
report = check_eeglab_replacement;
assert(isempty(report.startupFailures));
output = tempname(root);
run_replacement_examples(output);
result = struct('status','PASS','eeglab',eeg_getversion,'matlab',version, ...
    'plugins',numel(report.plugins),'syntheticExamples','QuickLab and NeuroLode', ...
    'outputFolder',output);
fid = fopen(fullfile(root,'desktop_validation.json'),'w');
assert(fid >= 0,'Cannot save the validation result.');
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(result));
end
