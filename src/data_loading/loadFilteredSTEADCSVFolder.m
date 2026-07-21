function [data, metadata] = loadFilteredSTEADCSVFolder(csvFolder, metadataPath, config)

% ── 1. Load or build metadata ─────────────────────────────────────────────
if isfile(metadataPath)
    fprintf('  Loading existing metadata: %s\n', metadataPath);
    metadata = readtable(metadataPath, 'TextType', 'string', ...
        'VariableNamingRule', 'preserve');
else
    fprintf('  Metadata not found at %s — building from CSV folder...\n', metadataPath);
    metadata = buildMetadataFromCSVFolder(csvFolder, config);
    ensureDir(fileparts(metadataPath));
    writetable(metadata, metadataPath);
    fprintf('  Metadata built and saved: %s\n', metadataPath);
end

[metadata, ~] = validateMetadataTable(metadata, config);

% ── 2. Read each waveform CSV ─────────────────────────────────────────────
nFiles = height(metadata);
fprintf('  Loading %d waveform CSV files...\n', nFiles);

data = repmat(struct( ...
    'waveform', [], 'sec', [], ...
    'p_arrival_sec', NaN, 's_arrival_sec', NaN, ...
    'p_arrival_sample_0based', NaN, 's_arrival_sample_0based', NaN, ...
    'p_arrival_sample_1based', NaN, 's_arrival_sample_1based', NaN, ...
    'file_name', '', 'event_id', '', 'source_id', '', ...
    'samplingRate', config.samplingRate, ...
    'source_magnitude', NaN, 'source_distance_km', NaN, 'SNR', NaN), nFiles, 1);

nFailed  = 0;
validIdx = false(nFiles, 1);

for i = 1:nFiles
    [rec, ok] = loadSingleSTEADCSV(metadata.file_path(i), config);
    if ~ok
        nFailed = nFailed + 1;
        continue;
    end

    data(i).waveform                = rec.waveform;
    data(i).sec                     = rec.sec;
    data(i).p_arrival_sec           = rec.p_arrival_sec;
    data(i).s_arrival_sec           = rec.s_arrival_sec;
    data(i).p_arrival_sample_0based = rec.p_arrival_sample_0based;
    data(i).s_arrival_sample_0based = rec.s_arrival_sample_0based;
    data(i).p_arrival_sample_1based = rec.p_arrival_sample_1based;
    data(i).s_arrival_sample_1based = rec.s_arrival_sample_1based;
    data(i).file_name                = rec.file_name;
    data(i).event_id                 = char(metadata.event_id(i));
    data(i).source_id                = char(metadata.source_id(i));
    data(i).samplingRate             = rec.samplingRate;

    if ismember('source_magnitude', metadata.Properties.VariableNames)
        data(i).source_magnitude = metadata.source_magnitude(i);
    end
    if ismember('source_distance_km', metadata.Properties.VariableNames)
        data(i).source_distance_km = metadata.source_distance_km(i);
    end
    if ismember('min_snr_db', metadata.Properties.VariableNames)
        data(i).SNR = metadata.min_snr_db(i);
    end

    validIdx(i) = true;

    if config.verbose && mod(i, 200) == 0
        fprintf('    ... loaded %d / %d\n', i, nFiles);
    end
end

data = data(validIdx);

fprintf('  CSV loading complete: %d succeeded, %d failed (of %d).\n', ...
    sum(validIdx), nFailed, nFiles);

end

% =========================================================================
function ensureDir(d)
if ~isempty(d) && ~isfolder(d); mkdir(d); end
end
