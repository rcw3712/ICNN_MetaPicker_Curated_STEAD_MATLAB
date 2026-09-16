function folds = sourceFolds(data,K,seed)
ids=string({data.source_id})';
assert(all(~ismissing(ids)&strlength(ids)>0),'Missing source IDs.');
u=unique(ids,'sorted');assert(numel(u)>=K);
stream=RandStream('mt19937ar','Seed',seed);
u=u(randperm(stream,numel(u)));
[ok,j]=ismember(ids,u);assert(all(ok));
folds=mod(j-1,K)+1;
end
