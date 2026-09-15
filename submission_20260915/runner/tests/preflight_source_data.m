function preflight_source_data(sourceRoot)
if nargin<1;sourceRoot='C:\Drive E\ICNN_MetaPicker_Curated_STEAD_MATLAB';end
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'clean'),fullfile(root,'config'),genpath(fullfile(root,'src')));
cfg=config_ICNN_MetaPicker();cfg.metadataPath=fullfile(sourceRoot,'metadata','metadata_master_2234_final.xlsx');
cfg.csvFolder=fullfile(sourceRoot,'data','csv_stead_filtered');cfg.filterExistingCSVOnly=false;
[data,~]=loadDatasetFromMetadata(cfg);[tr,va,te]=loadFrozenSplit(data,sourceRoot);
assert(numel(tr)==1556&&numel(va)==343&&numel(te)==335);
for mode=["Full3C","Zonly"]
    cfg.experimentMode=char(mode);
    sample=prepareMode(tr(1:5),cfg);sample=augmentClean(sample,cfg,42);
    assertRepresentation(sample,cfg);
end
% Syntax analyzer over the new entry point and new clean functions.
files=[dir(fullfile(root,'clean','*.m'));dir(fullfile(root,'run_submission40.m'))];
for i=1:numel(files)
    messages=checkcode(fullfile(files(i).folder,files(i).name),'-id');
    for j=1:numel(messages)
        if contains(messages(j).message,'Parse error') || (isfield(messages,'id') && contains(messages(j).id,'SYNER'))
            error('%s:%d %s',files(i).name,messages(j).line,messages(j).message);
        end
    end
end
fprintf('PASS: real source dataset 2234 records, split 1556/343/335, sample preparation both modes.\n');
end
