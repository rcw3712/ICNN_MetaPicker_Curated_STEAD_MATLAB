% =========================================================================
% run_export_oof_meta_features_v2.m
% =========================================================================
% PURPOSE:
%   Build the OOF meta-feature cache WITHOUT calling generateOOFPredictions.
%
%   The archived src/oof_stacking/generateOOFPredictions.m contains a broken
%   call at its line 174:
%
%       [metaTrainFeatures, metaTrainLabels] = ...
%           buildMetaFeatureTensor(oofPreds, trainValData, config);
%
%   buildMetaFeatureTensor is a SINGLE-RECORD function, so this raises
%   "Unsupported basePredictions format: cell". Rather than patching that
%   file in place (which proved fragile -- MATLAB kept resolving the
%   unpatched copy), this script performs the meta-feature assembly itself
%   and never calls generateOOFPredictions at all. Nothing in src/ has to
%   be modified or renamed.
%
% PREREQUISITES -- both produced by your earlier runs:
%   results/models/trained_base_models/oof_predictions_checkpoint.mat
%       written by run_recover_oof_from_fold_models.m
%   results/models/trained_base_models/base_models_final.mat
%       written automatically at the end of the k-fold stage
%       ("Training final base models ... / Final base models saved.")
%
%   If the checkpoint is missing, run run_recover_oof_from_fold_models.m
%   first. It rebuilds the OOF predictions from the fold models already on
%   disk, so the base pickers are NOT retrained.
%
% OUTPUT:
%   results/predictions/oof_meta_features.mat
%       metaTrFeat, metaTrLbl, metaValFeat, metaValLbl, metaTestFeat,
%       testKeys, featureNames, exportInfo
% =========================================================================

clear; clc;
addpath(genpath('src'));
addpath('config');

config = config_ICNN_MetaPicker();
rng(config.randomSeed, 'twister');

% Fast picker implementations (verified against the originals before use).
% Set to false to fall back to src/base_pickers/run*Picker.m.
USE_FAST_PICKERS = true;

fprintf('\n========================================================\n');
fprintf('  Export OOF meta-features (v2, standalone)\n');
fprintf('========================================================\n\n');

assert(config.icnn.includeWaveformContext, ...
    ['config.icnn.includeWaveformContext must be true so the exported ' ...
     'tensor is the canonical 15-channel version.']);

modelDir  = fullfile(config.outputFolder, 'models', 'trained_base_models');
ckptPath  = fullfile(modelDir, 'oof_predictions_checkpoint.mat');
finalPath = fullfile(modelDir, 'base_models_final.mat');

assert(isfile(ckptPath), ...
    ['OOF checkpoint not found:\n  %s\n' ...
     'Run run_recover_oof_from_fold_models.m first.'], ckptPath);
assert(isfile(finalPath), ...
    ['Final base models not found:\n  %s\n' ...
     'This file is written at the end of the k-fold stage.'], finalPath);

% --- Replicate the preamble EXACTLY (same seed => same split and order) --
[data, ~] = loadDatasetFromMetadata(config);
fprintf('Records loaded: %d\n', numel(data));

[trainData, valData, testData, splitInfo] = splitBySourceID(data, config);
fprintf('Split key: %s | Train: %d | Val: %d | Test: %d\n\n', ...
    splitInfo.keyUsed, numel(trainData), numel(valData), numel(testData));

trainData = addGaussianLabels(applyPreprocessing(trainData, config), config);
valData   = addGaussianLabels(applyPreprocessing(valData,   config), config);
testData  = addGaussianLabels(applyPreprocessing(testData,  config), config);

if config.useAugmentation
    trainValData = augmentTrainingWaveform(trainData, config);
else
    trainValData = trainData;
end
N_tr = numel(trainValData);

% --- Load the cached OOF predictions and the final base models ----------
fprintf('[Cache] Loading %s\n', ckptPath);
Sc = load(ckptPath);
oofPreds = Sc.oofPreds;

assert(numel(oofPreds) == N_tr, ...
    ['Record-count mismatch: checkpoint has %d records, current training ' ...
     'set has %d. The checkpoint was built from a different split or seed.'], ...
    numel(oofPreds), N_tr);

% Optional alignment check if the recovery script stored record keys
if isfield(Sc, 'trainKeys')
    mismatches = 0;
    for i = 1:N_tr
        if ~strcmp(Sc.trainKeys{i}, trainValData(i).event_id)
            mismatches = mismatches + 1;
        end
    end
    assert(mismatches == 0, ...
        ['Record ORDER mismatch: %d of %d records differ between the ' ...
         'checkpoint and the current training set.'], mismatches, N_tr);
    fprintf('[Cache] Record alignment verified (%d records).\n', N_tr);
else
    fprintf(['[Cache] Checkpoint has no trainKeys field; relying on the ' ...
             'record-count check only.\n']);
end

Sf = load(finalPath);
baseModels = Sf.baseModelsFinal;
fprintf('[Models] Final base models loaded.\n\n');

% --- Assemble the training meta-feature tensors, one record at a time ----
% Canonical channel order:
%   P_STA,S_STA,Noise_STA, P_AIC,S_AIC,Noise_AIC,
%   P_CNN,S_CNN,Noise_CNN, P_TCN,S_TCN,Noise_TCN, E_cond,N_cond,Z_cond
fprintf('[Meta] Assembling training meta-features (%d records)...\n', N_tr);
metaTrFeat = cell(N_tr, 1);
metaTrLbl  = cell(N_tr, 1);

for i = 1:N_tr
    o = oofPreds{i};
    Zprob = [ o.P_stalta(:), o.S_stalta(:), o.N_stalta(:), ...
              o.P_aic(:),    o.S_aic(:),    o.N_aic(:),    ...
              o.P_cnn(:),    o.S_cnn(:),    o.N_cnn(:),    ...
              o.P_tcn(:),    o.S_tcn(:),    o.N_tcn(:) ];   % [T x 12]

    if isfield(trainValData, 'waveform') && ~isempty(trainValData(i).waveform)
        wavCtx = trainValData(i).waveform;
    else
        wavCtx = trainValData(i).X;
    end

    metaTrFeat{i} = [Zprob, double(wavCtx(:, 1:3))];        % [T x 15]
    metaTrLbl{i}  = trainValData(i).label;

    if mod(i, 500) == 0
        fprintf('       %d / %d\n', i, N_tr);
    end
end
fprintf('[Meta] Training meta-features done.\n\n');

% --- Validation / test meta-features from the final base models ---------
if USE_FAST_PICKERS
    verifyFastPickers(testData(1).X, config);
    stFun = @fastSTALTAPicker; aiFun = @fastAICPicker;
else
    stFun = @runSTALTAPicker;  aiFun = @runAICPicker;
end

fprintf('[Meta] Building validation meta-features (%d records)...\n', numel(valData));
t0 = tic;
metaValFeat = buildMetaFeatureLocal(valData, baseModels, config, stFun, aiFun);
metaValLbl  = cellfun(@(d) d, {valData.label}, 'UniformOutput', false)';
fprintf('       done in %.1f s\n', toc(t0));

fprintf('[Meta] Building test meta-features (%d records)...\n', numel(testData));
t0 = tic;
metaTestFeat = buildMetaFeatureLocal(testData, baseModels, config, stFun, aiFun);
fprintf('       done in %.1f s\n', toc(t0));

% --- Record identity for the test set -----------------------------------
testKeys = cell(numel(testData), 1);
for i = 1:numel(testData)
    if isfield(testData(i), 'event_id')
        testKeys{i} = testData(i).event_id;
    else
        testKeys{i} = sprintf('record_%04d', i);
    end
end

featureNames = { ...
    'P_STA';'S_STA';'Noise_STA'; ...
    'P_AIC';'S_AIC';'Noise_AIC'; ...
    'P_CNN';'S_CNN';'Noise_CNN'; ...
    'P_TCN';'S_TCN';'Noise_TCN'; ...
    'E_conditioned';'N_conditioned';'Z_conditioned'};

C_meta = size(metaTrFeat{1}, 2);
assert(C_meta == numel(featureNames), ...
    'Channel count mismatch: tensor has %d channels, expected %d.', ...
    C_meta, numel(featureNames));
assert(size(metaTestFeat{1}, 2) == C_meta, ...
    'Train/test channel mismatch: %d vs %d.', C_meta, size(metaTestFeat{1}, 2));

exportInfo = struct( ...
    'createdOn',        datestr(now, 'yyyy-mm-dd HH:MM:SS'), ...
    'randomSeed',       config.randomSeed, ...
    'splitKeyUsed',     splitInfo.keyUsed, ...
    'nTrainRecords',    N_tr, ...
    'nValRecords',      numel(metaValFeat), ...
    'nTestRecords',     numel(metaTestFeat), ...
    'C_meta',           C_meta, ...
    'augmentationUsed', config.useAugmentation, ...
    'sourceScript',     'run_export_oof_meta_features_v2.m', ...
    'oofSource',        ckptPath);

predDir = fullfile(config.outputFolder, 'predictions');
if ~isfolder(predDir); mkdir(predDir); end
outPath = fullfile(predDir, 'oof_meta_features.mat');

save(outPath, 'metaTrFeat', 'metaTrLbl', 'metaValFeat', 'metaValLbl', ...
    'metaTestFeat', 'testKeys', 'featureNames', 'exportInfo', '-v7.3');

fprintf('\n[Done] Cached OOF meta-features:\n  %s\n', outPath);
fprintf('  Train: %d | Val: %d | Test: %d | Channels: %d\n', ...
    N_tr, numel(metaValFeat), numel(metaTestFeat), C_meta);
fprintf('\nNext: run_metalearner_ablations\n\n');

% =========================================================================
% Local equivalent of src/oof_stacking/buildMetaFeatureFromModels.m,
% parameterised by the picker implementation so the fast versions can be
% used without editing anything in src/.
% =========================================================================
function metaFeatures = buildMetaFeatureLocal(data, baseModels, config, stFun, aiFun)
N = numel(data);
metaFeatures = cell(N, 1);

cnnPreds = predictBaselineCNNPicker(baseModels.cnn, data, config);
tcnPreds = predictTCNPicker(baseModels.tcn, data, config);

for i = 1:N
    pcST = stFun(data(i).X, config);
    pcAI = aiFun(data(i).X, config);

    Z_meta = [ pcST.P, pcST.S, pcST.Noise, ...
               pcAI.P, pcAI.S, pcAI.Noise, ...
               cnnPreds{i}.P, cnnPreds{i}.S, cnnPreds{i}.Noise, ...
               tcnPreds{i}.P, tcnPreds{i}.S, tcnPreds{i}.Noise ];   % [T x 12]

    if config.icnn.includeWaveformContext
        Z_meta = [Z_meta, double(data(i).waveform(:, 1:3))];        %#ok<AGROW>
    end

    metaFeatures{i} = Z_meta;

    if mod(i, 100) == 0; fprintf('       %d / %d\n', i, N); end
end
end

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
