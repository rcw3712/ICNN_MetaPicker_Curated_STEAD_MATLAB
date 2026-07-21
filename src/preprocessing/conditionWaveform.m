% =========================================================================
% conditionWaveform.m  (src/preprocessing/)
% =========================================================================
% PURPOSE:
%   Apply signal conditioning to a raw waveform: demean, detrend,
%   bandpass filter, per-channel normalisation, and optional clipping.
%
% INPUT:
%   waveform - [T x 3] double, raw curated waveform (E, N, Z columns)
%   config   - struct, framework configuration
%
% OUTPUT:
%   waveformConditioned - [T x 3] double
%
% NOTES:
%   The input is not raw-only waveform; it is a conditioned signal
%   representation derived from curated STEAD CSV records. The curated
%   CSVs themselves are already filtered for quality (distance,
%   magnitude, SNR, manual picks) but still require standard signal
%   conditioning before use by any base picker, since amplitude scale,
%   DC offset, and broadband noise content vary across stations and
%   instruments even within the curated subset.
%
%   x_norm = (x - mean(x)) / (std(x) + eps)
% =========================================================================

function waveformConditioned = conditionWaveform(waveform, config)

[T, C] = size(waveform);
waveformConditioned = zeros(T, C);
fs = config.samplingRate;

for c = 1:C
    sig = double(waveform(:, c));

    if config.useDemean
        sig = sig - mean(sig);
    end

    if config.useDetrend
        sig = detrend(sig, 'linear');
    end

    fLow  = config.bandpassFreq(1);
    fHigh = config.bandpassFreq(2);
    nyq   = fs / 2;
    if fLow > 0 && fHigh < nyq
        [b, a] = butter(config.filterOrder, [fLow, fHigh] / nyq, 'bandpass');
        sig = filtfilt(b, a, sig);
    elseif fLow > 0
        [b, a] = butter(config.filterOrder, fLow / nyq, 'high');
        sig = filtfilt(b, a, sig);
    end

    if config.useNormalization
        eps_ = 1e-10;
        mu   = mean(sig);
        sd   = std(sig);
        sig  = (sig - mu) / (sd + eps_);
    end

    if config.useClipping
        thresh = config.clipThreshold;
        sig    = max(-thresh, min(thresh, sig));
        if config.useNormalization
            sd2 = std(sig);
            if sd2 > 1e-10
                sig = sig / sd2;
            end
        end
    end

    waveformConditioned(:, c) = sig;
end

end

% =========================================================================
% buildEnhancedRepresentation.m  (src/preprocessing/)
% =========================================================================
% PURPOSE:
%   Build an enhanced multi-channel representation from a conditioned
%   waveform, combining conditioned amplitude with envelope, short-term
%   energy, and STA/LTA characteristic function channels.
%
% INPUT:
%   waveformConditioned - [T x 3] double
%   config               - struct, framework configuration
%
% OUTPUT:
%   X - [T x C_out] double
%       useEnhancedRepresentation == false: X = [E_norm, N_norm, Z_norm] (C_out=3)
%       useEnhancedRepresentation == true:
%           X = [E_norm, N_norm, Z_norm, E_env, N_env, Z_env, STE_Z, CF_STA_LTA_Z]
%           (C_out = 8)
%
% NOTES:
%   Enhanced representation is used for base pickers so that the model is
%   more adaptive than raw-only waveform. This is the input fed to
%   STA/LTA, AIC, Baseline CNN, and TCN — never to the I-CNN meta-learner
%   directly (the I-CNN consumes the meta-feature tensor built from base
%   picker OUTPUTS; see buildMetaFeatureTensor.m).
% =========================================================================


function cf = computeCharacteristicFunction(absTrace, staSamp, ltaSamp)
N  = numel(absTrace);
cf = zeros(N, 1);
eps_ = 1e-10;
for i = (ltaSamp+1):N
    ltaStart = max(1, i - ltaSamp);
    staStart = max(1, i - staSamp);
    lta = mean(absTrace(ltaStart:i-1));
    sta = mean(absTrace(staStart:i));
    if lta > eps_
        cf(i) = sta / lta;
    end
end
end
