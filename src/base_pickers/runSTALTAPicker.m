% =========================================================================
% runSTALTAPicker.m  (src/base_pickers/)
% =========================================================================
% PURPOSE:
%   Classical STA/LTA-based base picker. LEVEL-1 base picker — generates
%   first-level probability curves directly from conditioned/enhanced
%   waveform.
%
% INPUT:
%   X      - [T x C] double, conditioned/enhanced waveform (output of
%            preprocessWaveform.m)
%   config - struct, framework configuration
%
% OUTPUT:
%   Yhat - struct with fields .P, .S, .Noise (each [T x 1], in [0,1])
%
% NOTES:
%   Base pickers generate first-level probability curves. STA/LTA itself
%   only produces a characteristic function (a ratio); this function
%   converts it to a probability-like curve via min-max normalisation and
%   Gaussian smoothing around the detected trigger.
% =========================================================================

function Yhat = runSTALTAPicker(X, config)

[T, C]  = size(X);
fs      = config.samplingRate;
staSamp = max(1, round(config.stalta.staSec * fs));
ltaSamp = max(staSamp+1, round(config.stalta.ltaSec * fs));
sigma   = config.stalta.sigmaConv;

zIdx = find(strcmp(config.channelOrder, 'Z'), 1);
eIdx = find(strcmp(config.channelOrder, 'E'), 1);
nIdx = find(strcmp(config.channelOrder, 'N'), 1);
if isempty(zIdx) || zIdx > C; zIdx = min(C,3); end

zTrace  = abs(X(:, zIdx));
staLtaZ = computeSTALTARatio(zTrace, staSamp, ltaSamp);

if ~isempty(eIdx) && ~isempty(nIdx) && C >= max(eIdx,nIdx) && ...
        any(X(:,eIdx)~=0) && any(X(:,nIdx)~=0)
    resultNE = sqrt(X(:,eIdx).^2 + X(:,nIdx).^2);
    staLtaNE = computeSTALTARatio(resultNE, staSamp, ltaSamp);
else
    staLtaNE = staLtaZ;  % Z-only fallback
end

staLtaZ_n  = normaliseRatio(staLtaZ);
staLtaNE_n = normaliseRatio(staLtaNE);

probP = ratioToProb(staLtaZ_n,  T, fs, sigma, config.stalta.trigOn);
probS = ratioToProb(staLtaNE_n, T, fs, sigma, config.stalta.trigOn);
probN = max(0, 1 - max(probP, probS));

Yhat.P = probP; Yhat.S = probS; Yhat.Noise = probN;
end

% =========================================================================
% runAICPicker.m  (src/base_pickers/)
% =========================================================================
% PURPOSE:
%   Classical AIC-based base picker. LEVEL-1 base picker.
%
% INPUT:
%   X      - [T x C] double, conditioned/enhanced waveform
%   config - struct, framework configuration
%
% OUTPUT:
%   Yhat - struct with .P, .S, .Noise
%
% NOTES:
%   AIC(k) = k*log(var(x[1:k])) + (N-k-1)*log(var(x[k+1:N]))
%   Reference: Maeda (1985), Sleeman & van Eck (1999).
% =========================================================================


function ratio = computeSTALTARatio(trace, staSamp, ltaSamp)
N = numel(trace); ratio = zeros(N,1); eps_ = 1e-10;
for i = (ltaSamp+1):N
    ltaStart = max(1, i-ltaSamp); staStart = max(1, i-staSamp);
    lta = mean(trace(ltaStart:i-1)); sta = mean(trace(staStart:i));
    ratio(i) = sta / max(lta, eps_);
end
end


function rN = normaliseRatio(ratio)
rMin = min(ratio); rMax = max(ratio);
if rMax - rMin < 1e-10; rN = zeros(size(ratio)); else; rN = (ratio-rMin)/(rMax-rMin); end
end


function prob = ratioToProb(ratioNorm, T, fs, sigma, trigThresh)
prob = zeros(T,1); t = (0:T-1)'/fs;
[pkVal, pkIdx] = max(ratioNorm);
relThresh = trigThresh/(trigThresh+1);
if pkVal >= relThresh
    tPeak = t(pkIdx);
    prob = exp(-(t-tPeak).^2/(2*sigma^2)) * pkVal;
else
    winSmooth = max(1, round(sigma*fs));
    prob = smoothdata(ratioNorm, 'gaussian', winSmooth);
end
prob = min(1, max(0, prob));
end


function aic = computeAICFunction(trace, winN)
N = numel(trace); aic = inf(N,1); eps_ = 1e-15;
searchEnd = min(N-2, winN);
for k = 2:searchEnd
    v1 = max(var(trace(1:k)), eps_);
    v2 = max(var(trace(k+1:N)), eps_);
    aic(k) = k*log(v1) + (N-k-1)*log(v2);
end
end


function prob = aicToProb(aic, T, fs, sigma)
t = (0:T-1)'/fs; prob = zeros(T,1);
validIdx = find(isfinite(aic));
if isempty(validIdx); return; end
[~, relMin] = min(aic(validIdx)); kMin = validIdx(relMin);
tMin = t(kMin);
prob = min(1, max(0, exp(-(t-tMin).^2/(2*sigma^2))));
end
