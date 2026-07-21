% =========================================================================
% run_ablation_study.m
% =========================================================================
% PURPOSE:
%   Comprehensive ablation study comparing base pickers, I-CNN
%   meta-learner variants, Full3C vs Z-only, and enhanced vs
%   non-enhanced representation, on the curated STEAD CSV dataset.
%
% INPUT:
%   (none — uses config/config_ICNN_MetaPicker.m)
%
% OUTPUT:
%   results/metrics/ablation_results.csv
%   results/figures/ablation_barchart.png
%
% NOTES:
%   Conditions compared:
%     1. STA/LTA only               - classical base picker
%     2. AIC only                   - classical base picker
%     3. Baseline CNN                - single deep-learning base picker
%     4. Dilated TCN                 - single deep-learning base picker
%     5. I-CNN (no physics picker)   - meta-learner, raw argmax
%     6. I-CNN + physics (FULL3C)    - FULL PROPOSED SYSTEM
%     7. I-CNN + physics (Zonly)     - PiGraf-limitation simulation
%     8. I-CNN (non-enhanced repr.)  - conditioned waveform only, no
%                                       envelope/STE/CF channels
%
%   *** IMPORTANT NAMING ***: Conditions 1-4 are base pickers (level-1).
%   Never refer to the Baseline CNN or TCN as "I-CNN" - that term is
%   reserved exclusively for the level-2 meta-learner.
% =========================================================================

clc; clear; close all;
rootDir = fileparts(mfilename('fullpath'));
addpath(genpath(rootDir));

fprintf('=== run_ablation_study ===\n\n');

config = config_ICNN_MetaPicker();
rng(config.randomSeed, 'twister');

% ── Shared data preparation (Full3C, enhanced representation) ────────────
fprintf('[Prep] Loading and preparing data...\n');
config.experimentMode = 'full3C';
[data, metadata] = loadDatasetFromMetadata(config);
dataClean = data;  % QC sudah dilakukan di metadata_master_filled.xlsx
[trainData, valData, testData, splitInfo] = splitBySourceID(dataClean, config);

trainData = addGaussianLabels(applyPreprocessing(trainData, config), config);
valData   = addGaussianLabels(applyPreprocessing(valData,   config), config);
testData  = addGaussianLabels(applyPreprocessing(testData,  config), config);

if config.useAugmentation
    trainDataAug = augmentTrainingWaveform(trainData, config);
else
    trainDataAug = trainData;
end
gtTest = extractGroundTruth(testData);

fprintf('[Prep] %d test records ready.\n\n', numel(testData));

% ── Train shared base models (conditions 3-7) ──────────────────────────────
fprintf('[Shared] Training Baseline CNN and TCN base models...\n');
nV  = max(1, round(0.15*numel(trainDataAug)));
iV  = randperm(numel(trainDataAug), nV);
iTr = setdiff(1:numel(trainDataAug), iV);
cnnModel = trainBaselineCNNPicker(trainDataAug(iTr), trainDataAug(iV), config);
tcnModel = trainTCNPicker(trainDataAug(iTr), trainDataAug(iV), config);
baseModels.cnn = cnnModel;
baseModels.tcn = tcnModel;

testCNNPred = predictBaselineCNNPicker(cnnModel, testData, config);
testTCNPred = predictTCNPicker(tcnModel, testData, config);

% ── OOF for I-CNN conditions ───────────────────────────────────────────────
fprintf('[Shared] OOF stacking for I-CNN meta-learner...\n');
[metaTrFeat, metaTrLbl, ~] = generateOOFPredictions(trainDataAug, config, splitInfo.keyUsed);
metaValFeat  = buildMetaFeatureFromModels(valData,  baseModels, config);
metaValLbl   = cellfun(@(d) d, {valData.label}, 'UniformOutput', false)';
metaTestFeat = buildMetaFeatureFromModels(testData, baseModels, config);

ablationResults = table();

% ── CONDITION 1: STA/LTA only ───────────────────────────────────────────────
fprintf('\n[Cond 1/8] STA/LTA only (base picker)...\n');
predsC1 = applyPickerToDataset(testData, @runSTALTAPicker, config);
picksC1 = physicsAwarePicker(predsC1, config);
metricsC1 = evaluatePickingPerformance(picksC1, gtTest, config);
ablationResults = appendAbl(ablationResults, metricsC1, 'STA/LTA only');

% ── CONDITION 2: AIC only ───────────────────────────────────────────────────
fprintf('\n[Cond 2/8] AIC only (base picker)...\n');
predsC2 = applyPickerToDataset(testData, @runAICPicker, config);
picksC2 = physicsAwarePicker(predsC2, config);
metricsC2 = evaluatePickingPerformance(picksC2, gtTest, config);
ablationResults = appendAbl(ablationResults, metricsC2, 'AIC only');

% ── CONDITION 3: Baseline CNN (base picker - NOT I-CNN) ────────────────────
fprintf('\n[Cond 3/8] Baseline CNN (base picker)...\n');
picksC3 = physicsAwarePicker(reformatPicker(testCNNPred), config);
metricsC3 = evaluatePickingPerformance(picksC3, gtTest, config);
ablationResults = appendAbl(ablationResults, metricsC3, 'Baseline CNN');

% ── CONDITION 4: Dilated TCN (base picker - NOT I-CNN) ─────────────────────
fprintf('\n[Cond 4/8] Dilated TCN (base picker)...\n');
picksC4 = physicsAwarePicker(reformatPicker(testTCNPred), config);
metricsC4 = evaluatePickingPerformance(picksC4, gtTest, config);
ablationResults = appendAbl(ablationResults, metricsC4, 'Dilated TCN');

% ── CONDITION 5: I-CNN meta-learner WITHOUT physics-aware picker ──────────
fprintf('\n[Cond 5/8] I-CNN meta-learner (no physics picker)...\n');
[icnnC5, ~] = trainICNNMetaLearner(metaTrFeat, metaTrLbl, metaValFeat, metaValLbl, config);
predC5  = predictICNNMetaLearner(icnnC5, metaTestFeat, config);
picksC5 = rawArgmaxPicker(predC5, config);
metricsC5 = evaluatePickingPerformance(picksC5, gtTest, config);
ablationResults = appendAbl(ablationResults, metricsC5, 'I-CNN (no physics)');

% ── CONDITION 6: I-CNN + physics-aware picker (FULL SYSTEM, Full3C) ───────
fprintf('\n[Cond 6/8] I-CNN meta-learner + physics-aware picker (FULL, Full3C)...\n');
picksC6 = physicsAwarePicker(predC5, config);
metricsC6 = evaluatePickingPerformance(picksC6, gtTest, config);
ablationResults = appendAbl(ablationResults, metricsC6, 'I-CNN + physics (Full3C)');

modelDir = fullfile(config.outputFolder,'models');
ensureDir(fullfile(modelDir,'trained_ICNN_meta_learner'));
ensureDir(fullfile(modelDir,'trained_base_models'));
save(fullfile(modelDir,'trained_ICNN_meta_learner','model_ICNN_meta.mat'), 'icnnC5', '-v7.3');
save(fullfile(modelDir,'trained_base_models','base_models_final.mat'), 'baseModels', '-v7.3');

% ── CONDITION 7: I-CNN + physics (Z-only, PiGraf simulation) ──────────────
fprintf('\n[Cond 7/8] I-CNN meta-learner + physics (Z-only, PiGraf simulation)...\n');
testDataZ = zeroHorizontalChannels(testData, config);
testDataZ = applyPreprocessing(testDataZ, config);
metaTestFeatZ = buildMetaFeatureFromModels(testDataZ, baseModels, config);
predCZ  = predictICNNMetaLearner(icnnC5, metaTestFeatZ, config);
picksCZ = physicsAwarePicker(predCZ, config);
metricsCZ = evaluatePickingPerformance(picksCZ, gtTest, config);
ablationResults = appendAbl(ablationResults, metricsCZ, 'I-CNN + physics (Zonly)');

% ── CONDITION 8: I-CNN with non-enhanced representation ───────────────────
fprintf('\n[Cond 8/8] I-CNN meta-learner (non-enhanced representation)...\n');
configNoEnh = config;
configNoEnh.useEnhancedRepresentation = false;

trainDataNoEnh = applyPreprocessing(trainData, configNoEnh);
trainDataNoEnh = addGaussianLabels(trainDataNoEnh, configNoEnh);
if configNoEnh.useAugmentation
    trainDataAugNoEnh = augmentTrainingWaveform(trainDataNoEnh, configNoEnh);
else
    trainDataAugNoEnh = trainDataNoEnh;
end
valDataNoEnh  = addGaussianLabels(applyPreprocessing(valData,  configNoEnh), configNoEnh);
testDataNoEnh = addGaussianLabels(applyPreprocessing(testData, configNoEnh), configNoEnh);

nV2  = max(1, round(0.15*numel(trainDataAugNoEnh)));
iV2  = randperm(numel(trainDataAugNoEnh), nV2);
iTr2 = setdiff(1:numel(trainDataAugNoEnh), iV2);
cnnModelNoEnh = trainBaselineCNNPicker(trainDataAugNoEnh(iTr2), trainDataAugNoEnh(iV2), configNoEnh);
tcnModelNoEnh = trainTCNPicker(trainDataAugNoEnh(iTr2), trainDataAugNoEnh(iV2), configNoEnh);
baseModelsNoEnh.cnn = cnnModelNoEnh;
baseModelsNoEnh.tcn = tcnModelNoEnh;

[metaTrFeatNE, metaTrLblNE, ~] = generateOOFPredictions(trainDataAugNoEnh, configNoEnh, splitInfo.keyUsed);
metaValFeatNE  = buildMetaFeatureFromModels(valDataNoEnh, baseModelsNoEnh, configNoEnh);
metaValLblNE   = cellfun(@(d) d, {valDataNoEnh.label}, 'UniformOutput', false)';
metaTestFeatNE = buildMetaFeatureFromModels(testDataNoEnh, baseModelsNoEnh, configNoEnh);

[icnnC8, ~] = trainICNNMetaLearner(metaTrFeatNE, metaTrLblNE, metaValFeatNE, metaValLblNE, configNoEnh);
predC8  = predictICNNMetaLearner(icnnC8, metaTestFeatNE, configNoEnh);
picksC8 = physicsAwarePicker(predC8, configNoEnh);
metricsC8 = evaluatePickingPerformance(picksC8, gtTest, configNoEnh);
ablationResults = appendAbl(ablationResults, metricsC8, 'I-CNN (non-enhanced repr.)');

% ── Save results ────────────────────────────────────────────────────────────
metricsDir = fullfile(config.outputFolder,'metrics');
ensureDir(metricsDir);
ablPath = fullfile(metricsDir, 'ablation_results.csv');
writetable(ablationResults, ablPath);
fprintf('\nAblation results saved: %s\n', ablPath);

% ── Print summary ────────────────────────────────────────────────────────────
fprintf('\n====== ABLATION SUMMARY ======\n');
fprintf('%-34s %-5s %-9s %-9s %-8s\n','Condition','Wave','MAE(ms)','F1@100ms','DetRate');
fprintf('%s\n', repmat('-',1,70));
for r = 1:height(ablationResults)
    fprintf('%-34s %-5s %-9.1f %-9.3f %-8.2f\n', ...
        ablationResults.Condition{r}, ablationResults.Component{r}, ...
        ablationResults.MAE_ms(r), ablationResults.F1_100ms(r), ...
        ablationResults.DetectionRate(r));
end
fprintf('%s\n\n', repmat('=',1,70));

% ── Figure ────────────────────────────────────────────────────────────────
figDir = fullfile(config.outputFolder,'figures');
ensureDir(figDir);
plotAblationResults(ablationResults, fullfile(figDir,'ablation_barchart.png'));
fprintf('Ablation bar chart saved.\n\n');

% =========================================================================
% LOCAL HELPER FUNCTIONS
% =========================================================================

function preds = applyPickerToDataset(data, pickerFn, config)
N = numel(data); preds = cell(N,1);
for i = 1:N
    pc = pickerFn(data(i).X, config);
    preds{i}.P = pc.P; preds{i}.S = pc.S; preds{i}.Noise = pc.Noise;
end
end

function preds = reformatPicker(rawPreds)
N = numel(rawPreds); preds = cell(N,1);
for i = 1:N
    preds{i}.P = rawPreds{i}.P; preds{i}.S = rawPreds{i}.S; preds{i}.Noise = rawPreds{i}.Noise;
end
end

function picks = rawArgmaxPicker(predictions, config)
N = numel(predictions); fs = config.samplingRate;
picks = struct('p_pick_sample',num2cell(nan(N,1)),'s_pick_sample',num2cell(nan(N,1)), ...
    'p_pick_sec',num2cell(nan(N,1)),'s_pick_sec',num2cell(nan(N,1)), ...
    'p_quality',num2cell(zeros(N,1)),'s_quality',num2cell(zeros(N,1)), ...
    'p_status',repmat({'argmax'},N,1),'s_status',repmat({'argmax'},N,1), ...
    'p_error_ms',num2cell(nan(N,1)),'s_error_ms',num2cell(nan(N,1)));
for i = 1:N
    probP = predictions{i}.P; probS = predictions{i}.S;
    T = numel(probP); sampleIdx = (1:T)';
    [pkP, idxP] = max(probP); [pkS, idxS] = max(probS);
    picks(i).p_pick_sample = sampleIdx(idxP); picks(i).p_pick_sec = sampleIdx(idxP)/fs;
    picks(i).s_pick_sample = sampleIdx(idxS); picks(i).s_pick_sec = sampleIdx(idxS)/fs;
    picks(i).p_quality = pkP; picks(i).s_quality = pkS;
end
end

function abl = appendAbl(abl, metrics, condName)
for r = 1:height(metrics)
    row = metrics(r,:);
    row.Condition = {condName};
    if isempty(abl); abl = row; else; abl = [abl; row]; end %#ok<AGROW>
end
end

function data = zeroHorizontalChannels(data, config)
eIdx = find(strcmp(config.channelOrder,'E'),1);
nIdx = find(strcmp(config.channelOrder,'N'),1);
for i = 1:numel(data)
    if ~isempty(eIdx); data(i).waveform(:,eIdx)=0; end
    if ~isempty(nIdx); data(i).waveform(:,nIdx)=0; end
end
end

function gt = extractGroundTruth(data)
N = numel(data);
gt = struct('p_arrival_sec',cell(N,1),'s_arrival_sec',cell(N,1), ...
            'source_id',cell(N,1),'event_id',cell(N,1),'file_name',cell(N,1));
for i=1:N
    gt(i).p_arrival_sec=data(i).p_arrival_sec; gt(i).s_arrival_sec=data(i).s_arrival_sec;
    gt(i).source_id=data(i).source_id; gt(i).event_id=data(i).event_id;
    gt(i).file_name=data(i).file_name;
end
end

function ensureDir(d)
if ~isempty(d) && ~isfolder(d); mkdir(d); end
end
