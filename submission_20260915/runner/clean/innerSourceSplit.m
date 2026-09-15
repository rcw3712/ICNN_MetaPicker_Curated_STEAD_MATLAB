function [fit,validation] = innerSourceSplit(data,seed)
% Only call on the non-held portion of outer training.
ids=string({data.source_id})';u=unique(ids,'sorted');
assert(numel(u)>=2,'Need at least two sources for inner validation.');
r=RandStream('mt19937ar','Seed',seed);u=u(randperm(r,numel(u)));
n=max(1,min(numel(u)-1,round(.15*numel(u))));
mask=ismember(ids,u(1:n));fit=data(~mask);validation=data(mask);
assertDisjointSources(fit,validation);
end
