% =========================================================================
% generateOOFPredictions.m  (src/oof_stacking/)
% =========================================================================
% PURPOSE:
%   Generate Out-Of-Fold (OOF) predictions from all four base pickers,
%   producing leakage-free meta-features for I-CNN meta-learner training.
%
% INPUT:
%   trainValData - struct array, TRAINING subset (post leakage-free
%                  split, post augmentation). Must have .X [T x C],
%                  .label [T x 3], and a split-key field (.source_id or
%                  .event_id, matching config.splitKey / splitInfo.keyUsed)
%   config       - struct, framework configuration
%   splitKeyField - char, the field name actually used for the split
%                   ('source_id' or 'event_id') — passed through from
%                   splitBySourceID.m's splitInfo.keyUsed so the OOF fold
%                   assignment uses the SAME identifier as the original
%                   train/val/test split, preserving leakage-free
%                   guarantees end-to-end.
%
% OUTPUT:
%   metaTrainFeatures - cell{N,1}, each [T x C_meta] meta-feature tensor
%   metaTrainLabels   - cell{N,1}, each [T x 3] Gaussian label
%   baseModelsFinal   - struct with .cnn, .tcn — models retrained on the
%                       FULL trainValData, used for val/test/Z-only sets
%
% NOTES:
%   *** OOF prediction is mandatory because I-CNN is a meta-learner. ***
%   The meta-learner must not be trained on base-model predictions
%   generated from events already seen by those base models.
%
%   K-fold OOF procedure (fold assignment by splitKeyField, matching the
%   key used in the outer train/val/test split):
%     FOR k = 1 to K:
%         heldFold  = trainValData[fold == k]
%         trainFold = trainValData[fold != k]   (K-1 folds)
%
%         OOF_STA[heldFold]  = runSTALTAPicker(heldFold.X)   % no training
%         OOF_AIC[heldFold]  = runAICPicker(heldFold.X)      % no training
%
%         cnn_k = trainBaselineCNNPicker(trainFold, valSubsetOfHeld)
%         tcn_k = trainTCNPicker(trainFold, valSubsetOfHeld)
%         OOF_CNN[heldFold] = predictBaselineCNNPicker(cnn_k, heldFold)
%         OOF_TCN[heldFold] = predictTCNPicker(tcn_k, heldFold)
%     END FOR
%
%     metaTrainFeatures = buildMetaFeatureTensor(OOF_STA, OOF_AIC,
%                                                  OOF_CNN, OOF_TCN, ...)
%
%     baseModelsFinal.cnn = trainBaselineCNNPicker(ALL trainValData, ...)
%     baseModelsFinal.tcn = trainTCNPicker(ALL trainValData, ...)
% =========================================================================

function [metaTrainFeatures, metaTrainLabels, baseModelsFinal] = ...
    generateOOFPredictions(trainValData, config, splitKeyField)

if nargin < 3 || isempty(splitKeyField)
    splitKeyField = config.splitKey;
    if ~isfield(trainValData, splitKeyField)
        splitKeyField = 'event_id';
    end
end

K = config.kFold;
N = numel(trainValData);

fprintf('  OOF stacking: %d-fold (by %s), N=%d training records\n', K, splitKeyField, N);

% ── 1. Assign IDs to folds (round-robin after shuffle) ────────────────────
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

fprintf('  Fold distribution (records per fold):\n');
for k = 1:K
    fprintf('    Fold %d: %d records\n', k, sum(recordFold == k));
end

% ── 2. Pre-allocate OOF prediction storage ────────────────────────────────
oofPreds = cell(N, 1);
for i = 1:N
    T = size(trainValData(i).waveform, 1);
    oofPreds{i}.P_stalta = zeros(T,1); oofPreds{i}.S_stalta = zeros(T,1); oofPreds{i}.N_stalta = zeros(T,1);
    oofPreds{i}.P_aic    = zeros(T,1); oofPreds{i}.S_aic    = zeros(T,1); oofPreds{i}.N_aic    = zeros(T,1);
    oofPreds{i}.P_cnn    = zeros(T,1); oofPreds{i}.S_cnn    = zeros(T,1); oofPreds{i}.N_cnn    = zeros(T,1);
    oofPreds{i}.P_tcn    = zeros(T,1); oofPreds{i}.S_tcn    = zeros(T,1); oofPreds{i}.N_tcn    = zeros(T,1);
end

% ── 3. K-fold loop ─────────────────────────────────────────────────────────
for k = 1:K
    fprintf('  --- OOF Fold %d/%d ---\n', k, K);

    heldIdx  = find(recordFold == k);
    trainIdx = find(recordFold ~= k);

    foldTrain = trainValData(trainIdx);
    foldHeld  = trainValData(heldIdx);

    % ── 3a. STA/LTA and AIC: deterministic, no training required ─────────
    for i = 1:numel(foldHeld)
        recIdx = heldIdx(i);
        pcST = runSTALTAPicker(foldHeld(i).X, config);
        oofPreds{recIdx}.P_stalta = pcST.P;
        oofPreds{recIdx}.S_stalta = pcST.S;
        oofPreds{recIdx}.N_stalta = pcST.Noise;

        pcAI = runAICPicker(foldHeld(i).X, config);
        oofPreds{recIdx}.P_aic = pcAI.P;
        oofPreds{recIdx}.S_aic = pcAI.S;
        oofPreds{recIdx}.N_aic = pcAI.Noise;
    end

    % ── 3b. Baseline CNN: train on K-1 folds, predict held fold ───────────
    nHeld = numel(foldHeld);
    nFoldVal = max(1, round(0.2*nHeld));
    foldHeldVal   = foldHeld(1:nFoldVal);
    foldHeldTrain = foldHeld(nFoldVal+1:end);
    innerTrain    = [foldTrain; foldHeldTrain];

    fprintf('    Training BaselineCNN (base picker) on fold %d...\n', k);
    cnnFoldModel = trainBaselineCNNPicker(innerTrain, foldHeldVal, config);
    cnnPreds = predictBaselineCNNPicker(cnnFoldModel, foldHeld, config);
    for i = 1:numel(foldHeld)
        recIdx = heldIdx(i);
        oofPreds{recIdx}.P_cnn = cnnPreds{i}.P;
        oofPreds{recIdx}.S_cnn = cnnPreds{i}.S;
        oofPreds{recIdx}.N_cnn = cnnPreds{i}.Noise;
    end

    % ── 3c. TCN: train on K-1 folds, predict held fold ─────────────────────
    fprintf('    Training TCN (base picker) on fold %d...\n', k);
    tcnFoldModel = trainTCNPicker(innerTrain, foldHeldVal, config);
    tcnPreds = predictTCNPicker(tcnFoldModel, foldHeld, config);
    for i = 1:numel(foldHeld)
        recIdx = heldIdx(i);
        oofPreds{recIdx}.P_tcn = tcnPreds{i}.P;
        oofPreds{recIdx}.S_tcn = tcnPreds{i}.S;
        oofPreds{recIdx}.N_tcn = tcnPreds{i}.Noise;
    end

    foldDir = fullfile(config.outputFolder, 'models', 'trained_base_models');
    ensureDir(foldDir);
    save(fullfile(foldDir, sprintf('fold%02d_models.mat', k)), ...
        'cnnFoldModel', 'tcnFoldModel', '-v7.3');
end

% ── 4. Retrain final base models on ALL training data ─────────────────────
fprintf('  Training final base models (Baseline CNN, TCN) on full training set...\n');
nFinalVal   = max(1, round(0.15*N));
finalValIdx = randperm(N, nFinalVal);
finalTrIdx  = setdiff(1:N, finalValIdx);

baseModelsFinal.cnn = trainBaselineCNNPicker(...
    trainValData(finalTrIdx), trainValData(finalValIdx), config);
baseModelsFinal.tcn = trainTCNPicker(...
    trainValData(finalTrIdx), trainValData(finalValIdx), config);

modelDir = fullfile(config.outputFolder, 'models', 'trained_base_models');
ensureDir(modelDir);
save(fullfile(modelDir, 'base_models_final.mat'), 'baseModelsFinal', '-v7.3');

fprintf('  OOF stacking complete. Final base models saved.\n');

% ── 5. Build meta-feature tensor from OOF predictions ─────────────────────
[metaTrainFeatures, metaTrainLabels] = buildMetaFeatureTensor(oofPreds, trainValData, config);

fprintf('  Meta-feature tensor: %d records x %d channels\n', ...
    numel(metaTrainFeatures), size(metaTrainFeatures{1}, 2));

end


function ensureDir(d)
if ~isempty(d) && ~isfolder(d); mkdir(d); end
end

% =========================================================================
% buildMetaFeatureTensor.m  (src/oof_stacking/)
% =========================================================================
% PURPOSE:
%   Construct the meta-feature tensor Z_meta(t) consumed by the I-CNN
%   meta-learner, from base picker probability curve outputs.
%
% INPUT:
%   basePredictions - cell{N,1}, struct per record with fields:
%       P_stalta,S_stalta,N_stalta, P_aic,S_aic,N_aic,
%       P_cnn,S_cnn,N_cnn, P_tcn,S_tcn,N_tcn   (each [T x 1])
%   data            - struct array, same length, used for optional
%                      waveform context (.waveform field, conditioned)
%   config          - struct, framework configuration
%                      (uses config.icnn.includeWaveformContext)
%
% OUTPUT:
%   metaFeatures - cell{N,1}, each [T x C_meta] double
%                  C_meta = 12 (base picker channels) [+3 waveform context]
%   metaLabels   - cell{N,1}, each [T x 3] double (Gaussian label)
%
% NOTES:
%   Z_meta(t) = [P_STA,S_STA,Noise_STA, P_AIC,S_AIC,Noise_AIC,
%                P_CNN,S_CNN,Noise_CNN, P_TCN,S_TCN,Noise_TCN]  (12 channels)
%
%   If config.icnn.includeWaveformContext == true:
%       Z_meta_context(t) = [Z_meta(t), E_conditioned, N_conditioned, Z_conditioned]
%                                                              (15 channels)
%
%   Waveform context is OPTIONAL. The I-CNN's primary input is always the
%   stacked base-picker probability curves; waveform context channels (if
%   included) supplement but never replace this. I-CNN must never be
%   configured to receive ONLY waveform channels.
% =========================================================================
