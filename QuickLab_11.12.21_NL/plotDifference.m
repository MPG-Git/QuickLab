function [report, figures] = plotDifference(ALLEEG, selection, makePlots)
% PLOTDIFFERENCE Compare two loaded EEGLAB datasets without changing them.
%   plotDifference(ALLEEG) compares last minus previous occupied dataset.
%   plotDifference(EEGa, EEGb) compares EEGa minus EEGb (legacy API).
%   plotDifference(ALLEEG, 'select') opens a chooser (last two preselected).
%   plotDifference(ALLEEG, [a b]) compares dataset a minus dataset b.
%   report = plotDifference(ALLEEG, [a b], false) returns statistics only.
%
% Load Infinity and Average versions of the SAME recording/retained epochs.
% Data are compared as stored: no re-referencing, filtering or mean removal.
% Channels are matched by label. Timing, events and available epoch identities
% must agree. Matching metadata alone cannot prove identical source samples.
% Supports numeric EEG.data, external .fdt data and 'in set file' datasets.
% Outputs: overlay, A-B scroll plot, and per-channel RMS difference chart.
% Statistics use all samples/epochs, in the original stored amplitude units.
% Requires EEGLAB. Compatible with MATLAB R2018b or later.

report = [];
figures = gobjects(0);
if nargin < 1 || ~isstruct(ALLEEG)
    error('QuickLab:Datasets', 'Pass the EEGLAB ALLEEG dataset array.');
end
if nargin < 2, selection = []; end
if isstruct(selection)
    if ~isscalar(ALLEEG) || ~isscalar(selection)
        error('QuickLab:Selection', 'The two-dataset API requires two scalar EEG structures.');
    end
    datasets = {ALLEEG, selection};
    selection = [1 2];
else
    datasets = num2cell(ALLEEG);
end
occupied = find(cellfun(@(e) isfield(e, 'nbchan') && ...
    isnumeric(e.nbchan) && isscalar(e.nbchan) && e.nbchan > 0, datasets));
if numel(occupied) < 2
    error('QuickLab:Datasets', ...
        'Load two versions of the same recording into EEGLAB first (for example, Infinity and Average).');
end
if isempty(selection), selection = occupied([end end-1]); end
if nargin < 3, makePlots = true; end
validateattributes(makePlots, {'logical','numeric'}, {'scalar','binary'});
if ischar(selection) || isstring(selection)
    if ~strcmpi(selection, 'select')
        error('QuickLab:Selection', 'Use ''select'' or two dataset indices.');
    end
    names = arrayfun(@(k) datasetName(datasets{k}, k), occupied, 'UniformOutput', false);
    [choice, ok] = listdlg('ListString', names, 'SelectionMode', 'multiple', ...
        'InitialValue', numel(occupied)-1:numel(occupied), 'ListSize', [650 250], ...
        'Name', 'Compare stored EEG data', ...
        'PromptString', {'Select exactly TWO versions of the same recording.', ...
        'Compare Infinity and Average with identical retained samples/epochs.', ...
        'Difference = first selected dataset (A) minus second (B).'});
    if ~ok, return; end
    selection = occupied(choice);
end
if ~isnumeric(selection) || numel(selection) ~= 2 || ...
        any(~ismember(selection, occupied)) || selection(1) == selection(2)
    error('QuickLab:Selection', 'Select exactly two different occupied dataset indices.');
end
selection = reshape(selection, 1, 2);
a = datasets{selection(1)}; b = datasets{selection(2)};
checkTiming(a, b);
checkEvents(a, b);
[labels, order] = matchChannels(a, b);
x = readData(a); y = readData(b);
y = y(order, :, :);
delta = x - y;
flat = reshape(delta, a.nbchan, []);
report.indices = selection;
report.names = {datasetName(a, selection(1)), datasetName(b, selection(2))};
report.channelLabels = labels(:);
report.secondChannelOrder = order;
report.samplesPerChannel = size(flat, 2);
report.meanDifference = mean(flat, 2);
report.rmsDifference = sqrt(mean(flat.^2, 2));
report.maxAbsDifference = max(abs(flat), [], 2);
report.overallRMS = sqrt(mean(report.rmsDifference.^2));
report.units = 'stored amplitude units';
fprintf('\nQuickLab comparison (A - B, data as stored)\nA: %s\nB: %s\n', report.names{:});
fprintf('%d channels; %d samples/channel; overall RMS difference = %.6g\n', ...
    a.nbchan, report.samplesPerChannel, report.overallRMS);
disp(table(report.channelLabels, report.meanDifference, report.rmsDifference, ...
    report.maxAbsDifference, 'VariableNames', {'Channel','Mean_A_minus_B','RMS','MaxAbsolute'}));
if ~makePlots, return; end
if isempty(which('eegplot'))
    error('QuickLab:MissingEEGLAB', 'Start EEGLAB before plotting the comparison.');
end

% Use the standard EEGLAB viewer, without a rejection command or store call.
% Explicitly turn off its default mean subtraction so DC differences remain.
locs = struct('labels', labels);
if a.trials > 1, window = min(5, a.trials);
else, window = min(5, a.pnts/a.srate); end
spacing = max(1, 2*max([std(reshape(x,a.nbchan,[]),0,2); ...
    std(reshape(y,a.nbchan,[]),0,2)]));
options = {'srate', a.srate, 'eloc_file', locs, 'submean', 'off', ...
    'limits', 1000*[a.xmin a.xmin+(a.pnts-1)/a.srate], ...
    'winlength', window, 'dispchans', min(32,a.nbchan), 'command', '', ...
    'color', {[0 0 0.65]}};
eegplot(x, options{:}, 'data2', y, 'spacing', spacing, ...
    'title', sprintf('A (blue): %s | B (red): %s', report.names{:}));
figures(end+1) = gcf;
eegplot(delta, options{:}, 'spacing', max(1,2*max(std(flat,0,2))), ...
    'title', sprintf('Difference A - B | %s minus %s', report.names{:}));
figures(end+1) = gcf;
figures(end+1) = figure('Name', 'QuickLab: RMS difference by channel', ...
    'NumberTitle', 'off', 'Color', 'w', 'Position', [150 150 1100 600]);
ax = axes('Parent', figures(end));
bar(ax, report.rmsDifference, 'FaceColor', [0.15 0.35 0.65]);
set(ax, 'XTick', 1:a.nbchan, 'XTickLabel', labels, 'TickLabelInterpreter', 'none');
xtickangle(ax, 45); grid(ax, 'on');
ylabel(ax, 'RMS(A - B), stored amplitude units');
xlabel(ax, 'Channel (all retained samples and epochs)');
title(ax, {['A: ' report.names{1}], ['B: ' report.names{2}], ...
    sprintf('Overall RMS difference: %.6g', report.overallRMS)}, 'Interpreter', 'none');
end

function checkTiming(a, b)
fields = {'nbchan','pnts','trials','srate','xmin'};
for k = 1:numel(fields)
    f = fields{k};
    if ~isfield(a,f) || ~isfield(b,f)
        error('QuickLab:Metadata', 'Both datasets need EEG.%s.', f);
    end
    validateattributes(a.(f), {'numeric'}, {'scalar','real','finite'});
    validateattributes(b.(f), {'numeric'}, {'scalar','real','finite'});
    if abs(double(a.(f))-double(b.(f))) > 1e-9
        error('QuickLab:TimingMismatch', ...
            'Datasets have different %s values. Use identical channels, sampling and retained samples/epochs.', f);
    end
end
if any([a.nbchan a.pnts a.trials a.srate] <= 0) || ...
        any(fix([a.nbchan a.pnts a.trials]) ~= [a.nbchan a.pnts a.trials])
    error('QuickLab:Metadata', 'Channel, sample and epoch counts must be positive integers, and sampling rate positive.');
end
% Compare each stored time axis with the sampling grid, allowing roundoff (ms).
for e = {a,b}
    d = e{1};
    if isfield(d,'times') && ~isempty(d.times)
        expected = 1000*(double(d.xmin)+(0:double(d.pnts)-1)/double(d.srate));
        if numel(d.times) ~= d.pnts || any(~isfinite(d.times(:))) || ...
                any(abs(double(d.times(:))-expected(:)) > 1e-3)
            error('QuickLab:TimingMismatch', 'Stored time axis does not match the sampling grid.');
        end
    end
end
end

function checkEvents(a, b)
if isfield(a,'epoch') && isfield(b,'epoch') && ...
        isfield(a.epoch,'eventurevent') && isfield(b.epoch,'eventurevent') && ...
        ~isequaln({a.epoch.eventurevent}, {b.epoch.eventurevent})
    error('QuickLab:EventMismatch', 'Original epoch identities/order differ.');
end
hasA = isfield(a,'event') && ~isempty(a.event);
hasB = isfield(b,'event') && ~isempty(b.event);
if hasA ~= hasB
    error('QuickLab:EventMismatch', 'Only one dataset has events; sample alignment cannot be checked.');
end
if ~hasA
    warning('QuickLab:NoEvents', ...
        'No event identities available. Verify that both datasets contain the same samples/epochs in the same order.');
    return;
end
if numel(a.event) ~= numel(b.event)
    error('QuickLab:EventMismatch', 'Event counts differ; use the same retained samples/epochs.');
end
fields = {'type','latency','epoch','urevent','duration'};
for k = 1:numel(fields)
    f = fields{k};
    ha = isfield(a.event,f); hb = isfield(b.event,f);
    if ha ~= hb
        error('QuickLab:EventMismatch', 'Event %s metadata exists in only one dataset.', f);
    end
    if ha
        va = {a.event.(f)}; vb = {b.event.(f)};
        if strcmp(f,'type')
            va = cellfun(@valueText, va, 'UniformOutput', false);
            vb = cellfun(@valueText, vb, 'UniformOutput', false);
        end
        if ~isequaln(va, vb)
            error('QuickLab:EventMismatch', ...
                'Event %s values/order differ. Use the same retained samples/epochs.', f);
        end
    end
end
end

function [labels, order] = matchChannels(a, b)
la = channelLabels(a); lb = channelLabels(b);
if all(cellfun('isempty',la)) && all(cellfun('isempty',lb))
    warning('QuickLab:UnlabelledChannels', ...
        'Neither dataset has channel labels. Verify identical channel order; comparing by channel number.');
    labels = arrayfun(@(k) sprintf('Ch%d',k), 1:a.nbchan, 'UniformOutput', false);
    order = 1:a.nbchan;
    return;
end
ka = cellfun(@lower, la, 'UniformOutput', false);
kb = cellfun(@lower, lb, 'UniformOutput', false);
if any(cellfun('isempty',ka)) || any(cellfun('isempty',kb)) || ...
        numel(unique(ka)) ~= a.nbchan || numel(unique(kb)) ~= b.nbchan
    error('QuickLab:ChannelMismatch', 'Both datasets must have complete, unique channel labels.');
end
[found, order] = ismember(ka, kb);
if ~all(found)
    error('QuickLab:ChannelMismatch', 'Channel label sets differ. Compare the same channels in both datasets.');
end
labels = la;
end

function labels = channelLabels(e)
labels = repmat({''}, 1, e.nbchan);
if isfield(e,'chanlocs') && ~isempty(e.chanlocs) && isfield(e.chanlocs,'labels')
    if numel(e.chanlocs) ~= e.nbchan
        error('QuickLab:ChannelMismatch', 'Channel label count does not match EEG.nbchan.');
    end
    labels = cellfun(@(s) strtrim(valueText(s)), {e.chanlocs.labels}, 'UniformOutput', false);
end
end

function data = readData(e)
if ~isfield(e,'data')
    error('QuickLab:Data', 'Dataset has no EEG.data field.');
end
if isnumeric(e.data) && ~isempty(e.data)
    data = e.data;
else
    if isempty(which('eeg_getdatact'))
        error('QuickLab:MissingEEGLAB', 'Start EEGLAB to read datasets stored on disk.');
    end
    data = eeg_getdatact(e);
end
if ~isnumeric(data) || ~isreal(data) || size(data,1) ~= e.nbchan || ...
        numel(data) ~= e.nbchan*e.pnts*e.trials || ...
        ~(isequal(size(data), [e.nbchan e.pnts*e.trials]) || ...
          (size(data,2) == e.pnts && size(data,3) == e.trials && ndims(data) <= 3))
    error('QuickLab:Data', 'Data dimensions do not match channel/sample/epoch metadata.');
end
data = reshape(double(data), e.nbchan, e.pnts, e.trials);
if any(~isfinite(data(:)))
    error('QuickLab:Data', 'Data contain NaN or Inf; resolve missing/nonfinite samples before comparing.');
end
end

function name = datasetName(e, index)
label = '';
if isfield(e,'setname'), label = valueText(e.setname); end
if isempty(label) && isfield(e,'filename'), label = valueText(e.filename); end
if isempty(label), label = 'unnamed dataset'; end
ref = 'unspecified';
if isfield(e,'ref') && ~isempty(e.ref), ref = valueText(e.ref); end
if strcmpi(ref,'averef') || strcmpi(ref,'average'), ref = 'Average'; end
name = sprintf('#%d %s [ref: %s]', index, label, ref);
end

function text = valueText(value)
if ischar(value)
    text = value;
elseif isstring(value)
    text = char(value);
elseif isnumeric(value)
    text = num2str(value);
elseif iscell(value)
    text = strjoin(cellfun(@valueText, value, 'UniformOutput', false), ', ');
else
    text = 'unspecified';
end
end
