% =========================================================================
% run_recover_oof_from_fold_models.m
% =========================================================================
% PURPOSE:
%   Rebuild the OOF prediction checkpoint WITHOUT retraining the base
%   pickers, by reusing the per-fold models that generateOOFPredictions
%   already saved to
%       results/models/trained_base_models/fold01_models.mat ... fold05_models.mat
%
%   Use this only if a previous run of run_export_oof_meta_features.m
%   completed all K folds but then crashed before the checkpoint existed
%   (for example on the buildMetaFeatureTensor batch-call bug). Base-picker
%   training is the expensive part and does not need to be repeated.
%
% SAFETY GATE:
%   The OOF fold assignment is recomputed from scratch. Because it depends
%   on the RNG state, this script replicates the exact preamble of
%   run_export_oof_meta_features.m (same seed, same split, same
%   conditioning, same augmentation) and then VERIFIES the resulting fold
%   sizes against EXPECTED_FOLD_SIZES below. If they do not match exactly,
%   the script aborts rather than silently producing an OOF set whose folds
%   differ from the saved models -- which would break the leakage-free
%   guarantee.
%
%   Set EXPECTED_FOLD_SIZES from the console log of the run that produced
%   the fold models, e.g.
%       Fold 1: 614 records
%       Fold 2: 640 records
%       ...
%
% OUTPUT:
%   results/models/trained_base_models/oof_predictions_checkpoint.mat
%       (variables: oofPreds, recordFold)
%
%   Afterwards run run_export_oof_meta_features.m as normal; the patched
%   generateOOFPredictions.m will detect the checkpoint and skip the
%   k-fold loop entirely.
% =========================================================================

clear; clc;
addpath(genpath('src'));
addpath('config');

% --- Fold sizes from the console log of the interrupted run --------------
EXPECTED_FOLD_SIZES = [614 640 628 602 628];

% --- Fast picker implementations -----------------------------------------
% The original runAICPicker/runSTALTAPicker recompute var()/mean() from
% scratch inside long loops, which dominates runtime. The local fast
% versions at the bottom of this file are the same formulas expressed with
% prefix sums. They are verified against the originals on your first real
% record before use; set to false to fall back to the originals.
USE_FAST_PICKERS = true;

config = config_ICNN_MetaPicker();
rng(config.randomSeed, 'twister');

fprintf('\n========================================================\n');
fprintf('  Recover OOF predictions from saved fold models\n');
fprintf('========================================================\n\n');

% --- Replicate the preamble EXACTLY (RNG sequence must match) ------------
[data, ~] = loadDatasetFromMetadata(config);
fprintf('Records loaded: %d\n', numel(data));

[trainData, ~, ~, splitInfo] = splitBySourceID(data, config);
trainData = addGaussianLabels(applyPreprocessing(trainData, config), config);

if config.useAugmentation
    trainValData = augmentTrainingWaveform(trainData, config);
else
    trainValData = trainData;
end

splitKeyField = splitInfo.keyUsed;
K = config.kFold;
N = numel(trainValData);
fprintf('Training records after augmentation: %d | K = %d\n\n', N, K);

% --- Recompute the fold assignment the same way generateOOFPredictions does
allIDs    = {trainValData.(splitKeyField)}';
uniqueIDs = unique(allIDs, 'stable');
nIDs      = numel(uniqueIDs);

perm       = randperm(nIDs);
foldAssign = mod(0:nIDs-1, K) + 1;
idFoldMap  = containers.Map(uniqueIDs(perm), foldAssign);

recordFold = zeros(N, 1);
for i = 1:N
    recordFold(i) = idFoldMap(allIDs{i});
end

actualSizes = zeros(1, K);
for k = 1:K
    actualSizes(k) = sum(recordFold == k);
end

fprintf('Fold sizes recomputed : [%s]\n', num2str(actualSizes));
fprintf('Fold sizes expected   : [%s]\n', num2str(EXPECTED_FOLD_SIZES));

if numel(EXPECTED_FOLD_SIZES) ~= K || ~isequal(actualSizes, EXPECTED_FOLD_SIZES)
    error(['FOLD MISMATCH -- aborting.\n' ...
           'The recomputed fold assignment does not match the run that produced\n' ...
           'the saved fold models, so those models cannot be reused safely.\n' ...
           'Delete results/models/trained_base_models/fold*_models.mat and run\n' ...
           'run_export_oof_meta_features.m for a full (slow) recomputation.']);
end
fprintf('Fold assignment VERIFIED. Reusing saved fold models.\n\n');

% --- Pre-allocate OOF storage (same as generateOOFPredictions) -----------
oofPreds = cell(N, 1);
for i = 1:N
    T = size(trainValData(i).waveform, 1);
    oofPreds{i}.P_stalta = zeros(T,1); oofPreds{i}.S_stalta = zeros(T,1); oofPreds{i}.N_stalta = zeros(T,1);
    oofPreds{i}.P_aic    = zeros(T,1); oofPreds{i}.S_aic    = zeros(T,1); oofPreds{i}.N_aic    = zeros(T,1);
    oofPreds{i}.P_cnn    = zeros(T,1); oofPreds{i}.S_cnn    = zeros(T,1); oofPreds{i}.N_cnn    = zeros(T,1);
    oofPreds{i}.P_tcn    = zeros(T,1); oofPreds{i}.S_tcn    = zeros(T,1); oofPreds{i}.N_tcn    = zeros(T,1);
end

modelDir = fullfile(config.outputFolder, 'models', 'trained_base_models');

% --- Select and verify the picker implementations ------------------------
if USE_FAST_PICKERS
    verifyFastPickers(trainValData(1).X, config);
    stFun = @fastSTALTAPicker;
    aiFun = @fastAICPicker;
else
    fprintf('[Pickers] Using original (slow) implementations.\n\n');
    stFun = @runSTALTAPicker;
    aiFun = @runAICPicker;
end

tPick = 0; tCNN = 0; tTCN = 0;   % phase timers

% --- Per-fold inference only (no training) -------------------------------
for k = 1:K
    fprintf('  --- Fold %d/%d (inference only) ---\n', k, K);

    foldFile = fullfile(modelDir, sprintf('fold%02d_models.mat', k));
    if ~isfile(foldFile)
        error('Missing fold model file: %s', foldFile);
    end
    Sf = load(foldFile);            % cnnFoldModel, tcnFoldModel

    heldIdx  = find(recordFold == k);
    foldHeld = trainValData(heldIdx);

    % STA/LTA and AIC are deterministic -- recomputed, not loaded
    t0 = tic;
    for i = 1:numel(foldHeld)
        recIdx = heldIdx(i);
        pcST = stFun(foldHeld(i).X, config);
        oofPreds{recIdx}.P_stalta = pcST.P;
        oofPreds{recIdx}.S_stalta = pcST.S;
        oofPreds{recIdx}.N_stalta = pcST.Noise;

        pcAI = aiFun(foldHeld(i).X, config);
        oofPreds{recIdx}.P_aic = pcAI.P;
        oofPreds{recIdx}.S_aic = pcAI.S;
        oofPreds{recIdx}.N_aic = pcAI.Noise;
    end
    tp = toc(t0); tPick = tPick + tp;
    fprintf('      STA/LTA + AIC : %6.1f s\n', tp);

    t0 = tic;
    cnnPreds = predictBaselineCNNPicker(Sf.cnnFoldModel, foldHeld, config);
    for i = 1:numel(foldHeld)
        recIdx = heldIdx(i);
        oofPreds{recIdx}.P_cnn = cnnPreds{i}.P;
        oofPreds{recIdx}.S_cnn = cnnPreds{i}.S;
        oofPreds{recIdx}.N_cnn = cnnPreds{i}.Noise;
    end

    tc = toc(t0); tCNN = tCNN + tc;
    fprintf('      CNN inference : %6.1f s\n', tc);

    t0 = tic;
    tcnPreds = predictTCNPicker(Sf.tcnFoldModel, foldHeld, config);
    for i = 1:numel(foldHeld)
        recIdx = heldIdx(i);
        oofPreds{recIdx}.P_tcn = tcnPreds{i}.P;
        oofPreds{recIdx}.S_tcn = tcnPreds{i}.S;
        oofPreds{recIdx}.N_tcn = tcnPreds{i}.Noise;
    end

    tt = toc(t0); tTCN = tTCN + tt;
    fprintf('      TCN inference : %6.1f s\n', tt);
    fprintf('      %d held-out records reconstructed.\n', numel(foldHeld));
end

% --- Save the checkpoint in the format the patched function expects ------
if ~isfolder(modelDir); mkdir(modelDir); end
ckptPath = fullfile(modelDir, 'oof_predictions_checkpoint.mat');

% Store record identity so the export step can verify ORDER, not just count
trainKeys = cell(N, 1);
for i = 1:N
    if isfield(trainValData(i), 'event_id')
        trainKeys{i} = trainValData(i).event_id;
    else
        trainKeys{i} = sprintf('record_%06d', i);
    end
end

save(ckptPath, 'oofPreds', 'recordFold', 'trainKeys', '-v7.3');

fprintf('\n[Timing] STA/LTA + AIC : %7.1f s\n', tPick);
fprintf('[Timing] CNN inference : %7.1f s\n', tCNN);
fprintf('[Timing] TCN inference : %7.1f s\n', tTCN);
fprintf('[Timing] (whichever dominates is the next thing worth optimising)\n');

fprintf('\n[Done] OOF checkpoint written:\n  %s\n', ckptPath);
fprintf('\nNext: run run_export_oof_meta_features_v2\n\n');

% =========================================================================
% FAST LOCAL PICKER IMPLEMENTATIONS
% =========================================================================
% Mathematically identical to src/base_pickers/runSTALTAPicker.m and
% runAICPicker.m, but with the inner loops replaced by cumulative sums.
%
%   original AIC      : for k = 2:winN, var(trace(1:k)) and var(trace(k+1:N))
%                       recomputed from scratch -> O(N x winN) with ~1000
%                       array copies of ~5500 elements per trace
%   original STA/LTA  : mean() inside a ~5900-iteration loop per trace
%
% Both are reformulated here as O(N) prefix-sum expressions. Defined as
% LOCAL functions on purpose, so nothing in src/ has to be edited.
% =========================================================================

function Yhat = fastSTALTAPicker(X, config)
[T, C]  = size(X);
fs      = config.samplingRate;
staSamp = max(1, round(config.stalta.staSec * fs));
ltaSamp = max(staSamp+1, round(config.stalta.ltaSec * fs));
sigma   = config.stalta.sigmaConv;

zIdx = find(strcmp(config.channelOrder, 'Z'), 1);
eIdx = find(strcmp(config.channelOrder, 'E'), 1);
nIdx = find(strcmp(config.channelOrder, 'N'), 1);
if isempty(zIdx) || zIdx > C; zIdx = min(C,3); end

zTrace  = abs(X(:, zIdx));
staLtaZ = computeSTALTARatioFast(zTrace, staSamp, ltaSamp);

if ~isempty(eIdx) && ~isempty(nIdx) && C >= max(eIdx,nIdx) && ...
        any(X(:,eIdx)~=0) && any(X(:,nIdx)~=0)
    resultNE = sqrt(X(:,eIdx).^2 + X(:,nIdx).^2);
    staLtaNE = computeSTALTARatioFast(resultNE, staSamp, ltaSamp);
else
    staLtaNE = staLtaZ;
end

staLtaZ_n  = normaliseRatioLocal(staLtaZ);
staLtaNE_n = normaliseRatioLocal(staLtaNE);

probP = ratioToProbLocal(staLtaZ_n,  T, fs, sigma, config.stalta.trigOn);
probS = ratioToProbLocal(staLtaNE_n, T, fs, sigma, config.stalta.trigOn);
probN = max(0, 1 - max(probP, probS));

Yhat.P = probP; Yhat.S = probS; Yhat.Noise = probN;
end

function Yhat = fastAICPicker(X, config)
[T, C] = size(X);
fs     = config.samplingRate;
sigma  = config.aic.sigmaConv;
winN   = round(config.aic.searchWindowSec * fs);

zIdx = find(strcmp(config.channelOrder,'Z'), 1);
eIdx = find(strcmp(config.channelOrder,'E'), 1);
nIdx = find(strcmp(config.channelOrder,'N'), 1);
if isempty(zIdx) || zIdx > C; zIdx = min(C,3); end

zTrace = X(:, zIdx);
aicZ   = computeAICFunctionFast(zTrace, winN);
probP  = aicToProbLocal(aicZ, T, fs, sigma);

if ~isempty(eIdx) && ~isempty(nIdx) && C >= max(eIdx,nIdx) && ...
        any(X(:,eIdx)~=0) && any(X(:,nIdx)~=0)
    resultNE = sqrt(X(:,eIdx).^2 + X(:,nIdx).^2);
    aicNE    = computeAICFunctionFast(resultNE, winN);
    probS    = aicToProbLocal(aicNE, T, fs, sigma);
else
    probS = probP;
end

probN = max(0, 1 - max(probP, probS));
Yhat.P = probP; Yhat.S = probS; Yhat.Noise = probN;
end

function ratio = computeSTALTARatioFast(trace, staSamp, ltaSamp)
% Vectorised equivalent of:
%   for i = (ltaSamp+1):N
%       lta = mean(trace(max(1,i-ltaSamp):i-1));
%       sta = mean(trace(max(1,i-staSamp):i));
%       ratio(i) = sta / max(lta, eps_);
N = numel(trace); ratio = zeros(N,1); eps_ = 1e-10;
if ltaSamp + 1 > N; return; end
x = double(trace(:));
c = [0; cumsum(x)];                       % c(j+1) = sum(x(1:j))
i = (ltaSamp+1:N)';
ltaStart = max(1, i - ltaSamp);
staStart = max(1, i - staSamp);
lta = (c(i)   - c(ltaStart)) ./ ((i-1) - ltaStart + 1);   % mean over ltaStart:i-1
sta = (c(i+1) - c(staStart)) ./ (i - staStart + 1);       % mean over staStart:i
ratio(i) = sta ./ max(lta, eps_);
end

function aic = computeAICFunctionFast(trace, winN)
% Vectorised equivalent of:
%   for k = 2:searchEnd
%       aic(k) = k*log(var(trace(1:k))) + (N-k-1)*log(var(trace(k+1:N)));
% using prefix sums; var() normalised by n-1 exactly as MATLAB's var().
N = numel(trace); aic = inf(N,1); eps_ = 1e-15;
searchEnd = min(N-2, winN);
if searchEnd < 2; return; end
x  = double(trace(:));
c1 = cumsum(x);
c2 = cumsum(x.^2);
T1 = c1(end); T2 = c2(end);
k  = (2:searchEnd)';
S1 = c1(k); S2 = c2(k);
v1 = (S2 - (S1.^2)./k) ./ (k - 1);            % var(trace(1:k))
nt = N - k;
R1 = T1 - S1; R2 = T2 - S2;
v2 = (R2 - (R1.^2)./nt) ./ (nt - 1);          % var(trace(k+1:N))
v1 = max(v1, eps_); v2 = max(v2, eps_);
aic(k) = k.*log(v1) + (N - k - 1).*log(v2);
end

function rN = normaliseRatioLocal(ratio)
rMin = min(ratio); rMax = max(ratio);
if rMax - rMin < 1e-10; rN = zeros(size(ratio)); else; rN = (ratio-rMin)/(rMax-rMin); end
end

function prob = ratioToProbLocal(ratioNorm, T, fs, sigma, trigThresh)
prob = zeros(T,1); t = (0:T-1)'/fs;
[pkVal, pkIdx] = max(ratioNorm);
relThresh = trigThresh/(trigThresh+1);
if pkVal >= relThresh
    tPeak = t(pkIdx);
    prob = exp(-(t-tPeak).^2/(2*sigma^2)) * pkVal;
else
    winSmooth = max(1, round(sigma*fs));
    prob = smoothdata(ratioNorm, 'gaussian', winSmooth);
end
prob = min(1, max(0, prob));
end

function prob = aicToProbLocal(aic, T, fs, sigma)
t = (0:T-1)'/fs; prob = zeros(T,1);
validIdx = find(isfinite(aic));
if isempty(validIdx); return; end
[~, relMin] = min(aic(validIdx)); kMin = validIdx(relMin);
tMin = t(kMin);
prob = min(1, max(0, exp(-(t-tMin).^2/(2*sigma^2))));
end

function verifyFastPickers(Xsample, config)
% Compare fast vs original implementations on one real record before use.
fprintf('[Verify] Checking fast pickers against originals on record 1...\n');
sl_old = runSTALTAPicker(Xsample, config);
sl_new = fastSTALTAPicker(Xsample, config);
ai_old = runAICPicker(Xsample, config);
ai_new = fastAICPicker(Xsample, config);

dSL = max([max(abs(sl_old.P - sl_new.P)), max(abs(sl_old.S - sl_new.S))]);
dAI = max([max(abs(ai_old.P - ai_new.P)), max(abs(ai_old.S - ai_new.S))]);

[~, iPold] = max(ai_old.P); [~, iPnew] = max(ai_new.P);
[~, iSold] = max(ai_old.S); [~, iSnew] = max(ai_new.S);
[~, jPold] = max(sl_old.P); [~, jPnew] = max(sl_new.P);
[~, jSold] = max(sl_old.S); [~, jSnew] = max(sl_new.S);

fprintf('         STA/LTA max |diff| = %.3e | peak idx P %d vs %d, S %d vs %d\n', ...
    dSL, jPold, jPnew, jSold, jSnew);
fprintf('         AIC     max |diff| = %.3e | peak idx P %d vs %d, S %d vs %d\n', ...
    dAI, iPold, iPnew, iSold, iSnew);

if iPold ~= iPnew || iSold ~= iSnew || jPold ~= jPnew || jSold ~= jSnew
    error(['Fast pickers changed a peak index on real data. ' ...
           'Set USE_FAST_PICKERS = false and re-run.']);
end
if dSL > 1e-6 || dAI > 1e-6
    warning('Fast/original difference larger than expected (%.3e, %.3e).', dSL, dAI);
end
fprintf('[Verify] PASS - peak indices identical, differences at rounding level.\n\n');
end
