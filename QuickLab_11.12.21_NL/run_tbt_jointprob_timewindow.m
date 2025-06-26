function [EEG, rejE] = run_tbt_jointprob_timewindow(EEG, timeWinMS, icacomp, chancomps, thresholds)
% timeWinMS: [start_ms end_ms]
% icacomp: 1 = use EEG.data (channels); 0 = use EEG.icaact (components)
% chancomps: vector of channels or components to test
% thresholds: [locthresh globthresh]

fprintf('[DEBUG] Thresholds used: local = %.2f, global = %.2f\n', thresholds(1), thresholds(2));

srate = EEG.srate;

% Convert time window (ms) to sample indices
t = linspace(EEG.xmin*1000, EEG.xmax*1000, EEG.pnts);  % epoch time in ms
[~, sampStart] = min(abs(t - timeWinMS(1)));
[~, sampEnd]   = min(abs(t - timeWinMS(2)));
fprintf('[DEBUG] Time window samples: %d to %d out of %d total\n', sampStart, sampEnd, EEG.pnts);
fprintf('[DEBUG] Channels/components tested: %s\n', mat2str(chancomps));
fprintf('[DEBUG] Thresholds used: loc=%.2f, glob=%.2f\n', thresholds(1), thresholds(2));

% Clip within bounds
sampStart = max(1, sampStart);
sampEnd   = min(EEG.pnts, sampEnd);

% Get data based on icacomp flag
if icacomp == 1
    data = eeg_getdatact(EEG); % channels × time × trials
    probStats = EEG.stats.jpE;
else
    if ~isfield(EEG, 'icaact') || isempty(EEG.icaact)
        EEG = eeg_checkset(EEG, 'ica'); % recompute ICA if needed
    end
    data = EEG.icaact; % components × time × trials
    probStats = EEG.stats.icajpE;
end

% Check chancomps indices
if max(chancomps) > size(data,1)
    error('Invalid component/channel index in chancomps (max = %d, available = %d)', ...
        max(chancomps), size(data,1));
end

numChans = length(chancomps);
numTrials = EEG.trials;
rejE = zeros(numChans, numTrials);
fprintf('[DEBUG] Data dimensions before loop: %s\n', mat2str(size(data))); % should be chan × time × trial

for i = 1:numChans
    ch = chancomps(i);
    sig = squeeze(data(ch, :, :));
    sig = reshape(sig, 1, size(sig,1), size(sig,2));  % 1 × time × trials
    fprintf('[DEBUG] Chan %d: sig reshaped to [%s]\n', ch, num2str(size(sig)));

    % Use existing probability stats if available, else leave empty
    if ~isempty(probStats)
        chanProb = probStats(ch,:);
    else
        chanProb = [];
    end

    [~, rejE(i,:)] = jointprob_NL(sig, thresholds, chanProb, 1, 1000, sampStart, sampEnd);
    fprintf('[DEBUG] Chan %d: rejection flags = [%s]\n', ch, num2str(rejE(i,:)));
end

EEG.reject.TBT.jointprob.winmin = timeWinMS(1);
EEG.reject.TBT.jointprob.winmax = timeWinMS(2);
end
