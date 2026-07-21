% =========================================================================
% run_reviewer_modules.m
% =========================================================================
% PURPOSE:
%   Master script untuk semua modul tambahan yang menjawab pertanyaan reviewer
%   Computers & Geosciences. Tidak mengubah pipeline utama.
%
% MODUL YANG DIJALANKAN:
%   M1: Meta-Learner Benchmark (justify I-CNN selection)
%   M2: Physics-Aware Ablation (justify post-processing)
%   M3: Base Picker Ablation   (justify each base picker)
%   M4: Failure Analysis       (explain failure cases)
%   M5: Extended Diagnostics   (skewness, kurtosis, P95AE)
%   M6: Stratified Analysis    (performance by mag/dist/SNR/SP)
%   M7: Leakage Validation     (prove zero leakage)
%   M9: Experiment Logging     (reproducibility)
%
% PREREQUISITE:
%   run_experiment_full3C_STEAD must be complete.
%
% USAGE:
%   >> run_reviewer_modules
%   >> run_reviewer_modules('M1')     % run only benchmark
%   >> run_reviewer_modules('M5,M6')  % run diagnostics only
% =========================================================================

function run_reviewer_modules(varargin)

if nargin==0; runModules='ALL'; else; runModules=upper(varargin{1}); end
runAll = strcmp(runModules,'ALL');
shouldRun = @(tag) runAll || contains(runModules, tag);

rootDir = fileparts(mfilename('fullpath'));
addpath(genpath(rootDir));

fprintf('==================================================\n');
fprintf('  Reviewer Response Modules -- I-CNN MetaPicker  \n');
fprintf('  Target: Computers & Geosciences                \n');
fprintf('==================================================\n\n');

config  = config_ICNN_MetaPicker();
modDir  = fullfile(config.outputFolder,'models');
predDir = fullfile(config.outputFolder,'predictions');
diagDir = fullfile(config.outputFolder,'diagnostics');
ablDir  = fullfile(config.outputFolder,'ablation');
benchDir= fullfile(config.outputFolder,'benchmark');
logDir  = config.outputFolder;

tStart  = tic;

%        M7: Leakage Validation (run first, always)                                                                                  
fprintf('[M7] Leakage Validation...\n');
try
    splitDir = fullfile(config.outputFolder,'splits');
    trainIds = readIds(fullfile(splitDir,'train_source_ids.csv'));
    valIds   = readIds(fullfile(splitDir,'val_source_ids.csv'));
    testIds  = readIds(fullfile(splitDir,'test_source_ids.csv'));
    validateNoLeakage(trainIds, valIds, testIds);
catch ME
    fprintf('  [WARN] M7: %s\n', ME.message);
end

%        Load shared resources                                                                                                                                                    
fprintf('\n[Load] Loading shared resources...\n');
[data, ~] = loadDatasetFromMetadata(config);
rng(config.randomSeed,'twister');
[trainData, valData, testData] = splitBySourceID(data, config);
trainData = applyPreprocessing(trainData, config);
valData   = applyPreprocessing(valData,   config);
testData  = applyPreprocessing(testData,  config);
trainData = addGaussianLabels(trainData, config);
valData   = addGaussianLabels(valData,   config);
trainDataAug = augmentTrainingWaveform(trainData, config);

% Load base models
basePath = fullfile(modDir,'trained_base_models','base_models_final.mat');
if isfile(basePath)
    Sb = load(basePath); fb=fieldnames(Sb); baseModels=Sb.(fb{1});
    metaTestFeat = buildMetaFeatureFromModels(testData, baseModels, config);
    metaTrainFeat= buildMetaFeatureFromModels(trainDataAug, baseModels, config);
    metaValFeat  = buildMetaFeatureFromModels(valData, baseModels, config);
else
    error('[FATAL] base_models_final.mat not found. Run run_experiment_full3C_STEAD first.');
end

% Load I-CNN model
icnnPath = fullfile(modDir,'trained_ICNN_meta_learner','model_ICNN_meta.mat');
if isfile(icnnPath)
    Si=load(icnnPath); fi=fieldnames(Si); icnnModel=Si.(fi{1});
else
    icnnModel = [];
    fprintf('[WARN] model_ICNN_meta.mat not found. M1/M2 will be limited.\n');
end

% Load predictions
predFull = loadCSV(fullfile(predDir,'predictions_full3C.csv'));
predZ    = loadCSV(fullfile(predDir,'predictions_Zonly.csv'));

%        M5: Extended Diagnostics                                                                                                                                           
if shouldRun('M5')
    fprintf('\n[M5] Extended Diagnostics (skewness, kurtosis, P90/P95)...\n');
    try
        cfgD = config;
        cfgD.outputDiagnosticsFolder = diagDir;
        if ~isempty(predFull)
            computeExtendedDiagnostics(predFull,'Full3C',cfgD);
        end
        if ~isempty(predZ)
            computeExtendedDiagnostics(predZ,'Zonly',cfgD);
        end
    catch ME; fprintf('  [WARN] M5: %s\n', ME.message); end
end

%        M6: Stratified Analysis                                                                                                                                              
if shouldRun('M6')
    fprintf('\n[M6] Stratified Analysis (magnitude, distance, SNR, SP time)...\n');
    try
        meta = loadMeta(config);
        if ~isempty(predFull) && ~isempty(meta)
            predFull = joinPredictionsWithMetadata(predFull, meta, config);
        end
        if ~isempty(predFull)
            computeDatasetStratifiedAnalysis(predFull, diagDir, config);
        end
    catch ME; fprintf('  [WARN] M6: %s\n', ME.message); end
end

%        M2: Physics-Aware Ablation                                                                                                                                     
if shouldRun('M2') && ~isempty(icnnModel)
    fprintf('\n[M2] Physics-Aware Picker Ablation...\n');
    try
        ensureDir(ablDir);
        runPhysicsAwareAblation(icnnModel, metaTestFeat, testData, config);
    catch ME; fprintf('  [WARN] M2: %s\n', ME.message); end
end

%        M3: Base Picker Ablation                                                                                                                                           
if shouldRun('M3')
    fprintf('\n[M3] Base Picker Ablation (each picker removed)...\n');
    fprintf('  NOTE: M3 requires retraining I-CNN 4 times (~70 min GPU).\n');
    fprintf('  Skipping in this run. To run: >> runBasePickerAblation(trainData,valData,testData,config)\n');
end

%        M1: Meta-Learner Benchmark                                                                                                                                     
if shouldRun('M1')
    fprintf('\n[M1] Meta-Learner Benchmark...\n');
    try
        ensureDir(benchDir);
        % Mean ensemble (no training)
        gt   = buildGT(testData);
        N    = numel(testData);
        tolMs= config.toleranceMs;

        fprintf('  Running Mean Ensemble...\n');
        picks1 = runMeanEnsemble(metaTestFeat, config);
        picks1 = fillErrors(picks1, gt);

        fprintf('  Running Logistic Regression...\n');
        trainLbl = cellfun(@(d) single(d.label), num2cell(trainDataAug), 'UniformOutput',false);
        [picks3,~] = runLogisticMetaLearner(metaTrainFeat, trainLbl, metaTestFeat, config);
        picks3 = fillErrors(picks3, gt);

        % Build benchmark table
        benchRows = {};
        benchRows{1} = evalBench(picks1, gt, N, tolMs, 'Mean Ensemble');
        benchRows{2} = evalBench(picks3, gt, N, tolMs, 'Logistic Regression');
        if ~isempty(icnnModel)
            pI = predictICNNMetaLearner(icnnModel, metaTestFeat, config);
            picksI = physicsAwarePicker(pI, config);
            picksI = fillErrors(picksI, gt);
            benchRows{3} = evalBench(picksI, gt, N, tolMs, 'I-CNN (proposed)');
        end
        benchT = vertcat(benchRows{:});
        writetable(benchT, fullfile(benchDir,'benchmark_summary.csv'));
        fprintf('  Saved: benchmark_summary.csv\n');
        printBenchmark(benchT);
    catch ME; fprintf('  [WARN] M1: %s\n', ME.message); end
end

%        M9: Log this run                                                                                                                                                                
totalTime = toc(tStart);
fprintf('\n[M9] Logging experiment...\n');
try
    metrics = loadCSV(fullfile(config.outputFolder,'metrics','metrics_full3C.csv'));
    logExperiment('reviewer_modules', config, metrics, totalTime, logDir);
catch ME; fprintf('  [WARN] M9: %s\n', ME.message); end

fprintf('\n==================================================\n');
fprintf('  Reviewer modules complete (%.1f min)\n', totalTime/60);
fprintf('  Outputs:\n');
fprintf('    results/benchmark/benchmark_summary.csv\n');
fprintf('    results/ablation/physics_ablation.csv\n');
fprintf('    results/diagnostics/extended/prediction_diagnostics_*.csv\n');
fprintf('    results/diagnostics/dataset_diagnostics.csv\n');
fprintf('    experiment_log.txt\n');
fprintf('==================================================\n');
end

%        Helpers                                                                                                                                                                                              
function r = evalBench(picks, gt, N, tolMs, name)
errP=[picks.p_error_ms]'; errS=[picks.s_error_ms]';
r=table(); r.Method={name};
for comp={'P','S'}
    c=comp{1}; err=ternary(strcmp(c,'P'),errP,errS);
    absE=abs(err(~isnan(err))); ev=err(~isnan(err)); nD=numel(ev);
    if nD==0; mae=NaN;med=NaN;dr=0;oR=NaN;f1s=nan(1,numel(tolMs));
    else
        mae=mean(absE);med=median(absE);dr=nD/N;oR=mean(absE>1000);
        f1s=zeros(1,numel(tolMs));
        for ti=1:numel(tolMs)
            tol=tolMs(ti);TP=sum(absE<=tol);FP=sum(absE>tol);FN=N-nD;
            pr=TP/max(1,TP+FP);rc=TP/max(1,TP+FN);
            f1s(ti)=2*pr*rc/max(1e-10,pr+rc);
        end
    end
    sfx=['_' c];
    r.(['MAE_ms' sfx])=mae;r.(['MedAE_ms' sfx])=med;
    r.(['DetRate' sfx])=dr;r.(['OutlierRate' sfx])=oR;
    for ti=1:numel(tolMs);r.(sprintf('F1_%dms%s',tolMs(ti),sfx))=f1s(ti);end
end
end

function printBenchmark(t)
fprintf('\n  %-25s %8s %8s %8s %8s\n','Method','F1@100_P','F1@100_S','MAE_P','MAE_S');
fprintf('  %s\n',repmat('-',1,60));
for i=1:height(t)
    fprintf('  %-25s %8.3f %8.3f %8.1f %8.1f\n',t.Method{i},...
        gv(t,i,'F1_100ms_P'),gv(t,i,'F1_100ms_S'),...
        gv(t,i,'MAE_ms_P'),gv(t,i,'MAE_ms_S'));
end
end

function ids = readIds(csvPath)
ids = {};
if ~isfile(csvPath); return; end
t = readtable(csvPath,'VariableNamingRule','preserve');
if height(t)>0; ids=cellstr(string(t{:,1})); end
end

function gt = buildGT(data)
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

function picks=fillErrors(picks,gt)
for i=1:numel(picks)
    if ~isnan(picks(i).p_pick_sec)&&~isnan(gt(i).p_arrival_sec)
        picks(i).p_error_ms=(picks(i).p_pick_sec-gt(i).p_arrival_sec)*1000;
    else;picks(i).p_error_ms=NaN;end
    if ~isnan(picks(i).s_pick_sec)&&~isnan(gt(i).s_arrival_sec)
        picks(i).s_error_ms=(picks(i).s_pick_sec-gt(i).s_arrival_sec)*1000;
    else;picks(i).s_error_ms=NaN;end
end
end

function t=loadCSV(p)
t=table();
if isfile(p);try;t=readtable(p,'VariableNamingRule','preserve');catch;end;end
end

function meta=loadMeta(config)
meta=table();
for p={config.metadataPath,...
        fullfile('metadata','metadata_master_filled.csv'),...
        fullfile('metadata','metadata_master_filled.xlsx')}
    if isfile(p{1})
        try;meta=readtable(p{1},'VariableNamingRule','preserve');return;catch;end
    end
end
end

function v=gv(t,row,col);v=NaN;if any(strcmp(t.Properties.VariableNames,col));v=t.(col)(row);end;end
function out=ternary(c,a,b);if c;out=a;else;out=b;end;end
function ensureDir(d);if ~isempty(d)&&~isfolder(d);mkdir(d);end;end
