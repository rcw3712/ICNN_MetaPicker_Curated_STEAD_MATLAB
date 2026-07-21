% =========================================================================
% run_post_evaluation_diagnostics.m
% =========================================================================
% PURPOSE:
%   Script utama untuk modul Post-Evaluation Diagnostics.
%   Menghasilkan analisis mendalam dari predictions_full3C.csv dan
%   predictions_Zonly.csv tanpa melakukan training ulang.
%
% PREREQUISITES:
%   1. run_experiment_full3C_STEAD.m harus sudah selesai
%   2. run_experiment_Zonly_STEAD.m harus sudah selesai
%   3. (Opsional) metadata_master_final.csv tersedia di metadata/
%
% OUTPUT:
%   results/diagnostics/
%             percentile_metrics/
%                   percentile_metrics_Full3C.csv
%                   percentile_metrics_Zonly.csv
%                   diagnostic_comparison_full3C_vs_Zonly.csv
%             outliers/
%                   top20_P_outliers_Full3C.csv
%                   top20_S_outliers_Full3C.csv
%                   top20_P_outliers_Zonly.csv
%                   top20_S_outliers_Zonly.csv
%                   outlier_summary_Full3C.csv
%                   outlier_summary_Zonly.csv
%             snr_stratified/
%                   metrics_by_snr_Full3C.csv
%                   metrics_by_snr_Zonly.csv
%             failure_cases/
%                   Full3C/  (*.png, failure waveform figures)
%                   Zonly/   (*.png)
%                   failure_cases_selected_Full3C.csv
%                   failure_cases_selected_Zonly.csv
%             figures/
%                   p_error_outliers_scatter_Full3C.png
%                   s_error_outliers_scatter_Full3C.png
%                   full3C_vs_Zonly_percentile_error.png
%                   full3C_vs_Zonly_outlier_rate.png
%                   diagnostic_delta_full3C_vs_Zonly.png
%                   snr_stratified_F1_full3C_vs_Zonly.png
%                   snr_stratified_MAE_full3C_vs_Zonly.png
%             diagnostic_report/
%                 diagnostic_summary_report.txt
%                 diagnostic_summary_report.md
%
% USAGE:
%   >> run_post_evaluation_diagnostics
%
% NOTE:
%   No model retraining is performed. All diagnostics are computed from
%   saved prediction results, metadata, and waveform CSV files.
% =========================================================================

clc;
rootDir = fileparts(mfilename('fullpath'));
addpath(genpath(rootDir));

fprintf('                                                                                                                                                                                    \n');
fprintf('     Post-Evaluation Diagnostics     I-CNN MetaPicker              \n');
fprintf('     No model retraining. Analysis from saved results only.      \n');
fprintf('                                                                                                                                                                                    \n\n');

%        1. Config                                                                                                                                                                                        
config = config_ICNN_MetaPicker();

% Diagnostics-specific config     tambahkan ke config yang sudah ada
config.outputDiagnosticsFolder   = fullfile(config.outputFolder, 'diagnostics');
config.predictionsFull3CPath     = fullfile(config.outputFolder, 'predictions', 'predictions_full3C.csv');
config.predictionsZonlyPath      = fullfile(config.outputFolder, 'predictions', 'predictions_Zonly.csv');
config.metricsFull3CPath         = fullfile(config.outputFolder, 'metrics', 'metrics_full3C.csv');
config.metricsZonlyPath          = fullfile(config.outputFolder, 'metrics', 'metrics_Zonly.csv');
config.numFailureCasesToPlot     = 20;
config.useProbabilityCurveInspection = false;

% Waveform folder     kompatibel dengan berbagai nama field config
if ~isfield(config, 'csvWaveformFolder')
    if isfield(config, 'csvFolder')
        config.csvWaveformFolder = config.csvFolder;
    else
        config.csvWaveformFolder = fullfile('data', 'csv_stead_filtered');
    end
end

ensureDir(config.outputDiagnosticsFolder);

%        2. Load predictions                                                                                                                                                          
fprintf('[Step 1/8] Loading predictions...\n');

if ~isfile(config.predictionsFull3CPath)
    error('predictions_full3C.csv not found. Run run_experiment_full3C_STEAD.m first.');
end
predFull = readtable(config.predictionsFull3CPath, 'VariableNamingRule','preserve');
fprintf('  Full3C: %d records loaded.\n', height(predFull));

hasZonly = isfile(config.predictionsZonlyPath);
if hasZonly
    predZ = readtable(config.predictionsZonlyPath, 'VariableNamingRule','preserve');
    fprintf('  Zonly : %d records loaded.\n', height(predZ));
else
    predZ = table();
    fprintf('  [SKIP] predictions_Zonly.csv not found. Zonly analysis will be skipped.\n');
end

%        3. Load metadata dan join                                                                                                                                        
fprintf('\n[Step 2/8] Loading and joining metadata...\n');

meta = table();
metaPaths = {
    config.metadataPath, ...
    fullfile('metadata','metadata_master_final.csv'), ...
    fullfile('metadata','metadata_master_filled.csv'), ...
    fullfile('metadata','metadata_master_latest.csv')
};
for mp = metaPaths
    if isfile(mp{1})
        try
            meta = readtable(mp{1}, 'VariableNamingRule','preserve');
            fprintf('  Metadata loaded: %d rows from %s\n', height(meta), mp{1});
            break;
        catch ME
            fprintf('  Warning: could not load %s: %s\n', mp{1}, ME.message);
        end
    end
end

if isempty(meta)
    fprintf('  [WARN] No metadata file found. SNR/magnitude/distance attributes will be NaN.\n');
end

predFull = joinPredictionsWithMetadata(predFull, meta, config);
if hasZonly; predZ = joinPredictionsWithMetadata(predZ, meta, config); end

%        4. Hitung ulang errors jika belum ada                                                                                                    
fprintf('\n[Step 3/8] Verifying / computing picking errors...\n');
predFull = computePredictionErrors(predFull);
if hasZonly; predZ = computePredictionErrors(predZ); end

%        5. Percentile metrics                                                                                                                                                    
fprintf('\n[Step 4/8] Computing percentile metrics...\n');
pctFull = computePercentileMetrics(predFull, 'Full3C', config);
pctZ    = table();
if hasZonly; pctZ = computePercentileMetrics(predZ, 'Zonly', config); end
printPercentileTable(pctFull, pctZ);

%        6. Outlier analysis                                                                                                                                                          
fprintf('\n[Step 5/8] Outlier analysis...\n');
outlierFull = analyzeOutliers(predFull, 'Full3C', config);
outlierZ    = struct();
if hasZonly; outlierZ = analyzeOutliers(predZ, 'Zonly', config); end

%        7. SNR-stratified evaluation                                                                                                                            
fprintf('\n[Step 6/8] SNR-stratified evaluation...\n');
snrFull = evaluateBySNRClass(predFull, 'Full3C', config);
snrZ    = table();
if hasZonly; snrZ = evaluateBySNRClass(predZ, 'Zonly', config); end

%        8. Waveform-level failure inspection                                                                                                    
fprintf('\n[Step 7/8] Waveform-level failure inspection...\n');
failFull = inspectFailureWaveforms(predFull, 'Full3C', config);
if hasZonly; inspectFailureWaveforms(predZ, 'Zonly', config); end

%        9. Full3C vs Z-only diagnostic comparison                                                                                     
fprintf('\n[Step 8a/8] Full3C vs Z-only comparison...\n');
if hasZonly && ~isempty(pctZ)
    compareFull3CvsZonlyDiagnostics(pctFull, pctZ, snrFull, snrZ, config);
else
    fprintf('  [Skip] Z-only results not available.\n');
end

%        10. Export report                                                                                                                                                             
fprintf('\n[Step 8b/8] Exporting diagnostic report...\n');
R = struct('pctFull',pctFull,'pctZ',pctZ, ...
           'snrFull',snrFull,'snrZ',snrZ, ...
           'outlierFull',outlierFull,'outlierZ',outlierZ);
exportDiagnosticReport(R, config);

%        Summary                                                                                                                                                                                           
figFiles = dir(fullfile(config.outputDiagnosticsFolder,'figures','*.png'));
csvFiles = dir(fullfile(config.outputDiagnosticsFolder,'**','*.csv'));

fprintf('\n                                                                                                                                                                                    \n');
fprintf('     Post-Evaluation Diagnostics complete.                       \n');
fprintf('     Output: %-47s    \n', config.outputDiagnosticsFolder);
fprintf('                                                                                                                                                                                    \n');
fprintf('     Figures generated : %-35d    \n', numel(figFiles));
fprintf('     CSV files saved   : %-35d    \n', numel(csvFiles));
fprintf('                                                                                                                                                                                    \n\n');

%        Helper: compute errors if missing                                                                                                                
function predTable = computePredictionErrors(predTable)
hasPErr = any(strcmpi(predTable.Properties.VariableNames,'p_error_ms'));
hasSErr = any(strcmpi(predTable.Properties.VariableNames,'s_error_ms'));

if ~hasPErr
    pTrue = safeGetNum(predTable,'p_true_sec');
    pPred = safeGetNum(predTable,'p_pred_sec');
    if ~all(isnan(pTrue)) && ~all(isnan(pPred))
        predTable.p_error_ms = (pPred - pTrue) * 1000;
        fprintf('  Computed p_error_ms from pred/true columns.\n');
    end
end
if ~hasSErr
    sTrue = safeGetNum(predTable,'s_true_sec');
    sPred = safeGetNum(predTable,'s_pred_sec');
    if ~all(isnan(sTrue)) && ~all(isnan(sPred))
        predTable.s_error_ms = (sPred - sTrue) * 1000;
        fprintf('  Computed s_error_ms from pred/true columns.\n');
    end
end
end

function printPercentileTable(pF, pZ)
fprintf('\n  %-22s %10s %10s %10s %10s\n', 'Metric', 'Full3C P','Zonly P','Full3C S','Zonly S');
fprintf('  %s\n', repmat('-',1,62));
metrics = {'MAE_ms','MedAE_ms','RMSE_ms','P90_ms','OutlierRate_1000ms'};
labels  = {'MAE (ms)','MedAE (ms)','RMSE (ms)','P90 (ms)','Outlier>1s'};
for mi = 1:numel(metrics)
    col = metrics{mi};
    scale = 1; fmt = '%10.1f';
    if contains(col,'Rate'); scale=100; fmt='%9.1f%%'; end
    fP = getMetricVal(pF,'P',col)*scale;
    fS = getMetricVal(pF,'S',col)*scale;
    zP = ternary(~isempty(pZ), getMetricVal(pZ,'P',col)*scale, NaN);
    zS = ternary(~isempty(pZ), getMetricVal(pZ,'S',col)*scale, NaN);
    fprintf(['  %-22s ' fmt ' ' fmt ' ' fmt ' ' fmt '\n'], labels{mi}, fP, zP, fS, zS);
end
end

function v = getMetricVal(t, comp, col)
v = NaN;
if isempty(t) || ~any(strcmp(t.Properties.VariableNames,'Component')); return; end
r = t(strcmp(t.Component,comp),:);
if isempty(r)||~any(strcmp(r.Properties.VariableNames,col)); return; end
v = r.(col);
end

function v = safeGetNum(t,col)
idx = strcmpi(t.Properties.VariableNames,col);
if ~any(idx); v=nan(height(t),1); return; end
v = double(t.(t.Properties.VariableNames{find(idx,1)}));
end

function out = ternary(c,a,b); if c; out=a; else; out=b; end; end
function ensureDir(d); if ~isempty(d)&&~isfolder(d); mkdir(d); end; end
