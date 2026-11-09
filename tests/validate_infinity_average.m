function result = validate_infinity_average(eeglabRoot, outputFolder)
% VALIDATE_INFINITY_AVERAGE Exercise actual REST Infinity vs Average data.
% Requires EEGLAB sample_data, REST 1.2, REST_fieldtrip, DIPFIT and FieldTrip
% installed under eeglabRoot/plugins. Creates reports/PNGs, not EEG files.
% Example (after adding this repository's tests folder to the MATLAB path):
%   validate_infinity_average('C:/eeglab2024', tempname)

oldPath = path;
cleanupPath = onCleanup(@() path(oldPath)); %#ok<NASGU>
repo = fileparts(fileparts(mfilename('fullpath')));
plugin = fullfile(repo,'QuickLab_11.12.21_NL');
addpath(eeglabRoot, genpath(fullfile(eeglabRoot,'functions')));
restRoot = pluginFolder(eeglabRoot,'dong_calc_leadfield3.m');
restFieldtrip = pluginFolder(eeglabRoot,'pop_refrefinf.m');
dipfitRoot = pluginFolder(eeglabRoot,'eeglab2fieldtrip.m');
% Fileio also ships ft_defaults, but cannot perform source reconstruction.
fieldtripRoot = pluginFolder(eeglabRoot,'ft_defaults.m','ft_sourceanalysis.m');
addpath(restRoot,restFieldtrip,dipfitRoot,fieldtripRoot);
ft_defaults;
addpath(plugin,'-begin');
assert(strcmp(which('plotDifference'),fullfile(plugin,'plotDifference.m')), ...
    'A different QuickLab copy is shadowing this repository.');
if ~exist(outputFolder,'dir'), mkdir(outputFolder); end

base = pop_loadset('filename','eeglab_data_epochs_ica.set', ...
    'filepath',fullfile(eeglabRoot,'sample_data'));
% Use real sample EEG, excluding auxiliary EOG channels, with four epochs.
eog = find(strncmpi({base.chanlocs.labels},'EOG',3));
base = pop_select(base,'nochannel',eog,'trial',1:min(4,base.trials));
base.data = double(base.data);
base.icaweights = []; base.icasphere = []; base.icawinv = [];
base.icaact = []; base.icachansind = [];
labels = {base.chanlocs.labels};
xyz = [[base.chanlocs.X]' [base.chanlocs.Y]' [base.chanlocs.Z]'];
assert(isequal(size(xyz),[base.nbchan 3]) && all(isfinite(xyz(:))));
directions = bsxfun(@rdivide,xyz,sqrt(sum(xyz.^2,2)));
% EEGLAB nose +X / left +Y -> REST nose +Y / left -X, unit scalp sphere.
pos = [-directions(:,2) directions(:,1) directions(:,3)];
% Use the official REST 1.2 public functions; dong_getleadfield is absent
% from its catalog ZIP. Parameters match the REST GUI's standard model.
dipoles = load(fullfile(restRoot,'corti869-3000dipoles.dat'),'-ascii');
orientations = bsxfun(@rdivide,dipoles,sqrt(sum(dipoles.^2,2)));
orientations(2601:3000,:) = repmat([0 0 1],400,1);
headmodel = struct('type','concentricspheres','o',[0 0 0], ...
    'r',[.87 .92 1],'cond',[1 .0125 1],'tissue',{{'brain','skull','scalp'}});
G = dong_calc_leadfield3(pos,dipoles,orientations,headmodel);
assert(isequal(size(G),[base.nbchan 3000]) && all(isfinite(G(:))));
rmax = max(sqrt(sum(dipoles.^2,2)));
if rmax >= .87, dipoles = dipoles*(.869/rmax); end
model.pos = 85*dipoles; model.unit = 'mm'; model.coordsys = 'ras';
model.label = labels(:); model.inside = true(size(dipoles,1),1);
model.leadfield = num2cell(G,1).'; model.leadfielddimord = '{pos}_chan_ori';
base.dipfit = struct('coordformat','spherical', ...
    'coord_transform',[0 0 0 0 0 -pi/2 1 1 1], ...
    'chansel',1:base.nbchan,'sourcemodel',model);
for k = 1:base.nbchan
    base.chanlocs(k).X = 85*directions(k,1);
    base.chanlocs(k).Y = 85*directions(k,2);
    base.chanlocs(k).Z = 85*directions(k,3);
    base.chanlocs(k).type = 'EEG';
end

average = pop_reref(base,[]);
average.setname = 'Sample EEG - Average';
infinity = pop_refrefinf(base,'infinity');
infinity.ref = 'Infinity'; infinity.setname = 'Sample EEG - Infinity (REST)';
% REST_fieldtrip does not set EEG.ref itself; label the known operation.
[infinity.chanlocs.ref] = deal('Infinity');
storedDifference = double(infinity.data)-double(average.data);
expectedRMS = sqrt(mean(reshape(storedDifference,base.nbchan,[]).^2,2));
% Independently compare the FieldTrip result to the REST toolbox routine.
nativeREST = rest_refer(reshape(double(average.data),base.nbchan,[]),G.');
nativeError = max(abs(nativeREST(:)-double(infinity.data(:))));
assert(nativeError < 1e-4,'FieldTrip Infinity differs from the REST reference calculation.');
assert(max(expectedRMS) > 1e-3,'Fixture does not distinguish Infinity from Average.');
offset = mean(reshape(storedDifference,base.nbchan,[]),1);
residual = bsxfun(@minus,reshape(storedDifference,base.nbchan,[]),offset);
assert(max(abs(residual(:))) < 1e-4,'Reference change unexpectedly altered between-channel voltages.');

before = {infinity,average};
[report,figs] = plotDifference(infinity,average);
cleanupFigures = onCleanup(@() closeValid(figs)); %#ok<NASGU>
assert(isequaln(before,{infinity,average}),'Comparison mutated its input datasets.');
assert(max(abs(report.rmsDifference-expectedRMS)) < 1e-10);
assert(max(abs(report.meanDifference-mean(reshape(storedDifference,base.nbchan,[]),2))) < 1e-10);
assert(contains(report.names{1},'Infinity') && contains(report.names{2},'Average'));
% Check that the viewer actually received signed differences and unmodified
% overlay samples; statistical correctness alone would miss a plotting bug.
diffAxes = findobj(figs(2),'Tag','eegaxis');
plottedDifference = get(diffAxes,'UserData');
assert(isequal(double(plottedDifference(:)),storedDifference(:)));
overlayAxes = findobj(figs(1),'Tag','eegaxis');
plottedInfinity = get(overlayAxes,'UserData');
assert(isequal(double(plottedInfinity(:)),double(infinity.data(:))));
overlaySettings = get(figs(1),'UserData');
assert(isequal(double(overlaySettings.data2(:)),double(average.data(:))));
assert(strcmp(overlaySettings.submean,'off'));
exportgraphics(overlayAxes,fullfile(outputFolder,'infinity_average_overlay.png'),'Resolution',120);
exportgraphics(diffAxes,fullfile(outputFolder,'infinity_minus_average.png'),'Resolution',120);
exportgraphics(figs(3),fullfile(outputFolder,'infinity_average_rms.png'),'Resolution',120);
% Verify default/explicit array calls and channel reordering with real output.
pair = [average infinity];
last = plotDifference(pair,[],false);
assert(max(abs(last.meanDifference-report.meanDifference)) < 1e-10);
reordered = average;
reordered.data = reordered.data(end:-1:1,:,:);
reordered.chanlocs = reordered.chanlocs(end:-1:1);
matched = plotDifference(infinity,reordered,false);
assert(max(abs(matched.rmsDifference-report.rmsDifference)) < 1e-10);

result = struct('status','PASS','matlab',version,'eeglab',eeg_getversion, ...
    'comparisonFunction',which('plotDifference'),'channels',base.nbchan, ...
    'epochs',base.trials,'samplesPerChannel',report.samplesPerChannel, ...
    'overallRMS',report.overallRMS,'nativeRESTMaxError',nativeError, ...
    'maxDifferentialResidual',max(abs(residual(:))), ...
    'dataSource','EEGLAB sample_data/eeglab_data_epochs_ica.set', ...
    'infinityMethod','REST_fieldtrip pop_refrefinf with REST 1.2 three-sphere / 3000-dipole leadfield', ...
    'averageMethod','EEGLAB pop_reref(EEG, [])');
writetable(table(report.channelLabels,report.meanDifference,report.rmsDifference, ...
    report.maxAbsDifference,'VariableNames',{'Channel','MeanInfinityMinusAverage','RMS','MaxAbsolute'}), ...
    fullfile(outputFolder,'infinity_average_statistics.csv'));
fid = fopen(fullfile(outputFolder,'infinity_average_validation.json'),'w');
assert(fid ~= -1,'Cannot write validation summary.');
cleanupFile = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(result));
disp(result);
end

function folder = pluginFolder(root, file, requiredFile)
matches = dir(fullfile(root,'plugins','*',file));
if nargin > 2
    matches = matches(arrayfun(@(m) exist(fullfile(m.folder,requiredFile),'file') == 2,matches));
end
assert(numel(matches)==1,'Expected exactly one installed %s under EEGLAB/plugins.',file);
folder = matches(1).folder;
end

function closeValid(figs)
delete(figs(isgraphics(figs)));
end
