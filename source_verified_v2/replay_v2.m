function replay_v2(wave,outputDir,stage,mode,base,maxRecords,device)
% Read-only portable replay of frozen v2 checkpoints; never trains or selects models.
% Example: replay_v2(waveDir,outDir,'test','Full3C',42,3,'gpu')
if nargin<6;maxRecords=Inf;end
if nargin<7;device='gpu';end
assert(ismember(string(stage),["test","phasenet","oof"]));
assert(ismember(string(mode),["Full3C","Zonly"]) && ismember(base,42:44));
assert(maxRecords>0 && (isinf(maxRecords)||maxRecords==floor(maxRecords)));
w=fileparts(mfilename('fullpath'));out=char(java.io.File(outputDir).getCanonicalPath());
assert(~startsWith(lower(string(out)),lower(string(w))),'Output must be outside the published package.');
if ~isfolder(out);mkdir(out);end
pkg=fullfile(w,'training');addpath(genpath(fullfile(pkg,'submission')));addpath(fullfile(pkg,'strengthening','clean'),'-end');
root=fullfile(w,'results');prep=fullfile(w,'inputs');verifiedProtocol(prep);
cfg=config_ICNN_MetaPicker();cfg.executionEnvironment=char(device);cfg.useGPU=strcmpi(device,'gpu');cfg.experimentMode=char(mode);cfg.outputFolder=out;
mode=string(mode);stage=string(stage);if cfg.useGPU;gpuDevice;end
manifest=readtable(fullfile(w,'model_manifest.csv'),'TextType','string');jobs=readtable(fullfile(w,'test_jobs.csv'),'TextType','string');
manifest.path=fullfile(w,manifest.path);jobs.expected=fullfile(w,jobs.expected);
waveHashes=readtable(fullfile(prep,'waveform_hashes.csv'),'TextType','string');
if stage~="phasenet";features=readtable(fullfile(w,'feature_hashes',mode+"_base"+base+".csv"),'TextType','string');end
opts=detectImportOptions(fullfile(prep,'partition_membership.csv'));opts=setvartype(opts,{'event_id','source_id','split'},'string');membership=readtable(fullfile(prep,'partition_membership.csv'),opts);
if base==42;runRoot=fullfile(root,'submission40');else;runRoot=fullfile(root,'strengthening',"base_"+base,mode);end
modelLoaded=table();
if stage=="oof"
 group=mode+"_base"+base+"_oof";dest=fullfile(out,group);if ~isfolder(dest);mkdir(dest);end
 ft=features(features.role=="oof",:);ft=sortrows(ft,"index");keys=ft.event_id;N=numel(keys)/2;assert(N==1544);
 foldtab=readtable(fullfile(runRoot,mode,'oof_membership.csv'),'TextType','string');cnn=cell(5,1);tcn=cell(5,1);
 for k=1:5;cnn{k}=loadModel('CNN',base,k,base);tcn{k}=loadModel('TCN',base,k,base);end
 rng(4242,'twister');rows=cell(min(N,maxRecords)*2,7);row=0;
 for i=1:min(N,maxRecords)
  savedRng=rng;r=record(keys(i));rng(savedRng);parts=[];evalc('parts=augmentTrainingWaveform(r,cfg);');nextRng=rng;assert(numel(parts)==2);
  k=foldtab.fold(foldtab.event_id==keys(i));assert(numel(k)==1);assertHeld(r,cnn{k});assertHeld(r,tcn{k});
  for q=1:2
   ix=i;if q==2;ix=N+i;end
   assert(string(parts(q).event_id)==keys(ix));fresh=makeMeta(parts(q),cnn{k},tcn{k},cfg);hash=tensorHash(fresh{1});matched=hash==ft.sha256_f32F(ix);
   row=row+1;rows(row,:)={keys(ix),string(r.source_id),k,q-1,hash,ft.sha256_f32F(ix),matched};
  end
  rng(nextRng);
  if mod(i,50)==0;fprintf('[OOF REPLAY] %s %d/%d records\n',group,i,N);end
 end
 receipt=cell2table(rows(1:row,:),'VariableNames',{'event_id','source_id','fold','augmented','ActualSHA256','ExpectedSHA256','ExactMatch'});writetable(receipt,fullfile(dest,'oof_replay_receipt.csv'));writetable(modelLoaded,fullfile(dest,'loaded_models.csv'));assert(all(receipt.ExactMatch),"Feature bytes differ: this checksum test is stricter than the numerical-tolerance audit; inspect hardware and inputs.");fprintf('PASS OOF %s %d tensors\n',group,row);return
end
if stage=="phasenet";group=mode+"_phasenet";else;group=mode+"_base"+base;end
dest=fullfile(out,group);if ~isfolder(dest);mkdir(dest);end
jj=jobs(jobs.group==group,:);assert(~isempty(jj));nets=cell(height(jj),1);
for j=1:height(jj);if ~jj.baseline(j);nets{j}=loadModel(jj.kind(j),jj.seed(j),-1,jj.base(j));end;end
if stage=="test"
 cnn=loadModel('CNN',base,0,base);tcn=loadModel('TCN',base,0,base);ft=features(features.role=="test",:);cacheKeys=ft.event_id;
 s=load(fullfile(runRoot,mode,'baselines','validation_weights.mat'),'weights');weights=s.weights;
end
ref=sortrows(membership(membership.split=="test",:),'event_id');ref=ref(1:min(height(ref),maxRecords),:);N=height(ref);constrained=cell(height(jj),N);ungated=cell(height(jj),N);stats=cell(height(jj),N);tensorDiff=zeros(N,1);
for i=1:N
 r=record(ref.event_id(i));
 if stage=="test"
  assertHeld(r,cnn);assertHeld(r,tcn);X=makeMeta(r,cnn,tcn,cfg);ix=find(cacheKeys==ref.event_id(i));assert(numel(ix)==1);tensorDiff(i)=double(tensorHash(X{1})~=ft.sha256_f32F(ix));
 end
 for j=1:height(jj)
  kind=jj.kind(j);
  if jj.baseline(j)
   names=["STA","AIC","CNN","TCN"];wi=zeros(4,2);
   if kind=="mean_ensemble";wi=ones(4,2)/4;elseif kind=="weighted_ensemble";wi=weights;else;wi(names==kind,:)=1;end
   curves=ensembleCurves(X,wi);
  else
   assertHeld(r,nets{j});
   if stage=="phasenet";input={r.waveform};else;channels=1:15;if kind=="probonly12";channels=1:12;elseif kind=="waveonly3";channels=13:15;end;input={X{1}(:,channels)};end
   curves=predictCurves(nets{j},input,cfg);
  end
  constrained{j,i}=predictionTable(decodeClean(curves,cfg,true),r);ungated{j,i}=predictionTable(decodeClean(curves,cfg,false),r);
  if kind=="full15ch" || kind=="PhaseNetMatched";stats{j,i}=thresholdStats(curves{1},r);end
 end
 if mod(i,25)==0;fprintf('[TEST REPLAY] %s %d/%d\n',group,i,N);end
end
receipts=table();
for j=1:height(jj)
 actual=vertcat(constrained{j,:});u=vertcat(ungated{j,:});expected=readPred(jj.expected(j));eu=readPred(strrep(jj.expected(j),'_predictions.csv','_unconstrained_predictions.csv'));
 receipts=[receipts;compare(actual,expected,jj.label(j),"constrained");compare(u,eu,jj.label(j),"unconstrained")];
 writetable(actual,fullfile(dest,jj.label(j)+"_replayed.csv"));writetable(u,fullfile(dest,jj.label(j)+"_unconstrained_replayed.csv"));
 if ~isempty(stats{j,1});writetable(struct2table([stats{j,:}]),fullfile(dest,jj.label(j)+"_threshold_statistics.csv"));end
end
writetable(receipts,fullfile(dest,'prediction_replay_receipt.csv'));writetable(modelLoaded,fullfile(dest,'loaded_models.csv'));writetable(table(ref.event_id,tensorDiff,'VariableNames',{'event_id','FeatureHashMismatch'}),fullfile(dest,'test_tensor_replay.csv'));
assert(all(receipts.StatusMismatches==0 & receipts.PickMismatches==0));assert(all(tensorDiff==0),'Feature bytes differ; do not treat hash differences as measured numerical error.');fprintf('PASS TEST %s outputs=%d records=%d feature_hash_mismatch_max=%.9g\n',group,height(jj),N,max(tensorDiff));
 function m=loadModel(kind,seed,fold,bs)
  mr=manifest(manifest.mode==mode & manifest.kind==string(kind) & manifest.seed==seed & manifest.fold==fold & manifest.base==bs,:);assert(height(mr)==1);assert(sha256File(mr.path)==mr.sha256);s=load(mr.path,'model');m=s.model;assert(string(m.kind)==string(kind));modelLoaded=[modelLoaded;mr];
 end
 function r=record(event)
  file=fullfile(wave,event+".csv");wh=waveHashes(waveHashes.event_id==event,:);assert(height(wh)==1 && sha256File(file)==wh.sha256,"Original CSV bytes required; input hash differs.");[r,ok]=loadSingleSTEADCSV(file,cfg);assert(ok);mr=membership(membership.event_id==event,:);assert(height(mr)==1);r.source_id=char(mr.source_id);r=prepareMode(r,cfg);
 end
 function assertHeld(r,m)
  assert(~ismember(string(r.source_id),string(m.trainSources)) && ~ismember(string(r.source_id),string(m.valSources)),'Source used by fitted checkpoint');
 end
 function t=readPred(path)
  op=detectImportOptions(path);op=setvartype(op,{'event_id','source_id','p_status','s_status'},'string');t=readtable(path,op);
 end
 function rr=compare(a,e,label,policy)
  [yes,ix]=ismember(a.event_id,e.event_id);assert(all(yes));e=e(ix,:);assert(isequal(a.source_id,e.source_id));assert(max(abs([a.p_true_sec-e.p_true_sec;a.s_true_sec-e.s_true_sec]))<1e-9);
  status=sum(a.p_status~=e.p_status)+sum(a.s_status~=e.s_status);d=abs([a.p_pred_sec-e.p_pred_sec;a.s_pred_sec-e.s_pred_sec]);missing=sum(xor(isnan(a.p_pred_sec),isnan(e.p_pred_sec)))+sum(xor(isnan(a.s_pred_sec),isnan(e.s_pred_sec)));picks=missing+sum(d>1e-7);quality=max(abs([a.p_quality-e.p_quality;a.s_quality-e.s_quality]),[],'omitnan');
  rr=table(group,label,policy,height(a),status,picks,max(d,[],'omitnan'),quality,'VariableNames',{'Group','Output','Policy','Records','StatusMismatches','PickMismatches','MaxPickDifferenceSec','MaxQualityDifference'});
 end
 function z=thresholdStats(c,r)
  p=c.P(:);ss=c.S(:);[pk,ip]=max(p);z=struct('event_id',string(r.event_id),'source_id',string(r.source_id),'p_true_sec',r.p_arrival_sec,'s_true_sec',r.s_arrival_sec,'p_peak',pk,'p_quality',pk/(mean(p)+1e-6),'p_time',(ip-1)/cfg.samplingRate);
  for mx=[20 30 40]
   dt=((1:numel(ss))'-ip)/cfg.samplingRate;mask=dt>=.1-1e-10 & dt<=mx+1e-10;peak=NaN;quality=0;tm=NaN;
   if any(mask);tmp=ss;tmp(~mask)=-Inf;[peak,is]=max(tmp);quality=peak/(mean(ss(mask))+1e-6);tm=(is-1)/cfg.samplingRate;end
   z.(sprintf('s_peak_%d',mx))=peak;z.(sprintf('s_quality_%d',mx))=quality;z.(sprintf('s_time_%d',mx))=tm;
  end
 end
end

function h=tensorHash(x)
% SHA-256 of column-major single-precision feature bytes, little-endian host.
[~,~,endian]=computer;assert(endian=='L');x=single(x);md=java.security.MessageDigest.getInstance('SHA-256');md.update(typecast(x(:),'uint8'));h=lower(string(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[])));
end
