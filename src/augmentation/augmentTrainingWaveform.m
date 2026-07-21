% =========================================================================
% augmentTrainingWaveform.m  (src/augmentation/)
% =========================================================================
% PURPOSE:
%   Apply data augmentation to TRAINING records only.
%
% INPUT:
%   data   - struct array, TRAINING SUBSET ONLY (post leakage-free split)
%   config - struct, framework configuration
%
% OUTPUT:
%   dataAug - struct array, originals plus config.augFactor augmented
%             copies of each
%
% NOTES:
%   Augmentation must be applied only after leakage-free split and only
%   on training data. Never call this function on validation, final
%   test, or Z-only evaluation data.
%
%   Operations (each independently toggled by config flags):
%     1. Additive Gaussian noise        (config.useAdditiveNoise)
%     2. Amplitude scaling               (config.useAmplitudeScaling)
%     3. Small time shift, label-aware   (config.useTimeShift)
%     4. Channel dropout: drop E, N, or both
%                                         (config.useChannelDropout)
%     5. Polarity flip                   (config.usePolarityFlip)
% =========================================================================

function dataAug = augmentTrainingWaveform(data, config)

factor  = config.augFactor;
N       = numel(data);
dataAug = data;
augIdx  = N;

for i = 1:N
    d = data(i);

    for k = 1:factor
        dA = d;
        wf = d.waveform;       % conditioned waveform [T x 3]
        T  = size(wf, 1);
        pSec = d.p_arrival_sec;
        sSec = d.s_arrival_sec;
        fs   = d.samplingRate;

        % ── 1. Additive Gaussian noise ────────────────────────────────────
        if config.useAdditiveNoise
            snrTarget = config.augNoiseSNR_dB;
            sigPow    = mean(wf(:).^2);
            noisePow  = sigPow / (10^(snrTarget/10));
            noise     = sqrt(max(noisePow,0)) * randn(size(wf));
            wf = wf + noise;
        end

        % ── 2. Amplitude scaling ──────────────────────────────────────────
        if config.useAmplitudeScaling
            r = config.augScaleRange;
            scale = r(1) + rand()*(r(2)-r(1));
            wf = wf * scale;
        end

        % ── 3. Small time shift (label-aware) ─────────────────────────────
        if config.useTimeShift
            maxShift = config.augTimeShiftSamples;
            shiftN   = round((rand()-0.5) * 2 * maxShift);
            newPSec  = pSec - shiftN/fs;
            newSSec  = sSec - shiftN/fs;
            if newPSec >= 0 && newSSec >= 0 && newPSec <= T/fs && newSSec <= T/fs
                if shiftN > 0
                    wf = [zeros(shiftN,size(wf,2)); wf(1:end-shiftN,:)];
                elseif shiftN < 0
                    wf = [wf(abs(shiftN)+1:end,:); zeros(abs(shiftN),size(wf,2))];
                end
                pSec = newPSec;
                sSec = newSSec;
            end
        end

        % ── 4. Channel dropout: drop E, N, or both ────────────────────────
        if config.useChannelDropout && rand() < config.augDropoutProb
            eIdx = find(strcmp(config.channelOrder, 'E'), 1);
            nIdx = find(strcmp(config.channelOrder, 'N'), 1);
            dropMode = randi(3);  % 1=E, 2=N, 3=both
            switch dropMode
                case 1
                    if ~isempty(eIdx); wf(:,eIdx) = 0; end
                case 2
                    if ~isempty(nIdx); wf(:,nIdx) = 0; end
                case 3
                    if ~isempty(eIdx); wf(:,eIdx) = 0; end
                    if ~isempty(nIdx); wf(:,nIdx) = 0; end
            end
        end

        % ── 5. Polarity flip ───────────────────────────────────────────────
        if config.usePolarityFlip && rand() < 0.5
            wf = -wf;
        end

        dA.waveform      = wf;
        dA.p_arrival_sec = pSec;
        dA.s_arrival_sec = sSec;
        dA.p_arrival_sample_0based = round(pSec*fs);
        dA.s_arrival_sample_0based = round(sSec*fs);
        dA.p_arrival_sample_1based = dA.p_arrival_sample_0based + 1;
        dA.s_arrival_sample_1based = dA.s_arrival_sample_0based + 1;

        if config.useEnhancedRepresentation
            dA.X = buildEnhancedRepresentation(wf, config);
        else
            dA.X = wf;
        end

        dA.label = generateGaussianMasks(d.sec, pSec, sSec, config);

        augIdx = augIdx + 1;
        dataAug(augIdx) = dA;
    end
end

fprintf('  Augmentation: %d -> %d records (factor x%d)\n', N, augIdx, factor+1);

end
