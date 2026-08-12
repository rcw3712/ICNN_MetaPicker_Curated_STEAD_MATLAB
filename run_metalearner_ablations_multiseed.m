% =========================================================================
% run_metalearner_ablations_multiseed.m
% =========================================================================
% PURPOSE:
%   Repeat every meta-learner variant across several random seeds so the
%   ablation differences can be reported as mean +/- standard deviation
%   instead of single-run point estimates.
%
% WHY THIS IS NEEDED:
%   The single-seed control (run_control_full15ch.m) returned
%       P F1@100ms = 0.8478 , S = 0.5732
%   against locked values of 0.8546 / 0.5985 -- a gap of -0.007 (P) and
%   -0.025 (S) with no ablation applied at all. Most of the observed
%   ablation effects fall in the 0.01-0.03 range, i.e. the same order as
%   that gap, so with one run per variant they cannot be separated from
%   training stochasticity. Only the logistic stacker's S-wave collapse
%   (about -0.52) is unambiguous at n = 1.
%
%   Running each variant over several seeds gives a proper spread and
%   makes it possible to state which differences are real.
%
% DESIGN NOTES:
%   - The data are reloaded ONCE and the OOF cache is loaded ONCE; every
%     variant/seed combination reuses them, so the only repeated cost is
%     I-CNN training (about 14 minutes per run in the observed log).
%   - rng(seed) is called immediately before each training call, so runs
%     differ only in initialisation and shuffling.
%   - full15ch is included as the within-run control. All comparisons
%     should be made against it, NOT against the locked numbers, because
%     the locked run used different base-picker weights.
%   - logistic is deterministic given the cached features, so it is run
%     once and reported without a spread.
%
% ESTIMATED RUNTIME:
%   nVariants(4) x nSeeds(3) x ~14 min  ~=  2.8 hours, plus one data load.
%   Reduce SEEDS or VARIANT_LIST if you need a shorter run.
%
% OUTPUT:
%   results/ablation_metalearner/multiseed_runs.csv
%       one row per variant x seed x phase x tolerance (raw)
%   results/ablation_metalearner/multiseed_summary.csv
%       mean / std / n per variant x phase x tolerance, plus the delta
%       against the full15ch control and whether it exceeds 2 standard
%       deviations of the control
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
fprintf('  Meta-learner ablations across multiple seeds\n');
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

% --- Configuration -------------------------------------------------------
SEEDS = [42 43 44];        % add more seeds for a tighter spread

% name, channel indices, dilation override ([] = as configured), description
VARIANT_LIST = { ...
    'full15ch',      1:15,  [],      'CONTROL - all 15 channels, dilations as configured'; ...
    'probonly_12ch', 1:12,  [],      'Probability channels only (no waveform context)'; ...
    'waveonly_3ch',  13:15, [],      'Conditioned waveform channels only (no base pickers)'; ...
    'nodilation',    1:15,  [1 1 1], 'All 15 channels, dilation factors forced to 1'};

RUN_LOGISTIC_ONCE = true;  % deterministic; no seed sweep needed

f1Rows = {};
nV = size(VARIANT_LIST, 1);
totalRuns = nV * numel(SEEDS);
runIdx = 0;
tStart = tic;

for v = 1:nV
    name    = VARIANT_LIST{v, 1};
    chanIdx = VARIANT_LIST{v, 2};
    dilOvr  = VARIANT_LIST{v, 3};
    descr   = VARIANT_LIST{v, 4};

    cfgV = config;
    if ~isempty(dilOvr); cfgV.icnn.dilations = dilOvr; end
    cfgV.icnn.includeWaveformContext = any(ismember(13:15, chanIdx));

    trF = sliceChannels(metaTrFeat,   chanIdx);
    vaF = sliceChannels(metaValFeat,  chanIdx);
    teF = sliceChannels(metaTestFeat, chanIdx);

    for s = 1:numel(SEEDS)
        seed = SEEDS(s);
        runIdx = runIdx + 1;

        fprintf('\n========================================================\n');
        fprintf('[%d/%d] %s | seed %d | %d channels | dilations [%s]\n', ...
            runIdx, totalRuns, name, seed, size(trF{1},2), num2str(cfgV.icnn.dilations));
        fprintf('        elapsed so far: %.1f min\n', toc(tStart)/60);
        fprintf('========================================================\n');

        rng(seed, 'twister');
        [modelV, ~] = trainICNNMetaLearner(trF, metaTrLbl, vaF, metaValLbl, cfgV);

        predV  = predictICNNMetaLearner(modelV, teF, cfgV);
        picksV = physicsAwarePicker(predV, cfgV);
        picksV = fillPickErrors(picksV, gtTest);

        runName = sprintf('%s_seed%d', name, seed);
        f1Rows = finalizeVariantSeeded(name, descr, seed, runName, picksV, ...
            gtTest, testData, predDir, TOL_MS, N_test, countUncertain, f1Rows);
    end
end

if RUN_LOGISTIC_ONCE
    fprintf('\n========================================================\n');
    fprintf('[extra] logistic stacker (deterministic, single run)\n');
    fprintf('========================================================\n');
    try
        [picksLR, ~] = runLogisticMetaLearner(metaTrFeat, metaTrLbl, metaTestFeat, config);
        picksLR = fillPickErrors(picksLR, gtTest);
        f1Rows = finalizeVariantSeeded('logistic', ...
            'Logistic-regression stacker (deterministic, no seed sweep)', NaN, ...
            'logistic', picksLR, gtTest, testData, predDir, TOL_MS, N_test, ...
            countUncertain, f1Rows);
    catch ME
        fprintf('  [SKIP] logistic failed: %s\n', ME.message);
    end
end

% =======================================================================
% Raw runs + mean/std summary
% =======================================================================
runs = vertcat(f1Rows{:});
rawPath = fullfile(outDirAbl, 'multiseed_runs.csv');
writetable(runs, rawPath);

variants = unique(runs.Variant, 'stable');
sumRows = {};
for i = 1:numel(variants)
    for phase = {'P','S'}
        ph = phase{1};
        for tol = TOL_MS
            m = strcmp(runs.Variant, variants{i}) & strcmp(runs.Phase, ph) & runs.Tolerance_ms == tol;
            f1v = runs.F1(m);
            r = table();
            r.Variant      = variants(i);
            r.Phase        = {ph};
            r.Tolerance_ms = tol;
            r.n_runs       = numel(f1v);
            r.F1_mean      = mean(f1v);
            r.F1_std       = std(f1v);          % NaN when n = 1
            r.F1_min       = min(f1v);
            r.F1_max       = max(f1v);
            r.MAE_ms_mean  = mean(runs.MAE_ms(m));
            r.MedAE_ms_mean= mean(runs.MedAE_ms(m));
            sumRows{end+1} = r; %#ok<AGROW>
        end
    end
end
summary = vertcat(sumRows{:});

% Delta against the full15ch control, expressed in control standard deviations
summary.delta_vs_control = nan(height(summary),1);
summary.delta_in_ctrl_sd = nan(height(summary),1);
for i = 1:height(summary)
    c = strcmp(summary.Variant,'full15ch') & strcmp(summary.Phase, summary.Phase{i}) ...
        & summary.Tolerance_ms == summary.Tolerance_ms(i);
    if any(c)
        summary.delta_vs_control(i) = summary.F1_mean(i) - summary.F1_mean(c);
        sd = summary.F1_std(c);
        if ~isnan(sd) && sd > 0
            summary.delta_in_ctrl_sd(i) = summary.delta_vs_control(i) / sd;
        end
    end
end

sumPath = fullfile(outDirAbl, 'multiseed_summary.csv');
writetable(summary, sumPath);

fprintf('\n[Done] total elapsed: %.1f min\n', toc(tStart)/60);
fprintf('  raw runs -> %s\n', rawPath);
fprintf('  summary  -> %s\n\n', sumPath);
disp(summary(summary.Tolerance_ms == 100, ...
    {'Variant','Phase','n_runs','F1_mean','F1_std','delta_vs_control','delta_in_ctrl_sd'}));

fprintf(['\nReading guide: a variant differs from the control only if\n' ...
         '|delta_in_ctrl_sd| is comfortably above ~2. Values below that are\n' ...
         'within training noise and should not be reported as an effect.\n\n']);


% =======================================================================
% As finalizeVariant, but records the seed and a per-run name.
% =======================================================================
function f1Rows = finalizeVariantSeeded(name, descr, seed, runName, picks, gt, ...
    dataStruct, predDir, TOL_MS, N_test, countUncertain, f1Rows)

predPath = fullfile(predDir, sprintf('predictions_multiseed_%s.csv', runName));
savePredictions(picks, gt, dataStruct, predPath);

for phase = {'P','S'}
    ph = phase{1};
    if strcmp(ph,'P')
        errV  = [picks.p_error_ms]';
        predV = [picks.p_pick_sec]';
        statV = {picks.p_status}';
    else
        errV  = [picks.s_error_ms]';
        predV = [picks.s_pick_sec]';
        statV = {picks.s_status}';
    end

    det = ~(strcmpi(statV,'not_detected') | isnan(predV) | isinf(predV));
    if countUncertain; det = det | strcmpi(statV,'uncertain'); end

    for tol = TOL_MS
        r = evaluateConventionalEventF1(errV, det, N_test, tol);
        row = table();
        row.Variant       = {name};
        row.Seed          = seed;
        row.RunName       = {runName};
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
        row.DetectionRate = sum(det)/N_test;
        f1Rows{end+1} = row; %#ok<AGROW>

        if tol == 100
            fprintf('  [%s] F1@100ms=%.4f  MAE=%.1f ms  MedAE=%.1f ms\n', ...
                ph, r.F1, r.MAE_ms, r.MedAE_ms);
        end
    end
end
end

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
