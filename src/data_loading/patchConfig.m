
function config = patchConfig(config)
% patchConfig.m -- Task 5
% Override metadata path with 2234-record pre-filtered file if it exists.
% Call after config_ICNN_MetaPicker() to skip loading 25000-row original.
filtered2234 = fullfile('metadata','metadata_master_2234_final.xlsx');
if isfile(filtered2234)
    config.metadataPath        = filtered2234;
    config.metadataPreFiltered = true;
    fprintf('  [patchConfig] Using pre-filtered metadata (2234 records).\n');
else
    config.metadataPreFiltered = false;
end
end
