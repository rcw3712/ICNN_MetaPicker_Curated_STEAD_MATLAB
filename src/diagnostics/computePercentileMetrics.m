% =========================================================================
% computePercentileMetrics.m
% =========================================================================
% PURPOSE:
%   Menghitung metrik error yang robust terhadap outlier untuk P-wave dan
%   S-wave, termasuk percentile errors dan outlier rates.
%
%   Interpretasi: "The gap between MAE and RMSE indicates whether large
%   timing outliers dominate the error distribution. A ratio RMSE/MAE >> 1
%   suggests a heavy-tailed distribution where the median absolute error
%   (MedAE) is more representative of typical picking performance."
%
% INPUTS:
%   predTable      - table dari predictions CSV (sudah di-join dengan metadata)
%   experimentName - char, 'Full3C' atau 'Zonly'
%   config         - struct framework
%
% OUTPUTS:
%   metrics - table, satu baris per komponen (P, S) dengan semua metrik
%   Saved:
%     results/diagnostics/percentile_metrics/percentile_metrics_<exp>.csv
% =========================================================================

function metrics = computePercentileMetrics(predTable, experimentName, config)

outDir = fullfile(config.outputDiagnosticsFolder, 'percentile_metrics');
ensureDir(outDir);

%        Ekstrak error arrays                                                                                                                                                          
errP = safeGetNum(predTable, 'p_error_ms');
errS = safeGetNum(predTable, 's_error_ms');
statP = safeGetStr(predTable, 'p_status');
statS = safeGetStr(predTable, 's_status');

N = height(predTable);

rows = {};
for comp = {'P','S'}
    c = comp{1};
    if strcmp(c,'P'); err = errP; stat = statP;
    else;             err = errS; stat = statS; end

    nDet   = sum(~isnan(err));
    detRate = nDet / N;

    absErr = abs(err(~isnan(err)));
    errVal = err(~isnan(err));

    if isempty(errVal)
        rows{end+1} = buildRow(c, experimentName, N, 0, 0, ...
            nan,nan,nan,nan,nan,nan,nan,nan,nan,0,0,0); %#ok
        continue;
    end

    mae    = mean(absErr);
    medAE  = median(absErr);
    rmse   = sqrt(mean(errVal.^2));
    bias   = mean(errVal);
    stdErr = std(errVal);
    p75    = prctile(absErr, 75);
    p90    = prctile(absErr, 90);
    p95    = prctile(absErr, 95);
    p99    = prctile(absErr, 99);
    maxAE  = max(absErr);
    outR500  = mean(absErr > 500);
    outR1000 = mean(absErr > 1000);
    outR2000 = mean(absErr > 2000);

    rows{end+1} = buildRow(c, experimentName, N, nDet, detRate, ...
        mae, medAE, rmse, bias, stdErr, p75, p90, p95, p99, maxAE, ...
        outR500, outR1000, outR2000); %#ok
end

metrics = vertcat(rows{:});

%        Save CSV                                                                                                                                                                                           
outPath = fullfile(outDir, sprintf('percentile_metrics_%s.csv', experimentName));
writetable(metrics, outPath);
fprintf('  [PercentileMetrics] Saved: %s\n', outPath);
end

%        Helper: build one row as table                                                                                                                         
function t = buildRow(comp, expName, N, nDet, detRate, ...
    mae, medAE, rmse, bias, stdErr, p75, p90, p95, p99, maxAE, ...
    outR500, outR1000, outR2000)
t = table( ...
    {comp}, {expName}, N, nDet, detRate, ...
    mae, medAE, rmse, bias, stdErr, p75, p90, p95, p99, maxAE, ...
    outR500, outR1000, outR2000, ...
    'VariableNames', { ...
    'Component','Experiment','N_total','N_detected','DetectionRate', ...
    'MAE_ms','MedAE_ms','RMSE_ms','Bias_ms','STD_ms', ...
    'P75_ms','P90_ms','P95_ms','P99_ms','MaxAE_ms', ...
    'OutlierRate_500ms','OutlierRate_1000ms','OutlierRate_2000ms'});
end

function v = safeGetNum(t, col)
c = findCol(t, col);
if isempty(c); v = nan(height(t),1); return; end
v = double(t.(c));
end

function v = safeGetStr(t, col)
c = findCol(t, col);
if isempty(c); v = repmat({'unknown'}, height(t),1); return; end
v = cellstr(string(t.(c)));
end

function colName = findCol(t, name)
idx = strcmpi(t.Properties.VariableNames, name);
if any(idx); colName = t.Properties.VariableNames{find(idx,1)};
else; colName = ''; end
end

function ensureDir(d)
if ~isempty(d) && ~isfolder(d); mkdir(d); end
end
