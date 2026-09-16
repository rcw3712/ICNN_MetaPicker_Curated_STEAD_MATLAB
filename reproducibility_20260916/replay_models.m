function receipt = replay_models(waveformDir,outputDir,maxRecords,executionEnvironment)
% Replay all reported expanded test models without fitting or checkpoint selection.
% waveformDir contains the identified curated CSVs; maxRecords=Inf replays all 335.
if nargin<3;maxRecords=Inf;end
if nargin<4;executionEnvironment='cpu';end
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'matlab'));
assert(isfolder(waveformDir),'Waveform directory is missing.');
if ~isfolder(outputDir);mkdir(outputDir);end
cfg=config_ICNN_MetaPicker();cfg.executionEnvironment=executionEnvironment;
manifest=readtable(fullfile(root,'checkpoint_manifest.csv'),'TextType','string');
opts=delimitedTextImportOptions('NumVariables',2);opts.DataLines=[2 Inf];opts.Delimiter=',';opts.VariableNames={'files','hashes'};opts.VariableTypes={'string','string'};
hashes=readtable(fullfile(root,'inputs','waveform_hashes.csv'),opts);
ref=readtable(fullfile(root,'expected','Stack_Full3C_base42_meta42.csv'),'TextType','string');
ref=sortrows(ref,'event_id');ref=ref(1:min(height(ref),maxRecords),:);
assert(height(ref)>0);receipt=table();
for mode=["Full3C","Zonly"]
 cfg.experimentMode=char(mode);
 for base=42:44
  cnn=checkpoint(mode,"CNN",base,base,0);tcn=checkpoint(mode,"TCN",base,base,0);
  meta=cell(3,1);for seed=42:44;meta{seed-41}=checkpoint(mode,"full15ch",base,seed,-1);end
  result=cell(3,1);for j=1:3;result{j}=table();end
  for i=1:height(ref)
   record=readRecord(i);assertUnseen(record,cnn);assertUnseen(record,tcn);
   X=makeMeta(record,cnn,tcn,cfg);
   for j=1:3
    assertUnseen(record,meta{j});curves=predictCurves(meta{j},X,cfg);
    row=predictionTable(decodeClean(curves,cfg,true),record);result{j}=[result{j};row];
   end
  end
  for j=1:3;label="Stack_"+mode+"_base"+base+"_meta"+(j+41);receipt=[receipt;compare(result{j},label)];end
  clear cnn tcn meta X curves result
 end
 for seed=42:44
  model=checkpoint(mode,"PhaseNetMatched",seed,seed,-1);result=table();
  for i=1:height(ref)
   record=readRecord(i);assertUnseen(record,model);
   curves=predictCurves(model,{record.waveform},cfg);
   result=[result;predictionTable(decodeClean(curves,cfg,true),record)];
  end
  receipt=[receipt;compare(result,"PhaseNetMatched_"+mode+"_seed"+seed)];clear model result curves
 end
end
writetable(receipt,fullfile(outputDir,'model_replay_receipt.csv'));
assert(all(receipt.StatusMismatches==0 & receipt.PickMismatches==0),'Replay differs; inspect receipts before using results.');
fprintf('PASS: %d model outputs x %d records; no pick/status mismatches.\n',height(receipt),height(ref));
 function model=checkpoint(mode,kind,base,seed,fold)
  ix=manifest.mode==mode & manifest.kind==kind & manifest.base_seed==base & manifest.seed==seed & manifest.fold==fold;
  assert(sum(ix)==1,'Checkpoint identity is ambiguous.');row=manifest(ix,:);
  file=fullfile(root,strrep(row.path,'/',filesep));assert(sha256(file)==row.sha256,'Checkpoint hash mismatch.');
  tmp=load(file,'model');model=tmp.model;assert(string(model.kind)==kind);
 end
 function record=readRecord(i)
  name=ref.event_id(i)+".csv";path=fullfile(waveformDir,name);
  h=hashes(hashes.files==name,:);assert(height(h)==1 && sha256(path)==h.hashes,'Waveform hash differs from historical input.');
  [record,ok]=loadSingleSTEADCSV(path,cfg);assert(ok);
  record.source_id=char(ref.source_id(i));
  assert(abs(record.p_arrival_sec-ref.p_true_sec(i))<1e-9 && abs(record.s_arrival_sec-ref.s_true_sec(i))<1e-9);
  record=prepareMode(record,cfg);
 end
 function assertUnseen(record,model)
  assert(~ismember(string(record.source_id),string(model.trainSources)) && ~ismember(string(record.source_id),string(model.valSources)),'Test source appears in fitting or validation.');
 end
 function row=compare(actual,label)
  expected=readtable(fullfile(root,'expected',label+".csv"),'TextType','string');[yes,loc]=ismember(actual.event_id,expected.event_id);assert(all(yes));expected=expected(loc,:);
  assert(isequal(actual.source_id,expected.source_id));status=sum(actual.p_status~=expected.p_status)+sum(actual.s_status~=expected.s_status);
  diffs=[abs(actual.p_pred_sec-expected.p_pred_sec);abs(actual.s_pred_sec-expected.s_pred_sec)];
  missing=sum(xor(isnan(actual.p_pred_sec),isnan(expected.p_pred_sec)))+sum(xor(isnan(actual.s_pred_sec),isnan(expected.s_pred_sec)));
  picks=missing+sum(diffs>1e-7);quality=max(abs([actual.p_quality-expected.p_quality;actual.s_quality-expected.s_quality]),[],'omitnan');
  maximum=max(diffs,[],'omitnan');
  row=table(label,height(actual),status,picks,maximum,quality,string(executionEnvironment),string(version),'VariableNames',{'Output','Records','StatusMismatches','PickMismatches','MaxPickDifferenceSec','MaxQualityDifference','Environment','MATLABVersion'});
  writetable(actual,fullfile(outputDir,label+"_replayed.csv"));writetable(evaluateClean(actual,true),fullfile(outputDir,label+"_accepted_metrics.csv"));
  fprintf('%s records=%d status_mismatch=%d pick_mismatch=%d\n',label,height(actual),status,picks);
 end
end
function value=sha256(file)
stream=java.security.MessageDigest.getInstance('SHA-256');fid=fopen(file,'rb');assert(fid>=0);clean=onCleanup(@()fclose(fid));
while ~feof(fid);bytes=fread(fid,1048576,'*uint8');stream.update(bytes);end
value=lower(string(reshape(dec2hex(typecast(stream.digest(),'uint8'),2).',1,[])));
end


