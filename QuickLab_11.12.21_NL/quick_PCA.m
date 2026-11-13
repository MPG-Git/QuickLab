function [EEG,com] = quick_PCA(EEG,IC,type,showPlots)
% QUICK_PCA Extended Infomax ICA, optionally reduced to IC dimensions.
% Uses bundled Windows BINICA when available; otherwise EEGLAB MATLAB runica.
% IC may be empty (estimated rank), a positive integer, or 'n-1'. Marked
% components are not silently removed: reject them explicitly before rerunning.
QuickLabDefs;
% Original QuickLab: Copyright (C) 2021 Ugo Bruzadin Nunes, GPL-2.0-or-later.
com = '';
if nargin < 2, IC = []; end
if nargin < 3 || isempty(type), type = ICATYPE; end
if nargin < 4 || isempty(showPlots), showPlots = true; end
if strcmpi(type,'auto')
    if ispc && ~isempty(which('ica_windows.exe')), type='binica';
    else, type='runica'; end
end
if isempty(EEG.data)
    error('QuickLab:NoData','Load a dataset before running ICA/PCA.');
end
[dataRank,info] = quicklab_data_rank(EEG.data);
if dataRank < 2
    error('QuickLab:InsufficientRank','ICA needs at least two independent signals (estimated rank: %d).',dataRank);
end
if ischar(IC) || (isstring(IC) && isscalar(IC))
    if ~strcmpi(IC,'n-1')
        error('QuickLab:InvalidComponents','Use a positive component count or ''n-1''.');
    end
    previousCount = size(EEG.icaweights,1);
    if previousCount == 0, previousCount = dataRank; end
    IC = min(previousCount,dataRank)-1;
end
if isempty(IC), IC = dataRank; end
if ~isnumeric(IC) || ~isscalar(IC) || ~isfinite(IC) || IC ~= fix(IC) || IC < 1 || IC > dataRank
    error('QuickLab:InvalidComponents', ...
        'Choose 1 to %d components. This dataset has %d channels and estimated rank %d.',dataRank,size(EEG.data,1),dataRank);
end
fprintf('QuickLab ICA: %d channels, estimated rank %d, %d components, algorithm %s.\n',size(EEG.data,1),dataRank,IC,type);
options = {'icatype',type,'extended',EXTENDED,'verbose',VERBOSE};
if IC < size(EEG.data,1), options = [options {'pca',IC}]; end
if strcmpi(type,'binica')
    EEG = quicklab_binica(EEG,IC,EXTENDED);
    com = sprintf('EEG = quick_PCA(EEG,%d,''binica'',0);',IC);
else
    [EEG,com] = pop_runica(EEG,options{:});
end
EEG = eegh(com,EEG);
info.components = IC;
info.algorithm = type;
EEG.etc.quicklab_ica = info;
if showPlots
    [EEG,plotcom] = quick_IClabel(EEG);
    EEG = eegh(plotcom,EEG);
end
end
