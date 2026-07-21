% =========================================================================
% computeOutlierRates.m
% =========================================================================
% PURPOSE:
%   Menghitung outlier rates berdasarkan threshold absolut dan IQR-based
%   statistical criterion untuk satu array error.
%
% INPUTS:
%   errMs - [N x 1] double, signed picking error dalam ms (NaN = no pick)
%
% OUTPUTS:
%   rates - struct dengan field:
%     .n_valid, .n_outlier_500, .n_outlier_1000, .n_outlier_2000
%     .rate_500, .rate_1000, .rate_2000
%     .n_iqr_outlier, .rate_iqr
%     .iqr_threshold
% =========================================================================

function rates = computeOutlierRates(errMs)

absErr = abs(errMs(~isnan(errMs)));
n = numel(absErr);

if n == 0
    rates = struct('n_valid',0,'n_outlier_500',0,'n_outlier_1000',0, ...
        'n_outlier_2000',0,'rate_500',0,'rate_1000',0,'rate_2000',0, ...
        'n_iqr_outlier',0,'rate_iqr',0,'iqr_threshold',NaN);
    return;
end

% IQR-based threshold
q1   = prctile(absErr, 25);
q3   = prctile(absErr, 75);
iqrV = q3 - q1;
iqrThresh = q3 + 1.5 * iqrV;

rates.n_valid        = n;
rates.n_outlier_500  = sum(absErr > 500);
rates.n_outlier_1000 = sum(absErr > 1000);
rates.n_outlier_2000 = sum(absErr > 2000);
rates.rate_500       = rates.n_outlier_500  / n;
rates.rate_1000      = rates.n_outlier_1000 / n;
rates.rate_2000      = rates.n_outlier_2000 / n;
rates.n_iqr_outlier  = sum(absErr > iqrThresh);
rates.rate_iqr       = rates.n_iqr_outlier / n;
rates.iqr_threshold  = iqrThresh;
end
