% =========================================================================
% run_metalearner_ablations.m
% =========================================================================
% PURPOSE:
%   Run the remaining meta-learner ablation variants requested for the
%   Computers & Geosciences submission, reusing the cached OOF tensors
%   produced by run_export_oof_meta_features.m. The base pickers are NOT
%   refitted here: every variant consumes the same leakage-free meta-
%   feature tensors, so differences between variants are attributable to
%   the meta-learner alone.
%
% VARIANTS:
%   A. probonly_12ch   I-CNN trained on the 12 base-picker probability
%                      channels only (waveform context removed). Tests
%                      whether the conditioned E/N/Z channels contribute.
%   B. waveonly_3ch    I-CNN trained on the 3 conditioned waveform
%                      channels only (all base-picker outputs removed).
%                      Tests whether the meta-learner genuinely fuses
%                      base-picker information rather than re-learning to
%                      pick directly from the waveform.
%   C. nodilation      Same 15 channels and same kernel width as the
%                      proposed model, but with all dilation factors set
%                      to 1 (receptive field 21 instead of 33 samples).
%                      This is the single-scale CNN meta-learner control.
%   D. logistic        Linear (logistic-regression) stacker, via the
%                      existing src/benchmark/runLogisticMetaLearner.m.
%   E. weighted_ens_INSAMPLE
%                      Performance-weighted ensemble via the existing
%                      src/benchmark/runWeightedEnsemble.m. DIAGNOSTIC
%                      ONLY: that function fits the weights on the same
%                      set it evaluates, so the result is optimistically
%                      biased. The publishable weighted-ensemble result
%                      is the one already in Supplementary Table S6.
%
%   NOTE ON VARIANT E: src/benchmark/runMetaLearnerBenchmarkFromOOF.m
%   currently contains the line "picks2=picks1;", which makes its
%   "Weighted Mean" row an exact copy of the unweighted mean ensemble.
%   That is why those two rows are byte-identical in
%   results/benchmark/benchmark_summary_final.csv. This script invokes
%   runWeightedEnsemble properly instead; the stub in the older
%   orchestrator should be fixed or that row disregarded.
%
% SCORING:
%   F1 is computed with src/f1_audit/evaluateConventionalEventF1.m -- the
%   same conventional TP/FP/FN definition used for Table 4 and
%   Supplementary Table S2 -- so the numbers are directly comparable to
%   the headline results. Records with status 'uncertain' are counted as
%   detected, matching config.f1Audit.countUncertainAsDetected = true.
%
% OUTPUT:
%   results/predictions/predictions_ablation_<variant>.csv
%   results/ablation_metalearner/ablation_metalearner_f1.csv
%       (one row per variant x phase x tolerance: TP, FP, FN, Precision,
%        Recall, F1, MAE_ms, MedAE_ms, DetectionRate)
% =========================================================================

clear; clc;
addpath(genpath('src'));
addpath('config');

config = config_ICNN_MetaPicker();
rng(config.randomSeed, 'twister');

TOL_MS = [50 100 200];
countUncertain = true;
if isfield(config, 'f1Audit') && isfield(config.f1Audit, 'countUncertainAsDetected')
    countUncertain = config.f1Audit.countUncertainAsDetected;
end

fprintf('\n========================================================\n');
fprintf('  Meta-learner ablation variants\n');
fprintf('========================================================\n\n');

% --- Load cached OOF tensors -------------------------------------------
predDir   = fullfile(config.outputFolder, 'predictions');
cachePath = fullfile(predDir, 'oof_meta_features.mat');
assert(isfile(cachePath), ...
    ['OOF cache not found:\n  %s\n' ...
     'Run run_export_oof_meta_features.m first.'], cachePath);

fprintf('[Cache] Loading %s\n', cachePath);
S = load(cachePath);
metaTrFeat   = S.metaTrFeat;
metaTrLbl    = S.metaTrLbl;
metaValFeat  = S.metaValFeat;
metaValLbl   = S.metaValLbl;
metaTestFeat = S.metaTestFeat;
fprintf('        Train: %d | Val: %d | Test: %d | Channels: %d\n\n', ...
    numel(metaTrFeat), numel(metaValFeat), numel(metaTestFeat), ...
    size(metaTrFeat{1}, 2));

% --- Rebuild val/test record structs (same seed => same split) ---------
fprintf('[Data] Reloading records to recover test-set ground truth...\n');
[data, ~] = loadDatasetFromMetadata(config);
[~, valData, testData, ~] = splitBySourceID(data, config);
valData  = addGaussianLabels(applyPreprocessing(valData,  config), config);
testData = addGaussianLabels(applyPreprocessing(testData, config), config);
gtTest   = extractGroundTruth(testData);
N_test   = numel(testData);

assert(N_test == numel(metaTestFeat), ...
    ['Test-set size mismatch (%d records vs %d cached tensors). ' ...
     'The cache was produced with a different split or seed.'], ...
    N_test, numel(metaTestFeat));

outDirAbl = fullfile(config.outputFolder, 'ablation_metalearner');
ensureDir(predDir); ensureDir(outDirAbl);

f1Rows = {};

% =======================================================================
% Variants A-C: retrain the I-CNN meta-learner on modified inputs
% =======================================================================
variants = { ...
    'probonly_12ch', 1:12,  [],      'Probability channels only (no waveform context)'; ...
    'waveonly_3ch',  13:15, [],      'Conditioned waveform channels only (no base pickers)'; ...
    'nodilation',    1:15,  [1 1 1], 'All 15 channels, dilation factors forced to 1'};

for v = 1:size(variants, 1)
    name    = variants{v, 1};
    chanIdx = variants{v, 2};
    dilOvr  = variants{v, 3};
    descr   = variants{v, 4};

    fprintf('\n--------------------------------------------------------\n');
    fprintf('[Variant %s] %s\n', name, descr);
    fprintf('--------------------------------------------------------\n');

    cfgV = config;
    if ~isempty(dilOvr)
        cfgV.icnn.dilations = dilOvr;
        fprintf('  dilations overridden -> [%s]\n', num2str(dilOvr));
    end
    % Keep the flag consistent with the channels actually present
    cfgV.icnn.includeWaveformContext = any(ismember(13:15, chanIdx));

    trF = sliceChannels(metaTrFeat,   chanIdx);
    vaF = sliceChannels(metaValFeat,  chanIdx);
    teF = sliceChannels(metaTestFeat, chanIdx);
    fprintf('  input channels: %d\n', size(trF{1}, 2));

    rng(config.randomSeed, 'twister');   % identical initialization per variant
    [modelV, ~] = trainICNNMetaLearner(trF, metaTrLbl, vaF, metaValLbl, cfgV);

    predV  = predictICNNMetaLearner(modelV, teF, cfgV);
    picksV = physicsAwarePicker(predV, cfgV);
    picksV = fillPickErrors(picksV, gtTest);

    f1Rows = finalizeVariant(name, descr, picksV, gtTest, testData, ...
        predDir, TOL_MS, N_test, countUncertain, f1Rows);
end

% =======================================================================
% Variant D: logistic-regression stacker (existing implementation)
% =======================================================================
fprintf('\n--------------------------------------------------------\n');
fprintf('[Variant logistic] Linear logistic-regression stacker\n');
fprintf('--------------------------------------------------------\n');
try
    [picksLR, ~] = runLogisticMetaLearner(metaTrFeat, metaTrLbl, metaTestFeat, config);
    picksLR = fillPickErrors(picksLR, gtTest);
    f1Rows = finalizeVariant('logistic', ...
        'Logistic-regression stacker (per-timestep, ridge lambda=0.01)', ...
        picksLR, gtTest, testData, predDir, TOL_MS, N_test, countUncertain, f1Rows);
catch ME
    fprintf('  [SKIP] logistic stacker failed: %s\n', ME.message);
end

% =======================================================================
% Variant E: performance-weighted ensemble (properly invoked)
% =======================================================================
fprintf('\n--------------------------------------------------------\n');
fprintf('[Variant weighted_ens] Performance-weighted base-picker ensemble\n');
fprintf('--------------------------------------------------------\n');
% WARNING -- IN-SAMPLE WEIGHTS:
% runWeightedEnsemble searches for the picker weights using the very set
% it is asked to pick on, and it does not expose the fitted weights. Run
% on the test tensor it therefore reports an optimistically biased,
% in-sample number that MUST NOT be quoted as a clean held-out benchmark.
% It is produced here only as a diagnostic upper bound, and is labelled
% as such in the output.
%
% For the publishable weighted-ensemble figure, use the out-of-sample
% version already reported in Supplementary Table S6, whose weights are
% derived from each base picker's own standalone F1 rather than fitted on
% the evaluation set. To make this variant publishable, refactor
% runWeightedEnsemble into a fit step and an apply step so weights can be
% fitted on validation and applied to test.
fprintf(['  NOTE: weights are fitted in-sample; treat as a diagnostic\n' ...
         '        upper bound, not a held-out benchmark.\n']);
try
    picksWE = runWeightedEnsemble(metaTestFeat, testData, config);
    picksWE = fillPickErrors(picksWE, gtTest);
    f1Rows = finalizeVariant('weighted_ens_INSAMPLE', ...
        ['DIAGNOSTIC ONLY - weighted ensemble with weights fitted on the ' ...
         'test set (optimistically biased; do not report as held-out)'], ...
        picksWE, gtTest, testData, predDir, TOL_MS, N_test, countUncertain, f1Rows);
catch ME
    fprintf('  [SKIP] weighted ensemble failed: %s\n', ME.message);
end

% =======================================================================
% Summary
% =======================================================================
if ~isempty(f1Rows)
    f1Tbl = vertcat(f1Rows{:});
    f1Path = fullfile(outDirAbl, 'ablation_metalearner_f1.csv');
    writetable(f1Tbl, f1Path);
    fprintf('\n[Done] Conventional-F1 summary written to:\n  %s\n\n', f1Path);
    disp(f1Tbl(f1Tbl.Tolerance_ms == 100, :));
else
    fprintf('\n[Warn] No variant completed successfully.\n');
end

% =======================================================================
% Helpers
% =======================================================================
function out = sliceChannels(featCell, chanIdx)
% Slice a subset of channels from every [T x C_meta] tensor in a cell array.
out = cell(size(featCell));
for i = 1:numel(featCell)
    Z = featCell{i};
    assert(max(chanIdx) <= size(Z, 2), ...
        'Requested channel %d exceeds tensor width %d.', max(chanIdx), size(Z, 2));
    out{i} = Z(:, chanIdx);
end
end

function f1Rows = finalizeVariant(name, descr, picks, gt, dataStruct, ...
    predDir, TOL_MS, N_test, countUncertain, f1Rows)
% Write the per-variant prediction CSV and append conventional-F1 rows.
predPath = fullfile(predDir, sprintf('predictions_ablation_%s.csv', name));
savePredictions(picks, gt, dataStruct, predPath);
fprintf('  predictions -> %s\n', predPath);

for phase = {'P', 'S'}
    ph = phase{1};
    if strcmp(ph, 'P')
        errV  = [picks.p_error_ms]';
        predV = [picks.p_pick_sec]';
        statV = {picks.p_status}';
    else
        errV  = [picks.s_error_ms]';
        predV = [picks.s_pick_sec]';
        statV = {picks.s_status}';
    end

    det = ~(strcmpi(statV, 'not_detected') | isnan(predV) | isinf(predV));
    if countUncertain
        det = det | strcmpi(statV, 'uncertain');
    end

    for tol = TOL_MS
        r = evaluateConventionalEventF1(errV, det, N_test, tol);
        row = table();
        row.Variant       = {name};
        row.Description   = {descr};
        row.Phase         = {ph};
        row.Tolerance_ms  = tol;
        row.N_total       = N_test;
        row.N_detected    = sum(det);
        row.TP            = r.TP;
        row.FP            = r.FP;
        row.FN            = r.FN;
        row.Precision     = r.Precision;
        row.Recall        = r.Recall;
        row.F1            = r.F1;
        row.MAE_ms        = r.MAE_ms;
        row.MedAE_ms      = r.MedAE_ms;
        row.DetectionRate = sum(det) / N_test;
        f1Rows{end+1} = row; %#ok<AGROW>

        if tol == 100
            fprintf('  [%s] F1@100ms=%.4f  MAE=%.1f ms  MedAE=%.1f ms  DetRate=%.3f\n', ...
                ph, r.F1, r.MAE_ms, r.MedAE_ms, sum(det) / N_test);
        end
    end
end
end

% --- Local copies of the helpers defined inside run_experiment_full3C_STEAD.m
%     (they are script-local there, so they are not on the MATLAB path)

function picks = fillPickErrors(picks, gt)
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
