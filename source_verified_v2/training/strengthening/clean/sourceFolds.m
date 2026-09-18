function folds = sourceFolds(data,K,seed,sourceRoot)
assert(nargin==4,'ICNN:UnverifiedInputs','sourceRoot is required for frozen verified OOF membership.');
[~,m]=verifiedProtocol(sourceRoot);m=m(m.split=="train",:);
assert(K==5 && seed==42,'ICNN:FoldProtocol','Use the frozen five-fold seed-42 protocol.');
eids=string({data.event_id})';ids=string({data.source_id})';
[ok,j]=ismember(eids,m.event_id);
assert(numel(data)==height(m) && numel(unique(eids))==height(m) && all(ok));
assert(all(ids==m.source_id(j)),'ICNN:IdentityMismatch','Source mapping mismatch.');
folds=m.fold(j);
end
