function metaFeatures = buildMetaFeatureFromModels(data, baseModels, config)

N = numel(data);
metaFeatures = cell(N, 1);
addWaveformContext = config.icnn.includeWaveformContext;

cnnPreds = predictBaselineCNNPicker(baseModels.cnn, data, config);
tcnPreds = predictTCNPicker(baseModels.tcn, data, config);

for i = 1:N
    pcST = runSTALTAPicker(data(i).X, config);
    pcAI = runAICPicker(data(i).X, config);

    Z_meta = [
        pcST.P, pcST.S, pcST.Noise, ...
        pcAI.P, pcAI.S, pcAI.Noise, ...
        cnnPreds{i}.P, cnnPreds{i}.S, cnnPreds{i}.Noise, ...
        tcnPreds{i}.P, tcnPreds{i}.S, tcnPreds{i}.Noise  ...
    ];  % [T x 12]

    if addWaveformContext
        Z_meta = [Z_meta, data(i).waveform];  % [T x 15] %#ok<AGROW>
    end

    metaFeatures{i} = Z_meta;
end

end


function ensureDir(d)
if ~isempty(d) && ~isfolder(d); mkdir(d); end
end

% =========================================================================
% buildMetaFeatureTensor.m  (src/oof_stacking/)
% =========================================================================
% PURPOSE:
%   Construct the meta-feature tensor Z_meta(t) consumed by the I-CNN
%   meta-learner, from base picker probability curve outputs.
%
% INPUT:
%   basePredictions - cell{N,1}, struct per record with fields:
%       P_stalta,S_stalta,N_stalta, P_aic,S_aic,N_aic,
%       P_cnn,S_cnn,N_cnn, P_tcn,S_tcn,N_tcn   (each [T x 1])
%   data            - struct array, same length, used for optional
%                      waveform context (.waveform field, conditioned)
%   config          - struct, framework configuration
%                      (uses config.icnn.includeWaveformContext)
%
% OUTPUT:
%   metaFeatures - cell{N,1}, each [T x C_meta] double
%                  C_meta = 12 (base picker channels) [+3 waveform context]
%   metaLabels   - cell{N,1}, each [T x 3] double (Gaussian label)
%
% NOTES:
%   Z_meta(t) = [P_STA,S_STA,Noise_STA, P_AIC,S_AIC,Noise_AIC,
%                P_CNN,S_CNN,Noise_CNN, P_TCN,S_TCN,Noise_TCN]  (12 channels)
%
%   If config.icnn.includeWaveformContext == true:
%       Z_meta_context(t) = [Z_meta(t), E_conditioned, N_conditioned, Z_conditioned]
%                                                              (15 channels)
%
%   Waveform context is OPTIONAL. The I-CNN's primary input is always the
%   stacked base-picker probability curves; waveform context channels (if
%   included) supplement but never replace this. I-CNN must never be
%   configured to receive ONLY waveform channels.
% =========================================================================
