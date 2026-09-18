function t=readVerifiedPredictions(path,sourceRoot)
opts=detectImportOptions(path,'Delimiter',',');fid=fopen(path,'r');header=fgetl(fid);fclose(fid);opts.VariableNames=cellstr(split(string(header),','))';opts.VariableNamesLine=1;opts.DataLines=[2 Inf];opts=setvartype(opts,{'event_id','source_id'},'string');t=readtable(path,opts);
[~,m]=verifiedProtocol(sourceRoot);m=m(m.split=="test",:);[ok,j]=ismember(t.event_id,m.event_id);
assert(height(t)==height(m) && numel(unique(t.event_id))==height(m) && all(ok),'ICNN:TestMembership','Predictions do not cover the verified test split.');
assert(all(t.source_id==m.source_id(j)),'ICNN:IdentityMismatch','Prediction source IDs disagree with verified test identities.');
end

