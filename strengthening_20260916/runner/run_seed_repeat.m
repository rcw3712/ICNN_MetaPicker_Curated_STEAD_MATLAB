function plan = run_seed_repeat(action,sourceRoot,runRoot,executionEnvironment,baseSeed,selectedMode)
% Default action displays one 15-fit seed/mode plan. 'train' runs/resumes it.
% Examples are in README.md. Old source/results are read-only inputs.
if nargin<1;action="plan";end
packageRoot=fileparts(mfilename('fullpath'));
addpath(fullfile(packageRoot,'clean'),fullfile(packageRoot,'config'));
addpath(genpath(fullfile(packageRoot,'src')));
if nargin<2;sourceRoot='C:\Drive E\ICNN_MetaPicker_Curated_STEAD_MATLAB';end
if nargin<3;runRoot=fullfile(fileparts(sourceRoot),'ICNN_strengthening_results','MUST_SPECIFY_RUN_ROOT');end
if nargin<4;executionEnvironment='gpu';end
if nargin<5;baseSeed=43;end
if nargin<6;selectedMode="Full3C";end
assert(ismember(baseSeed,[43 44]) && ismember(string(selectedMode),["Full3C","Zonly"]));
plan=trainingPlan40();
plan=plan(plan.mode==string(selectedMode) & (plan.fold>=0 | plan.kind=="full15ch"),:);
plan.seed(plan.fold>=0)=baseSeed;
plan.id=compose("%s_%s_fold%d_seed%d",plan.mode,plan.kind,plan.fold,plan.seed);
if strcmpi(action,'plan');disp(plan);return;end
assert(strcmpi(action,'train'),'Action must be plan or train.');
assert(ismember(string(executionEnvironment),["cpu","gpu"]));
sourceRoot=char(java.io.File(sourceRoot).getCanonicalPath());
runRoot=char(java.io.File(runRoot).getCanonicalPath());
assert(~strcmpi(runRoot,sourceRoot)&&~startsWith(lower(runRoot),[lower(sourceRoot) filesep]), ...
    'Use a separate output directory; do not write into the original project.');
assert(~contains(lower(runRoot),'submission40'),'Do not use a frozen submission40 output directory.');
if ~isfolder(runRoot);mkdir(runRoot);end
cfg=config_ICNN_MetaPicker();cfg.outputFolder=runRoot;
cfg.metadataPath=fullfile(sourceRoot,'metadata','metadata_master_2234_final.xlsx');
cfg.csvFolder=fullfile(sourceRoot,'data','csv_stead_filtered');
cfg.executionEnvironment=char(executionEnvironment);cfg.useGPU=strcmpi(executionEnvironment,'gpu');
cfg.cleanProtocol='fixed_split_base_seed_repeat_v1';
cfg.baseSeed=baseSeed;cfg.metaSeeds=42:44;cfg.selectedMode=char(selectedMode);
% Do not silently change the curated population.
cfg.filterExistingCSVOnly=false;
signature=manifestClean(packageRoot,sourceRoot,runRoot,cfg);
writetable(plan,fullfile(runRoot,'training_plan.csv'));
diary(fullfile(runRoot,'training_log.txt'));cleanup=onCleanup(@()diary('off'));
[data,~]=loadDatasetFromMetadata(cfg);
[rawTrain,rawVal,rawTest]=loadFrozenSplit(data,sourceRoot);clear data;
rawFile=fullfile(runRoot,'raw_split_work.mat');
save(rawFile,'rawTrain','rawVal','rawTest','-v7.3');
clear rawTrain rawVal rawTest;
for mode=string(selectedMode)
    c=cfg;c.experimentMode=char(mode);
    receiptFile=fullfile(runRoot,"completed_mode_"+mode+".mat");
    if isfile(receiptFile)
        receipt=load(receiptFile);assert(receipt.signature==signature);
        for r=1:height(receipt.artifacts)
            assert(sha256File(fullfile(runRoot,receipt.artifacts.relative(r)))==receipt.artifacts.hash(r));
        end
        completedJobs=plan(plan.mode==mode,:);
        for r=1:height(completedJobs)
            saved=load(fullfile(runRoot,'models',mode,completedJobs.id(r)+".mat"),'model');
            assert(saved.model.runSignature==signature && saved.model.jobId==completedJobs.id(r));
        end
        clear saved receipt completedJobs;
        fprintf('[REUSE MODE verified] %s: all models and evaluation artifacts verified.\n',mode);
        continue;
    end
    load(rawFile,'rawTrain','rawVal','rawTest');
    tr=prepareMode(rawTrain,c);clear rawTrain;
    va=prepareMode(rawVal,c);clear rawVal;
    te=prepareMode(rawTest,c);clear rawTest;
    modeDir=fullfile(runRoot,mode);if ~isfolder(modeDir);mkdir(modeDir);end
    folds=sourceFolds(tr,5,42);
    foldManifest=table(string({tr.event_id})',string({tr.source_id})',folds, ...
        'VariableNames',{'event_id','source_id','fold'});
    writetable(foldManifest,fullfile(modeDir,'oof_membership.csv'));
    for k=1:5
        remaining=tr(folds~=k);held=tr(folds==k);
        [fit,iv]=innerSourceSplit(remaining,100+k);
        assertDisjointSources(fit,iv,held,va,te);
        fit=augmentClean(fit,c,1000+k);assertDisjointSources(fit,iv,held);
        cnn=jobFit("CNN",baseSeed,k,fit,iv,{fit.X}',{fit.label}',{iv.X}',{iv.label}',c);
        tcn=jobFit("TCN",baseSeed,k,fit,iv,{fit.X}',{fit.label}',{iv.X}',{iv.label}',c);
        clear cnn tcn fit iv remaining held;
    end
    % Final bases fit all outer training records; outer validation selects checkpoint.
    finalTrain=augmentClean(tr,c,4242);assertDisjointSources(finalTrain,va,te);
    cnn=jobFit("CNN",baseSeed,0,finalTrain,va,{finalTrain.X}',{finalTrain.label}',{va.X}',{va.label}',c);
    tcn=jobFit("TCN",baseSeed,0,finalTrain,va,{finalTrain.X}',{finalTrain.label}',{va.X}',{va.label}',c);
    clear finalTrain;
    V=makeMeta(va,cnn,tcn,c);T=makeMeta(te,cnn,tcn,c);
    clear cnn tcn;
    % Store the original records temporarily, then consume one at a time.
    workFile=fullfile(modeDir,'oof_input_work.mat');
    save(workFile,'tr','folds','-v7.3');clear tr;
    [M,metaRecords]=streamOOFClean(workFile,c,mode,runRoot,signature,baseSeed);
    Y={metaRecords.label}';L={va.label}';
    trainKeys=string({metaRecords.event_id})';trainSources=string({metaRecords.source_id})';
    valKeys=string({va.event_id})';testKeys=string({te.event_id})';
    save(fullfile(modeDir,'meta_cache.mat'),'M','Y','V','L','T','trainKeys','trainSources', ...
        'valKeys','testKeys','signature','mode','-v7.3');
    exportBaselines(V,T,va,te,c,fullfile(modeDir,'baselines'));
    jobs=plan(plan.mode==mode & plan.fold==-1,:);
    for z=1:height(jobs)
        job=jobs(z,:);cc=c;channels=1:15;
        if job.kind=="probonly12";channels=1:12;end
        if job.kind=="waveonly3";channels=13:15;end
        if job.kind=="nodilation";cc.icnn.dilations=[1 1 1];end
        if isequal(channels,1:15)
            a=M;b=V;testX=T;
        else
            a=cellfun(@(x)x(:,channels),M,'UniformOutput',false);
            b=cellfun(@(x)x(:,channels),V,'UniformOutput',false);
            testX=cellfun(@(x)x(:,channels),T,'UniformOutput',false);
        end
        model=fitJob(job,a,Y,b,L,cc,metaRecords,va,signature,runRoot);
        curves=predictCurves(model,testX,cc);
        exportClean(curves,te,cc,fullfile(modeDir,'evaluation'),job.kind+"_seed"+job.seed);
        clear model a b testX curves;
    end
    clear M Y V L T metaRecords tr va te;
end
writeStrengtheningLedger(runRoot,plan);
fprintf('Completed %d planned fits for base seed %d / %s.\n',height(plan),baseSeed,selectedMode);
    function model=jobFit(kind,seed,fold,fit,validation,X,Y,V,L,c)
        job=plan(plan.mode==mode & plan.kind==kind & plan.seed==seed & plan.fold==fold,:);
        assert(height(job)==1);
        model=fitJob(job,X,Y,V,L,c,fit,validation,signature,runRoot);
    end
end

function [M,metaRecords] = streamOOFClean(workFile,c,mode,runRoot,signature,baseSeed)
s=load(workFile,'tr','folds');tr=s.tr;folds=s.folds;clear s;
N=numel(tr);factor=0;if c.useAugmentation;factor=c.augFactor;end
prototype=tr(1);prototype.X=[];prototype.waveform=[];prototype.sec=[];prototype.label=[];
metaRecords=repmat(prototype,N*(factor+1),1);M=cell(N*(factor+1),1);clear prototype;
cnn=cell(5,1);tcn=cell(5,1);
for k=1:5
    a=load(fullfile(runRoot,'models',mode,mode+"_CNN_fold"+k+"_seed"+baseSeed+".mat"),'model');
    b=load(fullfile(runRoot,'models',mode,mode+"_TCN_fold"+k+"_seed"+baseSeed+".mat"),'model');
    assert(a.model.runSignature==signature && b.model.runSignature==signature);
    assert(a.model.jobId==mode+"_CNN_fold"+k+"_seed"+baseSeed && b.model.jobId==mode+"_TCN_fold"+k+"_seed"+baseSeed);
    cnn{k}=a.model;tcn{k}=b.model;
end
clear a b;
rng(4242,'twister');
for i=1:N
    % The augmentation function visits originals in this same order in bulk.
    if c.useAugmentation
        evalc('parts=augmentTrainingWaveform(tr(i),c);');
    else
        parts=tr(i);
    end
    assert(numel(parts)==factor+1);assertRepresentation(parts,c);
    nextAugRng=rng;k=folds(i);
    assert(~ismember(string(tr(i).source_id),cnn{k}.trainSources));
    assert(~ismember(string(tr(i).source_id),tcn{k}.trainSources));
    for q=1:numel(parts)
        index=i;if q>1;index=N+(i-1)*factor+q-1;end
        one=makeMeta(parts(q),cnn{k},tcn{k},c);M{index}=one{1};
        parts(q).X=[];parts(q).waveform=[];parts(q).sec=[];
        metaRecords(index)=parts(q);
    end
    % Inference must not alter the random sequence used by augmentation.
    rng(nextAugRng);
    tr(i).X=[];tr(i).waveform=[];tr(i).sec=[];tr(i).label=[];
    clear parts one;
    if mod(i,100)==0 || i==N
        fprintf('[OOF STREAM] %s: %d/%d sources records, %d/%d meta records\n',mode,i,N,i*(factor+1),numel(M));
    end
end
assert(all(~cellfun(@isempty,M)));
end