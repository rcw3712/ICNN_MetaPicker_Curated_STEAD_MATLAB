% =========================================================================
% demo_synthetic_waveform.m  (examples/)
% =========================================================================
% PURPOSE:
%   Standalone demo using one synthetic waveform held entirely in memory
%   (no CSV file needed). Demonstrates conditioning, Gaussian labeling,
%   and base picker output without training any deep learning model.
%
% INPUT:  (none)
% OUTPUT: (figure displayed)
%
% NOTES:
%   This demo does NOT train or run the I-CNN meta-learner (that requires
%   a dataset with multiple events — see demo_small_subset.m). It
%   illustrates the conceptual distinction between base picker output
%   and the meta-feature tensor that would subsequently feed the I-CNN.
% =========================================================================

clc; clear; close all;
rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(rootDir));

fprintf('=== demo_synthetic_waveform ===\n\n');

config = config_ICNN_MetaPicker();
rng(config.randomSeed, 'twister');

fs = config.samplingRate;
T  = config.nSamples;
sec = (0:T-1)' / fs;

pSec = 12.0; sSec = 18.5; snr = 15;
sigLevel = 0.1 * 10^(snr/20);

E = 0.1*randn(T,1); N = 0.1*randn(T,1); Z = 0.1*randn(T,1);
tP = sec - pSec; Z = Z + sigLevel*sin(2*pi*5*tP).*exp(-tP.^2/0.18).*(tP>=-0.1);
tS = sec - sSec; N = N + 0.7*sigLevel*sin(2*pi*3*tS).*exp(-tS.^2/0.5).*(tS>=-0.2);
E = E + 0.6*sigLevel*sin(2*pi*3*tS).*exp(-tS.^2/0.5).*(tS>=-0.2);

waveform = [E, N, Z];

wfCond = conditionWaveform(waveform, config);
fprintf('Conditioning applied.\n');

X = buildEnhancedRepresentation(wfCond, config);
fprintf('Enhanced representation: [%d x %d]\n', size(X,1), size(X,2));

label = generateGaussianMasks(sec, pSec, sSec, config);
fprintf('Gaussian labels generated.\n');

pcSTALTA = runSTALTAPicker(X, config);
pcAIC    = runAICPicker(X, config);
fprintf('Base pickers run: STA/LTA, AIC\n');

combP = max(pcSTALTA.P, pcAIC.P);
combS = max(pcSTALTA.S, pcAIC.S);
[~, idxP] = max(combP);
tauP = sec(idxP);
winMask = (sec > tauP+config.minSPTimeSec) & (sec < tauP+config.maxSPTimeSec);
[~, idxS] = max(combS .* winMask);
tauS = sec(idxS);

fprintf('\nPicked (illustrative): P=%.3fs (true %.3fs) S=%.3fs (true %.3fs)\n\n', ...
    tauP, pSec, tauS, sSec);

fig = figure('Position',[50 50 1100 700],'Color','white');
subplot(4,1,1);
plot(sec, wfCond(:,3),'b','LineWidth',0.7); hold on;
xline(pSec,'b--','LineWidth',1.5); xline(sSec,'r--','LineWidth',1.5);
xline(tauP,'b-','LineWidth',2); xline(tauS,'r-','LineWidth',2);
ylabel('Z'); title('Synthetic Waveform'); box off;
subplot(4,1,2); plot(sec, wfCond(:,2),'Color',[0 0.6 0.3]); ylabel('N'); box off;
subplot(4,1,3); plot(sec, wfCond(:,1),'Color',[0.8 0.4 0]); ylabel('E'); box off;
subplot(4,1,4);
plot(sec, label(:,1),'b-','LineWidth',1.5,'DisplayName','P label'); hold on;
plot(sec, label(:,2),'r-','LineWidth',1.5,'DisplayName','S label');
plot(sec, pcSTALTA.P,'b:','DisplayName','STA/LTA P');
ylim([0 1.1]); legend('Location','northeast'); xlabel('Time (s)'); box off;
sgtitle('I-CNN MetaPicker Demo - Synthetic Waveform','FontWeight','bold');

fprintf('Demo complete.\n');
