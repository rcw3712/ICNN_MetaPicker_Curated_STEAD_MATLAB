function X = preprocessWaveform(waveform, config)
waveformConditioned = conditionWaveform(waveform, config);
if config.useEnhancedRepresentation
    X = buildEnhancedRepresentation(waveformConditioned, config);
else
    X = waveformConditioned;
end
end

% =========================================================================
% applyPreprocessing.m  (src/preprocessing/)
% =========================================================================
% PURPOSE:
%   Apply preprocessWaveform() to every record in a struct array,
%   preserving the conditioned [T x 3] waveform separately from the
%   model-ready (possibly enhanced) representation X.
%
% INPUT:
%   data   - struct array
%   config - struct, framework configuration
%
% OUTPUT:
%   data - struct array with:
%       .waveform replaced by CONDITIONED [T x 3] (for optional I-CNN
%                 waveform context — see buildMetaFeatureTensor.m)
%       .X        added: [T x C_out] enhanced representation (base picker
%                 input)
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
