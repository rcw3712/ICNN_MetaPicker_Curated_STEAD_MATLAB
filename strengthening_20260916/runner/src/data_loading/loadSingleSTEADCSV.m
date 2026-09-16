% =========================================================================
% loadSingleSTEADCSV.m  (src/data_loading/)
% =========================================================================
% PURPOSE:
%   Read one curated STEAD-derived CSV waveform file and return it as a
%   structured record ready for conditioning and labeling.
%
% INPUT:
%   filePath - char/string, full path to one CSV file
%   config   - struct, framework configuration
%
% OUTPUT:
%   record - struct with fields:
%       .waveform                [6000 x 3] double, columns = [E, N, Z]
%       .sec                     [6000 x 1] double, time axis (seconds)
%       .p_arrival_sec           double
%       .s_arrival_sec           double
%       .p_arrival_sample_0based double  (= round(p_arrival_sec * fs))
%       .s_arrival_sample_0based double
%       .p_arrival_sample_1based double  (= 0based + 1, MATLAB index)
%       .s_arrival_sample_1based double
%       .file_name               char
%       .event_id                char  (derived from filename without ext)
%       .samplingRate            double
%   ok - logical, true if file read and parsed successfully
%
% NOTES:
%   FORMAT AKTUAL FILE CSV STEAD YANG DIFILTER:
%       Kolom: time, sec, E, N, Z, p_arrival, s_arrival
%       - time    : string HH:MM:SS.mmm  (diabaikan, gunakan sec)
%       - sec     : float, 0.0 sampai 59.99, delta = 0.01 s (100 Hz)
%       - E, N, Z : amplitudo waveform (float, belum dinormalisasi)
%       - p_arrival, s_arrival : arrival time dalam detik, KONSTAN
%         diulang di setiap baris (dibaca dari baris pertama saja)
%
%   PENAMAAN FILE:
%       File bernama stead_event_NNNNN.csv, dengan NNNNN = nomor urut.
%       event_id = nama file tanpa ekstensi (mis. 'stead_event_00000').
%       source_id ASLI dari STEAD (mis. 'uw10827933') tersedia di kolom
%       source_id dalam metadata_master_filled.xlsx dan akan di-join
%       setelah loading via loadMetadataFromExcel.m.
%
%   PERBEDAAN DARI VERSI SEBELUMNYA:
%       Kolom 'time' (HH:MM:SS.mmm) di-skip; digunakan 'sec' langsung.
%       file_name dan file_path di metadata mungkin kosong (diisi di sini).
% =========================================================================

function [record, ok] = loadSingleSTEADCSV(filePath, config)

ok     = false;
record = struct();

if ~isfile(filePath)
    warning('loadSingleSTEADCSV:fileNotFound', 'CSV file not found: %s', filePath);
    return;
end

try
    T = readtable(filePath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
catch ME
    warning('loadSingleSTEADCSV:readFailed', ...
        'Failed to read CSV "%s": %s', filePath, ME.message);
    return;
end

% ── Verifikasi kolom wajib ────────────────────────────────────────────────
% Format aktual: time, sec, E, N, Z, p_arrival, s_arrival
requiredCols = {'sec','E','N','Z','p_arrival','s_arrival'};
missingCols  = setdiff(requiredCols, T.Properties.VariableNames);
if ~isempty(missingCols)
    warning('loadSingleSTEADCSV:missingColumns', ...
        'CSV "%s" missing required column(s): %s', ...
        filePath, strjoin(missingCols, ', '));
    return;
end

% ── Ekstrak kolom ──────────────────────────────────────────────────────────
secVec = double(T.sec);
E      = double(T.E);
N      = double(T.N);
Z      = double(T.Z);

% p_arrival dan s_arrival adalah konstanta yang diulang tiap baris
% — baca dari baris pertama saja
pArrivalSec = double(T.p_arrival(1));
sArrivalSec = double(T.s_arrival(1));

fs = config.samplingRate;

[~, fileNameNoExt, ~] = fileparts(filePath);

% ── Isi record struct ─────────────────────────────────────────────────────
record.waveform                = [E(:), N(:), Z(:)];   % [T x 3]
record.sec                     = secVec(:);
record.p_arrival_sec           = pArrivalSec;
record.s_arrival_sec           = sArrivalSec;
record.p_arrival_sample_0based = round(pArrivalSec * fs);
record.s_arrival_sample_0based = round(sArrivalSec * fs);
record.p_arrival_sample_1based = record.p_arrival_sample_0based + 1;
record.s_arrival_sample_1based = record.s_arrival_sample_0based + 1;
record.file_name               = [fileNameNoExt '.csv'];
record.event_id                = char(fileNameNoExt);
record.samplingRate            = fs;

% source_id dan metadata lain diisi kemudian via joinMetadata()
record.source_id          = '';
record.source_magnitude   = NaN;
record.source_distance_km = NaN;
record.SNR                = NaN;
record.quality_flag       = 'unknown';

ok = true;

end
