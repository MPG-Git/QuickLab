function EEG = quicklab_binica(EEG,components,extended)
% QUICKLAB_BINICA Run the bundled Windows BINICA in an isolated temp folder.
% File-backed stdin is essential: the upstream parser rewinds stdin. Java's
% ProcessBuilder also handles spaces without a shell or editing icadefs.m.
binary = which('ica_windows.exe');
if ~ispc || isempty(binary)
    error('QuickLab:BinicaUnavailable', ...
        'Windows BINICA is not installed. Use ICA (MATLAB), or install the lab desktop bundle.');
end
work = tempname; mkdir(work);
cleanup = onCleanup(@() cleanupFolder(work)); %#ok<NASGU>
data = reshape(double(EEG.data),EEG.nbchan,[]);
data = bsxfun(@minus,data,mean(data,2));
writeData(fullfile(work,'input.fdt'),data);
config = sprintf(['DataFile input.fdt\nchans %d\nframes %d\n' ...
    'WeightsOutFile weights.wts\nSphereFile sphere.sph\n' ...
    'extended %d\npca %d\nlrate 0.001\nmaxsteps 512\nstop 0.0000001\n' ...
    'sphering on\nbias on\nposact off\nannealstep 0.98\nannealdeg 60\n' ...
    'momentum 0\nverbose on\ndoublewrite off\nseed 1\n'], ...
    EEG.nbchan,size(data,2),extended,components);
file = fullfile(work,'config.sc'); fid=fopen(file,'w');
assert(fid~=-1,'QuickLab:BinicaIO','Cannot write the BINICA configuration.');
fprintf(fid,'%s',config); fclose(fid);
args = java.util.ArrayList; args.add(binary);
builder = java.lang.ProcessBuilder(args);
builder.directory(java.io.File(work)); builder.redirectInput(java.io.File(file));
builder.redirectErrorStream(true); builder.redirectOutput(java.io.File(fullfile(work,'binica.log')));
process = builder.start;
processCleanup = onCleanup(@() stopProcess(process)); %#ok<NASGU>
fprintf('Running bundled Windows BINICA (%d components)...\n',components);
while process.isAlive, drawnow; pause(.1); end
status = process.exitValue;
if status ~= 0
    % Keep paths and raw binary output local; reporting captures the code only.
    error('QuickLab:BinicaFailed','BINICA exited with code %d.\n%s',status,fileread(fullfile(work,'binica.log')));
end
weights = readMatrix(fullfile(work,'weights.wts'),components,EEG.nbchan);
sphere = readMatrix(fullfile(work,'sphere.sph'),EEG.nbchan,EEG.nbchan);
% Match pop_runica's decomposition history and invalidate component-derived
% results, including flags and ICLabel/DIPFIT fits from the previous run.
if ~isempty(EEG.icaweights)
    for field = {'icaweights','icasphere','icachansind'}
        old = ['old' field{1}];
        if ~isfield(EEG.etc,old), EEG.etc.(old) = {}; end
        EEG.etc.(old) = [{EEG.(field{1})} EEG.etc.(old)];
    end
end
if isfield(EEG.etc,'ic_classification'), EEG.etc = rmfield(EEG.etc,'ic_classification'); end
if isfield(EEG,'dipfit'), EEG = rmfield(EEG,'dipfit'); end
EEG.icaweights = weights; EEG.icasphere = sphere;
EEG.icawinv = pinv(weights*sphere); EEG.icachansind = 1:EEG.nbchan;
EEG.icaact = []; EEG.reject.gcompreject = false(1,components);
EEG.saved = 'no'; EEG = eeg_checkset(EEG);
end

function writeData(file,data)
fid = fopen(file,'w','ieee-le');
assert(fid~=-1,'QuickLab:BinicaIO','Cannot write temporary BINICA data.');
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
count=fwrite(fid,data,'single');
assert(count==numel(data),'QuickLab:BinicaIO','Incomplete temporary BINICA data file.');
end

function matrix = readMatrix(file,rows,columns)
fid=fopen(file,'r','ieee-le');
assert(fid~=-1,'QuickLab:BinicaOutput','BINICA did not create its output matrices.');
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
values=fread(fid,Inf,'single=>double');
assert(numel(values)==rows*columns && all(isfinite(values)), ...
    'QuickLab:BinicaOutput','BINICA returned an invalid matrix.');
matrix=reshape(values,rows,columns);
end

function stopProcess(process)
if process.isAlive, process.destroy; process.waitFor; end
end

function cleanupFolder(folder)
% Only remove the private folder allocated by this invocation under tempdir.
root=char(java.io.File(tempdir).getCanonicalPath());
target=char(java.io.File(folder).getCanonicalPath());
if startsWith([target filesep],[root filesep],'IgnoreCase',ispc) && isfolder(target)
    rmdir(target,'s');
end
end
