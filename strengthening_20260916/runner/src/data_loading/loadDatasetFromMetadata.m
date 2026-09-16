% =========================================================================
% loadDatasetFromMetadata.m  (src/data_loading/)
% =========================================================================
% PURPOSE:
%   Orchestrator utama: baca metadata dari Excel, lalu untuk setiap baris
%   yang quality_flag-nya 'good', baca waveform dari CSV yang sesuai.
%   Ini adalah pengganti loadFilteredSTEADCSVFolder.m untuk workflow di
%   mana metadata sudah tersedia lengkap (metadata_master_filled.xlsx).
%
% INPUT:
%   config - struct, framework configuration. Field yang digunakan:
%       config.metadataPath  - path ke metadata_master_filled.xlsx
%       config.csvFolder     - path ke folder berisi 2.234 file CSV
%       config.samplingRate  - 100 Hz
%       config.verbose       - true/false
%
% OUTPUT:
%   data     - struct array, satu elemen per trace yang berhasil dibaca.
%              Field penting:
%                .waveform    [6000 x 3] double  (E, N, Z)
%                .sec         [6000 x 1] double  (time axis, detik)
%                .p_arrival_sec  double  (dari CSV — ground truth picks)
%                .s_arrival_sec  double  (dari CSV — ground truth picks)
%                .p_arrival_sample_0based  double
%                .s_arrival_sample_0based  double
%                .event_id    char  (mis. 'stead_event_00000')
%                .source_id   char  (mis. 'uw10827933' — STEAD asli)
%                .quality_flag char  ('good')
%                .source_magnitude double
%                .source_distance_km double
%                .SNR          double
%   metadata - table, metadata yang sudah difilter (good only, file exists)
%
% NOTES:
%   DESAIN KEPUTUSAN — dua sumber arrival time:
%     (a) metadata_master_filled.xlsx: p_arrival_sec dari HDF5 STEAD
%     (b) kolom p_arrival / s_arrival di dalam file CSV
%   Framework ini menggunakan (b) sebagai ground truth karena CSV adalah
%   data yang benar-benar digunakan untuk training (waveform + picks).
%   Metadata digunakan HANYA untuk: source_id (split), quality_flag
%   (filter), dan atribut tambahan (magnitude, distance, SNR).
%
%   Jika config.usePArrivalFromMetadata = true (default: false), maka (a)
%   digunakan sebagai ground truth — berguna jika CSV arrival time berbeda
%   akibat konversi waktu referensi.
% =========================================================================

function [data, metadata] = loadDatasetFromMetadata(config)

% ── 1. Load metadata dari Excel ───────────────────────────────────────────
fprintf('[loadDatasetFromMetadata] Loading metadata...\n');
metadata = loadMetadataFromExcel(config.metadataPath, config);
nMeta    = height(metadata);

% ── 2. Preallocate output struct array ────────────────────────────────────
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

% ── 3. Loop: baca setiap CSV waveform ─────────────────────────────────────
for i = 1:nMeta

    fp = char(metadata.file_path(i));

    % Skip jika file tidak ada
    if ~isfile(fp)
        nSkipped = nSkipped + 1;
        if config.verbose && nSkipped <= 5
            fprintf('  SKIP (not found): %s\n', fp);
        end
        continue;
    end

    % Baca waveform dari CSV
    [rec, ok] = loadSingleSTEADCSV(fp, config);
    if ~ok
        nFailed = nFailed + 1;
        continue;
    end

    % ── Isi data struct ────────────────────────────────────────────────────
    data(i).waveform  = rec.waveform;
    data(i).sec       = rec.sec;
    data(i).file_name = rec.file_name;
    data(i).event_id  = char(metadata.event_id(i));
    data(i).samplingRate = config.samplingRate;

    % Arrival time: ambil dari CSV (ground truth dari waveform)
    % Kecuali jika config.usePArrivalFromMetadata = true
    if isfield(config, 'usePArrivalFromMetadata') && config.usePArrivalFromMetadata
        % Gunakan arrival dari metadata (HDF5 STEAD)
        pSec = double(metadata.p_arrival_sec(i));
        sSec = double(metadata.s_arrival_sec(i));
    else
        % Gunakan arrival dari dalam CSV itu sendiri (default)
        pSec = rec.p_arrival_sec;
        sSec = rec.s_arrival_sec;
    end

    data(i).p_arrival_sec           = pSec;
    data(i).s_arrival_sec           = sSec;
    data(i).p_arrival_sample_0based = round(pSec * config.samplingRate);
    data(i).s_arrival_sample_0based = round(sSec * config.samplingRate);
    data(i).p_arrival_sample_1based = data(i).p_arrival_sample_0based + 1;
    data(i).s_arrival_sample_1based = data(i).s_arrival_sample_0based + 1;

    % Atribut dari metadata
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

% ── 4. Filter hanya yang valid ────────────────────────────────────────────
data     = data(validIdx);
metadata = metadata(validIdx, :);

fprintf('[loadDatasetFromMetadata] Done.\n');
fprintf('  Loaded: %d | Skipped (no file): %d | Failed (read error): %d\n', ...
    sum(validIdx), nSkipped, nFailed);
fprintf('  Unique source_id in loaded data: %d\n', ...
    numel(unique({data.source_id})));

end
