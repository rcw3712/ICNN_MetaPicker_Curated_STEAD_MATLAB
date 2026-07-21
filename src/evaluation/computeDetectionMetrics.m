function m = computeDetectionMetrics(err, N, tolMs, compName)
% =========================================================================
% computeDetectionMetrics.m  (src/evaluation/)
% =========================================================================
% PURPOSE:
%   Compute MAE, RMSE, Bias, SD, and Precision/Recall/F1 at multiple
%   tolerances for a single phase component (P or S).
%
% INPUT:
%   err      - [N x 1] double, signed error in ms (NaN = no valid pick)
%   N        - int, total number of ground-truth records
%   tolMs    - [1 x K] double, tolerance thresholds in ms
%   compName - char, 'P' or 'S'
%
% OUTPUT:
%   m - 1-row table with columns:
%       Component, MAE_ms, RMSE_ms, Bias_ms, SD_ms, DetectionRate,
%       Precision_Xms, Recall_Xms, F1_Xms  (per tolerance),
%       F1_100ms  (convenience alias — only added if 100ms NOT in tolMs)
% =========================================================================

validErr = err(~isnan(err));
nValid   = numel(validErr);

% ── Case: no valid picks ──────────────────────────────────────────────────
if nValid == 0
    rowData  = [{compName}, num2cell(nan(1, 5))];
    varNames = {'Component','MAE_ms','RMSE_ms','Bias_ms','SD_ms','DetectionRate'};
    for tol = tolMs
        rowData  = [rowData, {0, 0, 0}]; %#ok<AGROW>
        varNames = [varNames, {sprintf('Precision_%dms',tol), ...
            sprintf('Recall_%dms',tol), sprintf('F1_%dms',tol)}]; %#ok<AGROW>
    end
    % Tambahkan F1_100ms HANYA jika 100ms belum ada di tolMs
    if ~ismember(100, tolMs)
        varNames = [varNames, {'F1_100ms'}];
        rowData  = [rowData, {0}];
    end
    m = cell2table(rowData, 'VariableNames', varNames);
    return;
end

% ── Compute scalar metrics ────────────────────────────────────────────────
mae  = mean(abs(validErr));
rmse = sqrt(mean(validErr.^2));
bias = mean(validErr);
sd   = std(validErr);
det  = nValid / N;

rowData  = {compName, mae, rmse, bias, sd, det};
varNames = {'Component','MAE_ms','RMSE_ms','Bias_ms','SD_ms','DetectionRate'};

f1_100 = NaN;
has100 = ismember(100, tolMs);

for tol = tolMs
    TP = sum(abs(validErr) <= tol);
    FP = sum(abs(validErr) >  tol);
    FN = N - nValid;

    prec = TP / max(1, TP + FP);
    rec  = TP / max(1, TP + FN);
    f1   = 2 * prec * rec / max(1e-10, prec + rec);

    if tol == 100
        f1_100 = f1;
    end

    rowData  = [rowData, {prec, rec, f1}]; %#ok<AGROW>
    varNames = [varNames, {sprintf('Precision_%dms', tol), ...
        sprintf('Recall_%dms', tol), sprintf('F1_%dms', tol)}]; %#ok<AGROW>
end

% Tambahkan F1_100ms sebagai kolom alias HANYA jika 100ms belum ada di tolMs
% (jika sudah ada, F1_100ms == F1_100ms dari loop — tidak perlu duplikat)
if ~has100
    varNames = [varNames, {'F1_100ms'}];
    if isnan(f1_100)
        % Hitung retroaktif untuk toleransi 100ms
        TP = sum(abs(validErr) <= 100);
        FP = sum(abs(validErr) >  100);
        FN = N - nValid;
        prec100 = TP / max(1, TP + FP);
        rec100  = TP / max(1, TP + FN);
        f1_100  = 2 * prec100 * rec100 / max(1e-10, prec100 + rec100);
    end
    rowData = [rowData, {f1_100}];
end

m = cell2table(rowData, 'VariableNames', varNames);

end
