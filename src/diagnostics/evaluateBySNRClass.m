% =========================================================================
% evaluateBySNRClass.m
% =========================================================================
% PURPOSE:
%   Mengevaluasi performa picking setelah dikelompokkan ke tiga kelas SNR:
%   Low (10   20 dB), Medium (20   40 dB), High (>=40 dB).
%
%   Interpretasi: Jika dataset didominasi SNR tinggi (common di curated
%   STEAD), evaluasi ini tetap valid sebagai profil internal, namun tidak
%   dapat secara langsung merepresentasikan performa pada data lapangan
%   berkualitas rendah.
%
% INPUTS:
%   predTable      - table dari predictions CSV (sudah di-join)
%   experimentName - char, 'Full3C' atau 'Zonly'
%   config         - struct framework
%
% OUTPUTS:
%   snrMetrics - table, metrik per kelas SNR    komponen
%   Saved:
%     results/diagnostics/snr_stratified/metrics_by_snr_<exp>.csv
% =========================================================================

function snrMetrics = evaluateBySNRClass(predTable, experimentName, config)

outDir = fullfile(config.outputDiagnosticsFolder, 'snr_stratified');
figDir = fullfile(config.outputDiagnosticsFolder, 'figures');
ensureDir(outDir); ensureDir(figDir);

%        Cari kolom SNR                                                                                                                                                                         
snrCol = '';
for cand = {'SNR','snr_mean_db','min_snr_db','snr_db'}
    if any(strcmpi(predTable.Properties.VariableNames, cand{1}))
        snrCol = cand{1}; break;
    end
end

if isempty(snrCol)
    warning('[evaluateBySNRClass] No SNR column found. Skipping SNR-stratified evaluation.');
    snrMetrics = table();
    return;
end

snr  = double(predTable.(snrCol));
errP = safeGetNum(predTable, 'p_error_ms');
errS = safeGetNum(predTable, 's_error_ms');
statP = safeGetStr(predTable, 'p_status');
statS = safeGetStr(predTable, 's_status');

%        SNR class definitions                                                                                                                                                    
snrBins  = [10, 20, 40, Inf];
snrLabels = {'Low (10-20 dB)', 'Medium (20-40 dB)', 'High (>=40 dB)'};
tolMs = [50, 100, 200];

rows = {};
for b = 1:numel(snrLabels)
    inBin = snr >= snrBins(b) & snr < snrBins(b+1);
    for comp = {'P','S'}
        c = comp{1};
        if strcmp(c,'P'); err = errP; stat = statP; else; err = errS; stat = statS; end

        errBin  = err(inBin);
        statBin = stat(inBin);
        N       = sum(inBin);
        nDet    = sum(~isnan(errBin));
        detRate = nDet / max(N, 1);

        absErr = abs(errBin(~isnan(errBin)));
        errVal = errBin(~isnan(errBin));

        if isempty(errVal)
            mae=NaN; medAE=NaN; rmse=NaN; bias=NaN;
            p90=NaN; p95=NaN; outR1000=0;
            f1s = [NaN NaN NaN];
        else
            mae     = mean(absErr);
            medAE   = median(absErr);
            rmse    = sqrt(mean(errVal.^2));
            bias    = mean(errVal);
            p90     = prctile(absErr, 90);
            p95     = prctile(absErr, 95);
            outR1000= mean(absErr > 1000);
            f1s     = computeF1s(errVal, statBin(~isnan(errBin)), N, tolMs);
        end

        rows{end+1} = table( ...
            {experimentName},{c},{snrLabels{b}}, N, nDet, detRate, ...
            mae, medAE, rmse, bias, p90, p95, outR1000, ...
            f1s(1), f1s(2), f1s(3), ...
            'VariableNames', { ...
            'Experiment','Component','SNR_Class','N','N_detected','DetectionRate', ...
            'MAE_ms','MedAE_ms','RMSE_ms','Bias_ms','P90_ms','P95_ms', ...
            'OutlierRate_1000ms','F1_50ms','F1_100ms','F1_200ms'}); %#ok
    end
end

snrMetrics = vertcat(rows{:});

outPath = fullfile(outDir, sprintf('metrics_by_snr_%s.csv', experimentName));
writetable(snrMetrics, outPath);
fprintf('  [SNR-Stratified] Saved: %s\n', outPath);
end

%        Compute F1 at multiple tolerances                                                                                                                
function f1s = computeF1s(errVal, stat, N_total, tolMs)
f1s = zeros(1, numel(tolMs));
for ti = 1:numel(tolMs)
    tol = tolMs(ti);
    TP  = sum(abs(errVal) <= tol);
    FP  = sum(abs(errVal) >  tol);
    FN  = N_total - numel(errVal);   % not detected
    pr  = TP / max(1, TP + FP);
    rc  = TP / max(1, TP + FN);
    f1s(ti) = 2*pr*rc / max(1e-10, pr+rc);
end
end

function v = safeGetNum(t, col)
idx = strcmpi(t.Properties.VariableNames, col);
if ~any(idx); v = nan(height(t),1); return; end
v = double(t.(t.Properties.VariableNames{find(idx,1)}));
end

function v = safeGetStr(t, col)
idx = strcmpi(t.Properties.VariableNames, col);
if ~any(idx); v = repmat({'unknown'}, height(t),1); return; end
v = cellstr(string(t.(t.Properties.VariableNames{find(idx,1)})));
end

function ensureDir(d)
if ~isempty(d) && ~isfolder(d); mkdir(d); end
end
