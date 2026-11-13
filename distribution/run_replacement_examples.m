function run_replacement_examples(outputDirectory)
% RUN_REPLACEMENT_EXAMPLES Run both bundled known-answer examples.
% Start this build with start_eeglab_replacement first. An existing output
% directory is refused; the example's expected files are never overwritten.
root = fileparts(mfilename('fullpath'));
if nargin < 1, outputDirectory = fullfile(root,'example_run'); end
assert(~exist(outputDirectory,'file'),'Choose a new output directory.');
check_eeglab_replacement;
previousPath = path;
cleanup = onCleanup(@() path(previousPath)); %#ok<NASGU>
mkdir(outputDirectory);
core = fullfile(root,'eeglab2026.1.0');
quick = fullfile(core,'plugins','QuickLabMPG1.0.0','examples','synthetic');
neuro = fullfile(core,'plugins','Neurolode','examples','synthetic');
addpath(quick,'-begin');
clear demo_prepare demo_verify demo_portable_set;
run_quicklab_demo(fullfile(outputDirectory,'QuickLab'));
rmpath(quick);
clear demo_prepare demo_verify demo_portable_set;
addpath(neuro,'-begin');
run_neurolode_demo(fullfile(outputDirectory,'NeuroLode'));
fprintf('Both examples passed. Outputs: %s\n',outputDirectory);
end
