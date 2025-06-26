function [Irej, Irejdetails, n, threshold, thresholdg] = rejstatepoch_NL(signal, rej, varargin)
    % Defaults
    threshold   = 5;
    thresholdg  = threshold;
    plotFlag    = 'off';
    globalrej   = 'off';
    normalize   = 'on';
    rejglob     = [];
    plotcom     = '';
    graphtitle  = '';
    labels      = [];
    winmin      = 1;
    winmax      = size(signal,2);

    % Parse input arguments
    for i = 1:2:length(varargin)
        switch lower(varargin{i})
            case 'plot',       plotFlag   = varargin{i+1};
            case 'threshold',  threshold  = varargin{i+1};
            case 'thresholdg', thresholdg = varargin{i+1};
            case 'global',     globalrej  = varargin{i+1};
            case 'rejglob',    rejglob    = varargin{i+1};
            case 'normalize',  normalize  = varargin{i+1};
            case 'plotcom',    plotcom    = varargin{i+1};
            case 'title',      graphtitle = varargin{i+1};
            case 'labels',     labels     = varargin{i+1};
            case 'winmin',     winmin     = varargin{i+1};
            case 'winmax',     winmax     = varargin{i+1};
        end
    end

    fprintf('[DEBUG] rejstatepoch_NL: signal size = [%d %d %d]\n', size(signal));
    fprintf('[DEBUG] Time window: [%d to %d]\n', winmin, winmax);

    % Normalize if requested
    if strcmpi(normalize, 'on')
        rej = (rej - mean(rej(:))) ./ std(rej(:));
        fprintf('[DEBUG] Normalized local rejection matrix.\n');
        if ~isempty(rejglob)
            rejglob = (rejglob - mean(rejglob)) ./ std(rejglob);
            fprintf('[DEBUG] Normalized global rejection array.\n');
        end
    end

    % Reject trials locally (per channel/component)
    Irejdetails = abs(rej) > threshold;
    fprintf('[DEBUG] Local rejection threshold: %.2f\n', threshold);

    % Reject trials globally (across all channels)
    if strcmpi(globalrej, 'on')
        if isempty(rejglob)
            rejglob = mean(rej);
            fprintf('[DEBUG] Computed global rejection from mean across channels.\n');
        end
        globrej = abs(rejglob) > thresholdg;
        Irejdetails(:, globrej) = 1;
        fprintf('[DEBUG] Global rejection threshold: %.2f\n', thresholdg);
        fprintf('[DEBUG] Total global rejected trials: %d\n', nnz(globrej));
    end

    % Final rejection list
    Irej = find(sum(Irejdetails, 1));
    n = length(Irej);
    fprintf('[DEBUG] Total trials rejected: %d out of %d\n', n, size(signal,3));

    % Optional plotting
    if strcmpi(plotFlag, 'on')
        figure('Name', 'RejStateEpoch NL', 'NumberTitle', 'off');
        imagesc(Irejdetails);
        xlabel('Trials');
        ylabel('Channels/Components');
        title(graphtitle);
        colorbar;
    end
end