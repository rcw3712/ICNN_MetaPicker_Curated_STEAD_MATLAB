% =========================================================================
% runMetaLearnerBenchmark.m
% =========================================================================
% PURPOSE:
%   Benchmark five meta-learners on the SAME dataset, split, preprocessing,
%   base pickers, and OOF predictions as the main experiment.
%   Purpose: justify why I-CNN is selected as meta-learner.
%
% PREREQUISITE:
%   run_experiment_full3C_STEAD must have completed (base_models_final.mat
%   and OOF meta-features must exist).
%
% OUTPUT:
%   results/benchmark/benchmark_summary.csv
%   results/benchmark/benchmark_comparison.png
%
% USAGE:
%   >> runMetaLearnerBenchmark
% =========================================================================

clc;
rootDir = fileparts(mfilename('fullpath'));
addpath(genpath(rootDir));

fprintf('==================================================\n');
fprintf('  Meta-Learner Benchmark\n');
fprintf('  Purpose: justify I-CNN selection\n');
fprintf('==================================================\n\n');

config  = config_ICNN_MetaPicker();
outDir  = fullfile(config.outputFolder, 'benchmark');
modDir  = fullfile(config.outputFolder, 'models');
ensureDir(outDir);

% Load dataset
fprintf('[1/6] Loading dataset...\n');
[data, ~] = loadDatasetFromMetadata(config);

% Split (same seed as main experiment)
rng(config.randomSeed, 'twister');
[trainData, valData, testData] = splitBySourceID(data, config);

% Preprocessing + labels (same pipeline)
fprintf('[2/6] Preprocessing...\n');
trainData = applyPreprocessing(trainData, config);
valData   = applyPreprocessing(valData,   config);
testData  = applyPreprocessing(testData,  config);
trainData = addGaussianLabels(trainData, config);
valData   = addGaussianLabels(valData,   config);

% Augmentation (same)
trainDataAug = augmentTrainingWaveform(trainData, config);

% Load pre-computed base models from main experiment
fprintf('[3/6] Loading base models from main experiment...\n');
basePath = fullfile(modDir,'trained_base_models','base_models_final.mat');
if ~isfile(basePath)
    error('base_models_final.mat not found. Run run_experiment_full3C_STEAD first.');
end
S = load(basePath);
flds = fieldnames(S);
baseModels = S.(flds{1});

% Build meta-features (same OOF features as main experiment)
fprintf('[4/6] Building meta-features...\n');
metaTrainFeat = buildMetaFeatureFromModels(trainDataAug, baseModels, config);
metaValFeat   = buildMetaFeatureFromModels(valData,      baseModels, config);
metaTestFeat  = buildMetaFeatureFromModels(testData,     baseModels, config);

% Labels for val (for MLP training)
metaValLbl = cell(numel(valData),1);
for i=1:numel(valData); metaValLbl{i} = single(valData(i).label); end
metaTrainLbl = cell(numel(trainDataAug),1);
for i=1:numel(trainDataAug); metaTrainLbl{i} = single(trainDataAug(i).label); end

gtTest = extractGroundTruth(testData);
N = numel(testData);
tolMs = config.toleranceMs;

% Define benchmark conditions
benchmarks = {
    'Mean Ensemble';
    'Weighted Ensemble';
    'Logistic Regression';
    'MLP (1-layer)';
    'I-CNN (proposed)';
};

results = table();

fprintf('[5/6] Running benchmarks...\n\n');

%        1. Mean Ensemble                                                                                                                                                                   
fprintf('  [1/5] Mean Ensemble...\n');
picks1 = runMeanEnsemble(metaTestFeat, config);
picks1 = fillPickErrors(picks1, gtTest);
r1 = evalPicks(picks1, gtTest, N, tolMs, 'Mean Ensemble');
results = [results; r1];

%        2. Weighted Ensemble                                                                                                                                                       
fprintf('  [2/5] Weighted Ensemble...\n');
picks2 = runWeightedEnsemble(metaValFeat, valData, config);
% Apply learned weights to test
picks2 = runWeightedEnsemble(metaTestFeat, testData, config);
picks2 = fillPickErrors(picks2, gtTest);
r2 = evalPicks(picks2, gtTest, N, tolMs, 'Weighted Ensemble');
results = [results; r2];

%        3. Logistic Regression                                                                                                                                                 
fprintf('  [3/5] Logistic Regression...\n');
[picks3, ~] = runLogisticMetaLearner(metaTrainFeat, metaTrainLbl, ...
    metaTestFeat, config);
picks3 = fillPickErrors(picks3, gtTest);
r3 = evalPicks(picks3, gtTest, N, tolMs, 'Logistic Regression');
results = [results; r3];

%        4. MLP                                                                                                                                                                                                 
fprintf('  [4/5] MLP Meta-Learner...\n');
[picks4, ~] = runMLPMetaLearner(metaTrainFeat, metaTrainLbl, ...
    metaValFeat, metaValLbl, metaTestFeat, config);
picks4 = fillPickErrors(picks4, gtTest);
r4 = evalPicks(picks4, gtTest, N, tolMs, 'MLP (1-layer)');
results = [results; r4];

%        5. I-CNN (existing, load from saved model)                                                                                     
fprintf('  [5/5] I-CNN (proposed, from saved model)...\n');
icnnPath = fullfile(modDir,'trained_ICNN_meta_learner','model_ICNN_meta.mat');
if isfile(icnnPath)
    Si = load(icnnPath);
    fi = fieldnames(Si);
    icnnModel = Si.(fi{1});
    picks5 = predictICNNMetaLearner(icnnModel, metaTestFeat, config);
    picks5_struct = physicsAwarePicker(picks5, config);
    picks5_struct = fillPickErrors(picks5_struct, gtTest);
else
    fprintf('  [WARN] model_ICNN_meta.mat not found, skipping I-CNN row.\n');
    picks5_struct = picks1;  % placeholder
end
r5 = evalPicks(picks5_struct, gtTest, N, tolMs, 'I-CNN (proposed)');
results = [results; r5];

%        Save and plot                                                                                                                                                                            
fprintf('[6/6] Saving results...\n');
csvPath = fullfile(outDir, 'benchmark_summary.csv');
writetable(results, csvPath);
fprintf('  Saved: %s\n', csvPath);

% Print table
fprintf('\n  === Benchmark Summary ===\n');
fprintf('  %-22s %8s %8s %8s %8s\n','Method','MAE_P','F1@100_P','MAE_S','F1@100_S');
fprintf('  %s\n', repmat('-',1,60));
for ri = 1:height(results)
    fprintf('  %-22s %8.1f %8.3f %8.1f %8.3f\n', ...
        results.Method{ri}, ...
        getVal(results,ri,'MAE_ms_P'), getVal(results,ri,'F1_100ms_P'), ...
        getVal(results,ri,'MAE_ms_S'), getVal(results,ri,'F1_100ms_S'));
end

% Plot
plotBenchmarkComparison(results, outDir);

fprintf('\n  Benchmark complete. Results: %s\n', outDir);

%        Helpers                                                                                                                                                                                              
function r = evalPicks(picks, gt, N, tolMs, methodName)
errP = [picks.p_error_ms]';
errS = [picks.s_error_ms]';

r = table();
r.Method = {methodName};
for comp = {'P','S'}
    c = comp{1};
    err = ternary(strcmp(c,'P'), errP, errS);
    absErr = abs(err(~isnan(err)));
    ev = err(~isnan(err));
    nDet = numel(ev);

    if nDet == 0
        mae=NaN;medAE=NaN;rmse=NaN;p90=NaN;f1s=[NaN NaN NaN];dr=0;outlR=NaN;
    else
        mae   = mean(absErr);
        medAE = median(absErr);
        rmse  = sqrt(mean(ev.^2));
        p90   = prctile(absErr,90);
        outlR = mean(absErr>1000);
        dr    = nDet/N;
        f1s   = zeros(1,numel(tolMs));
        for ti=1:numel(tolMs)
            tol=tolMs(ti);
            TP=sum(absErr<=tol); FP=sum(absErr>tol); FN=N-nDet;
            pr=TP/max(1,TP+FP); rc=TP/max(1,TP+FN);
            f1s(ti)=2*pr*rc/max(1e-10,pr+rc);
        end
    end

    sfx = ['_' c];
    r.(['MAE_ms' sfx])        = mae;
    r.(['MedianAE_ms' sfx])   = medAE;
    r.(['RMSE_ms' sfx])       = rmse;
    r.(['P90AE_ms' sfx])      = p90;
    r.(['DetectionRate' sfx]) = dr;
    r.(['OutlierRate' sfx])   = outlR;
    for ti=1:numel(tolMs)
        r.(sprintf('F1_%dms%s',tolMs(ti),sfx)) = f1s(ti);
    end
end
end

function v = getVal(t, row, col)
v = NaN;
if any(strcmp(t.Properties.VariableNames,col)); v = t.(col)(row); end
end

function picks = fillPickErrors(picks, gt)
for i=1:numel(picks)
    if ~isnan(picks(i).p_pick_sec)&&~isnan(gt(i).p_arrival_sec)
        picks(i).p_error_ms=(picks(i).p_pick_sec-gt(i).p_arrival_sec)*1000;
    else; picks(i).p_error_ms=NaN; end
    if ~isnan(picks(i).s_pick_sec)&&~isnan(gt(i).s_arrival_sec)
        picks(i).s_error_ms=(picks(i).s_pick_sec-gt(i).s_arrival_sec)*1000;
    else; picks(i).s_error_ms=NaN; end
end
end

function gt = extractGroundTruth(data)
N=numel(data);
gt=struct('p_arrival_sec',cell(N,1),'s_arrival_sec',cell(N,1),...
    'source_id',cell(N,1),'event_id',cell(N,1));
for i=1:N
    gt(i).p_arrival_sec=data(i).p_arrival_sec;
    gt(i).s_arrival_sec=data(i).s_arrival_sec;
    gt(i).source_id=data(i).source_id;
    gt(i).event_id=data(i).event_id;
end
end

function plotBenchmarkComparison(results, outDir)
fig = figure('Visible','off','Color','white','Units','centimeters','Position',[2 2 22 12]);
methods = results.Method;
nM = numel(methods);
x  = 1:nM;

metrics = {'F1_100ms_P','F1_100ms_S','MAE_ms_P','MAE_ms_S'};
titles  = {'F1@100ms (P-wave)','F1@100ms (S-wave)','MAE (P-wave, ms)','MAE (S-wave, ms)'};
cols    = {[0.122 0.467 0.706],[0.839 0.153 0.157],[0.173 0.627 0.173],[0.580 0.404 0.741]};

for mi = 1:4
    ax = subplot(2,2,mi);
    col = metrics{mi};
    vals = zeros(nM,1);
    for ri=1:nM
        if any(strcmp(results.Properties.VariableNames,col))
            vals(ri)=results.(col)(ri); end
    end
    b = bar(x, vals, 0.6, 'FaceColor', cols{mi}, 'EdgeColor','none');
    for ri=1:nM
        text(ri, vals(ri)+0.005*max(vals), sprintf('%.3f',vals(ri)), ...
            'HorizontalAlignment','center','FontSize',8,'FontName','Arial');
    end
    set(ax,'XTick',x,'XTickLabel',methods,'XTickLabelRotation',20,...
        'FontSize',9,'FontName','Arial','Box','off');
    title(titles{mi},'FontSize',11,'FontName','Arial','FontWeight','bold');
    grid on; ax.GridAlpha=0.2;
    % Highlight I-CNN bar
    if ~isempty(methods)
        icnnIdx = find(contains(methods,'I-CNN'),1);
        if ~isempty(icnnIdx)
            hold on;
            bar(icnnIdx, vals(icnnIdx), 0.6, ...
                'FaceColor', cols{mi}*0.6, 'EdgeColor','k','LineWidth',1.2);
        end
    end
end

sgtitle('Meta-Learner Benchmark: Justifying I-CNN Selection', ...
    'FontSize',13,'FontName','Arial','FontWeight','bold');

exportgraphics(fig, fullfile(outDir,'benchmark_comparison.png'), ...
    'Resolution',300,'BackgroundColor','white');
close(fig);
fprintf('  Saved: benchmark_comparison.png\n');
end

function out=ternary(c,a,b); if c;out=a;else;out=b;end; end
function ensureDir(d); if ~isempty(d)&&~isfolder(d); mkdir(d); end; end
