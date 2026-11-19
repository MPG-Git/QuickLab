function quicklab_preview(fig,eeg)
% Show the matching saved FFT image in the Golden Old right-hand space.
% A .fig can contain callbacks, so only a raster preview is read automatically.
old=findall(fig,'Tag','quicklab_fft_preview');
filename='';
if isstruct(eeg) && isscalar(eeg) && ~isempty(eeg.data) && ~isempty(eeg.filename) && isfolder(eeg.filepath)
    [~,stem]=fileparts(eeg.filename);
    candidates=dir(fullfile(eeg.filepath,'*'));
    index=find(strcmpi({candidates.name},[stem 'FFT.jpg']) & ~[candidates.isdir],1);
    if ~isempty(index), filename=fullfile(eeg.filepath,candidates(index).name); end
end
key='';
if ~isempty(filename)
    info=dir(filename); key=sprintf('%s|%d|%.12g',filename,info.bytes,info.datenum);
end
if isequal(getappdata(fig,'quicklab_fft_key'),key), return; end
delete(old); setappdata(fig,'quicklab_fft_key',key);
if isempty(filename), return; end
try
    [pixels,map]=imread(filename);
    panel=uipanel(fig,'Tag','quicklab_fft_preview','Units','normalized', ...
        'Position',[.51 .17 .44 .57],'BorderType','none','BackgroundColor',get(fig,'Color'));
    ax=axes('Parent',panel,'Position',[.02 .02 .96 .96]);
    if isempty(map), image(ax,pixels); else, image(ax,pixels); colormap(ax,map); end
    axis(ax,'image'); axis(ax,'off');
catch problem
    delete(findall(fig,'Tag','quicklab_fft_preview'));
    if exist('eeglab_diagnostics','file'), eeglab_diagnostics('capture',problem,'runtime'); end
    warning('QuickLab:PreviewUnavailable','The saved FFT preview could not be displayed. The EEG dataset is unchanged.');
end
end
