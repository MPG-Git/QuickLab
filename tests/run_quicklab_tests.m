function results = run_quicklab_tests(eeglabRoot)
% RUN_QUICKLAB_TESTS Run the comparison regression suite against an EEGLAB core.
%   addpath('path/to/QuickLab/tests'); run_quicklab_tests('path/to/eeglab');
previousPath = path;
cleanup = onCleanup(@() path(previousPath)); %#ok<NASGU>
addpath(eeglabRoot,genpath(fullfile(eeglabRoot,'functions')));
folder = fileparts(mfilename('fullpath'));
results = runtests({fullfile(folder,'test_plotDifference.m'),fullfile(folder,'test_setup_report.m')});
disp(table(results));
assert(all([results.Passed]),'QuickLab comparison tests failed.');
fprintf('PASS: %d QuickLab tests with EEGLAB %s\n',numel(results),eeg_getversion);
end
