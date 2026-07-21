% =========================================================================
% run_qc_and_metadata_build.m
% =========================================================================
% PURPOSE:
%   Verifikasi metadata_master_filled.xlsx dan menghubungkannya dengan
%   2.234 file CSV waveform. Karena QC sudah dilakukan sebelumnya (semua
%   kolom qc_* sudah terisi di Excel), skrip ini hanya melakukan:
%     1. Load metadata dari Excel
%     2. Isi kolom file_name dan file_path dari event_id
%     3. Verifikasi berapa CSV yang benar-benar ada di disk
%     4. Cetak ringkasan siap-eksperimen
%
%   TIDAK menjalankan QC ulang dari waveform — QC sudah selesai di metadata.
%
% INPUT:
%   (none — menggunakan config/config_ICNN_MetaPicker.m)
%
% OUTPUT:
%   metadata/metadata_master_filled.csv  (opsional, jauh lebih cepat dibaca)
%   Console: ringkasan dataset siap eksperimen
% =========================================================================

clc; clear; close all;
rootDir = fileparts(mfilename('fullpath'));
addpath(genpath(rootDir));

fprintf('╔══════════════════════════════════════════════════════════╗\n');
fprintf('║  run_qc_and_metadata_build                                ║\n');
fprintf('║  Verifikasi metadata + CSV linkage                        ║\n');
fprintf('╚══════════════════════════════════════════════════════════╝\n\n');

config = config_ICNN_MetaPicker();
rng(config.randomSeed, 'twister');

% ── LANGKAH 0 (OPSIONAL, SANGAT DISARANKAN): Export Excel -> CSV ─────────
% Membaca 25.000 baris Excel bisa memakan 2-5 menit.
% Export sekali ke CSV agar run berikutnya hanya butuh beberapa detik.
xlsxPath = config.metadataPath;
[~, ~, ext] = fileparts(xlsxPath);
if strcmpi(ext, '.xlsx')
    fprintf('[OPSIONAL] Ekspor Excel ke CSV untuk akses lebih cepat?\n');
    fprintf('  Ketik "y" lalu Enter untuk ekspor, atau tekan Enter untuk skip:\n');
    % Di batch mode, skip otomatis. Uncomment baris di bawah jika ingin
    % ekspor otomatis tanpa konfirmasi:
    % exportMetadataToCSV(config);
    % config.metadataPath = strrep(config.metadataPath, '.xlsx', '.csv');
end

% ── LANGKAH 1: Load metadata dari Excel ──────────────────────────────────
fprintf('\n[1] Loading metadata dari: %s\n', config.metadataPath);
config.filterExistingCSVOnly = false;  % cek dulu tanpa filter
metadata = loadMetadataFromExcel(config.metadataPath, config);
fprintf('    Metadata loaded: %d rows\n\n', height(metadata));

% ── LANGKAH 2: Verifikasi CSV files di disk ───────────────────────────────
fprintf('[2] Verifikasi CSV files di disk: %s\n', config.csvFolder);
if ~isfolder(config.csvFolder)
    fprintf('    PERINGATAN: Folder CSV tidak ditemukan: %s\n', config.csvFolder);
    fprintf('    Pastikan 2.234 file CSV ada di folder tersebut.\n\n');
    nFound = 0;
    nMissing = height(metadata);
else
    csvFiles = dir(fullfile(config.csvFolder, 'stead_event_*.csv'));
    nFound = numel(csvFiles);
    fprintf('    File CSV ditemukan di disk   : %d\n', nFound);

    % Cek cross-match dengan metadata
    foundNames = string({csvFiles.name});
    metaNames  = string(metadata.file_name);
    inBoth     = sum(ismember(metaNames, foundNames));
    inMetaOnly = sum(~ismember(metaNames, foundNames));
    inDiskOnly = sum(~ismember(foundNames, metaNames));

    fprintf('    Ada di metadata DAN disk     : %d\n', inBoth);
    fprintf('    Ada di metadata, TIDAK di disk: %d\n', inMetaOnly);
    fprintf('    Ada di disk, TIDAK di metadata: %d\n\n', inDiskOnly);
    nMissing = inMetaOnly;
end

% ── LANGKAH 3: Statistik dataset ─────────────────────────────────────────
fprintf('[3] Statistik dataset:\n');
fprintf('    Total traces di metadata     : %d\n', height(metadata));

% Quality flag distribution
if ismember('quality_flag', metadata.Properties.VariableNames)
    qf    = string(metadata.quality_flag);
    nGood = sum(qf == "good");
    nBad  = sum(qf == "bad" | qf == "rejected" | qf == "poor");
    fprintf('    quality_flag = good          : %d\n', nGood);
    fprintf('    quality_flag = bad/rejected  : %d\n', nBad);
end

% Source ID statistics
nUniqSrc = numel(unique(string(metadata.source_id)));
fprintf('    Unique source_id (events)    : %d\n', nUniqSrc);

% Range statistics
if ismember('source_distance_km', metadata.Properties.VariableNames)
    dists = double(metadata.source_distance_km);
    fprintf('    Distance range               : %.1f - %.1f km (mean %.1f)\n', ...
        min(dists), max(dists), mean(dists));
end
if ismember('source_magnitude', metadata.Properties.VariableNames)
    mags = double(metadata.source_magnitude);
    fprintf('    Magnitude range              : %.1f - %.1f (mean %.2f)\n', ...
        min(mags), max(mags), mean(mags));
end
if ismember('min_snr_db', metadata.Properties.VariableNames)
    snrs = double(metadata.min_snr_db);
    fprintf('    SNR range                    : %.1f - %.1f dB (mean %.1f)\n', ...
        min(snrs), max(snrs), mean(snrs));
end
if ismember('sp_time_sec', metadata.Properties.VariableNames)
    sps = double(metadata.sp_time_sec);
    fprintf('    S-P time range               : %.2f - %.2f s (mean %.2f)\n', ...
        min(sps), max(sps), mean(sps));
end

% ── LANGKAH 4: Estimasi distribusi split ─────────────────────────────────
fprintf('\n[4] Estimasi split (berdasarkan %d unique source_id):\n', nUniqSrc);
nTrain = round(config.trainRatio * nUniqSrc);
nVal   = round(config.valRatio   * nUniqSrc);
nTest  = nUniqSrc - nTrain - nVal;
fprintf('    Train  (%.0f%%): ~%d events (dari %d unique source_id)\n', ...
    config.trainRatio*100, nTrain, nUniqSrc);
fprintf('    Val    (%.0f%%): ~%d events\n', config.valRatio*100, nVal);
fprintf('    Test   (%.0f%%): ~%d events\n', config.testRatio*100, nTest);

% ── Ringkasan akhir ────────────────────────────────────────────────────────
fprintf('\n╔══════════════════════════════════════════════════════════╗\n');
if nMissing == 0 && nFound >= 2000
    fprintf('║  ✓  Dataset SIAP untuk eksperimen.                       ║\n');
    fprintf('║     Jalankan: run_experiment_full3C_STEAD                 ║\n');
elseif nFound == 0
    fprintf('║  ✗  BELUM ADA file CSV di disk.                          ║\n');
    fprintf('║     Letakkan 2.234 CSV di: %-30s ║\n', config.csvFolder);
else
    fprintf('║  !  Dataset SEBAGIAN tersedia (%d/%d CSV).               ║\n', ...
        nFound, height(metadata));
    fprintf('║     Eksperimen bisa dijalankan dengan subset ini.         ║\n');
end
fprintf('╚══════════════════════════════════════════════════════════╝\n\n');

fprintf('LANGKAH SELANJUTNYA:\n');
fprintf('  1. (Opsional tapi disarankan) Export Excel ke CSV:\n');
fprintf('     >> exportMetadataToCSV(config_ICNN_MetaPicker())\n');
fprintf('     Lalu ubah config.metadataPath ke file .csv\n\n');
fprintf('  2. Jalankan eksperimen Full 3C:\n');
fprintf('     >> run_experiment_full3C_STEAD\n\n');
fprintf('  3. Jalankan eksperimen Z-only (simulasi PiGraf):\n');
fprintf('     >> run_experiment_Zonly_STEAD\n\n');
