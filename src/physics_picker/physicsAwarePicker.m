% =========================================================================
% physicsAwarePicker.m  (src/physics_picker/)
% =========================================================================
% PURPOSE:
%   Extract final P-wave and S-wave pick times from I-CNN meta-learner
%   probability curves, enforcing physically plausible arrival ordering.
%
% INPUT:
%   Yhat   - cell{N,1}, struct per record with .P, .S, .Noise [T x 1]
%   config - struct, framework configuration (uses config.minSPTimeSec,
%            config.maxSPTimeSec, config.pickProbThreshold,
%            config.qualityThresholdP, config.qualityThresholdS,
%            config.samplingRate)
%
% OUTPUT:
%   picks - struct array, one element per record, with fields:
%       .p_pick_sample, .s_pick_sample  (double, samples; s is NaN if undetected)
%       .p_pick_sec,    .s_pick_sec     (double, seconds)
%       .p_quality,     .s_quality      (double, quality score)
%       .p_status,      .s_status       ('detected'|'uncertain'|'not_detected')
%       .p_error_ms,    .s_error_ms     (populated later by evaluatePickingPerformance.m)
%
% NOTES:
%   Physics-aware picking enforces physically plausible P-S arrival
%   order. Without this constraint, the S-wave probability curve can
%   produce false peaks within the P-wave coda. By restricting the S
%   search to a window strictly AFTER the P pick, these false picks are
%   eliminated.
%
%   Rules:
%     1. tauP = argmax P_prob(t) over the entire trace
%     2. Search S_prob(t) only within [tauP + minSPTimeSec, tauP + maxSPTimeSec]
%     3. Enforce tauS > tauP (guaranteed by window construction)
%     4. If no valid S peak exceeds pickProbThreshold, status reflects
%        'uncertain' or 'not_detected'
%     5. Quality scores: Q_P = max(P_prob)/(mean(P_prob)+eps),
%                         Q_S = max(S_prob)/(mean(S_prob)+eps)
%        compared against config.qualityThresholdP/S to refine status.
% =========================================================================

function picks = physicsAwarePicker(Yhat, config)

N       = numel(Yhat);
fs      = config.samplingRate;
minSP   = config.minSPTimeSec;
maxSP   = config.maxSPTimeSec;
probThr = config.pickProbThreshold;
qThrP   = config.qualityThresholdP;
qThrS   = config.qualityThresholdS;
eps_    = 1e-6;

picks = struct(...
    'p_pick_sample', num2cell(nan(N,1)), 's_pick_sample', num2cell(nan(N,1)), ...
    'p_pick_sec',    num2cell(nan(N,1)), 's_pick_sec',    num2cell(nan(N,1)), ...
    'p_quality',     num2cell(zeros(N,1)), 's_quality',   num2cell(zeros(N,1)), ...
    'p_status',      repmat({'not_detected'}, N, 1), ...
    's_status',      repmat({'not_detected'}, N, 1), ...
    'p_error_ms',    num2cell(nan(N,1)), 's_error_ms',  num2cell(nan(N,1)));

for i = 1:N
    probP = Yhat{i}.P;
    probS = Yhat{i}.S;
    T     = numel(probP);
    sampleIdx = (1:T)';

    % ── Rule 1: P pick = global argmax ──────────────────────────────────
    [pkP, pkPIdx] = max(probP);
    tauP_sample = sampleIdx(pkPIdx);
    tauP_sec    = tauP_sample / fs;

    qP = pkP / (mean(probP) + eps_);
    picks(i).p_pick_sample = tauP_sample;
    picks(i).p_pick_sec    = tauP_sec;
    picks(i).p_quality     = qP;
    if pkP >= probThr && qP >= qThrP
        picks(i).p_status = 'detected';
    elseif pkP >= probThr * 0.5
        picks(i).p_status = 'uncertain';
    else
        picks(i).p_status = 'not_detected';
    end

    % ── Rule 2-3: S pick within physically valid window AFTER P ─────────
    winStartSample = tauP_sample + minSP * fs;
    winEndSample   = tauP_sample + maxSP * fs;
    winMask = (sampleIdx >= winStartSample) & (sampleIdx <= winEndSample);

    probS_win = probS;
    probS_win(~winMask) = 0;

    [pkS, pkSIdx] = max(probS_win);

    if pkS >= probThr && winMask(pkSIdx)
        tauS_sample = sampleIdx(pkSIdx);
        qS = pkS / (mean(probS(winMask)) + eps_);

        picks(i).s_pick_sample = tauS_sample;
        picks(i).s_pick_sec    = tauS_sample / fs;
        picks(i).s_quality     = qS;
        if qS >= qThrS
            picks(i).s_status = 'detected';
        else
            picks(i).s_status = 'uncertain';
        end
    elseif pkS >= probThr * 0.5 && any(winMask)
        tauS_sample = sampleIdx(pkSIdx);
        picks(i).s_pick_sample = tauS_sample;
        picks(i).s_pick_sec    = tauS_sample / fs;
        picks(i).s_quality     = pkS / (mean(probS(winMask)) + eps_);
        picks(i).s_status      = 'uncertain';
    else
        picks(i).s_pick_sample = NaN;
        picks(i).s_pick_sec    = NaN;
        picks(i).s_quality     = 0;
        picks(i).s_status      = 'not_detected';
    end
end

end
