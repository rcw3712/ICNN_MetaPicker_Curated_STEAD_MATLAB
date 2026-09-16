% =========================================================================
% loadMetadataFromExcel.m  (src/data_loading/)
% =========================================================================
% PURPOSE:
%   Read the pre-filled metadata master Excel file (metadata_master_filled.xlsx)
%   yang sudah berisi 25.000 baris lengkap dengan source_id ASLI STEAD,
%   quality_flag, p/s_arrival_sec, dan statistik amplitude per kanal.
%
% INPUT:
%   metadataPath - char/string, path ke file .xlsx atau .csv metadata
%   config       - struct, framework configuration
%
% OUTPUT:
%   metadata - table, schema disesuaikan dengan metadata_master_filled.xlsx:
%       file_name, file_path, event_id, source_id, trace_name,
%       quality_flag, p_arrival_sec, s_arrival_sec, source_magnitude,
%       source_distance_km, min_snr_db, sp_time_sec, ... dan semua 56 kolom.
%
% NOTES:
%   File metadata_master_filled.xlsx SUDAH berisi:
%     - source_id ASLI STEAD (mis. 'uw10827933') -> valid untuk source-level split
%     - quality_flag ('good'/'bad') -> QC sudah dilakukan sebelumnya
%     - p_arrival_sec, s_arrival_sec -> dari STEAD manual picks
%     - file_name, file_path KOSONG -> diisi oleh fungsi ini berdasarkan
%       event_id dan config.csvFolder
%
%   Format file yang didukung:
%     .xlsx -> dibaca via readtable dengan xlsxopts
%     .csv  -> dibaca via readtable standar (lebih cepat untuk file besar)
%
%   PENTING: p_arrival_sec dan s_arrival_sec di metadata BISA berbeda
%   dengan nilai di dalam CSV waveform (karena metadata dibuat dari HDF5
%   STEAD, sedangkan CSV mungkin menggunakan referensi waktu berbeda).
%   Framework menggunakan nilai dari kolom p_arrival / s_arrival di dalam
%   CSV itu sendiri sebagai ground truth (via loadSingleSTEADCSV.m),
%   bukan dari metadata — kecuali jika config.usePArrivalFromMetadata=true.
% =========================================================================

function metadata = loadMetadataFromExcel(metadataPath, config)

if ~isfile(metadataPath)
    error('loadMetadataFromExcel:fileNotFound', ...
        'Metadata file not found: %s\nLetakkan metadata_master_filled.xlsx di folder: %s', ...
        metadataPath, fileparts(metadataPath));
end

fprintf('  Loading metadata from: %s\n', metadataPath);
[~, ~, ext] = fileparts(metadataPath);

tic;
if strcmpi(ext, '.xlsx') || strcmpi(ext, '.xls')
    % Untuk file Excel besar (25.000 baris x 56 kolom), readtable membutuhkan
    % beberapa menit. Opsional: ekspor sekali ke CSV lalu gunakan .csv
    % untuk run selanjutnya (jauh lebih cepat).
    %
    % Catatan kompatibilitas: 'VariableNamingRule' harus diset di dalam
    % ImportOptions via detectImportOptions, BUKAN sebagai argumen terpisah
    % ke readtable ketika opts sudah diberikan.
    try
        % Cara 1: detectImportOptions dengan VariableNamingRule (R2020a+)
        opts = detectImportOptions(metadataPath);
        opts.VariableNamingRule = 'preserve';
        metadata = readtable(metadataPath, opts);
    catch
        % Cara 2: readtable langsung tanpa opts (kompatibel semua versi)
        metadata = readtable(metadataPath, 'VariableNamingRule','preserve');
    end
else
    % CSV: langsung readtable
    try
        metadata = readtable(metadataPath, 'TextType','string', ...
            'VariableNamingRule','preserve');
    catch
        % Fallback tanpa TextType untuk MATLAB lama
        metadata = readtable(metadataPath, 'VariableNamingRule','preserve');
    end
end
elapsed = toc;
fprintf('  Metadata loaded: %d rows x %d columns (%.1f s)\n', ...
    height(metadata), width(metadata), elapsed);

% ── Validasi kolom wajib ──────────────────────────────────────────────────
REQUIRED = {'event_id', 'source_id', 'quality_flag', ...
            'p_arrival_sec', 's_arrival_sec'};
missingCols = setdiff(REQUIRED, metadata.Properties.VariableNames);
if ~isempty(missingCols)
    error('loadMetadataFromExcel:missingCols', ...
        'Metadata missing required column(s): %s', strjoin(missingCols, ', '));
end

% ── Isi file_name dan file_path dari event_id + csvFolder ────────────────
% file_name = stead_event_00000.csv (derived from event_id)
% file_path = csvFolder/stead_event_00000.csv
csvFolder = config.csvFolder;
fprintf('  Building file_name and file_path from event_id + csvFolder: %s\n', csvFolder);

nRows = height(metadata);
fileNames  = string(metadata.event_id) + ".csv";
filePaths  = string(csvFolder) + filesep + fileNames;

% Isi atau timpa kolom file_name dan file_path
metadata.file_name = fileNames;
metadata.file_path = filePaths;

% ── Filter by quality_flag ────────────────────────────────────────────────
qfCol = string(metadata.quality_flag);
nBad  = sum(strcmpi(qfCol, 'bad') | strcmpi(qfCol, 'rejected') | strcmpi(qfCol, 'poor'));
if nBad > 0
    fprintf('  Removing %d records with quality_flag bad/rejected/poor\n', nBad);
    keepMask = ~(strcmpi(qfCol,'bad') | strcmpi(qfCol,'rejected') | strcmpi(qfCol,'poor'));
    metadata = metadata(keepMask, :);
    fprintf('  Records after quality filter: %d\n', height(metadata));
end

% ── Filter: hanya record yang CSV-nya tersedia di disk ───────────────────
if isfield(config, 'filterExistingCSVOnly') && config.filterExistingCSVOnly
    fprintf('  Checking which CSV files exist on disk...\n');
    existsMask = arrayfun(@(p) isfile(char(p)), metadata.file_path);
    nMissing   = sum(~existsMask);
    if nMissing > 0
        fprintf('  WARNING: %d CSV files not found on disk, removing from metadata\n', nMissing);
        metadata = metadata(existsMask, :);
    end
    fprintf('  Records with CSV on disk: %d\n', height(metadata));
end

% ── Statistik akhir ────────────────────────────────────────────────────────
nUniqueSrc = numel(unique(string(metadata.source_id)));
fprintf('  Final metadata: %d traces, %d unique source_id (events)\n', ...
    height(metadata), nUniqueSrc);

% ── Validasi source_id (pastikan bukan fallback alias event_id) ────────────
sids = string(metadata.source_id);
eids = string(metadata.event_id);
fracSame = mean(sids == eids);
if fracSame > 0.99
    warning('loadMetadataFromExcel:sourceIDFallback', ...
        ['source_id appears identical to event_id (%.0f%% of rows). ' ...
         'Strict source-level split requires original STEAD source_id.'], ...
        fracSame*100);
else
    fprintf('  source_id validation: %.1f%% unique from event_id (STEAD source_id OK)\n', ...
        (1-fracSame)*100);
end

end
