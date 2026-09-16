function run_phasenet_matched(sourceRoot,runRoot,mode,seed,executionEnvironment)
if nargin<5;executionEnvironment='gpu';end
assert(ismember(string(mode),["Full3C","Zonly"])&&ismember(seed,42:44));
packageRoot=fileparts(mfilename('fullpath'));
addpath(fullfile(packageRoot,'clean'),fullfile(packageRoot,'config'),genpath(fullfile(packageRoot,'src')));
sourceRoot=char(java.io.File(sourceRoot).getCanonicalPath());
runRoot=char(java.io.File(runRoot).getCanonicalPath());
assert(~startsWith(lower(runRoot),lower(sourceRoot)) && ~contains(lower(runRoot),'submission40'));
if ~isfolder(runRoot);mkdir(runRoot);end
cfg=config_ICNN_MetaPicker();cfg.outputFolder=runRoot;
cfg.metadataPath=fullfile(sourceRoot,'metadata','metadata_master_2234_final.xlsx');
cfg.csvFolder=fullfile(sourceRoot,'data','csv_stead_filtered');cfg.filterExistingCSVOnly=false;
cfg.executionEnvironment=char(executionEnvironment);cfg.useGPU=strcmpi(executionEnvironment,'gpu');
cfg.experimentMode=char(mode);cfg.cleanProtocol='phasenet_style_matched_v1';cfg.seed=seed;
cfg.phaseNetMatched=struct('maxEpochs',50,'miniBatch',2,'learningRate',5e-4,'patience',10);
signature=manifestClean(packageRoot,sourceRoot,runRoot,cfg);
diary(fullfile(runRoot,'training_log.txt'));cleanup=onCleanup(@()diary('off'));
[data,~]=loadDatasetFromMetadata(cfg);
[tr,va,te]=loadFrozenSplit(data,sourceRoot);clear data;
% Save raw test until training finishes to reduce retained memory.
save(fullfile(runRoot,'test_work.mat'),'te','-v7.3');clear te;
tr=prepareMode(tr,cfg);va=prepareMode(va,cfg);
assertDisjointSources(tr,va);tr=augmentClean(tr,cfg,4242);
% Exactly the same conditioned E/N/Z waveforms used by meta input channels 13:15.
X={tr.waveform}';Y={tr.label}';V={va.waveform}';L={va.label}';
for i=1:numel(tr);tr(i).X=[];tr(i).waveform=[];tr(i).sec=[];tr(i).label=[];end
for i=1:numel(va);va(i).X=[];va(i).waveform=[];va(i).sec=[];va(i).label=[];end
id=string(mode)+"_PhaseNetMatched_fold-1_seed"+seed;
job=table(id,string(mode),"PhaseNetMatched",seed,-1,'VariableNames',{'id','mode','kind','seed','fold'});
model=fitPhaseNetJob(job,X,Y,V,L,cfg,tr,va,signature,runRoot);
clear X Y V L tr va;
load(fullfile(runRoot,'test_work.mat'),'te');te=prepareMode(te,cfg);
assert(isempty(intersect(model.trainSources,string({te.source_id})')));
assert(isempty(intersect(model.valSources,string({te.source_id})')));
curves=predictCurves(model,{te.waveform}',cfg);
exportClean(curves,te,cfg,fullfile(runRoot,string(mode),'evaluation'),"PhaseNetMatched_seed"+seed);
writeStrengtheningLedger(runRoot,job);
end
