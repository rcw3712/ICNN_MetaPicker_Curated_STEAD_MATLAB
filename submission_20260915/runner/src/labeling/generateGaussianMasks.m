% =========================================================================
% generateGaussianMasks.m  (src/labeling/)
% =========================================================================
% PURPOSE:
%   Generate probabilistic Gaussian labels for P-wave, S-wave, and
%   background/noise classes.
%
% INPUT:
%   sec           - [T x 1] double, time axis in seconds (from CSV 'sec'
%                   column)
%   p_arrival_sec - double, P-wave arrival in seconds
%   s_arrival_sec - double, S-wave arrival in seconds
%   config        - struct, framework configuration (gaussianSigmaP/S are
%                   expressed in SAMPLES; converted internally — see Notes)
%
% OUTPUT:
%   Y - [T x 3] double, columns: [P_mask, S_mask, Noise_mask], all in [0,1]
%
% NOTES:
%   Formulation:
%       P_mask(t) = exp(-(t - tauP)^2 / (2*sigmaP^2))
%       S_mask(t) = exp(-(t - tauS)^2 / (2*sigmaS^2))
%       Noise_mask = 1 - max(P_mask, S_mask), clipped to [0,1]
%
%   config.gaussianSigmaP / config.gaussianSigmaS are defined in SAMPLES
%   (consistent across the framework family). Since the `sec` vector from
%   curated CSV records is in SECONDS, this function converts the
%   configured sigma values (samples) to seconds internally by dividing
%   by config.samplingRate.
%
%   If useSoftmaxLabels is true, P_mask + S_mask + Noise_mask is forced
%   to sum to 1 at every time index.
% =========================================================================

function Y = generateGaussianMasks(sec, p_arrival_sec, s_arrival_sec, config)

T  = numel(sec);
fs = config.samplingRate;

sigmaP_sec = config.gaussianSigmaP / fs;
sigmaS_sec = config.gaussianSigmaS / fs;
truncN     = config.gaussianTruncation;

P_mask = exp(-(sec - p_arrival_sec).^2 / (2 * sigmaP_sec^2));
P_mask(abs(sec - p_arrival_sec) > truncN * sigmaP_sec) = 0;

S_mask = exp(-(sec - s_arrival_sec).^2 / (2 * sigmaS_sec^2));
S_mask(abs(sec - s_arrival_sec) > truncN * sigmaS_sec) = 0;

Noise_mask = max(0, 1 - max(P_mask, S_mask));

P_mask     = min(1, max(0, P_mask));
S_mask     = min(1, max(0, S_mask));
Noise_mask = min(1, max(0, Noise_mask));

if isfield(config, 'useSoftmaxLabels') && config.useSoftmaxLabels
    total = P_mask + S_mask + Noise_mask;
    total(total < 1e-10) = 1;
    P_mask     = P_mask     ./ total;
    S_mask     = S_mask     ./ total;
    Noise_mask = Noise_mask ./ total;
end

Y = [P_mask(:), S_mask(:), Noise_mask(:)];

assert(size(Y,1) == T && size(Y,2) == 3, ...
    'generateGaussianMasks: output dimension mismatch [%d x %d], expected [%d x 3]', ...
    size(Y,1), size(Y,2), T);

end

% =========================================================================
% addGaussianLabels.m  (src/labeling/)
% =========================================================================
% PURPOSE:
%   Apply generateGaussianMasks() to every record in a struct array.
%
% INPUT:
%   data   - struct array (must have .sec, .p_arrival_sec, .s_arrival_sec)
%   config - struct, framework configuration
%
% OUTPUT:
%   data - struct array, with .label field added: [T x 3]
% =========================================================================
