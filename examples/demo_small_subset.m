% =========================================================================
% demo_small_subset.m  (examples/)
% =========================================================================
% PURPOSE:
%   Run the complete pipeline (including I-CNN meta-learner training) on
%   a small self-generated synthetic curated-CSV subset, allowing
%   reviewers to verify the end-to-end framework without the full
%   2,234-file dataset.
%
% INPUT:  (none — generates its own small CSV folder + metadata)
% OUTPUT: Console output with metrics; figures in results/figures/
%
% NOTES:
%   Results from this demo are NOT representative of manuscript-reported
%   performance (which uses the full curated 2,234-file dataset). This
%   demo exists solely for pipeline verification.
% =========================================================================

clc; clear; close all;
rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(rootDir));

fprintf('=== demo_small_subset ===\n\n');

demoFolder = fullfile(rootDir, 'data', 'csv_demo_subset');
demoMeta   = fullfile(rootDir, 'metadata', 'metadata_demo_subset.csv');

if ~isfolder(demoFolder) || isempty(dir(fullfile(demoFolder,'*.csv')))
    fprintf('Generating small synthetic curated-CSV subset...\n');
    generateDemoSubset(demoFolder);
end

config = config_ICNN_MetaPicker();
config.csvFolder    = demoFolder;
config.metadataPath = demoMeta;
config.cnn.maxEpochs  = 15;
config.tcn.maxEpochs  = 15;
config.icnn.maxEpochs = 20;
config.kFold          = 3;
config.augFactor      = 2;
rng(config.randomSeed, 'twister');

[data, metadata] = loadFilteredSTEADCSVFolder(config.csvFolder, config.metadataPath, config);
fprintf('Loaded: %d records\n', numel(data));

[dataClean, ~, ~] = qcWaveformDataset(data, metadata, config);
fprintf('After QC: %d records\n', numel(dataClean));

[trainData, valData, testData, splitInfo] = splitBySourceID(dataClean, config);

trainData = addGaussianLabels(applyPreprocessing(trainData, config), config);
valData   = addGaussianLabels(applyPreprocessing(valData,   config), config);
testData  = addGaussianLabels(applyPreprocessing(testData,  config), config);

if config.useAugmentation
    trainDataAug = augmentTrainingWaveform(trainData, config);
else
    trainDataAug = trainData;
end

[metaTrFeat, metaTrLbl, baseModels] = generateOOFPredictions(trainDataAug, config, splitInfo.keyUsed);
metaValFeat  = buildMetaFeatureFromModels(valData,  baseModels, config);
metaValLbl   = cellfun(@(d) d, {valData.label}, 'UniformOutput', false)';
metaTestFeat = buildMetaFeatureFromModels(testData, baseModels, config);

[icnnModel, ~] = trainICNNMetaLearner(metaTrFeat, metaTrLbl, metaValFeat, metaValLbl, config);

predTest  = predictICNNMetaLearner(icnnModel, metaTestFeat, config);
picksTest = physicsAwarePicker(predTest, config);

gtTest = struct('p_arrival_sec', {testData.p_arrival_sec}, ...
                 's_arrival_sec', {testData.s_arrival_sec});

metrics = evaluatePickingPerformance(picksTest, gtTest, config);

fprintf('\n=== Demo Results (small synthetic subset) ===\n');
for r = 1:height(metrics)
    fprintf('  [%s] MAE=%.1f ms  F1@100ms=%.3f  DetRate=%.2f\n', ...
        metrics.Component{r}, metrics.MAE_ms(r), metrics.F1_100ms(r), metrics.DetectionRate(r));
end
fprintf('\nNote: results not representative of manuscript performance.\n');
fprintf('This demo exists for pipeline verification only.\n');

% =========================================================================
function generateDemoSubset(demoFolder)
if ~isfolder(demoFolder); mkdir(demoFolder); end
fs = 100; T = 6000; t = (0:T-1)'/fs;
rng(42);
nSources = 20; maxPerSource = 3;
idx = 0;
for s = 1:nSources
    sid = sprintf('SRC%04d', s);
    nSt = randi([1, maxPerSource]);
    pA  = 4 + rand()*8; sA = pA + 1 + rand()*8;
    for st = 1:nSt
        idx = idx + 1;
        snr = 8 + rand()*20;
        sigLevel = 0.1*10^(snr/20);
        E = 0.1*randn(T,1); N = 0.1*randn(T,1); Z = 0.1*randn(T,1);
        tP = t-pA; Z = Z + sigLevel*sin(2*pi*5*tP).*exp(-tP.^2/0.18).*(tP>=-0.1);
        tS = t-sA; N = N + 0.7*sigLevel*sin(2*pi*3*tS).*exp(-tS.^2/0.5).*(tS>=-0.2);
        E = E + 0.6*sigLevel*sin(2*pi*3*tS).*exp(-tS.^2/0.5).*(tS>=-0.2);
        fname = sprintf('%s_ST%02d_%04d.csv', sid, st, idx);
        T_csv = table(t, E, N, Z, repmat(pA,T,1), repmat(sA,T,1), ...
            'VariableNames', {'sec','E','N','Z','p_arrival','s_arrival'});
        writetable(T_csv, fullfile(demoFolder, fname));
    end
end
fprintf('Generated %d synthetic CSV files (%d sources) in %s\n', idx, nSources, demoFolder);
end
