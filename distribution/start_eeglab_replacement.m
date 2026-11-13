function [ALLEEG, EEG, CURRENTSET, ALLCOM] = start_eeglab_replacement()
% START_EEGLAB_REPLACEMENT Start the pinned build on a clean session path.
% The path change is temporary; this function never calls savepath.
% Run in a new MATLAB session, from this installation's top folder.
root = fileparts(mfilename('fullpath'));
assert(exist(fullfile(root,'COMPLETE.json'),'file') == 2, ...
    'Installation is incomplete. Run Install-EEGLAB.ps1 successfully first.');
assert(isempty(findall(groot,'Type','figure','Tag','EEGLAB')), ...
    'Close existing EEGLAB windows and start in a new MATLAB session.');
core = fullfile(root,'eeglab2026.1.0');
restoredefaultpath;
addpath(root,core);
cd(root);
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab('full');
% The installer omits Fileio's standalone bootstrap so there is exactly one
% FieldTrip initializer. Let ft_defaults select paths; never genpath FieldTrip.
addpath(fullfile(core,'plugins','Fieldtrip-lite250523'),'-begin');
ft_defaults;
addpath(genpath(fullfile(root,'dependencies','MWF')));
end
