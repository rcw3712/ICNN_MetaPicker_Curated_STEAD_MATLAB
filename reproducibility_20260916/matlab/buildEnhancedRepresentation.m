function X = buildEnhancedRepresentation(waveformConditioned, config)

[T, C] = size(waveformConditioned);

if ~config.useEnhancedRepresentation
    X = waveformConditioned;
    return;
end

fs = config.samplingRate;

envelope = zeros(T, C);
for c = 1:C
    envelope(:, c) = abs(hilbert(waveformConditioned(:, c)));
    sd = std(envelope(:, c));
    if sd > 1e-10
        envelope(:, c) = envelope(:, c) / sd;
    end
end

zIdx = find(strcmp(config.channelOrder, 'Z'), 1);
if isempty(zIdx); zIdx = C; end

steWinSamp = max(1, round(0.1 * fs));
STE_Z = movmean(waveformConditioned(:, zIdx).^2, steWinSamp);
sdSTE = std(STE_Z);
if sdSTE > 1e-10
    STE_Z = STE_Z / sdSTE;
end

staSamp = max(1, round(0.1 * fs));
ltaSamp = max(staSamp+1, round(1.0 * fs));
CF = computeCharacteristicFunction(abs(waveformConditioned(:, zIdx)), staSamp, ltaSamp);
sdCF = std(CF);
if sdCF > 1e-10
    CF = CF / sdCF;
end

X = [waveformConditioned, envelope, STE_Z, CF];  % [T x (3+3+1+1)] = [T x 8]

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
