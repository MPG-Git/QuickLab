function quicklab_save_figure(fig,eeg,destination)
% Save the figure belonging to its source dataset, regardless of current EEG.
if nargin<3
    [~,stem]=fileparts(eeg.filename); if isempty(stem), stem='EEG'; end
    [name,folder]=uiputfile({'*.jpg','JPEG image';'*.png','PNG image'}, ...
        'Save FFT picture',fullfile(eeg.filepath,[stem 'FFT.jpg']));
    if isequal(name,0), return; end
    destination=fullfile(folder,name);
end
exportgraphics(fig,destination,'Resolution',150);
end
