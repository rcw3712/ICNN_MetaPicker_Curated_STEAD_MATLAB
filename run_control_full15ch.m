% =========================================================================
% run_control_full15ch.m
% =========================================================================
% PURPOSE:
%   Train the UNABLATED control: all 15 meta-feature channels, dilation
%   factors exactly as configured. This is the within-run baseline the
%   ablation variants must be compared against.
%
% WHY THIS IS NEEDED:
%   run_metalearner_ablations.m trained probonly_12ch, waveonly_3ch,
%   nodilation and logistic in a single fresh run, but compared them
%   against the LOCKED I-CNN numbers (P F1@100ms = 0.8546, S = 0.5985)
%   which were produced by a much earlier training run. Any difference
%   therefore mixes together:
%       (a) the effect of the ablated component, and
%       (b) plain run-to-run variation.
%   Since the observed differences are small (0.008 to 0.057), (b) could
%   account for a meaningful share of them.
%
%   This script trains the full configuration under the SAME conditions as
%   the ablation variants (same cache, same seed, same code path), so the
%   comparison becomes like-for-like. If it reproduces roughly 0.855 / 0.599
%   the ablation deltas can be trusted; if it does not, the gap between it
%   and the locked values IS the run-to-run variation, and the ablation
%   deltas must be read against that.
%
% PREREQUISITE:
%   results/predictions/oof_meta_features.mat
%   (already produced by run_export_oof_meta_features_v2.m)
%
% COST:
%   Trains ONE I-CNN. Nothing is retrained for the other variants and no
%   existing output is overwritten.
%
% OUTPUT:
%   results/predictions/predictions_ablation_full15ch.csv
%   results/ablation_metalearner/control_full15ch_f1.csv
%       (written to its own file so ablation_metalearner_f1.csv is left intact)
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
fprintf('  Control: unablated full 15-channel model\n');
fprintf('========================================================\n\n');

% --- Load cached OOF tensors -------------------------------------------
predDir   = fullfile(config.outputFolder, 'predictions');
cachePath = fullfile(predDir, 'oof_meta_features.mat');
assert(isfile(cachePath), ...
    ['OOF cache not found:\n  %s\n' ...
     'Run run_export_oof_meta_features_v2.m first.'], cachePath);

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
% Control variant: full 15 channels, dilations as configured
% =======================================================================
name  = 'full15ch';
descr = 'CONTROL - all 15 channels, dilations as configured (unablated)';

fprintf('\n--------------------------------------------------------\n');
fprintf('[Control %s] %s\n', name, descr);
fprintf('--------------------------------------------------------\n');

cfgV = config;                       % nothing overridden
fprintf('  input channels: %d | dilations: [%s]\n', ...
    size(metaTrFeat{1}, 2), num2str(cfgV.icnn.dilations));

rng(config.randomSeed, 'twister');   % same initialization as every variant
[modelV, ~] = trainICNNMetaLearner(metaTrFeat, metaTrLbl, ...
                                   metaValFeat, metaValLbl, cfgV);

predV  = predictICNNMetaLearner(modelV, metaTestFeat, cfgV);
picksV = physicsAwarePicker(predV, cfgV);
picksV = fillPickErrors(picksV, gtTest);

f1Rows = finalizeVariant(name, descr, picksV, gtTest, testData, ...
    predDir, TOL_MS, N_test, countUncertain, f1Rows);

% =======================================================================
% Write to a SEPARATE file so the existing ablation CSV is not overwritten
% =======================================================================
f1Tbl  = vertcat(f1Rows{:});
f1Path = fullfile(outDirAbl, 'control_full15ch_f1.csv');
writetable(f1Tbl, f1Path);

fprintf('\n[Done] Control results written to:\n  %s\n\n', f1Path);
disp(f1Tbl(f1Tbl.Tolerance_ms == 100, :));

fprintf(['\nCompare the F1@100ms values above with the locked numbers\n' ...
         '  P = 0.8546 , S = 0.5985\n' ...
         'The gap between them is the run-to-run variation that every\n' ...
         'ablation delta must be judged against.\n\n']);

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
