
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

