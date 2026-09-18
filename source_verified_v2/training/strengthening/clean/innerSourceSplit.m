function [fit,validation] = innerSourceSplit(data,seed,sourceRoot)
assert(nargin==3,'ICNN:UnverifiedInputs','sourceRoot is required for frozen inner membership.');
[~,m]=verifiedProtocol(sourceRoot);k=seed-100;assert(ismember(k,1:5));
opts=detectImportOptions(fullfile(sourceRoot,'folds',sprintf('inner_fold_%d.csv',k)));
opts=setvartype(opts,{'event_id','source_id','role'},'string');t=readtable(fullfile(sourceRoot,'folds',sprintf('inner_fold_%d.csv',k)),opts);
train=m(m.split=="train",:);[ok,j]=ismember(t.event_id,train.event_id);
assert(height(t)==height(train) && numel(unique(t.event_id))==height(train) && all(ok));
assert(all(t.source_id==train.source_id(j)) && all(ismember(t.role,["held","fit","inner_val"])));
assert(all((t.role=="held")== (train.fold(j)==k)));
roles=["held","fit","inner_val"];for a=1:3;for b=a+1:3;assert(isempty(intersect(t.source_id(t.role==roles(a)),t.source_id(t.role==roles(b)))),'ICNN:SourceOverlap','Inner source overlap.');end;end
remaining=t(t.role~="held",:);eids=string({data.event_id})';ids=string({data.source_id})';[ok,j]=ismember(eids,remaining.event_id);
assert(numel(data)==height(remaining) && numel(unique(eids))==height(remaining) && all(ok));
assert(all(ids==remaining.source_id(j)),'ICNN:IdentityMismatch','Inner source mismatch.');
fit=data(remaining.role(j)=="fit");validation=data(remaining.role(j)=="inner_val");assertDisjointSources(fit,validation);
end
