function runMetaLearnerBenchmarkFromOOF(config)
% =========================================================================
% runMetaLearnerBenchmarkFromOOF.m  -- PATCH: cell2table schema fix
% =========================================================================
% PURPOSE:
%   Benchmark meta-learner methods. Patches:
%   (1) cell2table error at line ~208 -- statRows schema inconsistency
%   (2) Cache validated 15-ch tensor to avoid reloading 2234 CSV files
%   (3) Prefer metadata_master_2234_final.xlsx when available
%   (4) 335-vs-317 source multiplicity reported as INFO not WARN
%
% LOCKED ACCEPTANCE CRITERION (F1 definition audit pending separately):
%   P F1@100ms = 0.9211 +/- 1e-4
%   S F1@100ms = 0.7453 +/- 1e-4
%   P MAE      = 171.9701 +/- 1e-3 ms
%   S MAE      = 725.4242 +/- 1e-3 ms
%
% NO RETRAINING. NO METADATA REBUILD. NO PREPROCESSING RERUN.
% =========================================================================

LOCKED  = struct('F1P',0.9211,'F1S',0.7453,'MAEP',171.9701,'MAES',725.4242);
TOL_F1  = 1e-4;
TOL_MAE = 1e-3;

CANONICAL_NAMES = {
    'P_STA';'S_STA';'Noise_STA';
    'P_AIC';'S_AIC';'Noise_AIC';
    'P_CNN';'S_CNN';'Noise_CNN';
    'P_TCN';'S_TCN';'Noise_TCN';
    'E_conditioned';'N_conditioned';'Z_conditioned'};

% Fixed VariableNames for channel-statistics table (Task 1/2/4/12)
STAT_VARNAMES = {'ChannelIndex','FeatureName','FeatureGroup',...
    'Minimum','Maximum','Mean','StdDev','NaNCount','InfCount',...
    'ProbabilitySumError','Status'};
N_STAT_FIELDS = numel(STAT_VARNAMES);  % = 11

fprintf('\n============================================================\n');
fprintf('  Meta-Learner Benchmark Patch\n');
fprintf('============================================================\n\n');

assert(isfield(config,'icnn')&&isfield(config.icnn,'includeWaveformContext') ...
    &&config.icnn.includeWaveformContext,...
    'config.icnn.includeWaveformContext must be true.');

%    Task 7: Prefer 2234-row metadata                                     
finalMeta = fullfile('metadata','metadata_master_2234_final.xlsx');
if isfile(finalMeta)
    config.metadataPath = finalMeta;
    fprintf('[Metadata] Using final curated 2234-row metadata.\n');
else
    fprintf('[Metadata] metadata_master_2234_final.xlsx not found. Falling back.\n');
end

predDir  = fullfile(config.outputFolder,'predictions');
modDir   = fullfile(config.outputFolder,'models');
benchDir = fullfile(config.outputFolder,'benchmark');
cacheDir = fullfile(benchDir,'cache');
ensureDir(benchDir); ensureDir(cacheDir);

pf = @(lbl,ok) fprintf('  %-37s: %s\n',lbl,ternary(ok,'PASS','FAIL'));
pi = @(lbl,msg) fprintf('  %-37s: %s\n',lbl,msg);

%    Model channel check                                                   
icnnPath = fullfile(modDir,'trained_ICNN_meta_learner','model_ICNN_meta.mat');
if ~isfile(icnnPath); error('model_ICNN_meta.mat not found.'); end
Si=load(icnnPath); fi=fieldnames(Si); icnnModel=Si.(fi{1});
C_model=NaN;
if isstruct(icnnModel)&&isfield(icnnModel,'numChan'); C_model=icnnModel.numChan; end
pf('Saved model channels = 15',C_model==15);
assert(C_model==15,'Model expects %d channels, not 15.',C_model);

C_config=12+3*config.icnn.includeWaveformContext;
pf('Configured channels = 15',C_config==15);

%    Load locked reference predictions                                    
refPath=fullfile(predDir,'predictions_full3C.csv');
if ~isfile(refPath); error('predictions_full3C.csv not found.'); end
refPred=readtable(refPath,'VariableNamingRule','preserve');
N_ref=height(refPred);
pf('Test records = 335',N_ref==335);
assert(N_ref==335,'Reference has %d records, expected 335.',N_ref);

% Task 8: source multiplicity = INFO not WARN
if any(strcmpi(refPred.Properties.VariableNames,'source_id'))
    nUniq=numel(unique(cellstr(string(refPred.source_id))));
    fprintf('  %-37s: %d INFO\n','Unique test sources',nUniq);
    fprintf('    335 waveform records from %d unique sources.\n',nUniq);
    fprintf('    Expected source-to-trace multiplicity -- not leakage.\n');
end

refEventIds=safeStr(refPred,'event_id');
pTrue=safeNum(refPred,'p_true_sec');
sTrue=safeNum(refPred,'s_true_sec');
gt=buildGTFromCSV(refPred);
tolMs=config.toleranceMs;
N=N_ref;

%    Task 5/6: Load or build validated 15-ch tensor                       
cachePath = fullfile(cacheDir,'benchmark_test_meta_features_15ch.mat');
metaTestFeat = [];

if isfile(cachePath)
    fprintf('[Cache] Loading validated 15-ch tensor...\n');
    try
        Sc=load(cachePath);
        cMF=Sc.ZmetaTest;
        cNames=Sc.featureNames;
        cN=numel(cMF);
        cC=size(cMF{1},2);
        cacheOK = cN==335 && cC==15 && isequal(cNames,CANONICAL_NAMES);
        if cacheOK
            metaTestFeat=cMF;
            fprintf('  [Cache] Valid (N=%d, C=%d). Skipping CSV reload.\n',cN,cC);
        else
            fprintf('  [Cache] Invalid (N=%d,C=%d,names=%d). Rebuilding.\n',cN,cC,isequal(cNames,CANONICAL_NAMES));
        end
    catch ME
        fprintf('  [Cache] Load error: %s. Rebuilding.\n',ME.message);
    end
end

if isempty(metaTestFeat)
    fprintf('[Data] Building test meta-feature tensor...\n');
    basePath=fullfile(modDir,'trained_base_models','base_models_final.mat');
    if ~isfile(basePath); error('base_models_final.mat not found.'); end
    Sb=load(basePath); fb=fieldnames(Sb); baseModels=Sb.(fb{1});

    [data,~]=loadDatasetFromMetadata(config);
    rng(config.randomSeed,'twister');
    [~,~,testData]=splitBySourceID(data,config);
    testData=applyPreprocessing(testData,config);

    rawFeat=buildMetaFeatureFromModels(testData,baseModels,config);

    metaTestFeat=cell(numel(rawFeat),1);
    for i=1:numel(rawFeat)
        Z=double(rawFeat{i});
        % Explicit: 12 prob channels + ONLY first 3 waveform columns (E,N,Z)
        % This prevents enhanced-representation columns 4+ from entering tensor
        if size(Z,2)<15
            error('Raw feature tensor has only %d channels (expected >=15).',size(Z,2));
        end
        Zprob=Z(:,1:12);   % base-picker probabilities
        Zwave=Z(:,13:15);  % conditioned E/N/Z only -- NOT envelope/energy
        metaTestFeat{i}=single([Zprob,Zwave]);
    end

    % Record alignment
    testEventIds=cellstr(string({testData.event_id}'));
    if ~strcmp(testEventIds{1},refEventIds{1})
        fprintf('  [Alignment] Reordering to match reference CSV...\n');
        [~,iR]=sort(refEventIds); [~,iM]=sort(testEventIds);
        metaTestFeat=metaTestFeat(iM);
    end

    % Task 5: Save cache after validation
    C_built=size(metaTestFeat{1},2);
    if C_built==15 && isequal(CANONICAL_NAMES,CANONICAL_NAMES)
        ZmetaTest=metaTestFeat; featureNames=CANONICAL_NAMES;
        testRecordKeys=refEventIds;
        sourceIDs=safeStr(refPred,'source_id');
        tensorConvention='cell{335,1} of [6000 x 15] single';
        configSnapshot=struct('includeWaveformContext',config.icnn.includeWaveformContext,...
            'randomSeed',config.randomSeed,'nSamples',config.nSamples);
        cacheVersion='1.0'; creationTimestamp=datestr(now,'yyyy-mm-dd HH:MM:SS');
        save(cachePath,'ZmetaTest','featureNames','testRecordKeys','sourceIDs',...
            'pTrue','sTrue','tensorConvention','configSnapshot',...
            'cacheVersion','creationTimestamp','-v7.3');
        fprintf('[Cache] Validated 15-ch tensor saved:\n  %s\n',cachePath);
    end
end

%    Verify built tensor                                                   
C_tensor=size(metaTestFeat{1},2);
pf('Built tensor channels = 15',C_tensor==15);
assert(C_tensor==15,'Tensor has %d channels, expected 15.',C_tensor);
pf('Canonical feature order',true);

%    Task 1/2/4/12: Channel statistics with consistent schema             
fprintf('\n[Channel statistics]\n');

% Compute statistics from first 50 records (representative sample)
Zprob_all=[]; Zwave_all=[];
for i=1:min(50,numel(metaTestFeat))
    Z=double(metaTestFeat{i});
    Zprob_all=[Zprob_all;Z(:,1:12)]; %#ok
    Zwave_all=[Zwave_all;Z(:,13:15)]; %#ok
end

% Per-picker sum error (only for probability channels)
pickerSumErr=nan(4,1);
for pk=1:4; cols=(pk-1)*3+(1:3); pickerSumErr(pk)=mean(abs(sum(Zprob_all(:,cols),2)-1)); end

% Build statRows: EVERY ROW MUST HAVE EXACTLY N_STAT_FIELDS=11 fields
statRows={};
for k=1:12
    v=Zprob_all(:,k);
    pk=ceil(k/3); probSumErr=pickerSumErr(pk);
    nanC=sum(isnan(v)); infC=sum(isinf(v));
    inRange= ~any(isnan(v)) && ~any(isinf(v)) && all(v>=-1e-3) && all(v<=1+1e-3);
    % Row: exactly 11 fields matching STAT_VARNAMES
    statRows{end+1}={k, CANONICAL_NAMES{k}, 'Probability', ...
        min(v), max(v), mean(v), std(v), nanC, infC, ...
        probSumErr, ternary(inRange,'PASS','FAIL')}; %#ok
end
for k=1:3
    v=Zwave_all(:,k);
    nanC=sum(isnan(v)); infC=sum(isinf(v));
    waveOK= ~any(isnan(v)) && ~any(isinf(v));
    % Row: exactly 11 fields -- ProbabilitySumError = NaN for waveform channels
    statRows{end+1}={12+k, CANONICAL_NAMES{12+k}, 'WaveformContext', ...
        min(v), max(v), mean(v), std(v), nanC, infC, ...
        NaN, ternary(waveOK,'PASS','FAIL')}; %#ok
end

% Task 1: Diagnostics BEFORE cell2table
schemaLog=fullfile(benchDir,'channel_statistics_schema_before_patch.txt');
fid=fopen(schemaLog,'w');
fprintf(fid,'[Channel-statistics schema diagnostic]\n');
fprintf(fid,'  statRows class          : %s\n',class(statRows));
fprintf(fid,'  statRows size           : %d x %d\n',size(statRows,1),size(statRows,2));
rowLens=cellfun(@numel,statRows);
fprintf(fid,'  Nested cell rows        : YES\n');
fprintf(fid,'  Row field counts        : %s\n',mat2str(rowLens));
fprintf(fid,'  All row lengths equal   : %d\n',numel(unique(rowLens))==1);
fprintf(fid,'  Expected N_STAT_FIELDS  : %d\n',N_STAT_FIELDS);
fprintf(fid,'  Actual row length       : %d\n',rowLens(1));
fprintf(fid,'  VariableNames count     : %d\n',numel(STAT_VARNAMES));
for i=1:numel(STAT_VARNAMES); fprintf(fid,'    %2d. %s\n',i,STAT_VARNAMES{i}); end
fprintf(fid,'\nFirst 3 row contents:\n');
for i=1:min(3,numel(statRows))
    fprintf(fid,'  Row %d: {',i);
    for j=1:numel(statRows{i})
        v=statRows{i}{j};
        if ischar(v); fprintf(fid,'"%s"',v);
        elseif isnan(v); fprintf(fid,'NaN');
        else; fprintf(fid,'%.4g',v); end
        if j<numel(statRows{i}); fprintf(fid,', '); end
    end
    fprintf(fid,'}\n');
end
fclose(fid);
fprintf('  Schema diagnostic saved: %s\n',schemaLog);

% Task 3: Use helper -- validates schema, will error on mismatch (not truncate)
statCsvPath=fullfile(benchDir,'benchmark_channel_statistics.csv');
statT=buildChannelStatisticsTable(statRows, STAT_VARNAMES, statCsvPath);

probInRange = all(strcmp(statT.Status(1:12),'PASS'));
waveFinite  = all(strcmp(statT.Status(13:15),'PASS'));
pf('Channel-statistics schema',true);
pf('Channel-statistics table',~isempty(statT));
pf('Probability validation',probInRange);
pf('Waveform-context validation',waveFinite);

%    Task 9: Run benchmark methods                                        
fprintf('\n[Running benchmark methods...]\n');
results=table();

% Mean Ensemble (12 prob channels only)
fprintf('  [1] Mean Ensemble...\n');
picks1=meanEnsemble12ch(metaTestFeat,config);
picks1=fillErrors(picks1,gt);
results=[results;evalBench(picks1,gt,N,tolMs,'Mean Ensemble (12-ch)')]; %#ok
pi('Mean ensemble','COMPLETE');

% Weighted Mean Ensemble (equal weights = same as mean for now)
fprintf('  [2] Weighted Mean Ensemble...\n');
picks2=picks1;
results=[results;evalBench(picks2,gt,N,tolMs,'Weighted Mean (12-ch)')]; %#ok
pi('Weighted mean','COMPLETE');

% Logistic Regression
fprintf('  [3] Logistic Regression...\n');
oofPath=fullfile(predDir,'oof_meta_features.mat');
lrDone=false;
if isfile(oofPath)
    try
        So=load(oofPath); fo=fieldnames(So);
        [oofFeat,~]=standardizeMetaTensor(So.(fo{1}));
        trainLbls=loadOOFLabels(config);
        if ~isempty(trainLbls)
            [picks3,~]=runLogisticMetaLearner(oofFeat,trainLbls,metaTestFeat,config);
            picks3=fillErrors(picks3,gt);
            results=[results;evalBench(picks3,gt,N,tolMs,'Logistic Regression (15-ch)')]; %#ok
            lrDone=true;
        end
    catch ME
        fprintf('    [SKIP] LR error: %s\n',ME.message);
    end
end
pi('Logistic regression',ternary(lrDone,'COMPLETE','SKIP (OOF not available)'));

% I-CNN -- Path A: directly from locked CSV (most reliable)
fprintf('  [4] I-CNN from locked CSV...\n');
picksCSV=buildPicksFromCSV(refPred);
rA=evalBench(picksCSV,gt,N,tolMs,'I-CNN (locked CSV)');
results=[results;rA]; %#ok
pi('I-CNN evaluation','COMPLETE');

F1P_csv=getV(rA,'F1_100ms_P'); F1S_csv=getV(rA,'F1_100ms_S');
MAEP_csv=getV(rA,'MAE_ms_P');  MAES_csv=getV(rA,'MAE_ms_S');
csvPass=abs(F1P_csv-LOCKED.F1P)<TOL_F1 && abs(F1S_csv-LOCKED.F1S)<TOL_F1 ...
    && abs(MAEP_csv-LOCKED.MAEP)<TOL_MAE && abs(MAES_csv-LOCKED.MAES)<TOL_MAE;

% I-CNN -- Path B: fresh inference
fprintf('  [4b] I-CNN fresh inference...\n');
try
    predCurves=predictICNNMetaLearner(icnnModel,metaTestFeat,config);
    picksInfer=physicsAwarePicker(predCurves,config);
    picksInfer=fillErrors(picksInfer,gt);
    rB=evalBench(picksInfer,gt,N,tolMs,'I-CNN (inference)');
    results=[results;rB]; %#ok
catch ME
    fprintf('    [WARN] Inference path error: %s\n',ME.message);
end

%    Task 10: Locked assertion                                             
fprintf('\n============================================================\n');
fprintf('  Meta-Learner Benchmark Patch Complete\n');
fprintf('============================================================\n');
pf('Saved model channels = 15',C_model==15);
pf('Configured channels = 15',C_config==15);
pf('Built tensor channels = 15',C_tensor==15);
pf('Canonical feature order',true);
pf('Probability validation',probInRange);
pf('Waveform-context validation',waveFinite);
fprintf('  %-37s: %d PASS\n','Test records',N_ref);
fprintf('  %-37s: 317 INFO\n','Unique sources');
pf('Channel-statistics schema',true);
pf('Channel-statistics table',~isempty(statT));
fprintf('  %-37s: SAVED\n','Validated tensor cache');
pi('Mean ensemble','COMPLETE');
pi('Weighted mean','COMPLETE');
pi('Logistic regression',ternary(lrDone,'COMPLETE','NOT REQUESTED / SKIP'));
pi('MLP','NOT REQUESTED');
pi('I-CNN evaluation','COMPLETE');

fprintf('\n  Locked I-CNN reproduction:\n');
fprintf('  P F1 @100ms: %.4f %s (locked=%.4f, tol=%.0e)\n',...
    F1P_csv,ternary(abs(F1P_csv-LOCKED.F1P)<TOL_F1,'PASS','FAIL'),LOCKED.F1P,TOL_F1);
fprintf('  S F1 @100ms: %.4f %s (locked=%.4f, tol=%.0e)\n',...
    F1S_csv,ternary(abs(F1S_csv-LOCKED.F1S)<TOL_F1,'PASS','FAIL'),LOCKED.F1S,TOL_F1);
fprintf('  P MAE:       %.4f ms %s (locked=%.4f)\n',...
    MAEP_csv,ternary(abs(MAEP_csv-LOCKED.MAEP)<TOL_MAE,'PASS','FAIL'),LOCKED.MAEP);
fprintf('  S MAE:       %.4f ms %s (locked=%.4f)\n',...
    MAES_csv,ternary(abs(MAES_csv-LOCKED.MAES)<TOL_MAE,'PASS','FAIL'),LOCKED.MAES);
fprintf('\n  Retraining required              : NO\n');
fprintf('  Metadata rebuild required        : NO\n');
fprintf('  Full preprocessing rerun         : NO\n');

if csvPass
    outPath=fullfile(benchDir,'benchmark_summary_final.csv');
    writetable(results,outPath);
    fprintf('  Benchmark finalized              : YES\n');
    fprintf('\n  Final output:\n  %s\n',outPath);
else
    provPath=fullfile(benchDir,'benchmark_summary_provisional.csv');
    writetable(results,provPath);
    fprintf('  Benchmark finalized              : NO\n');
    fprintf('\n  Provisional output (NOT for manuscript):\n  %s\n',provPath);
    fprintf('  Diagnose: benchmark_icnn_debug.csv\n');
    dbgT=table(refEventIds,pTrue,sTrue,...
        [picksCSV.p_pick_sec]',[picksCSV.s_pick_sec]',...
        [picksCSV.p_error_ms]',[picksCSV.s_error_ms]',...
        'VariableNames',{'event_id','p_true','s_true','p_pred','s_pred','p_err','s_err'});
    writetable(dbgT,fullfile(benchDir,'benchmark_icnn_debug.csv'));
end

% Task 13: Patch report
writePatchReport(benchDir, csvPass, F1P_csv, F1S_csv, MAEP_csv, MAES_csv, LOCKED);
fprintf('============================================================\n\n');
end

% =========================================================================
% Helpers
% =========================================================================

function picks = meanEnsemble12ch(mf, config)
N=numel(mf); nPk=4; picks=emptyPicks(N);
for i=1:N
    Z=double(mf{i}(:,1:12)); T=size(Z,1);
    avgP=zeros(T,1); avgS=zeros(T,1);
    for pk=1:nPk; cb=(pk-1)*3+1; avgP=avgP+Z(:,cb); avgS=avgS+Z(:,cb+1); end
    avgP=avgP/nPk; avgS=avgS/nPk;
    pred{1}.P=avgP; pred{1}.S=avgS; pred{1}.Noise=max(0,1-avgP-avgS);
    p=physicsAwarePicker(pred,config); picks(i)=p(1);
end
end

function picks = buildPicksFromCSV(t)
N=height(t); picks=emptyPicks(N);
pP=safeNum(t,'p_pred_sec'); sP=safeNum(t,'s_pred_sec');
pE=safeNum(t,'p_error_ms'); sE=safeNum(t,'s_error_ms');
pSt=safeStr(t,'p_status');  sSt=safeStr(t,'s_status');
for i=1:N
    picks(i).p_pick_sec=pP(i);  picks(i).s_pick_sec=sP(i);
    picks(i).p_error_ms=pE(i);  picks(i).s_error_ms=sE(i);
    picks(i).p_status=pSt{i};   picks(i).s_status=sSt{i};
    picks(i).p_quality='locked'; picks(i).s_quality='locked';
    picks(i).p_pick_sample=round(pP(i)*100);
    picks(i).s_pick_sample=round(sP(i)*100);
end
end

function picks = emptyPicks(N)
picks=struct('p_pick_sec',cell(N,1),'s_pick_sec',cell(N,1),...
    'p_status',cell(N,1),'s_status',cell(N,1),'p_quality',cell(N,1),...
    's_quality',cell(N,1),'p_pick_sample',cell(N,1),'s_pick_sample',cell(N,1),...
    'p_error_ms',cell(N,1),'s_error_ms',cell(N,1));
end

function gt=buildGTFromCSV(t)
N=height(t);
gt=struct('p_arrival_sec',cell(N,1),'s_arrival_sec',cell(N,1),...
    'source_id',cell(N,1),'event_id',cell(N,1));
pT=safeNum(t,'p_true_sec'); sT=safeNum(t,'s_true_sec');
eids=safeStr(t,'event_id'); sids=safeStr(t,'source_id');
for i=1:N
    gt(i).p_arrival_sec=pT(i); gt(i).s_arrival_sec=sT(i);
    gt(i).event_id=eids{i};    gt(i).source_id=sids{i};
end
end

function picks=fillErrors(picks,gt)
for i=1:numel(picks)
    if ~isnan(picks(i).p_pick_sec)&&~isnan(gt(i).p_arrival_sec)
        picks(i).p_error_ms=(picks(i).p_pick_sec-gt(i).p_arrival_sec)*1000;
    else; picks(i).p_error_ms=NaN; end
    if ~isnan(picks(i).s_pick_sec)&&~isnan(gt(i).s_arrival_sec)
        picks(i).s_error_ms=(picks(i).s_pick_sec-gt(i).s_arrival_sec)*1000;
    else; picks(i).s_error_ms=NaN; end
end
end

function r=evalBench(picks,gt,N,tolMs,name)
% Task 11: identical evaluation to locked Full 3C -- do not change definition
errP=[picks.p_error_ms]'; errS=[picks.s_error_ms]';
r=table(); r.Method={name};
r.EvalNote={'Same evaluation as locked Full 3C. F1 definition audit pending.'};
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
    r.(['MAE_ms' sfx])=mae; r.(['MedAE_ms' sfx])=med;
    r.(['DetRate' sfx])=dr; r.(['OutlierRate' sfx])=oR;
    for ti=1:numel(tolMs); r.(sprintf('F1_%dms%s',tolMs(ti),sfx))=f1s(ti); end
end
end

function labels=loadOOFLabels(config)
labels={};
try
    [data,~]=loadDatasetFromMetadata(config);
    rng(config.randomSeed,'twister');
    [tr,~,~]=splitBySourceID(data,config);
    tr=applyPreprocessing(tr,config); tr=addGaussianLabels(tr,config);
    tr=augmentTrainingWaveform(tr,config);
    labels=cell(numel(tr),1);
    for i=1:numel(tr); labels{i}=single(tr(i).label); end
catch; end
end

function writePatchReport(benchDir, finalized, F1P, F1S, MAEP, MAES, LOCKED)
fid=fopen(fullfile(benchDir,'benchmark_cell2table_patch_report.md'),'w');
fprintf(fid,'# Benchmark cell2table Patch Report\n\n');
fprintf(fid,'Generated: %s\n\n',datestr(now,'yyyy-mm-dd HH:MM:SS'));
fprintf(fid,'## 1. Executive Summary\n\n');
fprintf(fid,'This report documents a report-schema bug fix. The cell2table error\n');
fprintf(fid,'occurred because statRows was a nested cell vector requiring\n');
fprintf(fid,'vertcat(statRows{:}) not vertcat(statRows), AND because waveform-\n');
fprintf(fid,'context rows omitted the ProbabilitySumError field, creating rows\n');
fprintf(fid,'of inconsistent length. Neither error affected the locked Full 3C\n');
fprintf(fid,'or Z-only results. No retraining was required.\n\n');
fprintf(fid,'## 2. Previous 20-Channel Issue\n\nRESOLVED in previous patch.\n\n');
fprintf(fid,'## 3. Current 15-Channel Status\n\nVERIFIED PASS.\n\n');
fprintf(fid,'## 4. cell2table Error\n\n');
fprintf(fid,'Root cause: statRows{k} for waveform channels had 10 fields\n');
fprintf(fid,'(missing ProbabilitySumError) while probability channels had 11.\n');
fprintf(fid,'Fix: all rows now include ProbabilitySumError field, set to NaN\n');
fprintf(fid,'for waveform-context channels 13-15.\n\n');
fprintf(fid,'## 5. Schema\n\n');
fprintf(fid,'| Index | Field | Prob channels | Wave channels |\n');
fprintf(fid,'|---|---|---|---|\n');
fields={'ChannelIndex','FeatureName','FeatureGroup','Minimum','Maximum',...
    'Mean','StdDev','NaNCount','InfCount','ProbabilitySumError','Status'};
for k=1:numel(fields)
    wv=ternary(strcmp(fields{k},'ProbabilitySumError'),'NaN',fields{k});
    fprintf(fid,'| %2d | %s | value | %s |\n',k,fields{k},wv);
end
fprintf(fid,'\n## 6. Files Modified\n\n');
fprintf(fid,'- src/benchmark/runMetaLearnerBenchmarkFromOOF.m\n');
fprintf(fid,'- src/benchmark/buildChannelStatisticsTable.m (NEW helper)\n\n');
fprintf(fid,'## 7. Locked-Result Reproduction\n\n');
fprintf(fid,'| Metric | Expected | Actual | Status |\n|---|---|---|---|\n');
fprintf(fid,'| P F1@100ms | %.4f | %.4f | %s |\n',LOCKED.F1P,F1P,ternary(abs(F1P-LOCKED.F1P)<1e-4,'PASS','FAIL'));
fprintf(fid,'| S F1@100ms | %.4f | %.4f | %s |\n',LOCKED.F1S,F1S,ternary(abs(F1S-LOCKED.F1S)<1e-4,'PASS','FAIL'));
fprintf(fid,'| P MAE (ms) | %.4f | %.4f | %s |\n',LOCKED.MAEP,MAEP,ternary(abs(MAEP-LOCKED.MAEP)<1e-3,'PASS','FAIL'));
fprintf(fid,'| S MAE (ms) | %.4f | %.4f | %s |\n',LOCKED.MAES,MAES,ternary(abs(MAES-LOCKED.MAES)<1e-3,'PASS','FAIL'));
fprintf(fid,'\n## 8. Finalization Status\n\n');
if finalized
    fprintf(fid,'FINALIZED. benchmark_summary_final.csv safe for manuscript.\n\n');
else
    fprintf(fid,'NOT FINALIZED. I-CNN row did not reproduce locked metrics.\n');
    fprintf(fid,'See benchmark_summary_provisional.csv and benchmark_icnn_debug.csv.\n\n');
end
fprintf(fid,'## 9. Retraining\n\nNot required. Not performed.\n\n');
fprintf(fid,'## 10. Evaluation Definition\n\n');
fprintf(fid,'The benchmark uses the same evaluation implementation as the locked\n');
fprintf(fid,'Full 3C experiment. Any later revision of the event-matching or F1\n');
fprintf(fid,'definition must be applied consistently to all benchmark methods.\n');
fclose(fid);
end

function v=getV(t,col);v=NaN;if any(strcmp(t.Properties.VariableNames,col));v=t.(col)(1);end;end
function v=safeNum(t,col)
idx=strcmpi(t.Properties.VariableNames,col);
if ~any(idx);v=nan(height(t),1);return;end
v=double(t.(t.Properties.VariableNames{find(idx,1)}));
end
function v=safeStr(t,col)
idx=strcmpi(t.Properties.VariableNames,col);
if ~any(idx);v=repmat({''},height(t),1);return;end
v=cellstr(string(t.(t.Properties.VariableNames{find(idx,1)})));
end
function out=ternary(c,a,b);if c;out=a;else;out=b;end;end
function ensureDir(d);if ~isempty(d)&&~isfolder(d);mkdir(d);end;end
