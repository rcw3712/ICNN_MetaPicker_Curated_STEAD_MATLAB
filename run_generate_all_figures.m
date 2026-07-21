% =========================================================================
% run_generate_all_figures.m
% =========================================================================
% PURPOSE:
%   Script utama framework visualisasi     menghasilkan seluruh figure
%   manuscript Computers & Geosciences dari satu perintah.
%   Tidak melakukan training ulang. Semua figure dari data hasil pipeline.
%
% USAGE:
%   >> run_generate_all_figures
%
% OUTPUT:  results/figures_publication/
%             png/       PNG 300 dpi
%             tiff/      TIFF 600 dpi
%             pdf/       PDF vector
%             failure_cases/
% =========================================================================

clc;
rootDir = fileparts(mfilename('fullpath'));
addpath(genpath(rootDir));

fprintf('                                                                                                                                                                                    \n');
fprintf('     Publication Figure Generator     I-CNN MetaPicker             \n');
fprintf('     Computers & Geosciences  |  300 dpi PNG + TIFF + PDF       \n');
fprintf('                                                                                                                                                                                    \n\n');

%        Config                                                                                                                                                                                                 
config  = config_ICNN_MetaPicker();
outDir  = fullfile(config.outputFolder, 'figures_publication');
predDir = fullfile(config.outputFolder, 'predictions');
metDir  = fullfile(config.outputFolder, 'metrics');
diagDir = fullfile(config.outputFolder, 'diagnostics');
modDir  = fullfile(config.outputFolder, 'models');
ensureDir(outDir);

%        Style                                                                                                                                                                                                    
setPublicationStyle();

%        Load semua data yang tersedia                                                                                                                            
fprintf('[Load] Loading dataset and results...\n');

% Dataset
[data, ~] = loadDatasetFromMetadata(config);
fprintf('  Dataset: %d records loaded.\n', numel(data));

% Predictions
predFull = loadCSV(fullfile(predDir,'predictions_full3C.csv'));
predZ    = loadCSV(fullfile(predDir,'predictions_Zonly.csv'));

% Metrics
mFull = loadCSV(fullfile(metDir,'metrics_full3C.csv'));
mZ    = loadCSV(fullfile(metDir,'metrics_Zonly.csv'));

% Conventional F1 audit summary (post-audit source of truth for F1/Precision/Recall)
f1Conv = loadCSV(fullfile(config.outputFolder,'f1_audit','f1_conventional_summary.csv'));

% Diagnostics (opsional     dihasilkan oleh run_post_evaluation_diagnostics)
pctFull = loadCSV(fullfile(diagDir,'percentile_metrics','percentile_metrics_Full3C.csv'));
pctZ    = loadCSV(fullfile(diagDir,'percentile_metrics','percentile_metrics_Zonly.csv'));
snrFull = loadCSV(fullfile(diagDir,'snr_stratified','metrics_by_snr_Full3C.csv'));
snrZ    = loadCSV(fullfile(diagDir,'snr_stratified','metrics_by_snr_Zonly.csv'));

% Trained I-CNN model (untuk Meta-Feature Tensor figure)
icnnPath = fullfile(modDir,'trained_ICNN_meta_learner','model_ICNN_meta.mat');
basePath = fullfile(modDir,'trained_base_models','base_models_final.mat');

captions = {};

fprintf('\n[Figures] Generating publication figures...\n\n');

%                                                                                                                                                                                                                               
% FIG 02     Dataset Characteristics
%                                                                                                                                                                                                                               
fprintf('[Fig 02] Dataset Characteristics...\n');
try
    cap = plotDatasetCharacteristics(data, outDir);
    captions{end+1} = cap;
catch ME; fprintf('  [ERROR] %s\n', ME.message); end

%                                                                                                                                                                                                                               
% FIG 03     Gaussian Label
%                                                                                                                                                                                                                               
fprintf('[Fig 03] Gaussian Label...\n');
try
    % Pilih record dengan SNR tinggi dan kedua picks tersedia
    rec3 = pickBestRecord(data, config);
    if ~isempty(rec3)
        cap = plotGaussianLabel(rec3, config, outDir);
        captions{end+1} = cap;
    else
        fprintf('  [Skip] No suitable record found.\n');
    end
catch ME; fprintf('  [ERROR] %s\n', ME.message); end

%                                                                                                                                                                                                                               
% FIG 04     Meta-Feature Tensor
%                                                                                                                                                                                                                               
fprintf('[Fig 04] Meta-Feature Tensor...\n');
try
    if isfile(basePath)
        S2 = load(basePath);
        baseModels = loadModelVar(S2, {'baseModels','baseModelsFinal','base_models','models'});
        if ~isempty(baseModels) && ~isempty(rec3)
            rec4 = applyPreprocessing(rec3, config);
            mf4  = buildMetaFeatureFromModels(rec4, baseModels, config);
            cap  = plotMetaFeatureTensor(mf4{1}, rec4, config, outDir);
            captions{end+1} = cap;
        else
            fprintf('  [Skip] base_models_final.mat or record not available.\n');
        end
    else
        fprintf('  [Skip] base_models_final.mat not found.\n');
    end
catch ME; fprintf('  [ERROR] %s\n', ME.message); end

%                                                                                                                                                                                                                               
% FIG 05     Performance Comparison
%                                                                                                                                                                                                                               
fprintf('[Fig 05] Performance Comparison...\n');
try
    if ~isempty(mFull) && ~isempty(mZ)
        cap = plotPerformanceComparison(f1Conv, pctFull, pctZ, outDir);
        captions{end+1} = cap;
    else
        fprintf('  [Skip] Metrics CSV not found.\n');
    end
catch ME; fprintf('  [ERROR] %s\n', ME.message); end

%                                                                                                                                                                                                                               
% FIG 06     Residual Distribution
%                                                                                                                                                                                                                               
fprintf('[Fig 06] Residual Distribution...\n');
try
    if ~isempty(predFull)
        cap = plotResidualDistribution(predFull, 'Full3C', outDir);
        captions{end+1} = cap;
    else
        fprintf('  [Skip] predictions_full3C.csv not found.\n');
    end
catch ME; fprintf('  [ERROR] %s\n', ME.message); end

%                                                                                                                                                                                                                               
% FIG 07     Arrival Scatter
%                                                                                                                                                                                                                               
fprintf('[Fig 07] Arrival Scatter...\n');
try
    if ~isempty(predFull)
        % Join dengan metadata untuk SNR
        meta = loadMeta(config);
        if ~isempty(meta)
            predFull = joinPredictionsWithMetadata(predFull, meta, config);
        end
        cap = plotArrivalScatter(predFull, outDir);
        captions{end+1} = cap;
    else
        fprintf('  [Skip] predictions_full3C.csv not found.\n');
    end
catch ME; fprintf('  [ERROR] %s\n', ME.message); end

%                                                                                                                                                                                                                               
% FIG 08     Residual vs Attributes
%                                                                                                                                                                                                                               
fprintf('[Fig 08] Residual vs Attributes...\n');
try
    if ~isempty(predFull)
        cap = plotResidualAttributes(predFull, data, outDir);
        captions{end+1} = cap;
    else
        fprintf('  [Skip] predictions_full3C.csv not found.\n');
    end
catch ME; fprintf('  [ERROR] %s\n', ME.message); end

%                                                                                                                                                                                                                               
% FIG 09     SNR Stratified Performance
%                                                                                                                                                                                                                               
fprintf('[Fig 09] SNR Stratified Performance...\n');
try
    if ~isempty(snrFull)
        cap = plotSNRPerformance(snrFull, snrZ, outDir);
        captions{end+1} = cap;
    else
        fprintf('  [Skip] SNR metrics not found. Run run_post_evaluation_diagnostics first.\n');
    end
catch ME; fprintf('  [ERROR] %s\n', ME.message); end

%                                                                                                                                                                                                                               
% FIG 10     Percentile Metrics
%                                                                                                                                                                                                                               
fprintf('[Fig 10] Percentile Metrics...\n');
try
    if ~isempty(pctFull)
        cap = plotPercentileMetrics(pctFull, pctZ, outDir);
        captions{end+1} = cap;
    else
        fprintf('  [Skip] Percentile metrics not found. Run run_post_evaluation_diagnostics first.\n');
    end
catch ME; fprintf('  [ERROR] %s\n', ME.message); end

%                                                                                                                                                                                                                               
% FIG 11     Outlier Analysis
%                                                                                                                                                                                                                               
fprintf('[Fig 11] Outlier Analysis...\n');
try
    if ~isempty(predFull)
        cap = plotOutlierAnalysis(predFull, outDir);
        captions{end+1} = cap;
    else
        fprintf('  [Skip] predictions_full3C.csv not found.\n');
    end
catch ME; fprintf('  [ERROR] %s\n', ME.message); end

%                                                                                                                                                                                                                               
% FIG S1     Training History (hanya jika trainInfo tersedia)
%                                                                                                                                                                                                                               
fprintf('[Fig S1] Training History...\n');
try
    if isfile(icnnPath)
        cap = plotTrainingHistory(icnnPath, outDir);
        if ~isempty(cap); captions{end+1} = cap; end
    else
        fprintf('  [Skip] model_ICNN_meta.mat not found.\n');
    end
catch ME; fprintf('  [ERROR] %s\n', ME.message); end

%                                                                                                                                                                                                                               
% FIG 12     Failure Waveforms
%                                                                                                                                                                                                                               
fprintf('[Fig 12] Failure Waveforms...\n');
try
    if ~isempty(predFull)
        csvDir = getfield_safe(config, {'csvFolder','csvWaveformFolder'}, fullfile('data','csv_stead_filtered'));
        cap = plotFailureWaveforms(predFull, csvDir, 'Full3C', outDir);
        captions{end+1} = cap;
    end
    if ~isempty(predZ)
        csvDir = getfield_safe(config, {'csvFolder','csvWaveformFolder'}, fullfile('data','csv_stead_filtered'));
        plotFailureWaveforms(predZ, csvDir, 'Zonly', outDir);
    end
catch ME; fprintf('  [ERROR] %s\n', ME.message); end

%        Save captions                                                                                                                                                                            
capPath = fullfile(outDir, 'figure_captions.txt');
fid = fopen(capPath,'w');
for k=1:numel(captions)
    fprintf(fid,'%s\n\n', captions{k});
end
fclose(fid);

%        Summary                                                                                                                                                                                              
pngFiles = dir(fullfile(outDir,'png','*.png'));
fprintf('\n                                                                                                                                                                                    \n');
fprintf('     Figure generation complete.                                 \n');
fprintf('                                                                                                                                                                                    \n');
fprintf('     PNG files (300 dpi) : %-33d    \n', numel(pngFiles));
fprintf('     Output: %-47s    \n', outDir);
fprintf('                                                                                                                                                                                    \n\n');

fprintf('Files generated:\n');
for f = 1:numel(pngFiles)
    fprintf('       %s\n', pngFiles(f).name);
end
fprintf('\nCaptions: %s\n', capPath);

%        Helpers                                                                                                                                                                                              
function t = loadCSV(p)
t = table();
if isfile(p)
    try; t = readtable(p,'VariableNamingRule','preserve');
    catch ME; fprintf('  [WARN] Could not load %s: %s\n',p,ME.message); end
else
    fprintf('  [INFO] Not found: %s\n', p);
end
end

function meta = loadMeta(config)
meta = table();
for p = {config.metadataPath, ...
        fullfile('metadata','metadata_master_final.csv'), ...
        fullfile('metadata','metadata_master_filled.csv')}
    if isfile(p{1})
        try; meta = readtable(p{1},'VariableNamingRule','preserve'); return;
        catch; end
    end
end
end

function rec = pickBestRecord(data, config)
rec = [];
for i = 1:numel(data)
    d = data(i);
    if isfield(d,'SNR') && ~isnan(d.SNR) && d.SNR > 30 && ...
       isfield(d,'p_arrival_sec') && ~isnan(d.p_arrival_sec) && ...
       isfield(d,'s_arrival_sec') && ~isnan(d.s_arrival_sec)
        rec = applyPreprocessing(d, config);
        rec = addGaussianLabels(rec, config);
        return;
    end
end
end

function v = loadModelVar(S, names)
v = [];
flds = fieldnames(S);
for k=1:numel(names)
    if isfield(S,names{k}); v=S.(names{k}); return; end
end
if ~isempty(flds); v=S.(flds{1}); end
end

function v = getfield_safe(s, names, default)
% Coba beberapa nama field, kembalikan default jika tidak ada
for k=1:numel(names)
    if isfield(s, names{k}) && ~isempty(s.(names{k}))
        v = s.(names{k}); return;
    end
end
v = default;
end

function ensureDir(d); if ~isempty(d)&&~isfolder(d); mkdir(d); end; end
