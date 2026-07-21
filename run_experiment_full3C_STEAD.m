% =========================================================================
% run_experiment_full3C_STEAD.m
% =========================================================================
% Eksperimen benchmark Full 3-Component (E, N, Z).
%
% CATATAN: Tidak perlu menjalankan run_qc_and_metadata_build.m dulu.
% QC sudah ada di metadata_master_filled.xlsx (kolom quality_flag).
%
% Output: results/metrics/metrics_full3C.csv
% =========================================================================

clc; clear; close all;
rootDir = fileparts(mfilename('fullpath'));
addpath(genpath(rootDir));

fprintf('=== run_experiment_full3C_STEAD ===\n\n');

config = config_ICNN_MetaPicker();
config.experimentMode = 'full3C';
rng(config.randomSeed, 'twister');

% Load metadata + CSV waveform (QC sudah di metadata)
[data, metadata] = loadDatasetFromMetadata(config);
fprintf('Records loaded: %d\n', numel(data));

% Split berbasis source_id ASLI STEAD
[trainData, valData, testData, splitInfo] = splitBySourceID(data, config);
fprintf('Split key: %s | Train: %d | Val: %d | Test: %d\n\n', ...
    splitInfo.keyUsed, numel(trainData), numel(valData), numel(testData));

% Conditioning + labels
trainData = addGaussianLabels(applyPreprocessing(trainData, config), config);
valData   = addGaussianLabels(applyPreprocessing(valData,   config), config);
testData  = addGaussianLabels(applyPreprocessing(testData,  config), config);

% Augmentasi (training only)
if config.useAugmentation
    trainDataAug = augmentTrainingWaveform(trainData, config);
else
    trainDataAug = trainData;
end

% OOF stacking
[metaTrFeat, metaTrLbl, baseModels] = generateOOFPredictions(...
    trainDataAug, config, splitInfo.keyUsed);
metaValFeat  = buildMetaFeatureFromModels(valData,  baseModels, config);
metaValLbl   = cellfun(@(d) d, {valData.label}, 'UniformOutput', false)';
metaTestFeat = buildMetaFeatureFromModels(testData, baseModels, config);

% Train I-CNN meta-learner
[icnnModel, trainInfo] = trainICNNMetaLearner(...
    metaTrFeat, metaTrLbl, metaValFeat, metaValLbl, config);

modelDir = fullfile(config.outputFolder, 'models', 'trained_ICNN_meta_learner');
ensureDir(modelDir);
save(fullfile(modelDir, 'model_ICNN_meta.mat'), 'icnnModel', 'trainInfo', '-v7.3');

% Predict + evaluasi
predTest  = predictICNNMetaLearner(icnnModel, metaTestFeat, config);
picksTest = physicsAwarePicker(predTest, config);
gtTest    = extractGroundTruth(testData);

% Isi p_error_ms dan s_error_ms ke dalam picks (untuk CSV predictions dan figures)
picksTest = fillPickErrors(picksTest, gtTest);

metricsFull3C = evaluatePickingPerformance(picksTest, gtTest, config);
metricsDir = fullfile(config.outputFolder, 'metrics');
ensureDir(metricsDir);
writetable(metricsFull3C, fullfile(metricsDir, 'metrics_full3C.csv'));

predDir = fullfile(config.outputFolder, 'predictions');
ensureDir(predDir);
savePredictions(picksTest, gtTest, testData, fullfile(predDir, 'predictions_full3C.csv'));

fprintf('\n[Results] Full 3C:\n');
for r = 1:height(metricsFull3C)
    fprintf('  [%s] MAE=%.1f ms  F1@100ms=%.3f  DetRate=%.2f\n', ...
        metricsFull3C.Component{r}, metricsFull3C.MAE_ms(r), ...
        metricsFull3C.F1_100ms(r), metricsFull3C.DetectionRate(r));
end

function picks = fillPickErrors(picks, gt)
% Isi p_error_ms dan s_error_ms ke dalam struct picks
% error = (pred_sec - true_sec) * 1000  [ms, bertanda]
for i = 1:numel(picks)
    if ~isnan(picks(i).p_pick_sec) && ~isnan(gt(i).p_arrival_sec)
        picks(i).p_error_ms = (picks(i).p_pick_sec - gt(i).p_arrival_sec) * 1000;
    else
        picks(i).p_error_ms = NaN;
    end
    if ~isnan(picks(i).s_pick_sec) && ~isnan(gt(i).s_arrival_sec)
        picks(i).s_error_ms = (picks(i).s_pick_sec - gt(i).s_arrival_sec) * 1000;
    else
        picks(i).s_error_ms = NaN;
    end
end
end

function savePredictions(picks, gt, data, outPath)
N = numel(picks); snrs = nan(N,1);
for i = 1:N; if isfield(data,'SNR'); snrs(i) = data(i).SNR; end; end
T = table({gt.event_id}', {gt.source_id}', ...
    [picks.p_pick_sec]', [picks.s_pick_sec]', ...
    [gt.p_arrival_sec]', [gt.s_arrival_sec]', ...
    [picks.p_error_ms]', [picks.s_error_ms]', ...
    {picks.p_status}', {picks.s_status}', snrs, ...
    'VariableNames', {'event_id','source_id','p_pred_sec','s_pred_sec', ...
        'p_true_sec','s_true_sec','p_error_ms','s_error_ms', ...
        'p_status','s_status','SNR'});
ensureDir(fileparts(outPath));
writetable(T, outPath);
end

function gt = extractGroundTruth(data)
N = numel(data);
gt = struct('p_arrival_sec',cell(N,1),'s_arrival_sec',cell(N,1), ...
            'source_id',cell(N,1),'event_id',cell(N,1));
for i = 1:N
    gt(i).p_arrival_sec = data(i).p_arrival_sec;
    gt(i).s_arrival_sec = data(i).s_arrival_sec;
    gt(i).source_id     = data(i).source_id;
    gt(i).event_id      = data(i).event_id;
end
end
function ensureDir(d); if ~isempty(d) && ~isfolder(d); mkdir(d); end; end
