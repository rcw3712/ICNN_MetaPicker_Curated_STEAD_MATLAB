% =========================================================================
% exportMetadataToCSV.m  (src/data_loading/)
% =========================================================================
% PURPOSE:
%   Export metadata_master_filled.xlsx ke format CSV agar pembacaan pada
%   run berikutnya jauh lebih cepat (readtable CSV ~10x lebih cepat dari
%   Excel untuk file besar seperti 25.000 baris x 56 kolom).
%
% INPUT:
%   config - struct, framework configuration
%
% OUTPUT:
%   (file CSV disimpan, path dicetak ke console)
%   csvPath - char, path ke file CSV yang dihasilkan
%
% USAGE:
%   >> exportMetadataToCSV(config_ICNN_MetaPicker())
%   Kemudian ubah config.metadataPath ke file .csv yang dihasilkan:
%   >> config.metadataPath = 'metadata/metadata_master_filled.csv';
%
% NOTES:
%   Jalankan SEKALI saja setelah mendapatkan file .xlsx. Setelah itu
%   gunakan file .csv untuk semua run eksperimen — jauh lebih cepat.
% =========================================================================

function csvPath = exportMetadataToCSV(config)

xlsxPath = config.metadataPath;
if ~isfile(xlsxPath)
    error('exportMetadataToCSV:fileNotFound', 'File tidak ditemukan: %s', xlsxPath);
end

[folder, name, ext] = fileparts(xlsxPath);
if strcmpi(ext, '.csv')
    fprintf('  File sudah dalam format CSV: %s\n', xlsxPath);
    csvPath = xlsxPath;
    return;
end

csvPath = fullfile(folder, [name '.csv']);
fprintf('  Membaca Excel: %s\n', xlsxPath);
fprintf('  (Proses ini memakan beberapa menit untuk 25.000 baris...)\n');

tic;
opts     = detectImportOptions(xlsxPath, 'VariableNamingRule','preserve');
metadata = readtable(xlsxPath, opts, 'VariableNamingRule','preserve');
t1 = toc;
fprintf('  Excel dibaca dalam %.1f detik.\n', t1);

tic;
writetable(metadata, csvPath);
t2 = toc;
fprintf('  CSV disimpan: %s (%.1f detik)\n', csvPath, t2);
fprintf('\n  Untuk run selanjutnya, gunakan:\n');
fprintf('  config.metadataPath = ''%s'';\n', csvPath);

end
