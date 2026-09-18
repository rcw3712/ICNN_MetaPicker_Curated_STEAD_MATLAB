function export_v2_tensor_hashes
% Export checksums of existing feature caches; no inference or fitting.
root='D:\ICNN_source_verified_results\v2';out='C:\Users\catur\.codex\visualizations\2026\09\11\01a08fc7-0cf1-7772-a384-020417c19593\sync_repo\source_verified_v2\feature_hashes';
if ~isfolder(out);mkdir(out);end
for base=42:44
 for mode=["Full3C","Zonly"]
  if base==42;rr=fullfile(root,'submission40');else;rr=fullfile(root,'strengthening',"base_"+base,mode);end
  path=fullfile(rr,mode,'meta_cache.mat');c=matfile(path);rows=cell(3418,4);pos=0;
  for field=["M","T"]
   if field=="M";keys=c.trainKeys;role="oof";else;keys=c.testKeys;role="test";end
   for start=1:128:numel(keys)
    stop=min(start+127,numel(keys));if field=="M";block=c.M(start:stop,1);else;block=c.T(start:stop,1);end
    for j=1:numel(block)
     a=single(block{j});assert(isequal(size(a),[6000 15]));md=java.security.MessageDigest.getInstance('SHA-256');md.update(typecast(a(:),'uint8'));h=lower(string(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[])));
     pos=pos+1;rows(pos,:)={role,start+j-1,string(keys(start+j-1)),h};
    end
   end
  end
  t=cell2table(rows,'VariableNames',{'role','index','event_id','sha256_f32F'});writetable(t,fullfile(out,mode+"_base"+base+".csv"));fprintf('EXPORTED %s base%d %d existing tensor hashes\n',mode,base,pos);
 end
end
end
