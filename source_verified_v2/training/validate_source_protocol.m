function report=validate_source_protocol(sourceRoot,outputRoot)
% Metadata/partition, actual CSV loader, and fail-closed checks. No training.
if nargin<1;sourceRoot='D:\STEAD_identity_recovery\prepared_source_v2';end
if nargin<2;outputRoot=fullfile(tempdir,'ICNN_verified_protocol_validation');end
if ~isfolder(outputRoot);mkdir(outputRoot);end
root=fileparts(mfilename('fullpath'));report=struct;baselineFolds=[];
for package=["submission","strengthening"]
 p=fullfile(root,package);addpath(fullfile(p,'clean'),fullfile(p,'config'),genpath(fullfile(p,'src')));
 cfg=config_ICNN_MetaPicker();cfg=configureVerifiedInputs(cfg,sourceRoot);cfg.verbose=false;
 t=loadMetadataFromExcel(cfg.metadataPath,cfg);
 data=repmat(struct('event_id','','source_id',''),height(t),1);
 for i=1:height(t);data(i).event_id=char(t.event_id(i));data(i).source_id=char(t.source_id(i));end
 [tr,va,te]=loadFrozenSplit(data,sourceRoot);assert(isequal([numel(tr),numel(va),numel(te)],[1544 360 330]));
 f=sourceFolds(tr,5,42,sourceRoot);reversed=sourceFolds(tr(end:-1:1),5,42,sourceRoot);assert(isequal(f,flipud(reversed)));
 if isempty(baselineFolds);baselineFolds=f;else;assert(isequal(f,baselineFolds));end
 for k=1:5
  [fit,iv]=innerSourceSplit(tr(f~=k),100+k,sourceRoot);held=tr(f==k);
  assertDisjointSources(fit,iv,held,va,te);
  assert(numel(fit)+numel(iv)+numel(held)==numel(tr));
 end
 broken=data;broken(1).source_id='WRONG_SOURCE';mustFail(@()loadFrozenSplit(broken,sourceRoot),'ICNN:IdentityMismatch');
 mustFail(@()configureVerifiedInputs(cfg,'C:\Drive E\ICNN_MetaPicker_Curated_STEAD_MATLAB'),'ICNN:UnverifiedInputs');
 mustFail(@()assertDisjointSources(tr,tr(1)),'ICNN:SourceOverlap');
 % One real CSV through the unchanged loader/representation for both modes.
 [rec,ok]=loadSingleSTEADCSV(char(t.file_path(1)),cfg);assert(ok && isequal(size(rec.waveform),[6000 3]));
 assert(abs(rec.p_arrival_sec-t.csv_p_arrival_sec(1))<1e-9 && abs(rec.s_arrival_sec-t.csv_s_arrival_sec(1))<1e-9);
 predictionFile=fullfile(outputRoot,package+"_identity_roundtrip.csv");testTable=table(string({te.event_id})',string({te.source_id})','VariableNames',{'event_id','source_id'});writetable(testTable,predictionFile);
 imported=readVerifiedPredictions(predictionFile,sourceRoot);assert(isequal(imported.source_id,testTable.source_id));
 % A legacy checkpoint must fail before fitClean is reached.
 runRoot=fullfile(outputRoot,package,'old_checkpoint');folder=fullfile(runRoot,'models','Full3C');if ~isfolder(folder);mkdir(folder);end
 model=struct('runSignature',"legacy",'jobId',"probe");save(fullfile(folder,'probe.mat'),'model');
 job=table("probe","Full3C","CNN",42,0,'VariableNames',{'id','mode','kind','seed','fold'});
 rejected=false;try;fitJob(job,{},{},{},{},cfg,tr(1),va(1),"verified",runRoot);catch;rejected=true;end;assert(rejected,'Legacy checkpoint was not rejected.');
 report.(char(package))=struct('records',height(t),'sources',numel(unique(t.source_id)),'outer_records',[numel(tr),numel(va),numel(te)],'five_folds_disjoint',true,'row_order_invariant',true,'legacy_inputs_rejected',true,'wrong_source_rejected',true,'overlap_rejected',true,'legacy_checkpoint_rejected',true,'real_csv_loaded',true);
end
% A single-byte change to a split manifest must be rejected.
badRoot=fullfile(outputRoot,'tampered_protocol');if ~isfolder(badRoot);mkdir(badRoot);end
pr=jsondecode(fileread(fullfile(sourceRoot,'protocol.json')));copyfile(fullfile(sourceRoot,'protocol.json'),badRoot);
for i=1:numel(pr.files)
 dest=fullfile(badRoot,pr.files(i).relative_path);parent=fileparts(dest);if ~isfolder(parent);mkdir(parent);end;copyfile(fullfile(sourceRoot,pr.files(i).relative_path),dest);
end
fid=fopen(fullfile(badRoot,'partition_membership.csv'),'a');fprintf(fid,'\n');fclose(fid);
mustFail(@()verifiedProtocol(badRoot),'ICNN:ProtocolChanged');report.tampered_protocol_rejected=true;
report.training_started=false;report.shared_folds_across_packages=true;
fid=fopen(fullfile(outputRoot,'validation_report.json'),'w');fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fclose(fid);disp(report);fprintf('PASS: verified source protocol; no training performed.\n');
end
function mustFail(fn,identifier)
 caught=false;try;fn();catch ME;assert(strcmp(ME.identifier,identifier),'Unexpected error: %s (%s)',ME.message,ME.identifier);caught=true;end
 assert(caught,'Expected rejection: %s',identifier);
end
