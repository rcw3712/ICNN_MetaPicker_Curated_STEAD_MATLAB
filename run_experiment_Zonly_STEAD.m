% =========================================================================
% run_experiment_Zonly_STEAD.m
% =========================================================================
% PURPOSE:
%   Run the Z-only experiment on the curated STEAD CSV dataset, simulating
%   the current PiGraf field acquisition limitation where only the
%   vertical (Z) component is recorded reliably.
%
% INPUT:
%   (none — uses config/config_ICNN_MetaPicker.m)
%
% OUTPUT:
%   results/metrics/metrics_Zonly.csv
%   results/predictions/predictions_Zonly.csv
%
% NOTES:
%   *** Z-only mode simulates the current limitation of PiGraf field
%   data. *** PiGraf data themselves are NOT used for quantitative
%   validation at this stage — this experiment uses the curated STEAD CSV
%   dataset with the E and N channels zeroed out, i.e., X = [0, 0, Z], to
%   characterise how the framework's performance degrades under the
%   single-channel constraint that currently affects PiGraf acquisition.
%
%   *** PiGraf is referenced only as a future deployment target ***, to
%   be quantitatively validated once 3-component (E, N, Z) acquisition is
%   restored at the field site. No PiGraf waveform data are loaded or
%   evaluated anywhere in this script.
%
%   Compare metrics_Zonly.csv against metrics_full3C.csv to quantify the
%   performance gap attributable to losing the horizontal components.
% =========================================================================

clc; clear; close all;
rootDir = fileparts(mfilename('fullpath'));
addpath(genpath(rootDir));

fprintf('=== run_experiment_Zonly_STEAD ===\n');
fprintf('NOTE: This experiment simulates PiGraf single-channel limitation\n');
fprintf('using curated STEAD CSV data. No PiGraf field data are used.\n\n');

config = config_ICNN_MetaPicker();
config.experimentMode = 'Zonly';
rng(config.randomSeed, 'twister');

% ── Load ───────────────────────────────────────────────────────────────────
[data, metadata] = loadDatasetFromMetadata(config);
dataClean = data;  % QC sudah dilakukan di metadata_master_filled.xlsx
ensureDir(fullfile(config.outputFolder,'qc'));

% ── Leakage-free split ─────────────────────────────────────────────────────
[trainData, valData, testData, splitInfo] = splitBySourceID(dataClean, config);
fprintf('Split key: %s | Train: %d | Val: %d | Test: %d\n', ...
    splitInfo.keyUsed, numel(trainData), numel(valData), numel(testData));

% ── Zero out E and N channels — KEY DIFFERENCE FROM FULL3C ───────────────
fprintf('Zeroing out E and N channels (Z-only simulation)...\n');
trainData = zeroHorizontalChannels(trainData, config);
valData   = zeroHorizontalChannels(valData,   config);
testData  = zeroHorizontalChannels(testData,  config);

% ── Conditioning + labels ─────────────────────────────────────────────────
trainData = addGaussianLabels(applyPreprocessing(trainData, config), config);
valData   = addGaussianLabels(applyPreprocessing(valData,   config), config);
testData  = addGaussianLabels(applyPreprocessing(testData,  config), config);

% ── Augmentation (training only) ──────────────────────────────────────────
if config.useAugmentation
    trainDataAug = augmentTrainingWaveform(trainData, config);
else
    trainDataAug = trainData;
end

% ── OOF stacking + base pickers ───────────────────────────────────────────
% Base pickers automatically fall back to Z-only S-detection logic — see
% "Z-only fallback" branches in runSTALTAPicker.m / runAICPicker.m.
[metaTrFeat, metaTrLbl, baseModels] = generateOOFPredictions(trainDataAug, config, splitInfo.keyUsed);
metaValFeat  = buildMetaFeatureFromModels(valData, baseModels, config);
metaValLbl   = cellfun(@(d) d, {valData.label}, 'UniformOutput', false)';
metaTestFeat = buildMetaFeatureFromModels(testData, baseModels, config);

% ── Train I-CNN meta-learner (Z-only mode) ────────────────────────────────
[icnnModel, trainInfo] = trainICNNMetaLearner(metaTrFeat, metaTrLbl, metaValFeat, metaValLbl, config);

modelDir = fullfile(config.outputFolder,'models','trained_ICNN_meta_learner');
ensureDir(modelDir);
save(fullfile(modelDir,'model_ICNN_meta_Zonly.mat'), 'icnnModel','trainInfo','-v7.3');

% ── Predict + physics-aware pick ──────────────────────────────────────────
predTest  = predictICNNMetaLearner(icnnModel, metaTestFeat, config);
picksTest = physicsAwarePicker(predTest, config);
gtTest    = extractGroundTruth(testData);

% Isi p_error_ms dan s_error_ms ke dalam picks
picksTest = fillPickErrors(picksTest, gtTest);

% ── Evaluate ──────────────────────────────────────────────────────────────
metricsZonly = evaluatePickingPerformance(picksTest, gtTest, config);
metricsDir = fullfile(config.outputFolder,'metrics');
ensureDir(metricsDir);
writetable(metricsZonly, fullfile(metricsDir,'metrics_Zonly.csv'));

predDir = fullfile(config.outputFolder,'predictions');
ensureDir(predDir);
savePredictions(picksTest, gtTest, testData, fullfile(predDir,'predictions_Zonly.csv'));

fprintf('\n[Results] Z-only (PiGraf simulation, curated STEAD CSV):\n');
for r = 1:height(metricsZonly)
    fprintf('  [%s] MAE=%.1f ms  F1@100ms=%.3f  DetRate=%.2f\n', ...
        metricsZonly.Component{r}, metricsZonly.MAE_ms(r), ...
        metricsZonly.F1_100ms(r), metricsZonly.DetectionRate(r));
end

% ── Compare against Full3C if available ───────────────────────────────────
full3CPath = fullfile(config.outputFolder,'metrics','metrics_full3C.csv');
if isfile(full3CPath)
    metricsFull3C = readtable(full3CPath);
    fprintf('\n[Comparison] Full3C vs Z-only (S-wave F1@100ms degradation):\n');
    rF = metricsFull3C(strcmp(metricsFull3C.Component,'S'),:);
    rZ = metricsZonly(strcmp(metricsZonly.Component,'S'),:);
    if ~isempty(rF) && ~isempty(rZ)
        fprintf('  Full3C: %.3f  |  Z-only: %.3f  |  Drop: %.3f (%.1f%%)\n', ...
            rF.F1_100ms, rZ.F1_100ms, rF.F1_100ms-rZ.F1_100ms, ...
            100*(rF.F1_100ms-rZ.F1_100ms)/max(rF.F1_100ms,1e-6));
    end

    % Build comparison table and figure
    combined = [metricsFull3C; metricsZonly];
    combined.Condition = [repmat({'Full3C'},height(metricsFull3C),1); ...
                           repmat({'Zonly'}, height(metricsZonly),1)];
    figDir = fullfile(config.outputFolder,'figures');
    ensureDir(figDir);
    plotFull3CvsZonly(combined, fullfile(figDir,'full3C_vs_Zonly.png'));
else
    fprintf('\n  (Run run_experiment_full3C_STEAD.m for Full3C vs Z-only comparison.)\n');
end

% ── Helpers ───────────────────────────────────────────────────────────────
function picks = fillPickErrors(picks, gt)
for i = 1:numel(picks)
    if ~isnan(picks(i).p_pick_sec) && ~isnan(gt(i).p_arrival_sec)
        picks(i).p_error_ms = (picks(i).p_pick_sec - gt(i).p_arrival_sec) * 1000;
    else; picks(i).p_error_ms = NaN; end
    if ~isnan(picks(i).s_pick_sec) && ~isnan(gt(i).s_arrival_sec)
        picks(i).s_error_ms = (picks(i).s_pick_sec - gt(i).s_arrival_sec) * 1000;
    else; picks(i).s_error_ms = NaN; end
end
end
function data = zeroHorizontalChannels(data, config)
eIdx = find(strcmp(config.channelOrder, 'E'), 1);
nIdx = find(strcmp(config.channelOrder, 'N'), 1);
for i = 1:numel(data)
    if ~isempty(eIdx); data(i).waveform(:,eIdx) = 0; end
    if ~isempty(nIdx); data(i).waveform(:,nIdx) = 0; end
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
function savePredictions(picks,gt,data,outPath)
N=numel(picks); snrs=nan(N,1);
for i=1:N; if isfield(data,'SNR'); snrs(i)=data(i).SNR; end; end
T=table({gt.file_name}',{gt.event_id}',{gt.source_id}', ...
    [picks.p_pick_sec]',[picks.s_pick_sec]',[gt.p_arrival_sec]',[gt.s_arrival_sec]', ...
    [picks.p_error_ms]',[picks.s_error_ms]',{picks.p_status}',{picks.s_status}',snrs, ...
    'VariableNames',{'file_name','event_id','source_id','p_pred_sec','s_pred_sec', ...
        'p_true_sec','s_true_sec','p_error_ms','s_error_ms','p_status','s_status','SNR'});
ensureDir(fileparts(outPath));
writetable(T, outPath);
end
function ensureDir(d); if ~isempty(d)&&~isfolder(d); mkdir(d); end; end
