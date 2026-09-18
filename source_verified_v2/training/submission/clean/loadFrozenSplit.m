function [tr,va,te] = loadFrozenSplit(data,sourceRoot)
[p,m]=verifiedProtocol(sourceRoot);
eids=string({data.event_id})';ids=string({data.source_id})';
assert(numel(data)==p.records && numel(unique(eids))==p.records && numel(unique(ids))==p.sources);
[ok,j]=ismember(eids,m.event_id);assert(all(ok));
assert(all(ids==m.source_id(j)),'ICNN:IdentityMismatch','Loaded waveform/source mapping differs from verified protocol.');
part=m.split(j);tr=data(part=="train");va=data(part=="val");te=data(part=="test");
assertDisjointSources(tr,va,te);
end
