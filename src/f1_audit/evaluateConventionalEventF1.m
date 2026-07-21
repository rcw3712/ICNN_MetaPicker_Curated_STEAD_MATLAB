function result = evaluateConventionalEventF1(errMs, detected, N_total, tol_ms)
% evaluateConventionalEventF1.m
% PURPOSE: Compute conventional event-matching F1 at one tolerance.
%
% CONVENTIONAL DEFINITION (Case B):
%   Case 1: detected AND |error| <= tol  ->  TP=1, FP=0, FN=0
%   Case 2: detected AND |error| >  tol  ->  TP=0, FP=1, FN=1
%   Case 3: not detected                  ->  TP=0, FP=0, FN=1
%
% INPUTS:
%   errMs    -- [N x 1] signed timing error in ms for ALL N_total records.
%               NaN means no prediction / not detected.
%   detected -- [N x 1] logical, true if a prediction was produced.
%   N_total  -- scalar, total test records (denominator for recall).
%   tol_ms   -- scalar, tolerance threshold in ms.
%
% OUTPUTS: result struct with TP,FP,FN,Precision,Recall,F1,MAE,MedAE,N_detected.
%
% DENOMINATOR NOTE:
%   MAE is computed over detected picks only (independent of tolerance).
%   Precision denominator: TP + FP (detected picks evaluated for accuracy).
%   Recall denominator: TP + FN = N_total (all ground-truth events).
%   F1 = 2*P*R/(P+R).

assert(numel(errMs) == N_total, ...
    'evaluateConventionalEventF1: errMs length %d != N_total %d', numel(errMs), N_total);
assert(numel(detected) == N_total, ...
    'evaluateConventionalEventF1: detected length %d != N_total %d', numel(detected), N_total);

TP = 0; FP = 0; FN = 0;

for i = 1:N_total
    if ~detected(i)
        % Case 3: missing prediction
        FN = FN + 1;
    elseif abs(errMs(i)) <= tol_ms
        % Case 1: detected and within tolerance
        TP = TP + 1;
    else
        % Case 2: detected but outside tolerance
        FP = FP + 1;
        FN = FN + 1;
    end
end

% Precision, Recall, F1
pr = TP / max(1, TP + FP);
rc = TP / max(1, TP + FN);
f1 = 2*pr*rc / max(1e-10, pr+rc);

% MAE and MedAE on detected picks only (tolerance-independent)
detErr = abs(errMs(detected & ~isnan(errMs)));
mae    = ternary(isempty(detErr), NaN, mean(detErr));
medAE  = ternary(isempty(detErr), NaN, median(detErr));

n_det         = sum(detected);
n_within_tol  = TP;
n_outside_tol = FP;
n_missing     = N_total - n_det;

result = struct('TP',TP,'FP',FP,'FN',FN,'Precision',pr,'Recall',rc,'F1',f1,...
    'MAE_ms',mae,'MedAE_ms',medAE,'N_total',N_total,...
    'N_detected',n_det,'N_within_tol',n_within_tol,...
    'N_outside_tol',n_outside_tol,'N_missing',n_missing,'tol_ms',tol_ms);
end

function out=ternary(c,a,b);if c;out=a;else;out=b;end;end
