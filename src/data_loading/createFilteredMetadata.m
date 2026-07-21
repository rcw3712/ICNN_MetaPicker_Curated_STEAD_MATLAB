
function createFilteredMetadata(config)
% createFilteredMetadata.m -- Task 5
% Run ONCE to create metadata_master_2234_final.xlsx.
% After this, patchConfig() will use it instead of the 25000-row original.
outPath = fullfile('metadata','metadata_master_2234_final.xlsx');
if isfile(outPath)
    fprintf('[createFilteredMetadata] Already exists: %s\n', outPath); return;
end
fprintf('[createFilteredMetadata] Loading original metadata...\n');
meta = readtable(config.metadataPath,'VariableNamingRule','preserve');
fprintf('  Original: %d rows\n', height(meta));
if any(strcmpi(meta.Properties.VariableNames,'quality_flag'))
    bad = ismember(lower(string(meta.quality_flag)),{'bad','rejected','poor'});
    meta = meta(~bad,:);
end
csvDir  = config.csvFolder;
eventIds= cellstr(string(meta.event_id));
keep    = false(height(meta),1);
for i=1:height(meta)
    if isfile(fullfile(csvDir,[eventIds{i} '.csv'])); keep(i)=true; end
end
meta2234 = meta(keep,:);
fprintf('  Filtered: %d rows\n', height(meta2234));
writetable(meta2234, outPath);
fprintf('[createFilteredMetadata] Saved: %s\n', outPath);
end
