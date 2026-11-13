function [EEG,com] = quick_dipfit(EEG,comps,dipoles)
% [EEG,com] = quick_PCA(EEG,comps,dipoles) 
%
% Author: Ugo Bruzadin Nunes
%
% Copyright (C) 2021 Ugo Bruzadin Nunes
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; if not, write to the Free Software

if nargin < 3
    dipoles = 1; 
end

if nargin < 2
    comps = []; 
end

% Resolve models through the installed DIPFIT settings dialog. Preserve an
% existing valid alignment; never substitute a developer's hard-coded paths
% or silently assume the old lab's electrode coordinate transform.
com = '';
if isempty(EEG.icaweights)
    error('QuickLab:NoICA','Run ICA before fitting dipoles.');
end
if ~isfield(EEG,'dipfit') || ~isfield(EEG.dipfit,'hdmfile') || ~isfile(EEG.dipfit.hdmfile)
    [EEG,com] = pop_dipfit_settings(EEG);
    if isempty(com), return; end
    EEG = eegh(com,EEG);
end
if isempty(comps), comps = 1:size(EEG.icaweights,1); end
[EEG,com] = pop_multifit(EEG,comps,'threshold',100,'plotopt',{'normlen','on'},'dipoles',dipoles);
EEG = eegh(com,EEG);
end
