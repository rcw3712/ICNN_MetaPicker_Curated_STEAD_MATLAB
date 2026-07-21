% =========================================================================
% generateAllFigures.m
% =========================================================================
% PURPOSE:
%   Generate semua figure publikasi setelah run_experiment_full3C_STEAD
%   dan run_experiment_Zonly_STEAD selesai dijalankan.
%   Semua figure disimpan di results/figures/ dengan resolusi 300 DPI.
%
% PENGGUNAAN:
%   >> run_experiment_full3C_STEAD   % tunggu selesai dulu
%   >> run_experiment_Zonly_STEAD    % opsional
%   >> generateAllFigures            % jalankan ini
%
% OUTPUT (di results/figures/):
%   fig02_dataset_statistics.png
%   fig03_picking_examples.png        (3 contoh: low/medium/high SNR)
%   fig04_gaussian_label_example.png
%   fig05_meta_feature_tensor.png
%   fig06_error_distribution.png
%   fig07_ablation_results.png
%   fig08_snr_performance.png
%   fig09_full3C_vs_Zonly.png
%   fig10_arrival_scatter_P.png
%   fig10_arrival_scatter_S.png
%   fig11_training_curves.png
%   fig12_residual_vs_attributes.png
% =========================================================================

clc;
rootDir = fileparts(mfilename('fullpath'));
addpath(genpath(rootDir));

config  = config_ICNN_MetaPicker();
figDir  = fullfile(config.outputFolder, 'figures');
metDir  = fullfile(config.outputFolder, 'metrics');
predDir = fullfile(config.outputFolder, 'predictions');
modDir  = fullfile(config.outputFolder, 'models');
ensureDir(figDir);

fprintf('╔══════════════════════════════════════════════════════════╗\n');
fprintf('║  generateAllFigures — Computers & Geosciences Q1         ║\n');
fprintf('╚══════════════════════════════════════════════════════════╝\n\n');

% ── Load dataset (untuk Fig 2, 4, 12) ────────────────────────────────────
fprintf('[Load] Loading dataset for figure generation...\n');
[data, ~] = loadDatasetFromMetadata(config);
fprintf('  %d records loaded.\n\n', numel(data));

% ── Load predictions (untuk Fig 6, 10, 12) ───────────────────────────────
predPath = fullfile(predDir, 'predictions_full3C.csv');
hasPred  = isfile(predPath);
if hasPred
    predTable = readtable(predPath, 'VariableNamingRule','preserve');
    errP = predTable.p_error_ms;
    errS = predTable.s_error_ms;
    fprintf('[Load] Predictions loaded: %d records.\n\n', height(predTable));
else
    fprintf('[WARNING] predictions_full3C.csv not found. Run run_experiment_full3C_STEAD first.\n\n');
    errP = []; errS = [];
end

% ── Load ablation results (untuk Fig 7) ──────────────────────────────────
ablPath = fullfile(metDir, 'ablation_results.csv');
if isfile(ablPath)
    ablTable = readtable(ablPath, 'VariableNamingRule','preserve');
else
    ablTable = [];
    fprintf('[INFO] ablation_results.csv not found. Fig7 will be skipped.\n');
end

% ── Load metrics untuk Full3C vs Z-only (Fig 9) ───────────────────────────
full3CMetPath = fullfile(metDir, 'metrics_full3C.csv');
zonlyMetPath  = fullfile(metDir, 'metrics_Zonly.csv');

% ── FIG 2: Dataset Statistics ─────────────────────────────────────────────
fprintf('[Fig 02] Dataset statistics...\n');
plotDatasetStatistics(data, fullfile(figDir,'fig02_dataset_statistics.png'));

% ── FIG 3: Picking Examples (low/medium/high SNR) ─────────────────────────
fprintf('[Fig 03] Picking examples...\n');
if hasPred
    snrs = [data.SNR];
    snrBins = [prctile(snrs,15), prctile(snrs,50), prctile(snrs,85)];
    labels = {'low_snr','medium_snr','high_snr'};

    icnnPath = fullfile(modDir,'trained_ICNN_meta_learner','model_ICNN_meta.mat');
    basePath = fullfile(modDir,'trained_base_models','base_models_final.mat');

    if isfile(icnnPath) && isfile(basePath)
        % ── Load I-CNN model ──────────────────────────────────────────────
        S1 = load(icnnPath);
        flds1 = fieldnames(S1);
        % Coba nama variabel yang mungkin: icnnModel, icnnC5, model_ICNN_meta
        icnnCandidates = {'icnnModel','icnnC5','model_ICNN_meta','net','model'};
        icnnModel = [];
        for k = 1:numel(icnnCandidates)
            if isfield(S1, icnnCandidates{k})
                icnnModel = S1.(icnnCandidates{k}); break;
            end
        end
        if isempty(icnnModel) && ~isempty(flds1)
            icnnModel = S1.(flds1{1});   % ambil variabel pertama
        end

        % ── Load base models ──────────────────────────────────────────────
        S2 = load(basePath);
        flds2 = fieldnames(S2);
        % Coba nama variabel yang mungkin: baseModels, baseModelsFinal
        baseCandidates = {'baseModels','baseModelsFinal','base_models','models'};
        baseModels = [];
        for k = 1:numel(baseCandidates)
            if isfield(S2, baseCandidates{k})
                baseModels = S2.(baseCandidates{k}); break;
            end
        end
        if isempty(baseModels) && ~isempty(flds2)
            baseModels = S2.(flds2{1});   % ambil variabel pertama
        end

        if ~isempty(icnnModel) && ~isempty(baseModels)
            % Ambil 3 record yang SNR-nya dekat dengan ketiga persentil
            pickIndices = zeros(1,3);
            for bi = 1:3
                [~, idx] = min(abs(snrs - snrBins(bi)));
                pickIndices(bi) = idx;
            end

            for bi = 1:3
                try
                    idx  = pickIndices(bi);
                    rec  = applyPreprocessing(data(idx), config);
                    rec  = addGaussianLabels(rec, config);
                    mf   = buildMetaFeatureFromModels(rec, baseModels, config);
                    pred = predictICNNMetaLearner(icnnModel, mf, config);
                    picks_i = physicsAwarePicker(pred, config);
                    picks_i(1).p_error_ms = (picks_i(1).p_pick_sec - rec.p_arrival_sec)*1000;
                    picks_i(1).s_error_ms = (picks_i(1).s_pick_sec - rec.s_arrival_sec)*1000;
                    outF = fullfile(figDir, sprintf('fig03_picking_%s.png', labels{bi}));
                    plotPickingResult(rec.waveform, rec.sec, rec.label, pred{1}, picks_i(1), outF);
                catch ME
                    fprintf('  [Fig 03] Skip example %d: %s\n', bi, ME.message);
                end
            end
        else
            fprintf('  [Skip] Could not load model variables from MAT files.\n');
        end
    else
        fprintf('  [Skip] Trained models not found. Run experiment first.\n');
    end
else
    fprintf('  [Skip] No predictions available.\n');
end

% ── FIG 4: Gaussian Label Example ─────────────────────────────────────────
fprintf('[Fig 04] Gaussian label example...\n');
rec4 = applyPreprocessing(data(1), config);
rec4 = addGaussianLabels(rec4, config);
plotGaussianLabelExample(rec4, fullfile(figDir,'fig04_gaussian_label.png'));

% ── FIG 5: Meta-Feature Tensor ────────────────────────────────────────────
fprintf('[Fig 05] Meta-feature tensor example...\n');
basePath = fullfile(modDir,'trained_base_models','base_models_final.mat');
if isfile(basePath)
    S2 = load(basePath);
    flds = fieldnames(S2);
    baseCandidates = {'baseModels','baseModelsFinal','base_models','models'};
    baseModels5 = [];
    for k = 1:numel(baseCandidates)
        if isfield(S2, baseCandidates{k})
            baseModels5 = S2.(baseCandidates{k}); break;
        end
    end
    if isempty(baseModels5) && ~isempty(flds)
        baseModels5 = S2.(flds{1});
    end
    if ~isempty(baseModels5)
        try
            rec5 = applyPreprocessing(data(1), config);
            mf5  = buildMetaFeatureFromModels(rec5, baseModels5, config);
            plotMetaFeatureExample(mf5{1}, fullfile(figDir,'fig05_meta_feature_tensor.png'));
        catch ME
            fprintf('  [Skip] Fig05 error: %s\n', ME.message);
        end
    else
        fprintf('  [Skip] base_models_final.mat variable not found.\n');
    end
else
    fprintf('  [Skip] base_models_final.mat not found.\n');
end

% ── FIG 6: Error Distribution ──────────────────────────────────────────────
fprintf('[Fig 06] Error distribution...\n');
if ~isempty(errP)
    plotErrorHistogram(errP, errS, fullfile(figDir,'fig06_error_distribution.png'));
else
    fprintf('  [Skip] No predictions available.\n');
end

% ── FIG 7: Ablation Results ────────────────────────────────────────────────
fprintf('[Fig 07] Ablation results...\n');
if ~isempty(ablTable)
    plotAblationResults(ablTable, fullfile(figDir,'fig07_ablation_results.png'));
else
    fprintf('  [Skip] Run run_ablation_study first.\n');
end

% ── FIG 8: SNR Performance ────────────────────────────────────────────────
fprintf('[Fig 08] SNR stratified performance...\n');
snrMetPath = fullfile(metDir,'metrics_SNR_stratified.csv');
if isfile(snrMetPath)
    snrMet = readtable(snrMetPath,'VariableNamingRule','preserve');
    plotSNRPerformance(snrMet, fullfile(figDir,'fig08_snr_performance.png'));
else
    fprintf('  [Skip] metrics_SNR_stratified.csv not found.\n');
end

% ── FIG 9: Full3C vs Z-only ────────────────────────────────────────────────
fprintf('[Fig 09] Full3C vs Z-only comparison...\n');
if isfile(full3CMetPath) && isfile(zonlyMetPath)
    m3C = readtable(full3CMetPath,'VariableNamingRule','preserve');
    mZo = readtable(zonlyMetPath,'VariableNamingRule','preserve');
    m3C.Condition = repmat({'I-CNN+physics (Full3C)'},height(m3C),1);
    mZo.Condition = repmat({'I-CNN+physics (Zonly)'}, height(mZo),1);
    combined = [m3C; mZo];
    plotFull3CvsZonly(combined, fullfile(figDir,'fig09_full3C_vs_Zonly.png'));
else
    fprintf('  [Skip] Run both experiments first.\n');
end

% ── FIG 10: Arrival Scatter ────────────────────────────────────────────────
fprintf('[Fig 10] Arrival scatter plots...\n');
if hasPred
    pPred = predTable.p_pred_sec;
    sTrue = predTable.s_true_sec;
    pTrue = predTable.p_true_sec;
    sPred = predTable.s_pred_sec;
    snrV  = predTable.SNR;

    plotArrivalScatter(pPred, pTrue, snrV, 'P', ...
        fullfile(figDir,'fig10_arrival_scatter_P.png'));
    plotArrivalScatter(sPred, sTrue, snrV, 'S', ...
        fullfile(figDir,'fig10_arrival_scatter_S.png'));
else
    fprintf('  [Skip] No predictions available.\n');
end

% ── FIG 11: Training Curves ────────────────────────────────────────────────
fprintf('[Fig 11] Training curves...\n');
icnnPath = fullfile(modDir,'trained_ICNN_meta_learner','model_ICNN_meta.mat');
if isfile(icnnPath)
    S11 = load(icnnPath);
    % Cari icnnModel dan trainHistory
    icnnCandidates = {'icnnModel','icnnC5','model_ICNN_meta','net','model'};
    mdl11 = [];
    for k = 1:numel(icnnCandidates)
        if isfield(S11, icnnCandidates{k}); mdl11 = S11.(icnnCandidates{k}); break; end
    end
    if isempty(mdl11) && ~isempty(fieldnames(S11))
        flds11 = fieldnames(S11); mdl11 = S11.(flds11{1});
    end

    ti_icnn = struct();
    try
        if isstruct(mdl11) && isfield(mdl11,'trainHistory')
            % Format baru: trainHistory tersimpan di dalam model struct
            ti_icnn = mdl11.trainHistory;
        elseif isfield(S11,'trainInfo')
            ti_icnn = S11.trainInfo;
        end
    catch; end

    try
        plotTrainingCurves(struct(), struct(), ti_icnn, ...
            fullfile(figDir,'fig11_training_curves.png'));
    catch ME
        fprintf('  [Skip] Fig11 error: %s\n', ME.message);
    end
else
    fprintf('  [Skip] model_ICNN_meta.mat not found.\n');
end

% ── FIG 12: Residual vs Attributes ────────────────────────────────────────
fprintf('[Fig 12] Residual vs geophysical attributes...\n');
if hasPred
    N = height(predTable);

    % Buat struct picks dan gt dari predictions CSV
    picksFig12 = struct( ...
        'p_pick_sec', num2cell(predTable.p_pred_sec), ...
        's_pick_sec', num2cell(predTable.s_pred_sec), ...
        'p_error_ms', num2cell(predTable.p_error_ms), ...
        's_error_ms', num2cell(predTable.s_error_ms));
    gtFig12 = struct( ...
        'p_arrival_sec', num2cell(predTable.p_true_sec), ...
        's_arrival_sec', num2cell(predTable.s_true_sec));

    % Gabungkan atribut geofisika dari dataset yang sudah dimuat (data)
    % Gunakan event_id / source_id untuk matching
    dataFig12 = repmat(struct( ...
        'source_distance_km', NaN, 'source_magnitude', NaN, 'SNR', NaN), N, 1);

    % Buat lookup dari event_id ke index di data
    allEventIds = {data.event_id};
    predEventIds = predTable.event_id;
    if ~iscell(predEventIds); predEventIds = cellstr(string(predEventIds)); end

    for i = 1:N
        eid = predEventIds{i};
        idx = find(strcmp(allEventIds, eid), 1);
        if ~isempty(idx)
            if isfield(data,'source_distance_km') && ~isnan(data(idx).source_distance_km)
                dataFig12(i).source_distance_km = data(idx).source_distance_km;
            end
            if isfield(data,'source_magnitude') && ~isnan(data(idx).source_magnitude)
                dataFig12(i).source_magnitude = data(idx).source_magnitude;
            end
            if isfield(data,'SNR') && ~isnan(data(idx).SNR)
                dataFig12(i).SNR = data(idx).SNR;
            end
        end
    end

    % Cek berapa record yang berhasil di-link
    nLinked = sum(~isnan([dataFig12.source_distance_km]));
    fprintf('  Linked %d/%d records to geophysical attributes.\n', nLinked, N);

    plotResidualVsAttribute(picksFig12, gtFig12, dataFig12, ...
        fullfile(figDir,'fig12_residual_vs_attributes.png'));
else
    fprintf('  [Skip] No predictions available.\n');
end

% ── Summary ───────────────────────────────────────────────────────────────
figFiles = dir(fullfile(figDir,'fig*.png'));
fprintf('\n╔══════════════════════════════════════════════════════════╗\n');
fprintf('║  Figure generation complete.                              ║\n');
fprintf('║  %2d figure(s) saved to: %-32s ║\n', numel(figFiles), figDir);
fprintf('╚══════════════════════════════════════════════════════════╝\n\n');

for f = 1:numel(figFiles)
    fprintf('  ✓  %s\n', figFiles(f).name);
end

function ensureDir(d)
if ~isempty(d) && ~isfolder(d); mkdir(d); end
end
