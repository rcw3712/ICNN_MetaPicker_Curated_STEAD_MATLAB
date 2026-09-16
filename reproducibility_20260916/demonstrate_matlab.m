function receipt = demonstrate_matlab(outputDir)
% Synthetic conditioning/decoder checks and checkpoint source-provenance audit.
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'matlab'));
if ~isfolder(outputDir);mkdir(outputDir);end
cfg=config_ICNN_MetaPicker();cfg.experimentMode='Zonly';cfg.executionEnvironment='cpu';
x=zeros(cfg.nSamples,3);y=conditionWaveform(x,cfg);assert(all(isfinite(y),'all') && all(y==0,'all'));
c=struct('P',zeros(cfg.nSamples,1),'S',zeros(cfg.nSamples,1),'Noise',ones(cfg.nSamples,1));
c.P(101)=0.2;c.S(111)=0.9;
a=decodeClean({c},cfg,true);assert(a.p_status=="uncertain" && abs(a.s_pred_sec-1.1)<1e-9);
c.P(:)=0;c.P(101)=0.149;
a=decodeClean({c},cfg,true);assert(a.p_status=="not_detected" && a.s_status=="not_detected");
c.P(101)=.3;c.S(:)=0;c.S(3101)=.9;
a=decodeClean({c},cfg,true);assert(abs(a.s_pred_sec-31)<1e-9);
c.S(:)=0;c.S(3102)=.9;
a=decodeClean({c},cfg,true);assert(a.s_status=="not_detected");
manifest=readtable(fullfile(root,'checkpoint_manifest.csv'),'TextType','string');
reference=readtable(fullfile(root,'expected','Stack_Full3C_base42_meta42.csv'),'TextType','string');
receipt=table();
for i=1:height(manifest)
 s=load(fullfile(root,strrep(manifest.path(i),'/',filesep)),'model');m=s.model;
 fit=unique(string(m.trainSources));validation=unique(string(m.valSources));
 assert(isempty(intersect(fit,validation)));
 assert(isempty(intersect(fit,reference.source_id)) && isempty(intersect(validation,reference.source_id)));
 expected=manifest.mode(i)+"_"+manifest.kind(i)+"_fold"+manifest.fold(i)+"_seed"+manifest.seed(i);
 assert(string(m.jobId)==expected);
 hasNetwork=isfield(m,'net') && isa(m.net,'dlnetwork');
 assert(hasNetwork || manifest.kind(i)=="logistic");
 receipt=[receipt;table(manifest.path(i),string(m.jobId),numel(fit),numel(validation),hasNetwork,'VariableNames',{'Checkpoint','JobID','FitSources','ValidationSources','NetworkLoaded'})];clear m s;
end
writetable(receipt,fullfile(outputDir,'checkpoint_source_audit.csv'));
fid=fopen(fullfile(outputDir,'synthetic_matlab_checks.txt'),'w');fprintf(fid,'PASS: zero-channel conditioning; uncertain-P gating; rejected-P gating; upper S endpoint and exclusion; 106 checkpoint identities/source memberships.\n');fclose(fid);
fprintf('PASS: %d checkpoints loaded; fit/validation/test source checks passed.\n',height(receipt));
end
