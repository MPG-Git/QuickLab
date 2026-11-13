function [n,info] = quicklab_data_rank(data)
% QUICKLAB_DATA_RANK Rank of centered EEG signals, using every sample.
% The covariance tolerance (1e-7 uV^2) follows EEGLAB's pop_runica policy.
% Work in double, in bounded blocks, including single-precision input. Merge
% centered block scatter matrices to avoid cancellation from large DC offsets.
if ~isnumeric(data) || ~isreal(data) || isempty(data) || any(~isfinite(data(:)))
    error('QuickLab:InvalidData','EEG data must be a finite, real numeric array.');
end
channels = size(data,1);
data = reshape(data,channels,[]);
count = 0; average = zeros(channels,1); scatter = zeros(channels);
for first = 1:10000:size(data,2)
    block = double(data(:,first:min(first+9999,size(data,2))));
    m = size(block,2); blockMean = mean(block,2);
    centered = bsxfun(@minus,block,blockMean);
    delta = blockMean-average;
    scatter = scatter + centered*centered' + (count*m/(count+m))*(delta*delta');
    average = average + delta*(m/(count+m));
    count = count+m;
end
covariance = scatter/max(1,count);
eigenvalues = sort(real(eig((covariance+covariance')/2)),'descend');
tolerance = max(1e-7,channels*eps(max([eigenvalues; 1])));
n = min(count-1,sum(eigenvalues > tolerance));
info = struct('rank',n,'channels',channels,'samples',count, ...
    'covarianceTolerance',tolerance,'covarianceEigenvalues',eigenvalues);
end
