function validate_desktop_update()
% Validate before activation; capture safe facts even under an older launcher.
root=fileparts(mfilename('fullpath'));
closeCleanup=onCleanup(@() close('all','force')); %#ok<NASGU>
stage='startup';
startupException=[];
try
    [ALLEEG,EEG,CURRENTSET,ALLCOM]=start_eeglab_replacement; %#ok<ASGLU>
    startupException=lasterror; %#ok<LERR> EEGLAB catches plugin-hook errors internally.
    stage='validation'; report=check_eeglab_replacement;
    stage='practice'; output=tempname(root); run_replacement_examples(output);
    result=struct('status','PASS','eeglab',eeg_getversion,'matlab',version, ...
        'plugins',numel(report.plugins),'syntheticExamples','QuickLab comparison, ICA and NeuroLode','outputFolder',output);
    fid=fopen(fullfile(root,'desktop_validation.json'),'w');
    assert(fid>=0,'Cannot save the validation result.');
    cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s\n',jsonencode(result));
catch exception
    try
        catalog=jsondecode(fileread(fullfile(root,'diagnostic-sources.json')));
        failures=pluginFailures(root);
        cause=exception;
        % Preserve the underlying last plugin-hook exception when EEGLAB has
        % caught it and the later inventory check only reports startup failure.
        if strcmp(stage,'validation') && ~isempty(startupException) && ~isempty(startupException.stack)
            manifest=jsondecode(fileread(fullfile(root,'manifest.json')));
            for k=1:numel(manifest.plugins)
                p=manifest.plugins(k); if iscell(p), p=p{1}; end
                if any(strcmp({failures.component},p.name) & strcmp({failures.reason},'startup'))
                    prefix=lower(strrep([fullfile(root,'eeglab2026.1.0','plugins',p.folder) filesep],'\','/'));
                    if any(startsWith(lower(strrep({startupException.stack.file},'\','/')),prefix)), cause=startupException; break; end
                end
            end
        end
        detail=struct('targetVersion',catalog.release,'stage',stage,'component','EEGLAB', ...
            'reason','validation-failed','httpStatus',0,'exitCode',0,'systemCode',0,'source','','line',0, ...
            'pluginFailures',{num2cell(failures)},'matlabIdentifier','','startupSignals',{{}}, ...
            'environment',struct('matlabVersion',regexp(version,'^\d+(\.\d+){1,4}','match','once'), ...
            'windowsVersion',char(System.Environment.OSVersion.Version.ToString()),'powershellVersion','unknown','architecture','x64', ...
            'freeDiskMB',floor(double(java.io.File(root).getUsableSpace())/1024/1024)));
        if any(strcmp(cause.identifier,catalog.identifiers)), detail.matlabIdentifier=cause.identifier; end
        eeglab_diagnostics('init',root); eeglab_diagnostics('stop');
        r=eeglab_diagnostics('capture',cause,'validation',detail);
        if ~isempty(r)
            % Windows sender runs without MATLAB, without waiting for a dialog.
            info=System.Diagnostics.ProcessStartInfo();
            info.FileName=fullfile(getenv('WINDIR'),'System32','WindowsPowerShell','v1.0','powershell.exe');
            worker=fullfile(root,'setup','desktop','Reporting-Worker.ps1');
            info.Arguments=sprintf('-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%s" -HomeRoot "%s" -VersionRoot "%s" -Once',worker,fileparts(fileparts(root)),root);
            info.UseShellExecute=false; info.CreateNoWindow=true;
            System.Diagnostics.Process.Start(info);
        end
    catch
        % Reporting must never replace the real validation error.
    end
    rethrow(exception);
end
end

function failures=pluginFailures(root)
% Names come from the shipped manifest, never from arbitrary error text.
failures=struct('component',{},'reason',{});
manifest=jsondecode(fileread(fullfile(root,'manifest.json')));
global PLUGINLIST;
for k=1:numel(manifest.plugins)
    p=manifest.plugins(k); if iscell(p), p=p{1}; end
    reason='';
    if ~isfolder(fullfile(root,'eeglab2026.1.0','plugins',p.folder))
        reason='missing';
    elseif isempty(PLUGINLIST) || ~isfield(PLUGINLIST,'foldername') || ~any(strcmp({PLUGINLIST.foldername},p.folder))
        reason='unregistered';
    else
        entry=PLUGINLIST(strcmp({PLUGINLIST.foldername},p.folder));
        expected=p.version; if strcmp(p.name,'Neurolode'), expected='1.7.0'; end
        if isfield(entry,'status') && any(strcmp({entry.status},'error')), reason='startup';
        elseif ~isfield(entry,'version') || ~all(strcmp({entry.version},expected)), reason='version'; end
    end
    if ~isempty(reason), failures(end+1)=struct('component',p.name,'reason',reason); end %#ok<AGROW>
end
end
