% =========================================================================
% evaluatePickingPerformance.m  (src/evaluation/)
% =========================================================================
% PURPOSE:
%   Compute P-wave and S-wave picking performance metrics against ground
%   truth arrival times.
%
% INPUT:
%   predictions - struct array, output of physicsAwarePicker.m
%   groundTruth - struct array, same length, with .p_arrival_sec,
%                 .s_arrival_sec fields
%   config      - struct, framework configuration (uses config.toleranceMs)
%
% OUTPUT:
%   metrics - table, 2 rows (Component='P','S'), columns:
%       Component, MAE_ms, RMSE_ms, Bias_ms, SD_ms, DetectionRate,
%       Precision_50ms, Recall_50ms, F1_50ms,
%       Precision_100ms, Recall_100ms, F1_100ms,
%       Precision_200ms, Recall_200ms, F1_200ms
%
% NOTES:
%   error_i = tau_pred_i - tau_true_i (signed, ms)
%   MAE=mean(abs(error_i)); RMSE=sqrt(mean(error_i^2));
%   Bias=mean(error_i); SD=std(error_i)
%   TP: prediction exists AND abs(error) <= tolerance
%   FP: prediction exists BUT abs(error) > tolerance
%   FN: prediction does not exist
%   Precision=TP/(TP+FP); Recall=TP/(TP+FN); F1=2PR/(P+R)
% =========================================================================

function metrics = evaluatePickingPerformance(predictions, groundTruth, config)

tolMs = config.toleranceMs;
N     = numel(predictions);

errP = nan(N, 1);
errS = nan(N, 1);

for i = 1:N
    if ~isnan(predictions(i).p_pick_sec) && ~isnan(groundTruth(i).p_arrival_sec)
        errP(i) = (predictions(i).p_pick_sec - groundTruth(i).p_arrival_sec) * 1000;
    end
    if ~isnan(predictions(i).s_pick_sec) && ~isnan(groundTruth(i).s_arrival_sec)
        errS(i) = (predictions(i).s_pick_sec - groundTruth(i).s_arrival_sec) * 1000;
    end
end

metricsP = computeDetectionMetrics(errP, N, tolMs, 'P');
metricsS = computeDetectionMetrics(errS, N, tolMs, 'S');

metrics = [metricsP; metricsS];

fprintf('\n  === Picking Performance Summary ===\n');
for r = 1:height(metrics)
    fprintf('  [%s] MAE=%.1f ms | RMSE=%.1f ms | Bias=%.1f ms | F1@100ms=%.3f | DetRate=%.2f\n', ...
        metrics.Component{r}, metrics.MAE_ms(r), metrics.RMSE_ms(r), ...
        metrics.Bias_ms(r), metrics.F1_100ms(r), metrics.DetectionRate(r));
end

end

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
%   m - 1-row table with all computed metrics for this component
% =========================================================================
