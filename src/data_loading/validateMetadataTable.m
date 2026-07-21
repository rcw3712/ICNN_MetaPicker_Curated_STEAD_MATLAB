% =========================================================================
% validateMetadataTable.m  (src/data_loading/)
% =========================================================================
% PURPOSE:
%   Validate that a metadata table conforms to the schema required by
%   this framework, filling in missing optional columns where possible.
%
% INPUT:
%   metadata - table, candidate metadata (loaded from CSV or built fresh)
%   config   - struct, framework configuration
%
% OUTPUT:
%   metadataValid - table, validated (and possibly augmented) metadata
%   reportStr     - char, human-readable validation summary
%
% NOTES:
%   Required columns (validation fails with error if absent):
%       file_name, file_path, event_id, source_id, p_arrival_sec,
%       s_arrival_sec
%   Optional columns (filled with sensible defaults if absent):
%       trace_category, source_distance_km, source_magnitude, min_snr_db,
%       p_status, s_status, sampling_rate_hz, n_samples, duration_sec,
%       channel_order, p_arrival_sample_0based, s_arrival_sample_0based,
%       p_arrival_sample_1based, s_arrival_sample_1based, qc_*, quality_flag,
%       split_group, experiment_mode, filter_version
% =========================================================================

function [metadataValid, reportStr] = validateMetadataTable(metadata, config)

REQUIRED = {'file_name','file_path','event_id','source_id', ...
            'p_arrival_sec','s_arrival_sec'};

missingRequired = setdiff(REQUIRED, metadata.Properties.VariableNames);
if ~isempty(missingRequired)
    error('validateMetadataTable:missingRequired', ...
        'Metadata is missing required column(s): %s', ...
        strjoin(missingRequired, ', '));
end

OPTIONAL_DEFAULTS = struct( ...
    'trace_category',     string(config.filter.traceCategory), ...
    'source_distance_km', NaN, ...
    'source_magnitude',   NaN, ...
    'min_snr_db',         NaN, ...
    'p_status',           string(config.filter.pStatus), ...
    's_status',           string(config.filter.sStatus), ...
    'sampling_rate_hz',   config.samplingRate, ...
    'n_samples',          config.nSamples, ...
    'duration_sec',       config.durationSec, ...
    'channel_order',      string(strjoin(config.channelOrder,',')), ...
    'p_arrival_sample_0based', NaN, ...
    's_arrival_sample_0based', NaN, ...
    'p_arrival_sample_1based', NaN, ...
    's_arrival_sample_1based', NaN, ...
    'qc_nan_inf',          "", ...
    'qc_flatline',         "", ...
    'qc_length',           "", ...
    'qc_arrival_order',    "", ...
    'qc_status',           "", ...
    'quality_flag',        "", ...
    'split_group',         "", ...
    'experiment_mode',     "", ...
    'filter_version',      string(config.filter.version) ...
);

fields = fieldnames(OPTIONAL_DEFAULTS);
addedCols = {};
N = height(metadata);
for f = 1:numel(fields)
    colName = fields{f};
    if ~ismember(colName, metadata.Properties.VariableNames)
        defaultVal = OPTIONAL_DEFAULTS.(colName);
        if isstring(defaultVal) || ischar(defaultVal)
            metadata.(colName) = repmat(string(defaultVal), N, 1);
        else
            metadata.(colName) = repmat(defaultVal, N, 1);
        end
        addedCols{end+1} = colName; %#ok<AGROW>
    end
end

% Fill in derived sample indices if missing but seconds are present
if all(isnan(metadata.p_arrival_sample_0based)) && ~all(isnan(metadata.p_arrival_sec))
    fs = config.samplingRate;
    metadata.p_arrival_sample_0based = round(metadata.p_arrival_sec * fs);
    metadata.s_arrival_sample_0based = round(metadata.s_arrival_sec * fs);
    metadata.p_arrival_sample_1based = metadata.p_arrival_sample_0based + 1;
    metadata.s_arrival_sample_1based = metadata.s_arrival_sample_0based + 1;
end

metadataValid = metadata;

reportStr = sprintf(['Metadata validation: %d rows, %d required columns OK, ' ...
    '%d optional column(s) auto-filled: %s'], ...
    N, numel(REQUIRED), numel(addedCols), strjoin(addedCols, ', '));

fprintf('  %s\n', reportStr);

end

% =========================================================================
% loadFilteredSTEADCSVFolder.m  (src/data_loading/)
% =========================================================================
% PURPOSE:
%   Top-level orchestrator: read or build metadata_master_latest.csv,
%   then read every waveform CSV in the folder, assembling a struct array
%   ready for QC.
%
% INPUT:
%   csvFolder    - char/string, folder containing curated STEAD CSV files
%   metadataPath - char/string, path to metadata_master_latest.csv
%                  (built automatically if not found)
%   config       - struct, framework configuration
%
% OUTPUT:
%   data     - struct array, one element per successfully-read CSV, with
%              fields: .waveform [T x 3], .sec, .p_arrival_sec,
%              .s_arrival_sec, .p_arrival_sample_0based,
%              .s_arrival_sample_0based, .file_name, .event_id,
%              .source_id, .samplingRate
%   metadata - table, the validated metadata master (saved to disk if
%              freshly built)
%
% NOTES:
%   If metadata_master_latest.csv does not exist, this function builds it
%   via buildMetadataFromCSVFolder.m and saves the result so that
%   subsequent runs can simply read the cached metadata instead of
%   re-scanning all CSV files. See run_qc_and_metadata_build.m for the
%   recommended standalone metadata-construction workflow.
% =========================================================================
