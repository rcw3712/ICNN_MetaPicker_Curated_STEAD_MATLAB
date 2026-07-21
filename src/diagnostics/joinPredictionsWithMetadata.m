% =========================================================================
% joinPredictionsWithMetadata.m
% =========================================================================
% PURPOSE:
%   Join prediction table dengan metadata master untuk menambahkan kolom
%   geofisika (SNR, magnitude, distance, SP-time) yang tidak tersimpan
%   di predictions CSV.
%
% INPUTS:
%   predTable - table, hasil readtable dari predictions_full3C.csv atau Zonly
%   meta      - table, hasil readtable dari metadata_master_final.csv
%   config    - struct, framework configuration
%
% OUTPUTS:
%   predOut   - table, predTable diperkaya dengan kolom metadata
%
% NOTES:
%   Join key priority: file_name > event_id > source_id
%   Kolom yang ditambahkan jika tersedia:
%     SNR, source_magnitude, source_distance_km, sp_time_sec,
%     filter_version, quality_flag
% =========================================================================

function predOut = joinPredictionsWithMetadata(predTable, meta, config)

predOut = predTable;
if isempty(meta) || isempty(predTable)
    warning('[joinPredictions] Empty input     returning predTable as-is.');
    return;
end

%        Tentukan join key                                                                                                                                                                
predCols = lower(predTable.Properties.VariableNames);
metaCols = lower(meta.Properties.VariableNames);

joinKey = '';
for key = {'file_name','event_id','source_id'}
    if any(strcmp(predCols, key{1})) && any(strcmp(metaCols, key{1}))
        joinKey = key{1}; break;
    end
end

if isempty(joinKey)
    warning('[joinPredictions] No common join key found. Skipping join.');
    return;
end

fprintf('  [Join] Using key: %s (%d pred rows, %d meta rows)\n', ...
    joinKey, height(predTable), height(meta));

%        Normalise key ke cell string                                                                                                                            
predKey = ensureCellStr(predTable.(findCol(predTable, joinKey)));
metaKey = ensureCellStr(meta.(findCol(meta, joinKey)));

% Buat lookup map dari meta
metaIdx = containers.Map(metaKey, 1:height(meta));

%        Kolom yang ingin di-join                                                                                                                                           
wantCols = {'SNR','snr_mean_db','min_snr_db', ...
    'source_magnitude','source_distance_km','sp_time_sec', ...
    'filter_version','quality_flag'};

% Tambahkan kolom kosong dulu
for w = wantCols
    col = w{1};
    metaColName = findCol(meta, col);
    if ~isempty(metaColName) && ~any(strcmp(predTable.Properties.VariableNames, col))
        if isnumeric(meta.(metaColName))
            predOut.(col) = nan(height(predOut), 1);
        else
            predOut.(col) = repmat({''}, height(predOut), 1);
        end
    end
end

%        Isi nilai berdasarkan join                                                                                                                                     
nFilled = 0;
for i = 1:height(predOut)
    k = predKey{i};
    if isKey(metaIdx, k)
        mi = metaIdx(k);
        for w = wantCols
            col = w{1};
            metaColName = findCol(meta, col);
            if ~isempty(metaColName) && any(strcmp(predOut.Properties.VariableNames, col))
                predOut.(col)(i) = meta.(metaColName)(mi);
            end
        end
        nFilled = nFilled + 1;
    end
end

% SNR alias     gunakan snr_mean_db sebagai SNR jika SNR tidak ada
if ~any(strcmp(predOut.Properties.VariableNames,'SNR')) && ...
        any(strcmp(predOut.Properties.VariableNames,'snr_mean_db'))
    predOut.SNR = predOut.snr_mean_db;
end

fprintf('  [Join] Filled metadata for %d/%d records.\n', nFilled, height(predOut));
end

%        Helpers                                                                                                                                                                                              
function colName = findCol(t, name)
cols = t.Properties.VariableNames;
idx  = strcmpi(cols, name);
if any(idx); colName = cols{find(idx,1)}; else; colName = ''; end
end

function c = ensureCellStr(v)
if iscell(v);    c = cellfun(@num2str, v, 'UniformOutput', false);
elseif isnumeric(v); c = arrayfun(@num2str, v, 'UniformOutput', false);
else;            c = cellstr(string(v));
end
end
