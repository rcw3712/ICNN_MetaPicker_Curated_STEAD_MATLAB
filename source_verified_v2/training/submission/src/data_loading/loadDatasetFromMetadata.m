% Numerical implementation from the source-verified v2 run.
% See USER_GUIDE.md for inputs, labels, inert legacy fields and current protocol.

function [data, metadata] = loadDatasetFromMetadata(config)

fprintf('[loadDatasetFromMetadata] Loading metadata...\n');
metadata = loadMetadataFromExcel(config.metadataPath, config);
nMeta    = height(metadata);

emptyStruct = struct(...
    'waveform', [], 'sec', [], ...
    'p_arrival_sec', NaN, 's_arrival_sec', NaN, ...
    'p_arrival_sample_0based', NaN, 's_arrival_sample_0based', NaN, ...
    'p_arrival_sample_1based', NaN, 's_arrival_sample_1based', NaN, ...
    'file_name', '', 'event_id', '', 'source_id', '', ...
    'quality_flag', '', 'samplingRate', config.samplingRate, ...
    'source_magnitude', NaN, 'source_distance_km', NaN, 'SNR', NaN, ...
    'sp_time_sec', NaN);

data     = repmat(emptyStruct, nMeta, 1);
validIdx = false(nMeta, 1);
nFailed  = 0;
nSkipped = 0;

fprintf('[loadDatasetFromMetadata] Reading %d CSV waveform files...\n', nMeta);

for i = 1:nMeta

    fp = char(metadata.file_path(i));

    if ~isfile(fp)
        nSkipped = nSkipped + 1;
        if config.verbose && nSkipped <= 5
            fprintf('  SKIP (not found): %s\n', fp);
        end
        continue;
    end

    [rec, ok] = loadSingleSTEADCSV(fp, config);
    if ~ok
        nFailed = nFailed + 1;
        continue;
    end

    data(i).waveform  = rec.waveform;
    data(i).sec       = rec.sec;
    data(i).file_name = rec.file_name;
    data(i).event_id  = char(metadata.event_id(i));
    data(i).samplingRate = config.samplingRate;

    if isfield(config, 'usePArrivalFromMetadata') && config.usePArrivalFromMetadata
        pSec = double(metadata.p_arrival_sec(i));
        sSec = double(metadata.s_arrival_sec(i));
    else
        pSec = rec.p_arrival_sec;
        sSec = rec.s_arrival_sec;
    end

    data(i).p_arrival_sec           = pSec;
    data(i).s_arrival_sec           = sSec;
    data(i).p_arrival_sample_0based = round(pSec * config.samplingRate);
    data(i).s_arrival_sample_0based = round(sSec * config.samplingRate);
    data(i).p_arrival_sample_1based = data(i).p_arrival_sample_0based + 1;
    data(i).s_arrival_sample_1based = data(i).s_arrival_sample_0based + 1;

    data(i).source_id = char(metadata.source_id(i));
    data(i).quality_flag = char(metadata.quality_flag(i));

    if ismember('source_magnitude', metadata.Properties.VariableNames)
        v = metadata.source_magnitude(i);
        data(i).source_magnitude = double(v);
    end
    if ismember('source_distance_km', metadata.Properties.VariableNames)
        v = metadata.source_distance_km(i);
        data(i).source_distance_km = double(v);
    end
    if ismember('min_snr_db', metadata.Properties.VariableNames)
        v = metadata.min_snr_db(i);
        data(i).SNR = double(v);
    end
    if ismember('sp_time_sec', metadata.Properties.VariableNames)
        v = metadata.sp_time_sec(i);
        data(i).sp_time_sec = double(v);
    end

    validIdx(i) = true;

    if config.verbose && mod(i, 200) == 0
        fprintf('  ... %d / %d loaded\n', i, nMeta);
    end
end

data     = data(validIdx);
metadata = metadata(validIdx, :);

fprintf('[loadDatasetFromMetadata] Done.\n');
fprintf('  Loaded: %d | Skipped (no file): %d | Failed (read error): %d\n', ...
    sum(validIdx), nSkipped, nFailed);
fprintf('  Unique source_id in loaded data: %d\n', ...
    numel(unique({data.source_id})));

end
