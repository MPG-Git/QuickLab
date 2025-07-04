% POP_JOINTPROB - reject artifacts in an EEG dataset using joint 
%                   probability of the recorded electrode or component 
%                   activities observed at each time point.  e.g., Observing 
%                   large absolute values at most electrodes or components 
%                   is improbable and may well mark the presence of artifact.
% Usage:
%   >> pop_jointprob( INEEG, typerej) % pop-up interactive window mode
%   >> [OUTEEG, locthresh, globthresh, nrej] = ...
%		= pop_jointprob( INEEG, typerej, elec_comp, ...
%                   locthresh, globthresh, superpose, reject, vistype);
%
% Graphic interface:
%   "Electrode|Component" - [edit box] electrodes or components indices to take 
%                 into consideration for rejection. Same as the 'elec_comp'
%                 parameter in the command line call (see below).
%   "Single-channel limit|Single-component limit" - [edit box] activity 
%                 probability limit(s) (in  std. dev.) Sets the 'locthresh'
%                  command line parameter. If more than one, defined individual 
%                 electrode|channel limits. If fewer values than the number 
%                 of electrodes|components specified above, the last input  
%                 value is used for all remaining electrodes|components.
%   "All-channel limit|All-component limit" - [edit box] activity probability 
%                 limit(s) (in std. dev.) for all channels (grouped). 
%                 Sets the 'globthresh' command line parameter.
%   "visualization type" - [popup menu] can be either 'REJECTRIALS'|'EEGPLOT'.
%                 This correspond to the command line input option 'vistype'
%   "Display with previous rejection(s)" - [checkbox] This checkbox set the
%                 command line input option 'superpose'.          
%   "Reject marked trial(s)" - [checkbox] This checkbox set the command
%                  line input option 'reject'.
% Inputs:
%   INEEG      - input dataset
%   typerej    - [1|0] data to reject on (0 = component activations; 
%              1 = electrode data). {Default: 1 = electrode data}. 
%   elec_comp  - [n1 n2 ...] electrode|component number(s) to take into 
%              consideration for rejection
%   locthresh  - activity probability limit(s) (in std. dev.) See "Single-
%              channel limit(s)" above.
%   globthresh - global limit(s) (all activities grouped) (in std. dev.)
%   superpose  - [0|1] 0 = Do not superpose rejection marks on previously
%              marks stored in the dataset: 1 = Show both current and 
%              previous marks using different colors. {Default: 0}.
%   reject     - 0 = do not reject marked trials (but store the marks: 
%              1 = reject marked trials {Default: 1}.
%   vistype    - Visualization type. [0] calls REJSTATEPOCH and [1] calls
%              EEGPLOT default is [0].When added to the command line
%              call it will not display the plots if the option 'plotflag'
%              is not set.
% topcommand   - [] Deprecated argument , keep to ensure backward compatibility
% plotflag     - [1,0] [1]Turns plots 'on' from command line, [0] off.
%              (Note for developers: When called from command line 
%              it will make 'calldisp = plotflag') {Default: 0}
%
% Outputs:
%   OUTEEG     - output dataset with updated joint probability array
%   locthresh  - electrodes probability of activity thresholds in terms
%              of standard-dev.
%   globthresh - global threshold (where all electrode activity are 
%              regrouped).
%   nrej       - number of rejected sweeps
%
% Author: Arnaud Delorme, CNL / Salk Institute, 2001
%
% See also: JOINTPROB, REJSTATEPOCH, EEGPLOT, EEGLAB, POP_REJEPOCH  

% Copyright (C) 2001 Arnaud Delorme, Salk Institute, arno@salk.edu
%
% This file is part of EEGLAB, see http://www.eeglab.org
% for the documentation and details.
%
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are met:
%
% 1. Redistributions of source code must retain the above copyright notice,
% this list of conditions and the following disclaimer.
%
% 2. Redistributions in binary form must reproduce the above copyright notice,
% this list of conditions and the following disclaimer in the documentation
% and/or other materials provided with the distribution.
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
% THE POSSIBILITY OF SUCH DAMAGE.

% 01-25-02 reformated help & license -ad 
% 03-07-02 added srate argument to eegplot call -ad
% 03-08-02 add eeglab options -ad
function [EEG, locthresh, globthresh, nrej, com] = pop_jointprob_NL( EEG, icacomp, elecrange, ...
                        		locthresh, globthresh, superpose, reject, vistype, topcommand, plotflag, winmin, winmax)


% Store the user-defined time window for later access in EEG.reject.TBT.jointprob
EEG.reject.TBT.jointprob.winmin = winmin;
EEG.reject.TBT.jointprob.winmax = winmax;



nrej = []; com = '';
if nargin < 1
   help pop_jointprob;
   return;
end
if nargin < 2
   icacomp = 1;
end

if icacomp == 0
	if isempty( EEG.icasphere )
	    ButtonName=questdlg( 'Do you want to run ICA now ?', ...
                         'Confirmation', 'NO', 'YES', 'YES');
    	switch ButtonName
        	case 'NO', disp('Operation cancelled'); return;   
        	case 'YES', [ EEG com ] = pop_runica(EEG);
    	end % switch
	end
end
if exist('reject') ~= 1
    reject = 1;
end

if nargin < 3
    
    promptstr   = { 'Time window minimum (ms):', ...
                'Time window maximum (ms):', ...
                [ fastif(icacomp, 'Electrode', 'Component') ' indices (e.g., 1:32):'], ...
                'Local threshold(s) (std dev)', ...
                'Global threshold(s) (std dev)', ...
                'Visualization type', ...
                'Display previous rejections?', ...
                'Reject marked trial(s)?' };

    inistr = { '-200', '0', ...
            fastif(icacomp, ['1:' int2str(EEG.nbchan)], ['1:' int2str(size(EEG.icaweights,1))]), ...
            '3', '3', '', '1', '0' };

    vismodelist= {'REJECTTRIALS','EEGPLOT'};
    g1 = [1 0.6 0.5];
	g2 = [1 0.6 0.5];
	g3 = [1 0.6 0.5];
	g4 = [1 0.6 0.5];
	g5 = [1 0.6 0.5];
	g6 = [1 0.6 0.5];
	g7 = [1 0.6 0.5];
	g8 = [1 0.6 0.5];

	geometry = {g1 g2 g3 g4 g5 g6 g7 g8};
	
uilist = {
    { 'style', 'text', 'string', 'Time window minimum (ms)' }, {}, { 'style', 'edit', 'string', '-200', 'tag', 'winmin' }
    { 'style', 'text', 'string', 'Time window maximum (ms)' }, {}, { 'style', 'edit', 'string', '0', 'tag', 'winmax' }
    { 'style', 'text', 'string', 'Electrode/component indices' }, {}, { 'style', 'edit', 'string', '1:32', 'tag', 'elecs' }
    { 'style', 'text', 'string', 'Local threshold(s)' }, {}, { 'style', 'edit', 'string', '3', 'tag', 'locthresh' }
    { 'style', 'text', 'string', 'Global threshold(s)' }, {}, { 'style', 'edit', 'string', '3', 'tag', 'globthresh' }
    { 'style', 'text', 'string', 'Visualization type' }, {}, { 'style', 'popupmenu', 'string', {'REJECTTRIALS','EEGPLOT'}, 'tag', 'vistype', 'value', 1 }
    { 'style', 'text', 'string', 'Display previous rejection marks?' }, {}, { 'style', 'checkbox', 'value', 1, 'tag', 'superpose' }
    { 'style', 'text', 'string', 'Reject marked trial(s)?' }, {}, { 'style', 'checkbox', 'value', 0, 'tag', 'reject' }
};

figname = fastif( ~icacomp, 'Reject. improbable comp. -- pop_jointprob()', 'Reject improbable data -- pop_jointprob()');
result = inputgui( geometry,uilist,'pophelp(''pop_jointprob'');', figname);
% Already captured earlier:
winmin = str2double(result{1});
winmax = str2double(result{2});
% Store it in EEG
EEG.reject.TBT.jointprob.winmin = winmin;
EEG.reject.TBT.jointprob.winmax = winmax;


if isempty(result), return; end

winmin     = str2double(result{1});
winmax     = str2double(result{2});
elecrange  = eval(['[' result{3} ']']);
locthresh  = str2num(result{4});
globthresh = str2num(result{5});
vistype    = result{6};
superpose  = result{7};
reject     = result{8};

% --- pass these to downstream jointprob_NL and implement in jointprob_NL
  
   
%winmin = str2double(result{1});
%winmax = str2double(result{2});
%elecrange = result{3};
%locthresh = result{4};
%globthresh = result{5};
%switch result{6}, case 1, vistype=0; otherwise, vistype=1; end
%superpose = result{7};
%reject = result{8};		
;
    
end

if ~exist('vistype'  ,'var'), vistype   = 0; end
if ~exist('reject'   ,'var'), reject    = 0; end
if ~exist('superpose','var'), superpose = 1; end

if ischar(elecrange) % convert arguments if they are in text format 
    calldisp = 1;
	elecrange  = eval( [ '[' elecrange ']'  ]  );
	locthresh  = eval( [ '[' locthresh ']'  ]  );
	globthresh = eval( [ '[' globthresh ']' ]  );
else
    calldisp = 0;
end

if exist('plotflag','var') && ismember(plotflag,[1,0])
    calldisp = plotflag;
else
    plotflag = 0;
end

if isempty(elecrange)
	error('No electrode selectionned');
end;	

% compute the joint probability
% -----------------------------
if icacomp == 1
	fprintf('Computing joint probability for channels...\n');
    tmpdata = eeg_getdatact(EEG);
    if isempty(EEG.stats.jpE)
		[ EEG.stats.jpE, rejE ] = jointprob_NL( tmpdata, locthresh, EEG.stats.jpE, 1); 
	end
	[rejEtmp] = run_tbt_jointprob_timewindow(EEG, [winmin winmax], icacomp, elecrange, [locthresh globthresh]);

rejE    = zeros(EEG.nbchan, size(rejEtmp,2));
rejE(elecrange,:) = rejEtmp;
fprintf('[DEBUG] Max jointprob rej per trial: %s\n', mat2str(max(rejE, [], 1)));
fprintf('[DEBUG] Total trials marked for rejection: %d\n', sum(max(rejE, [], 1)));

rej = max(rejE, [], 1);  % in case rej wasn't computed yet
	
	fprintf('Computing all-channel probability...\n');
	tmpdata2 = permute(tmpdata, [3 1 2]);
	tmpdata2 = reshape(tmpdata2, size(tmpdata2,1), size(tmpdata2,2)*size(tmpdata2,3));
	%[ EEG.stats.jp, rej ] = jointprob( tmpdata2, globthresh, EEG.stats.jp, 1); 
    clear tmpdata2;
else
    tmpdata = eeg_getica(EEG);
	fprintf('Computing joint probability for components...\n');
    if isempty(EEG.stats.icajpE)
		[ EEG.stats.icajpE, rejE ] = jointprob_NL( tmpdata, locthresh, EEG.stats.icajpE, 1); 
	end
	
	if isempty(elecrange)
    error('pop_jointprob_NL: elecrange is empty. Please check channel/component indexing.');
	end

	if any(elecrange < 1) || any(elecrange > size(tmpdata,1))
		error('pop_jointprob_NL: elecrange has invalid indices. Must be between 1 and %d', size(tmpdata,1));
	end
% Call jointprob safely
	[ tmp, rejEtmp ] = jointprob_NL( tmpdata(elecrange,:), locthresh, EEG.stats.icajpE(elecrange,:), 1); 
    rejE    = zeros(size(tmpdata,1), size(rejEtmp,2));
	rejE(elecrange,:) = rejEtmp;
		fprintf('[DEBUG] Max jointprob rej per trial: %s\n', mat2str(max(rejE, [], 1)));
		fprintf('[DEBUG] Total trials marked for rejection: %d\n', sum(max(rejE, [], 1)));

	fprintf('Computing global joint probability...\n');
	tmpdata2 = permute(tmpdata, [3 1 2]);
	tmpdata2 = reshape(tmpdata2, size(tmpdata2,1), size(tmpdata2,2)*size(tmpdata2,3));
	[ EEG.stats.icajp,  rej] = jointprob_NL( tmpdata2, globthresh, EEG.stats.icajp, 1); 
	clear tmpdata2;
end
rej = rej' | max(rejE, [], 1);
fprintf('%d/%d trials marked for rejection\n', sum(rej), EEG.trials);

if calldisp
    if vistype == 1
        if icacomp == 1
            macrorej = 'EEG.reject.rejjp';
            macrorejE = 'EEG.reject.rejjpE';
        else
            macrorej  = 'EEG.reject.icarejjp';
            macrorejE = 'EEG.reject.icarejjpE';
        end
		colrej = EEG.reject.rejjpcol;
		eeg_rejmacro; % script macro for generating command and old rejection arrays

	    if icacomp == 1
	        eegplot( tmpdata(elecrange,:,:), 'srate', ...
		      EEG.srate, 'limits', [EEG.xmin EEG.xmax]*1000 , 'command', command, eegplotoptions{:}); 
	    else
	        eegplot( tmpdata(elecrange,:,:), 'srate', ...
		      EEG.srate, 'limits', [EEG.xmin EEG.xmax]*1000 , 'command', command, eegplotoptions{:}); 
        end
    else % REJECTRIALS -------------------------
	  	if icacomp	== 1 
			[rej, rejE, n, locthresh, globthresh] = ...
				rejstatepoch_NL( tmpdata(elecrange,:,:), EEG.stats.jpE(elecrange,:), ...
				'global', 'on', 'rejglob', EEG.stats.jp, ...
				'threshold', locthresh, 'thresholdg', globthresh, ...
				'winmin', winmin, 'winmax', winmax, 'normalize', 'off'  );

		else 
			[ rej, rejE, n, locthresh, globthresh] = ... 
				rejstatepoch_NL( tmpdata(elecrange,:,:), EEG.stats.icajpE(elecrange,:), 'global', 'on', 'rejglob', EEG.stats.icajp, ...
						'threshold', locthresh, 'thresholdg', globthresh, 'normalize', 'off' );
        end	
		nrej = n;
    end
else
	% compute rejection locally
	rejtmp = max(rejE(elecrange,:),[],1);
	rej = rejtmp | rej;
	nrej =  sum(rej);
	fprintf('%d trials marked for rejection\n', nrej);
    if reject
        EEG = pop_rejepoch(EEG, rej, 0);
    end
end
if ~isempty(rej)
	if icacomp	== 1
		EEG.reject.rejjp = rej;
		EEG.reject.rejjpE = rejE;
	else
		EEG.reject.icarejjp = rej;
		EEG.reject.icarejjpE = rejE;
	end
end
nrej = sum(rej);

com = [ com sprintf('EEG = pop_jointprob_NL(EEG,%s);', ...
		vararg2str({icacomp,elecrange,locthresh,globthresh,superpose,reject & ~calldisp, vistype, [],plotflag})) ]; 
if nargin < 3 && nargout == 2
	locthresh = com;
end

return;
