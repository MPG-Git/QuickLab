% JOINTPROB - rejection of odd columns of a data array  using 
%              joint probability of the values in that column (and
%              using the probability distribution of all columns).
%
% Usage:
%   >>  [jp rej] = jointprob( signal );
%   >>  [jp rej] = jointprob( signal, threshold, jp, normalize, discret, winmin, winmax);
%  
%
% Inputs:
%   signal     - one dimensional column vector of data values, two 
%                dimensional column vector of values of size 
%                sweeps x frames or three dimensional array of size 
%                component x sweeps x frames. If three dimensional, 
%                all components are treated independently. 
%   threshold  - Absolute threshold. If normalization is used then the 
%                threshold is expressed in standard deviation of the
%                mean. 0 means no threshold.
%   jp         - pre-computed joint probability (only perform thresholding). 
%                Default is the empty array [].
%   normalize  - 0 = do not not normalize entropy. 1 = normalize entropy.
%                2 is 20% trimming (10% low and 10% high) proba. before 
%                normalizing. Default is 0.
%   discret    - discretization variable for calculation of the 
%                discrete probability density. Default is 1000 points.
%   winmin     - (optional) minimum time window index for analysis (in ms or sample index)
%   winmax     - (optional) maximum time window index for analysis (in ms or sample index)
% 
% Outputs:
%   jp         - normalized joint probability  of the single trials 
%                (size component x sweeps)
%   rej        - rejected matrix (0 and 1, size comp x sweeps)
%
% Remark:
%   The exact values of joint-probability depend on the size of a time 
%   step and thus cannot be considered as absolute.
%
% See also: REALPROBA

function [jp, rej] = jointprob_NL( signal, threshold, oldjp, normalize, discret, winmin, winmax );

if nargin < 1
	help jointprob;
	return;
end	
if nargin < 2
	threshold = 0;
end	
if nargin < 3
	oldjp = [];
end	
if nargin < 4
	normalize = 0;
end	
if nargin < 5
	discret = 1000;
end	
if nargin < 6
	winmin = 1;
end
if nargin < 7
	winmax = size(signal,2);
end

if size(signal,2) == 1 % transpose if necessary
	signal = signal';
end

[nbchan, pnts, sweeps] = size(signal);
jp  = zeros(nbchan,sweeps);

% Restrict analysis to time window
winmin = max(1, winmin);
winmax = min(pnts, winmax);

fprintf('[DEBUG] jointprob_NL: signal size = [%d %d %d]\n', nbchan, pnts, sweeps);
fprintf('[DEBUG] Time window applied: [%d to %d]\n', winmin, winmax);

if exist('oldjp', 'var') && ~isempty(oldjp)  % use cached jp
    jp = oldjp;
else
    for rc = 1:nbchan
        for index = 1:sweeps
            trialData = squeeze(signal(rc, winmin:winmax, index));  % limited time window
            if isempty(trialData)
                warning('[DEBUG] trialData is empty at chan %d, trial %d. Skipping.', rc, index);
                continue;
            end
            [dataProba, ~] = realproba(trialData, discret);
            if any(dataProba <= 0)
                warning('[DEBUG] Non-positive probabilities found at chan %d, trial %d. Clipping.', rc, index);
                dataProba(dataProba <= 0) = eps;
            end
            jp(rc, index) = -sum(log(dataProba));
            if index == 1 || rc == 1
                fprintf('[DEBUG] Channel %d, Trial %d: -log(prob) = %.4f\n', rc, index, jp(rc, index));
            end
        end
    end

    % normalize the last dimension
    if normalize
		tmpjp = jp;
		if normalize == 2
			tmpjp = sort(jp, 2);  % sort across trials (dim 2)
			n = size(tmpjp, 2);
			tmpjp = tmpjp(:, round(0.1*n):round(0.9*n));  % trim 10%
		end

		mu = mean(tmpjp, 2);      % mean across trials (1 value per channel)
		sigma = std(tmpjp, 0, 2); % std across trials

		% Subtract mean and divide by std for each channel across trials
		jp = (jp - mu) ./ sigma;
	end

    fprintf('[DEBUG] JP stats after normalization: min = %.4f, max = %.4f\n', min(jp(:)), max(jp(:)));
end

% reject
fprintf('[DEBUG] Threshold for rejection: %s\n', mat2str(threshold));
    if length(threshold) > 1
        if threshold(1) == threshold(2)
            rej = abs(jp) > threshold(1);  % symmetric threshold
        else
            rej = (jp < threshold(1)) | (jp > threshold(2));
        end

    else
    	rej = abs(jp) > threshold;
    end


fprintf('[DEBUG] -log(prob) min/max: %.2f / %.2f\n', min(jp(:)), max(jp(:)));

return;
