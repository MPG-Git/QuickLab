%QuickLabDefs() Calling this function will alter the defaults of QuickLab
%               QuickLab is a compilation of modified EEGLAB functions
%               for experienced users that wish to speed up manual
%               process, made by Ugo Bruzadin Nunes in
%               colaboration with the INL lab in Carbondale, IL.
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
%% COLOR DEFAULTS
BUTTONCOLOR = [0.9 0.9 0.9];
BACKGROUNDCOLOR = [.66 .76 1];

%% FILTER DEFAULTS
HIGHPASS = 2;
LOWPASS = 55;
NOTCHFILTER = 60;

%% EEGPLOTW2 DEFAULTS



%% SPECTOPO DISPLAY DEFAULTS
% Highest Frequency, Lowest Frequency, Maxwindow
FREQDISPLAYDEFS = [40,2,2048];
% Specific Expected Frequencies for Topoplot Display 
SPECTRATOPO = [2 3 4 5 6 7 8 9 10 11 12 13 14 15 18 20 25 30 36];

%% Headmodel and references defaults
% Location of Headmodel(s)
HEADMODELLOCATION = [''];

% References
OG_REF = 'Cz';
CZ_REF = 'Cz';
LE_REFS = [57 100];

try
    if ~isempty(EEG)
        if EEG.nbchan == 92
            LE_REFS = [44 74];
        elseif EEG.nbchan == 128
            LE_REFS = [57 100];
        else
            LE_REFS = [57 100];
        end
    end
catch
end

REFLOC = struct('labels',{'Cz'},'Y',{0},'X',{0},'Z',{8.7919},'sph_theta',{0},'sph_phi',{0},'sph_radius',{0},'theta',{0},'radius',{0},'type',{''},'ref',{'Cz'},'urchan',{[]},'datachan',{0});
KEEPREF = 'on';

%% CORRMAP defaults
% CORRMAP folder locations
CORRMAPDEFS = [''];

%% Defaults for PCA/ICA & ICLABEL
ICATYPE = 'binica';
EXTENDED = 1;
VERBOSE = 'off';
PCADEFS = ['icatype',ICATYPE,'extended',EXTENDED,'verbose',VERBOSE];
% ICLABEL type, Highest Frequency, Lowest Frquency

ICLABELDEFS = ['default',40,2];

%% Number of dipoles to plot in DIPFIT (1 or 2)
DIPFITDEFS = [1];
OTHERDIPFITDEFS = [];

%% Defaults for running BSS
BSSDEFS = [];

%% Defaults for lowpass and highpass filter for quick filter
% smallest frequency, highest frequency, in between steps
LOWPASSDEFS = [14,40,1];
HIGHPASSDEFS = [0.5,0.5,22];

%% Default for epoching the data
% Epoch name(s), if any
EPOCHNAMES = ['DIN '];
% Epoch time pre and post (1)
EPOCH1DEFS = [0.600,2.648];
% Epoch time pre and post (2)
EPOCH2DEFS = [-1,3.096];
% Recurrent epoch length
EPOCHLENGTH = 1;

%% Binary default options for data plotting and saving in QuickLab

% Should ICLABEL be plotted after every iclabel run?
PLOTICLABELS = 1;
% Should every data modification try to plot the data difference?
PLOTDATADIFF = 1;

% Should every data modification save the markers in a new file?
SAVADATAMARKERS = 1;
% if so, what should the new file markers be named?
SAVEDATAMARKERTITLE = 'SM';