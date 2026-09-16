
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
