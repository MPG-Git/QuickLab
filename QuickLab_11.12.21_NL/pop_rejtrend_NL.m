function [EEG, com] = pop_rejtrend_NL(EEG, icacomp, elecrange, timeWinMS1, timeWinMS2, winsize, minslope, minstd, superpose, reject, calldisp)
        % [EEG, com] = pop_rejtrend_NL(EEG,1, 1:EEG.nbchan,-200 , 0 ,1500 , 0.5 , 0.3, 1, 0,0)

com = '';
if nargin < 1
    help pop_rejtrend_NL;
    return;
end
if nargin < 3
    icacomp = 1;
end
if icacomp == 0 && isempty(EEG.icasphere)
    ButtonName = questdlg('Do you want to run ICA now?', 'Confirmation', 'NO', 'YES', 'YES');
    switch ButtonName
        case 'NO', disp('Operation cancelled'); return;
        case 'YES', [EEG, com] = pop_runica(EEG);
    end
end

if ischar(elecrange)
    elecrange = eval(['[' elecrange ']']);
end
winsize  = double(winsize);
minslope = double(minslope);
minstd   = double(minstd);

% Convert time window (ms) to sample indices
epoch_ms = linspace(EEG.xmin*1000, EEG.xmax*1000, EEG.pnts);
[~, sampStart] = min(abs(epoch_ms - timeWinMS1));
[~, sampEnd]   = min(abs(epoch_ms - timeWinMS2));
sampStart = max(1, sampStart);
sampEnd   = min(EEG.pnts, sampEnd);

timeWinMS = [timeWinMS1 timeWinMS2];

fprintf('Running trend rejection on time window %d-%d ms (samples %d-%d)...\n', timeWinMS(1), timeWinMS(2), sampStart, sampEnd);

if icacomp == 1
    data = EEG.data(elecrange, sampStart:sampEnd, :);
    [rej, tmprejE] = rejtrend(data, sampEnd - sampStart + 1, minslope, minstd);

   % [rej, tmprejE] = rejtrend(data, winsize, minslope, minstd);
    rejE = zeros(EEG.nbchan, EEG.trials);
    rejE(elecrange,:) = tmprejE;
else
    icaact = eeg_getdatact(EEG, 'component', elecrange);
    data = icaact(:, sampStart:sampEnd, :);
    [rej, tmprejE] = rejtrend(data, sampEnd - sampStart + 1, minslope, minstd);

    %[rej, tmprejE] = rejtrend(data, winsize, minslope, minstd);
    rejE = zeros(size(icaact,1), EEG.trials);
    rejE(elecrange,:) = tmprejE;
end

rejtrials = find(rej > 0);
fprintf('%d channel(s)/component(s) tested\n', numel(elecrange));
fprintf('%d/%d trial(s) marked for rejection\n', numel(rejtrials), EEG.trials);

if calldisp
    macrorej  = fastif(icacomp == 1, 'EEG.reject.rejconst', 'EEG.reject.icarejconst');
    macrorejE = fastif(icacomp == 1, 'EEG.reject.rejconstE', 'EEG.reject.icarejconstE');
    colrej    = EEG.reject.rejconstcol;
    eeg_rejmacro;

    if icacomp == 1
        eegplot(EEG.data(elecrange,:,:), 'srate', EEG.srate, 'limits', [EEG.xmin EEG.xmax]*1000, 'command', command, eegplotoptions{:});
    else
        eegplot(icaact, 'srate', EEG.srate, 'limits', [EEG.xmin EEG.xmax]*1000, 'command', command, eegplotoptions{:});
    end
else
    if ~isempty(rej)
        if icacomp == 1
            EEG.reject.rejconst  = rej;
            EEG.reject.rejconstE = rejE;
        else
            EEG.reject.icarejconst  = rej;
            EEG.reject.icarejconstE = rejE;
        end
        if reject
            EEG = pop_rejepoch(EEG, rej, 0);
        end
    end
end
com = sprintf('EEG = pop_rejtrend_NL(EEG, [%d %d], %s);', timeWinMS(1), timeWinMS(2), vararg2str({icacomp, elecrange, winsize, minslope, minstd, superpose, reject, calldisp}));

end
