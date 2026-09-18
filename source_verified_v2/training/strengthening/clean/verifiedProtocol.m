function [p,m] = verifiedProtocol(sourceRoot)
path=fullfile(sourceRoot,'protocol.json');
assert(isfile(path),'ICNN:UnverifiedInputs','Prepared source-verified protocol is required; legacy metadata is prohibited.');
p=jsondecode(fileread(path));assert(strcmp(p.schema,'stead-source-verified-v2'));
assert(p.records==2234 && p.sources==1477);
for k=1:numel(p.files)
 relative=string(p.files(k).relative_path);
 assert(~contains(relative,'..') && ~startsWith(relative,'/') && ~contains(relative,':'));
 file=fullfile(sourceRoot,relative);
 assert(isfile(file) && sha256File(file)==string(p.files(k).sha256),'ICNN:ProtocolChanged','Prepared metadata/split file changed: %s',file);
end
opts=detectImportOptions(fullfile(sourceRoot,'partition_membership.csv'));opts=setvartype(opts,{'event_id','source_id','trace_name','split'},'string');
m=readtable(fullfile(sourceRoot,'partition_membership.csv'),opts);
m.source_id=string(m.source_id);m.event_id=string(m.event_id);
assert(height(m)==p.records && numel(unique(m.event_id))==p.records && numel(unique(m.source_id))==p.sources);
assert(all(~ismissing(m.source_id)&strlength(m.source_id)>0));
assert(all(ismember(m.split,["train","val","test"])));
assert(all(m.fold(m.split~="train")==0) && all(ismember(m.fold(m.split=="train"),1:5)));
names=["train","val","test"];groups=cell(3,1);
for k=1:3
 groups{k}=unique(m.source_id(m.split==names(k)));
 opts=detectImportOptions(fullfile(sourceRoot,'results','splits',names(k)+"_source_ids.csv"));opts=setvartype(opts,'source_id','string');
 t=readtable(fullfile(sourceRoot,'results','splits',names(k)+"_source_ids.csv"),opts);
 assert(isequal(sort(t.source_id),sort(groups{k})),'ICNN:PartitionMismatch','Source list disagrees with membership.');
 for j=1:k-1;assert(isempty(intersect(groups{k},groups{j})),'ICNN:SourceOverlap','Outer source overlap.');end
end
for s=unique(m.source_id(m.split=="train"))'
 assert(numel(unique(m.fold(m.source_id==s)))==1,'ICNN:FoldOverlap','A source crosses OOF folds.');
end
end

