function [EEG, Irej, com] = pop_eegthresh_NL(EEG, timeWinMS, icacomp, elecrange, negthresh, posthresh, ...
    starttime, endtime, superpose, reject, topcommand)
winmin_ms = timeWinMS(1);
winmax_ms = timeWinMS(2);
Irej = [];
com = '';
if nargin < 1
   help pop_eegthresh_NL;
   return;
end
if nargin < 2
   icacomp = 1;
end

if icacomp == 0 && isempty(EEG(1).icasphere)
    disp('Error: you must run ICA first'); return;
end
if exist('reject') ~= 1
    reject = 1;
end

% Check time window (ms) and convert to sample range
srate = EEG.srate;
t_ms = linspace(EEG.xmin*1000, EEG.xmax*1000, EEG.pnts);
[~, sampStart] = min(abs(t_ms - winmin_ms));
[~, sampEnd]   = min(abs(t_ms - winmax_ms));
sampStart = max(1, sampStart);
sampEnd   = min(EEG.pnts, sampEnd);

fprintf('[DEBUG] Window samples: %d to %d / %d total', sampStart, sampEnd, EEG.pnts);

% Clip start/end time limits
if any(starttime < EEG.xmin)
    fprintf('Warning: starttime < EEG.xmin, adjusted');
    starttime(starttime < EEG.xmin) = EEG.xmin;
end
if any(endtime > EEG.xmax)
    fprintf('Warning: endtime > EEG.xmax, adjusted');
    endtime(endtime > EEG.xmax) = EEG.xmax;
end
if isempty(elecrange)
    elecrange = 1:EEG.nbchan;
end

if icacomp == 1
    data = EEG.data(elecrange, sampStart:sampEnd, :);
else
    data = eeg_getdatact(EEG, 'component', elecrange);
    data = data(:, sampStart:sampEnd, :);
end

% Call eegthresh with trimmed data
[~, Irej, ~, Erej] = eegthresh(data, size(data,2), 1:length(elecrange), negthresh, posthresh, ...
    [EEG.xmin EEG.xmax], starttime, endtime);

rej  = zeros(1, EEG.trials);
rej(Irej) = 1;
rejE = zeros(size(data,1), EEG.trials);
rejE(:, Irej) = Erej;

% Store results
if icacomp == 1
    EEG.reject.rejthresh  = rej;
    EEG.reject.rejthreshE = rejE;
else
    EEG.reject.icarejthresh  = rej;
    EEG.reject.icarejthreshE = rejE;
end

fprintf('%d/%d trials marked for rejection', length(Irej), EEG.trials);

% Compose command string
com = sprintf('EEG = pop_eegthresh_NL(EEG, %d, [%s], [%s], [%s], [%s], [%s], %d, %d);', ...
        icacomp, num2str(elecrange), num2str(negthresh), num2str(posthresh), ...
        num2str(starttime), num2str(endtime), winmin_ms, winmax_ms);

