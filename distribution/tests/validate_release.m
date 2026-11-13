function validate_release(root, outputDirectory)
% VALIDATE_RELEASE Regression checks for the managed desktop distribution.
% Run in a fresh MATLAB session. Output must be a new directory.
assert(~isfolder(outputDirectory),'Choose a new output directory.');
mkdir(outputDirectory);
addpath(root);
startup=evalc('[ALLEEG,EEG,CURRENTSET,ALLCOM] = start_eeglab_replacement;');
fprintf('%s',startup);
assert(~contains(startup,'Multiple versions of FieldTrip'));
assert(~contains(startup,'You probably used addpath(genpath'));
assert(~contains(startup,'new version') && ~contains(startup,'v? (see'));
assert(~contains(startup,'version in the folder name'));
report=check_eeglab_replacement;
assert(numel(report.startup)==54);
assert(numel(findall(groot,'Type','uimenu','Tag','quicklab_menu'))==1);
assert(numel(findall(groot,'Type','uimenu','Label','Source reconstruction of ERP'))==1);
assert(numel(findall(groot,'Type','uimenu','Label','Reject by Max-Min Threshold'))==1);
run_replacement_examples(fullfile(outputDirectory,'examples'));
% SPM's NIfTI API and compiled Windows reader; no native SPM M/EEG session.
spm('defaults','FMRI');
[v,r]=spm('Ver'); assert(strcmp(v,'SPM26') && strcmp(r,'26.10.01'));
assert(exist('spm_sample_vol','file')==3);
vol=struct('fname',fullfile(outputDirectory,'synthetic_spm.nii'), ...
 'dim',[4 5 6],'dt',[16 0],'mat',eye(4),'pinfo',[1;0;0]);
known=reshape(single(1:120),[4 5 6]);
spm_write_vol(vol,known); loaded=spm_vol(vol.fname);
assert(isequal(spm_read_vols(loaded),double(known)));
assert(spm_sample_vol(loaded,2,3,4,0)==double(known(2,3,4)));
% Every Fileio reader is retained; exercise reading an actual synthetic set.
file=fullfile(root,'eeglab2026.1.0','plugins','QuickLabMPG1.1.0', ...
 'examples','synthetic','data','synthetic_average.set');
header=ft_read_header(file); data=ft_read_data(file);
assert(header.nChans==3 && size(data,1)==3 && all(isfinite(data(:))));
check_eeglab_replacement;
fid=fopen(fullfile(outputDirectory,'PASS.txt'),'w');
assert(fid>=0); cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'PASS: startup, version metadata, practice examples, SPM NIfTI and FieldTrip import.\n');
close all force;
end
