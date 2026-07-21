% =========================================================================
% demo_single_csv.m  (examples/)
% =========================================================================
% Demo baca SATU file CSV STEAD sesuai format aktual:
%   time, sec, E, N, Z, p_arrival, s_arrival
%
% Cari file CSV pertama di config.csvFolder, atau buat sintetis jika kosong.
% =========================================================================

clc; clear; close all;
rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(rootDir));

fprintf('=== demo_single_csv ===\n\n');

config = config_ICNN_MetaPicker();
rng(config.randomSeed, 'twister');

% Cari satu file CSV
csvFolder = config.csvFolder;
exampleCSV = '';

if isfolder(csvFolder)
    fileList = dir(fullfile(csvFolder, '*.csv'));
    if ~isempty(fileList)
        exampleCSV = fullfile(fileList(1).folder, fileList(1).name);
    end
end

if isempty(exampleCSV)
    fprintf('Tidak ada CSV di %s — membuat file sintetis...\n', csvFolder);
    if ~isfolder(csvFolder); mkdir(csvFolder); end
    exampleCSV = fullfile(csvFolder, 'stead_event_00000.csv');
    generateExampleCSV(exampleCSV);
end

fprintf('Membaca: %s\n\n', exampleCSV);

% Baca CSV
[record, ok] = loadSingleSTEADCSV(exampleCSV, config);
assert(ok, 'Gagal membaca CSV.');

fprintf('Ringkasan record:\n');
fprintf('  file_name  : %s\n', record.file_name);
fprintf('  event_id   : %s\n', record.event_id);
fprintf('  waveform   : [%d x %d] (E, N, Z)\n', size(record.waveform));
fprintf('  p_arrival  : %.3f s (sample 0-based=%d)\n', ...
    record.p_arrival_sec, record.p_arrival_sample_0based);
fprintf('  s_arrival  : %.3f s (sample 0-based=%d)\n', ...
    record.s_arrival_sec, record.s_arrival_sample_0based);
fprintf('  S-P time   : %.3f s\n\n', record.s_arrival_sec - record.p_arrival_sec);

% Conditioning + label
wfCond = conditionWaveform(record.waveform, config);
X      = buildEnhancedRepresentation(wfCond, config);
label  = generateGaussianMasks(record.sec, record.p_arrival_sec, ...
    record.s_arrival_sec, config);

% Base pickers
pcST = runSTALTAPicker(X, config);
pcAI = runAICPicker(X, config);

fprintf('Enhanced representation X: [%d x %d]\n', size(X));
fprintf('Gaussian label: [%d x 3] (P, S, Noise)\n\n', size(label,1));

% Plot
fig = figure('Position', [50 50 1100 700], 'Color', 'white');
compNames = {'E','N','Z'};
for c = 1:3
    subplot(4,1,c);
    plot(record.sec, wfCond(:,c), 'LineWidth', 0.7); hold on;
    xline(record.p_arrival_sec, 'b--', 'LineWidth', 1.5, 'Label','P');
    xline(record.s_arrival_sec, 'r--', 'LineWidth', 1.5, 'Label','S');
    ylabel(compNames{c}); box off;
end
subplot(4,1,4);
plot(record.sec, label(:,1), 'b-',  'LineWidth', 1.5, 'DisplayName','P label'); hold on;
plot(record.sec, label(:,2), 'r-',  'LineWidth', 1.5, 'DisplayName','S label');
plot(record.sec, pcST.P,     'b--', 'LineWidth', 1.0, 'DisplayName','STA/LTA P');
plot(record.sec, pcAI.P,     'b:',  'LineWidth', 1.0, 'DisplayName','AIC P');
ylim([0 1.1]); xlabel('Time (s)'); ylabel('Probability');
legend('Location','northeast','FontSize',8); box off;
sgtitle(sprintf('Demo: %s', record.file_name), 'FontWeight', 'bold');

fprintf('Demo selesai.\n');

% ──────────────────────────────────────────────────────────────────────────
function generateExampleCSV(outPath)
% Format ASLI: time, sec, E, N, Z, p_arrival, s_arrival
fs = 100; T = 6000; t = (0:T-1)'/fs;
pA = 7.0; sA = 12.95; snr = 20;
sigLevel = 100 * 10^(snr/20);
E = 100*randn(T,1); N = 100*randn(T,1); Z = 100*randn(T,1);
tP = t-pA; Z = Z + sigLevel*sin(2*pi*5*tP).*exp(-tP.^2/0.18).*(tP>=-0.1);
tS = t-sA; N = N + 0.8*sigLevel*sin(2*pi*3*tS).*exp(-tS.^2/0.5).*(tS>=-0.2);
              E = E + 0.7*sigLevel*sin(2*pi*3*tS).*exp(-tS.^2/0.5).*(tS>=-0.2);

% Format time sebagai HH:MM:SS.mmm
timeStr = strings(T,1);
for i = 1:T
    ts = t(i);
    h  = floor(ts/3600);
    m  = floor(mod(ts,3600)/60);
    s  = mod(ts,60);
    timeStr(i) = sprintf('%02d:%02d:%06.3f', h, m, s);
end

fid = fopen(outPath, 'w');
fprintf(fid, 'time,sec,E,N,Z,p_arrival,s_arrival\n');
for i = 1:T
    fprintf(fid, '%s,%.4f,%.6f,%.6f,%.6f,%.6f,%.6f\n', ...
        timeStr(i), t(i), E(i), N(i), Z(i), pA, sA);
end
fclose(fid);
fprintf('File CSV sintetis dibuat: %s\n', outPath);
end
