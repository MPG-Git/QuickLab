function run_quicklab_demo(out)
% Load two bundled .set files, run the real comparison and check known results.
if nargin<1, out=''; end
[here,out,cleanup]=demo_prepare(mfilename('fullpath'),out); %#ok<ASGLU>
addpath(fileparts(fileparts(here)));
assert(~isempty(which('pop_loadset')),'Start EEGLAB first');
a=pop_loadset('filename','synthetic_infinity.set','filepath',fullfile(here,'data'));
b=pop_loadset('filename','synthetic_average.set','filepath',fullfile(here,'data'));
[r,figs]=plotDifference(a,b,true);
figCleanup=onCleanup(@() close(figs(isgraphics(figs)))); %#ok<NASGU>
writetable(table(string(r.channelLabels),r.meanDifference,r.rmsDifference,r.maxAbsDifference, ...
 'VariableNames',{'Channel','Mean_A_minus_B','RMS','MaxAbsolute'}),fullfile(out,'channel_differences.csv'));
print(figs(3),fullfile(out,'rms_by_channel.png'),'-dpng','-r120');
f=figure; c=onCleanup(@()close(f)); %#ok<NASGU>
subplot(2,1,1); plot(a.times/1000,double(a.data(1,:)),a.times/1000,double(b.data(1,:)));
xlim([0 1]); ylabel('Cz (microvolts)'); legend('Illustrative Infinity','Average'); grid on;
subplot(2,1,2); plot(a.times/1000,double(a.data(1,:))-double(b.data(1,:)));
xlim([0 1]); xlabel('Time (seconds)'); ylabel('A - B (microvolts)'); grid on;
print(f,fullfile(out,'comparison.png'),'-dpng','-r120');
% Independent analytic oracle: the common term has DC=2, amplitude=1.
assert(max(abs(mean(double(b.data),1)))<1e-6);
assert(max(abs(r.meanDifference-2))<1e-6);
assert(max(abs(r.rmsDifference-sqrt(4.5)))<1e-6);
demo_verify(here,out,{'Channels','SamplesPerChannel','MeanDifference','OverallRMS'}, ...
 [a.nbchan,r.samplesPerChannel,mean(r.meanDifference),r.overallRMS]);
end
