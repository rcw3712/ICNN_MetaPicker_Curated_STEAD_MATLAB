function data = applyPreprocessing(data, config)
for i = 1:numel(data)
    condWf = conditionWaveform(data(i).waveform, config);
    data(i).waveform = condWf;
    if config.useEnhancedRepresentation
        data(i).X = buildEnhancedRepresentation(condWf, config);
    else
        data(i).X = condWf;
    end
end
end

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
