function [tr,va,te] = loadFrozenSplit(data,sourceRoot)
allids=string({data.source_id})';eids=string({data.event_id})';
assert(numel(data)==2234 && numel(unique(allids))==2114);
assert(numel(unique(eids))==2234 && all(strlength(allids)>0 & ~ismissing(allids)));
parts=cell(3,1);sizes=[1480 317 317];counts=[1556 343 335];
names=["train","val","test"]; masks=false(numel(data),3);
for i=1:3
    opts=detectImportOptions(fullfile(sourceRoot,'results','splits',names(i)+"_source_ids.csv"));
    opts=setvartype(opts,opts.VariableNames,'string');
    t=readtable(fullfile(sourceRoot,'results','splits',names(i)+"_source_ids.csv"),opts);
    ids=string(t{:,1});assert(numel(unique(ids))==sizes(i)&&numel(ids)==sizes(i));
    assert(all(ismember(ids,allids)));masks(:,i)=ismember(allids,ids);
    parts{i}=data(masks(:,i));assert(numel(parts{i})==counts(i));
end
assert(all(sum(masks,2)==1),'Frozen split does not partition all records.');
tr=parts{1};va=parts{2};te=parts{3};assertDisjointSources(tr,va,te);
end
