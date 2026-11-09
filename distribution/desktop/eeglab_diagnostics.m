function result = eeglab_diagnostics(action, varargin)
% Local technical diagnostics; external reporting requires explicit consent.
% Deliberately never serializes exception messages, commands, EEG or user paths.
persistent root catalog lastException monitor
result = [];
if isempty(root), root = char(java.io.File(fileparts(mfilename('fullpath'))).getCanonicalPath()); end
switch action
    case 'init'
        if ~isempty(varargin), root = char(java.io.File(varargin{1}).getCanonicalPath()); end
        catalog = jsondecode(fileread(fullfile(root,'diagnostic-sources.json')));
        folders(root);
        % MException.last explicitly refuses calls from timer callbacks, even
        % through evalin('base',...). lasterror is the supported legacy API
        % available in this asynchronous context. Never reset its global state.
        try, lastException = lasterror; catch, lastException = []; end %#ok<LERR>
        if isempty(monitor) || ~isvalid(monitor)
            monitor = timer('Name','EEGLAB technical diagnostics','ExecutionMode','fixedSpacing', ...
                'Period',10,'BusyMode','drop','TimerFcn',@(~,~) eeglab_diagnostics('poll'));
            start(monitor);
        end
    case 'stop'
        if ~isempty(monitor) && isvalid(monitor), stop(monitor); delete(monitor); end
        monitor = [];
    case 'poll'
        try
            exception = lasterror; %#ok<LERR>
            if ~isempty(exception.stack)
                [~,origin] = fileparts(exception.stack(1).file);
                if strcmpi(origin,'eeglab_diagnostics'), return; end
            end
            if ~isempty(exception.message) && ~isequal(exception,lastException)
                lastException = exception;
                eeglab_diagnostics('capture',exception,'runtime');
            end
        catch
            % Diagnostics must never interfere with an analysis or recurse.
        end
    case 'capture'
        try
            if isempty(catalog), catalog = jsondecode(fileread(fullfile(root,'diagnostic-sources.json'))); end
            record = makeRecord(varargin{1},varargin{2},root,catalog);
            [base,history,queue] = folders(root);
            saveRecord(history,record);
            if consent(base), saveRecord(queue,record); end
            result = record;
        catch
            % The regular local MATLAB session log remains available.
        end
    case 'record'
        % Pure formatter, also used by privacy/regression tests.
        result = makeRecord(varargin{1},varargin{2},varargin{3},varargin{4});
    case 'offer'
        [base,~,~] = folders(root);
        config = jsondecode(fileread(fullfile(root,'setup','desktop','reporting.json')));
        if ~isfile(fullfile(base,'preferences.json')) && ~isempty(config.endpoint)
            eeglab_diagnostics('settings');
        end
    case 'settings'
        [base,~,queue] = folders(root);
        config = jsondecode(fileread(fullfile(root,'setup','desktop','reporting.json')));
        if isempty(config.endpoint)
            msgbox({'Automatic reporting is not connected yet.', ...
                'Use Get error report to save a report you can email to Matt.'},'Error reporting');
            return;
        end
        choice = questdlg({'Allow automatic technical error reports to Matt?', ...
            'Reports contain error codes, software versions and locations in plugin code.', ...
            'They go through Matt''s Supabase service to his private GitHub support repository.', ...
            'Recordings, commands, names, file paths and error-message text are not sent.', ...
            'Internet providers still process normal connection information.', ...
            'You can turn this off here at any time. EEGLAB works either way.'}, ...
            'Automatic error reporting','Yes, allow','No, turn off','No, turn off');
        if isempty(choice), return; end
        enabled = strcmp(choice,'Yes, allow');
        savePreferences(base,enabled);
        if ~enabled
            files = dir(fullfile(queue,'report-*.json'));
            for k=1:numel(files), delete(fullfile(queue,files(k).name)); end
        end
    case 'consent'
        % Used by the settings UI's noninteractive regression tests.
        [base,~,queue] = folders(root);
        assert(islogical(varargin{1}) && isscalar(varargin{1}));
        savePreferences(base,varargin{1});
        if ~varargin{1}
            files=dir(fullfile(queue,'report-*.json'));
            for k=1:numel(files), delete(fullfile(queue,files(k).name)); end
        end
    case 'export'
        [base,history,~] = folders(root);
        out=fullfile(base,'exports'); if ~isfolder(out), mkdir(out); end
        file=fullfile(out,['EEGLAB-error-report-' datestr(now,'yyyymmdd-HHMMSS') '.txt']);
        if isempty(catalog), catalog=jsondecode(fileread(fullfile(root,'diagnostic-sources.json'))); end
        fid=fopen(file,'w','n','UTF-8'); assert(fid>=0); cleanup=onCleanup(@() fclose(fid));
        fprintf(fid,'EEGLAB technical error report\nNo recordings, commands, full paths or error-message text are included.\n\n');
        files=dir(fullfile(history,'report-*.json'));
        if isempty(files), fprintf(fid,'No technical errors have been recorded by this installation.\n'); end
        for k=1:numel(files)
            r=jsondecode(fileread(fullfile(history,files(k).name)));
            % Revalidate before writing; never copy arbitrary local JSON fields.
            if ~validRecord(r,catalog), continue; end
            reportCatalog=selectCatalog(catalog,r.release);
            fprintf(fid,'%s | EEGLAB package %s | MATLAB %s | %s | error code %d\n', ...
                r.observedAt,r.release,r.matlabRelease,r.context,r.errorCode);
            for j=1:numel(r.frames)
                name=reportCatalog.sources.(['s' r.frames(j).sourceId]);
                fprintf(fid,'  %s, line %d\n',name,r.frames(j).line);
            end
            fprintf(fid,'\n');
        end
        clear cleanup;
        result=file;
        if isempty(varargin) || varargin{1}
            winopen(out);
            msgbox({'Your technical error report has been saved.', ...
                'The folder is open. Email the newest EEGLAB-error-report file to Matt.'},'Error report ready');
        end
    otherwise
        error('EEGLAB:diagnosticsAction','Unknown diagnostics action.');
end
end

function [base,history,queue]=folders(root)
parent=fileparts(root); [~,parentName]=fileparts(parent);
assert(strcmpi(parentName,'versions'),'Not a managed installation.');
base=fullfile(fileparts(parent),'reporting'); history=fullfile(base,'history'); queue=fullfile(base,'queue');
for path={base,history,queue}, if ~isfolder(path{1}), mkdir(path{1}); end; end
end

function value=consent(base)
value=false;
try
    p=jsondecode(fileread(fullfile(base,'preferences.json')));
    value=islogical(p.enabled) && isscalar(p.enabled) && p.enabled && p.privacyVersion==1;
catch
end
end

function savePreferences(base,enabled)
p=struct('enabled',enabled,'privacyVersion',1);
file=fullfile(base,'preferences.json'); tmp=[tempname(base) '.tmp'];
fid=fopen(tmp,'w'); assert(fid>=0); fprintf(fid,'%s',jsonencode(p)); fclose(fid);
movefile(tmp,file,'f');
end

function saveRecord(folder,r)
files=dir(fullfile(folder,'report-*.json'));
[~,order]=sort([files.datenum]); files=files(order);
% Keep at most 100 records and no records older than 30 days.
for k=1:numel(files)
    if k<=numel(files)-99 || now-files(k).datenum>30, delete(fullfile(folder,files(k).name)); end
end
file=fullfile(folder,['report-' r.eventId '.json']); tmp=[file '.tmp'];
fid=fopen(tmp,'w'); assert(fid>=0); fprintf(fid,'%s',jsonencode(r)); fclose(fid);
movefile(tmp,file,'f');
end

function r=makeRecord(exception,context,root,catalog)
assert(any(strcmp(context,{'startup','practice','runtime','update','validation'})));
codes={'MATLAB:badsubscript','MATLAB:UndefinedFunction','MATLAB:dimagree', ...
    'MATLAB:innerdim','MATLAB:nomem','MATLAB:TooManyInputs','MATLAB:TooManyOutputs', ...
    'MATLAB:minrhs','MATLAB:narginchk:notEnoughInputs','MATLAB:narginchk:tooManyInputs', ...
    'MATLAB:load:couldNotReadFile','MATLAB:FileIO:InvalidFid','MATLAB:assertion:failed'};
code=find(strcmp(exception.identifier,codes),1); if isempty(code), code=0; end
frames=struct('sourceId',{},'line',{});
prefix=lower(strrep([char(java.io.File(root).getCanonicalPath()) filesep],'\','/'));
for k=1:min(numel(exception.stack),40)
    stack=exception.stack(k); file=lower(strrep(char(java.io.File(stack.file).getCanonicalPath()),'\','/'));
    if ~startsWith(file,prefix), continue; end
    relative=file(numel(prefix)+1:end);
    digest=java.security.MessageDigest.getInstance('SHA-256');
    bytes=typecast(digest.digest(uint8(unicode2native(relative,'UTF-8'))),'uint8');
    id=lower(reshape(dec2hex(bytes,2)',1,[])); id=id(1:32);
    if ~isfield(catalog.sources,['s' id]), continue; end
    line=double(stack.line);
    if ~isscalar(line) || ~isfinite(line) || line<1 || line>1000000 || line~=fix(line), continue; end
    frames(end+1)=struct('sourceId',id,'line',line); %#ok<AGROW>
    if numel(frames)==8, break; end
end
stamp=datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ss.SSS''Z''');
r=struct('schemaVersion',1,'eventId',lower(strrep(char(java.util.UUID.randomUUID()),'-','')), ...
    'observedAt',char(stamp),'release',catalog.release,'matlabRelease',version('-release'), ...
    'context',context,'errorCode',code,'frames',{num2cell(frames)});
end

function valid=validRecord(r,catalog)
valid=false;
try
    catalog=selectCatalog(catalog,r.release);
    names=sort({'schemaVersion';'eventId';'observedAt';'release';'matlabRelease';'context';'errorCode';'frames'});
    assert(isequal(sort(fieldnames(r)),names));
    assert(r.schemaVersion==1 && strcmp(r.release,catalog.release));
    assert(~isempty(regexp(r.eventId,'^[a-f0-9]{32}$','once')));
    assert(~isempty(regexp(r.observedAt,'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$','once')));
    assert(~isempty(regexp(r.matlabRelease,'^\d{4}[ab]$','once')));
    assert(any(strcmp(r.context,{'startup','practice','runtime','update','validation'})));
    assert(isscalar(r.errorCode) && r.errorCode==fix(r.errorCode) && r.errorCode>=0 && r.errorCode<=22);
    assert(numel(r.frames)<=8);
    for k=1:numel(r.frames)
        frame=r.frames(k);
        assert(isequal(sort(fieldnames(frame)),{'line';'sourceId'}));
        assert(~isempty(regexp(frame.sourceId,'^[a-f0-9]{32}$','once')) && isfield(catalog.sources,['s' frame.sourceId]));
        assert(isscalar(frame.line) && isfinite(frame.line) && frame.line==fix(frame.line) && frame.line>=1 && frame.line<=1000000);
    end
    valid=true;
catch
end
end

function selected=selectCatalog(catalog,release)
selected=catalog;
if strcmp(catalog.release,release), return; end
if isfield(catalog,'previous')
    for k=1:numel(catalog.previous)
        if strcmp(catalog.previous(k).release,release), selected=catalog.previous(k); return; end
    end
end
error('EEGLAB:unknownReportVersion','Unknown report version.');
end
