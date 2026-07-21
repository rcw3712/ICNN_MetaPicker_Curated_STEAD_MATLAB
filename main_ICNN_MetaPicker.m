% =========================================================================
% main_ICNN_MetaPicker.m
% =========================================================================
% PURPOSE:
%   Pipeline utama end-to-end untuk I-CNN MetaPicker menggunakan:
%     - metadata_master_filled.xlsx  (25.000 baris, sudah terisi QC)
%     - 2.234 file CSV stead_event_NNNNN.csv (waveform E,N,Z)
%
% URUTAN EKSEKUSI YANG DISARANKAN:
%   Pertama kali (sekali saja):
%     >> run_qc_and_metadata_build     % verifikasi metadata + CSV
%     >> exportMetadataToCSV(config)   % (opsional) percepat pembacaan
%
%   Eksperimen utama:
%     >> run_experiment_full3C_STEAD   % benchmark Full 3C
%     >> run_experiment_Zonly_STEAD    % simulasi PiGraf (Z-only)
%     >> run_ablation_study            % 8 kondisi ablasi
%
%   ATAU jalankan semuanya sekaligus via skrip ini:
%     >> main_ICNN_MetaPicker
% =========================================================================

clc; clear; close all;
rootDir = fileparts(mfilename('fullpath'));
addpath(genpath(rootDir));

fprintf('╔══════════════════════════════════════════════════════════╗\n');
fprintf('║  Leakage-Free I-CNN Meta-Learning Framework               ║\n');
fprintf('║  Curated STEAD CSV  |  Computers & Geosciences            ║\n');
fprintf('╚══════════════════════════════════════════════════════════╝\n\n');

% ── 1. Config ─────────────────────────────────────────────────────────────
config = config_ICNN_MetaPicker();
config.rootDir = rootDir;
config.experimentMode = 'full3C';

rng(config.randomSeed, 'twister');
ensureDir(fullfile(config.outputFolder, 'logs'));
save(fullfile(config.outputFolder,'logs','config_used.mat'), 'config');
logFid = fopen(fullfile(config.outputFolder,'logs','random_seed_log.txt'),'w');
fprintf(logFid,'Seed: %d | Time: %s | MATLAB: %s\n', ...
    config.randomSeed, datestr(now), version);
fclose(logFid);
fprintf('[1] Config loaded. Mode: %s. Seed: %d\n\n', config.experimentMode, config.randomSeed);

% ── 2. Load metadata + waveforms ──────────────────────────────────────────
fprintf('[2] Loading dataset (metadata + 2.234 CSV waveforms)...\n');
fprintf('    Metadata: %s\n', config.metadataPath);
fprintf('    CSV folder: %s\n', config.csvFolder);
[data, metadata] = loadDatasetFromMetadata(config);
fprintf('    Total records loaded: %d\n\n', numel(data));

if numel(data) == 0
    error('main_ICNN_MetaPicker:noData', ...
        ['Tidak ada data yang berhasil di-load. Pastikan:\n' ...
         '  1. metadata_master_filled.xlsx ada di: %s\n' ...
         '  2. File CSV ada di: %s\n' ...
         '  3. Jalankan run_qc_and_metadata_build terlebih dahulu.'], ...
        config.metadataPath, config.csvFolder);
end

% Simpan metadata ringkasan
ensureDir(fullfile(config.outputFolder,'qc'));
writetable(metadata, fullfile(config.outputFolder,'qc','metadata_active.csv'));

% ── 3. Split berbasis source_id ASLI STEAD ────────────────────────────────
fprintf('[3] Source-level split (source_id STEAD asli)...\n');
[trainData, valData, testData, splitInfo] = splitBySourceID(data, config);
fprintf('    Split key: %s | Train: %d | Val: %d | Test: %d\n\n', ...
    splitInfo.keyUsed, numel(trainData), numel(valData), numel(testData));

% ── 4. Signal conditioning ────────────────────────────────────────────────
fprintf('[4] Signal conditioning (demean -> detrend -> bandpass -> normalize)...\n');
trainData = applyPreprocessing(trainData, config);
valData   = applyPreprocessing(valData,   config);
testData  = applyPreprocessing(testData,  config);
fprintf('    Enhanced representation: %s (channels: %d)\n\n', ...
    mat2str(config.useEnhancedRepresentation), size(trainData(1).X, 2));

% ── 5. Gaussian labels ────────────────────────────────────────────────────
fprintf('[5] Generating Gaussian labels (sigmaP=%d, sigmaS=%d samples)...\n', ...
    config.gaussianSigmaP, config.gaussianSigmaS);
trainData = addGaussianLabels(trainData, config);
valData   = addGaussianLabels(valData,   config);
testData  = addGaussianLabels(testData,  config);
fprintf('\n');

% ── 6. Augmentation ───────────────────────────────────────────────────────
fprintf('[6] Augmenting training set (factor x%d, training only)...\n', config.augFactor);
if config.useAugmentation
    trainDataAug = augmentTrainingWaveform(trainData, config);
else
    trainDataAug = trainData;
end
fprintf('\n');

% ── 7. OOF stacking + base pickers ────────────────────────────────────────
fprintf('[7] K-fold OOF stacking (K=%d, base pickers: STA/LTA, AIC, CNN, TCN)...\n', config.kFold);
[metaTrFeat, metaTrLbl, baseModels] = ...
    generateOOFPredictions(trainDataAug, config, splitInfo.keyUsed);
metaValFeat  = buildMetaFeatureFromModels(valData,  baseModels, config);
metaValLbl   = {valData.label}';
metaTestFeat = buildMetaFeatureFromModels(testData, baseModels, config);
fprintf('\n');

% ── 8. Train I-CNN meta-learner ───────────────────────────────────────────
fprintf('[8] Training I-CNN meta-learner (level-2, input: %d channels)...\n', ...
    size(metaTrFeat{1}, 2));
[icnnModel, trainInfo] = trainICNNMetaLearner(...
    metaTrFeat, metaTrLbl, metaValFeat, metaValLbl, config);

modelDir = fullfile(config.outputFolder,'models','trained_ICNN_meta_learner');
ensureDir(modelDir);
save(fullfile(modelDir,'model_ICNN_meta.mat'), 'icnnModel','trainInfo','-v7.3');
fprintf('\n');

% ── 9. Prediksi + physics-aware picking ───────────────────────────────────
fprintf('[9] Physics-aware picking on test set...\n');
predTest  = predictICNNMetaLearner(icnnModel, metaTestFeat, config);
picksTest = physicsAwarePicker(predTest, config);
gtTest    = extractGroundTruth(testData);

% ── 10. Evaluasi ──────────────────────────────────────────────────────────
fprintf('[10] Evaluating picking performance...\n');
metricsFull3C = evaluatePickingPerformance(picksTest, gtTest, config);
ensureDir(fullfile(config.outputFolder,'metrics'));
writetable(metricsFull3C, fullfile(config.outputFolder,'metrics','metrics_full3C.csv'));

ensureDir(fullfile(config.outputFolder,'predictions'));
savePredictions(picksTest, gtTest, testData, ...
    fullfile(config.outputFolder,'predictions','predictions_full3C.csv'));

% ── 11. Figures ────────────────────────────────────────────────────────────
fprintf('[11] Generating figures...\n');
figDir = fullfile(config.outputFolder,'figures');
ensureDir(figDir);

errP = [picksTest.p_error_ms]; errS = [picksTest.s_error_ms];
plotErrorHistogram(errP, errS, fullfile(figDir,'error_histogram_full3C.png'));
plotMetaFeatureExample(metaTestFeat{1}, fullfile(figDir,'meta_feature_example.png'));

nPlot = min(3, numel(testData));
for i = 1:nPlot
    plotPickingResult(testData(i).waveform, testData(i).sec, ...
        testData(i).label, predTest{i}, picksTest(i), ...
        fullfile(figDir, sprintf('picking_example_%03d.png', i)));
end
fprintf('\n');

fprintf('╔══════════════════════════════════════════════════════════╗\n');
fprintf('║  Pipeline complete (Full 3C mode).                        ║\n');
fprintf('║  >> run_experiment_Zonly_STEAD   (simulasi PiGraf)        ║\n');
fprintf('║  >> run_ablation_study           (8 kondisi)              ║\n');
fprintf('╚══════════════════════════════════════════════════════════╝\n');

% =========================================================================
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

function savePredictions(picks,gt,data,outPath)
N=numel(picks); snrs=nan(N,1);
for i=1:N; if isfield(data,'SNR'); snrs(i)=data(i).SNR; end; end
T=table({gt.file_name}',{gt.event_id}',{gt.source_id}', ...
    [picks.p_pick_sec]',[picks.s_pick_sec]', ...
    [gt.p_arrival_sec]',[gt.s_arrival_sec]', ...
    [picks.p_error_ms]',[picks.s_error_ms]', ...
    {picks.p_status}',{picks.s_status}',snrs, ...
    'VariableNames',{'file_name','event_id','source_id','p_pred_sec','s_pred_sec', ...
        'p_true_sec','s_true_sec','p_error_ms','s_error_ms','p_status','s_status','SNR'});
ensureDir(fileparts(outPath));
writetable(T, outPath);
end

function ensureDir(d)
if ~isempty(d) && ~isfolder(d); mkdir(d); end
end
