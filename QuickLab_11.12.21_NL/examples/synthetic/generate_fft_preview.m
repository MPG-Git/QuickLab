function filename=generate_fft_preview(datasetFile,outputFolder)
% Generate a saved FFT picture for the known synthetic rank-three example.
% Use only the bundled synthetic input; this function does not load base EEG.
e=pop_loadset(datasetFile);
assert(strcmp(e.setname,'Synthetic average reference - expected rank 3'), ...
    'This example expects the supplied synthetic rank-three dataset.');
assert(isfolder(outputFolder),'Choose an existing output folder.');
[~,stem]=fileparts(datasetFile); filename=fullfile(outputFolder,[stem 'FFT.jpg']);
assert(~isfile(filename),'The preview already exists. Choose a fresh output folder.');
x=double(e.data); x=x-mean(x,2); n=size(x,2);
power=abs(fft(x,[],2)).^2/(e.srate*n);
power=power(:,1:floor(n/2)+1); power(:,2:end-1)=2*power(:,2:end-1);
frequency=(0:floor(n/2))*e.srate/n;
fig=figure('Visible','off','Color','w','Position',[100 100 720 480]);
cleanup=onCleanup(@() delete(fig)); %#ok<NASGU>
plot(frequency,10*log10(max(power,realmin))'); xlim([2 55]); grid on;
xlabel('Frequency (Hz)'); ylabel('Power (dB microvolts^2/Hz)');
title('Synthetic average reference: 4 channels, rank 3');
legend({e.chanlocs.labels},'Location','northeast');
print(fig,filename,'-djpeg','-r120');
end
