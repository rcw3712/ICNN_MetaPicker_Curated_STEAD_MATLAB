% =========================================================================
% buildMetadataFromCSVFolder.m  (src/data_loading/)
% =========================================================================
% PURPOSE:
%   Construct a metadata master table by scanning a folder of curated
%   STEAD-derived CSV waveform files, when metadata_master_latest.csv is
%   not yet available.
%
% INPUT:
%   csvFolder - char/string, path to folder containing CSV waveform files
%   config    - struct, framework configuration
%
% OUTPUT:
%   metadata - table, one row per CSV file, with the full column schema
%              described in docs/data_format.md (file_name, file_path,
%              event_id, source_id, trace_name, trace_category,
%              source_distance_km, source_magnitude, min_snr_db,
%              p_status, s_status, sampling_rate_hz, n_samples,
%              duration_sec, channel_order, p_arrival_sec, s_arrival_sec,
%              p_arrival_sample_0based, s_arrival_sample_0based,
%              p_arrival_sample_1based, s_arrival_sample_1based,
%              qc_nan_inf, qc_flatline, qc_length, qc_arrival_order,
%              qc_status, quality_flag, split_group, experiment_mode,
%              filter_version)
%
% NOTES:
%   If source_id is missing, event_id is used as a temporary fallback,
%   but original STEAD source_id is preferred. This function populates
%   source_id with the same value as event_id (derived from the file
%   name) and emits a warning, since the curated CSV format used here
%   does not separately encode the original STEAD source_id unless
%   provided through a side metadata file.
%
%   QC-related columns (qc_nan_inf, qc_flatline, etc.) are initialised to
%   NaN/empty here and populated later by qcWaveformDataset.m.
%   split_group and experiment_mode are similarly initialised empty and
%   populated by splitBySourceID.m / splitByEventID.m and the run_*
%   scripts respectively.
% =========================================================================

function metadata = buildMetadataFromCSVFolder(csvFolder, config)

if ~isfolder(csvFolder)
    error('buildMetadataFromCSVFolder:folderNotFound', ...
        'CSV folder not found: %s', csvFolder);
end

fileList = dir(fullfile(csvFolder, '*.csv'));
nFiles   = numel(fileList);

if nFiles == 0
    error('buildMetadataFromCSVFolder:noFiles', ...
        'No CSV files found in folder: %s', csvFolder);
end

fprintf('  Building metadata from %d CSV files in: %s\n', nFiles, csvFolder);

% Warn once about source_id fallback (per framework convention)
warning('buildMetadataFromCSVFolder:sourceIDFallback', ...
    ['source_id is missing. event_id is used as fallback. Strict ' ...
     'STEAD source-level leakage-free split requires original ' ...
     'source_id. See docs/data_format.md Section 4 for guidance on ' ...
     'recovering source_id if available from an auxiliary file.']);

fileName  = cell(nFiles,1);
filePath  = cell(nFiles,1);
eventID   = cell(nFiles,1);
sourceID  = cell(nFiles,1);
traceName = cell(nFiles,1);

fs = config.samplingRate;

for i = 1:nFiles
    fp = fullfile(fileList(i).folder, fileList(i).name);
    [~, fnNoExt, ~] = fileparts(fileList(i).name);

    fileName{i}  = fileList(i).name;
    filePath{i}  = fp;
    eventID{i}   = fnNoExt;
    sourceID{i}  = fnNoExt;   % fallback: source_id == event_id
    traceName{i} = fnNoExt;

    if config.verbose && mod(i, 200) == 0
        fprintf('    ... scanned %d / %d files\n', i, nFiles);
    end
end

nRows = nFiles;
metadata = table( ...
    string(fileName), string(filePath), string(eventID), string(sourceID), ...
    string(traceName), ...
    repmat(string(config.filter.traceCategory), nRows, 1), ...
    nan(nRows,1), nan(nRows,1), nan(nRows,1), ...
    repmat(string(config.filter.pStatus), nRows, 1), ...
    repmat(string(config.filter.sStatus), nRows, 1), ...
    repmat(fs, nRows, 1), repmat(config.nSamples, nRows, 1), ...
    repmat(config.durationSec, nRows, 1), ...
    repmat(string(strjoin(config.channelOrder, ',')), nRows, 1), ...
    nan(nRows,1), nan(nRows,1), nan(nRows,1), nan(nRows,1), nan(nRows,1), nan(nRows,1), ...
    strings(nRows,1), strings(nRows,1), strings(nRows,1), strings(nRows,1), strings(nRows,1), ...
    strings(nRows,1), strings(nRows,1), ...
    repmat(string(config.filter.version), nRows, 1), ...
    'VariableNames', { ...
        'file_name','file_path','event_id','source_id','trace_name', ...
        'trace_category','source_distance_km','source_magnitude','min_snr_db', ...
        'p_status','s_status','sampling_rate_hz','n_samples','duration_sec', ...
        'channel_order','p_arrival_sec','s_arrival_sec', ...
        'p_arrival_sample_0based','s_arrival_sample_0based', ...
        'p_arrival_sample_1based','s_arrival_sample_1based', ...
        'qc_nan_inf','qc_flatline','qc_length','qc_arrival_order', ...
        'qc_status','quality_flag','split_group', ...
        'experiment_mode','filter_version'});

% ── Populate arrival times by reading each CSV's first row ───────────────
fprintf('  Reading arrival times from each CSV (first-row scan)...\n');
for i = 1:nRows
    [rec, ok] = loadSingleSTEADCSV(metadata.file_path(i), config);
    if ok
        metadata.p_arrival_sec(i)           = rec.p_arrival_sec;
        metadata.s_arrival_sec(i)           = rec.s_arrival_sec;
        metadata.p_arrival_sample_0based(i) = rec.p_arrival_sample_0based;
        metadata.s_arrival_sample_0based(i) = rec.s_arrival_sample_0based;
        metadata.p_arrival_sample_1based(i) = rec.p_arrival_sample_1based;
        metadata.s_arrival_sample_1based(i) = rec.s_arrival_sample_1based;
    end
    if config.verbose && mod(i, 200) == 0
        fprintf('    ... arrival scan %d / %d\n', i, nRows);
    end
end

fprintf('  Metadata construction complete: %d rows.\n', height(metadata));

end
