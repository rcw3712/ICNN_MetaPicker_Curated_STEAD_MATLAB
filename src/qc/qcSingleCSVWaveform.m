% =========================================================================
% qcSingleCSVWaveform.m  (src/qc/)
% =========================================================================
% PURPOSE:
%   Perform quality control checks on a single curated STEAD CSV waveform
%   record.
%
% INPUT:
%   record - struct, output of loadSingleSTEADCSV.m
%   config - struct, framework configuration
%
% OUTPUT:
%   qcResult - struct with fields:
%       .qc_status      'pass' | 'warning' | 'fail'
%       .quality_flag   'good' | 'moderate' | 'poor' | 'rejected'
%       .qc_nan_inf     logical, true if NaN/Inf detected
%       .qc_flatline    logical, true if any channel is flatline
%       .qc_length      logical, true if sample count != config.nSamples
%       .qc_arrival_order logical, true if s_arrival <= p_arrival
%       .reasons        char, semicolon-separated list of issues found
%       .channelStats   struct with .mean, .std, .max, .min per channel
%       .SNR            double, estimated SNR (dB) if not already known
%
% NOTES:
%   Checks performed (in order):
%     1. Required columns available (assumed pre-validated by
%        loadSingleSTEADCSV.m; this function re-checks waveform/sec are
%        non-empty as a defensive measure)
%     2. Sample count == config.nSamples (6000)
%     3. sec is monotonically increasing
%     4. delta(sec) ~ 1/samplingRate (0.01 s for 100 Hz)
%     5. Effective sampling rate ~ config.samplingRate
%     6. No NaN / Inf in waveform
%     7. E, N, Z are not flatline (near-zero variance)
%     8. No clipping / extreme amplitude outliers
%     9. p_arrival within [0, durationSec]
%    10. s_arrival within [0, durationSec]
%    11. s_arrival > p_arrival
%    12. S-P time within a physically reasonable range
%    13. Per-channel statistics computed (mean, std, max, min)
% =========================================================================

function qcResult = qcSingleCSVWaveform(record, config)

issues = {};
severity = 0;  % 0=good(pass), 1=moderate(warning-ish), 2=poor(warning), 3=rejected(fail)

qc_nan_inf       = false;
qc_flatline      = false;
qc_length        = false;
qc_arrival_order = false;

% ── 1. Basic presence check ───────────────────────────────────────────────
if isempty(record.waveform) || isempty(record.sec)
    qcResult = makeRejectedResult('EMPTY_RECORD');
    return;
end

[T, C] = size(record.waveform);
fs     = config.samplingRate;

% ── 2. Sample count ────────────────────────────────────────────────────────
if T ~= config.nSamples
    qc_length = true;
    issues{end+1} = sprintf('LENGTH_%d_vs_%d', T, config.nSamples); %#ok<AGROW>
    severity = max(severity, 2);
end

% ── 3-4. sec monotonic and delta consistency ──────────────────────────────
secVec = record.sec;
if any(diff(secVec) <= 0)
    issues{end+1} = 'SEC_NOT_MONOTONIC'; %#ok<AGROW>
    severity = max(severity, 2);
end
expectedDelta = 1 / fs;
actualDelta   = median(diff(secVec));
if abs(actualDelta - expectedDelta) > 0.2 * expectedDelta
    issues{end+1} = sprintf('DELTA_SEC_%.4f_vs_%.4f', actualDelta, expectedDelta); %#ok<AGROW>
    severity = max(severity, 1);
end

% ── 5. Effective sampling rate ────────────────────────────────────────────
if actualDelta > 0
    effFs = 1 / actualDelta;
    if abs(effFs - fs) > 0.05 * fs
        issues{end+1} = sprintf('SAMPLING_RATE_%.1f_vs_%.1f', effFs, fs); %#ok<AGROW>
        severity = max(severity, 1);
    end
end

% ── 6. NaN / Inf ────────────────────────────────────────────────────────────
if any(isnan(record.waveform(:))) || any(isinf(record.waveform(:)))
    qc_nan_inf = true;
    issues{end+1} = 'NAN_OR_INF'; %#ok<AGROW>
    severity = 3;
end

% ── 7. Flatline per channel ────────────────────────────────────────────────
flatChans = {};
chanStats = struct();
for c = 1:min(C,3)
    chName = config.channelOrder{c};
    sig    = record.waveform(:,c);
    chanStats.(['mean_' chName]) = mean(sig);
    chanStats.(['std_'  chName]) = std(sig);
    chanStats.(['max_'  chName]) = max(sig);
    chanStats.(['min_'  chName]) = min(sig);
    if std(sig) < 1e-10
        flatChans{end+1} = chName; %#ok<AGROW>
    end
end
if ~isempty(flatChans)
    qc_flatline = true;
    issues{end+1} = ['FLATLINE_' strjoin(flatChans,'_')]; %#ok<AGROW>
    if any(strcmp(flatChans,'Z'))
        severity = max(severity, 3);
    else
        severity = max(severity, 2);
    end
end

% ── 8. Clipping / extreme amplitude ───────────────────────────────────────
zIdx = find(strcmp(config.channelOrder,'Z'), 1);
if isempty(zIdx); zIdx = min(C,3); end
medAmp = median(abs(record.waveform(:,zIdx)));
if medAmp > 0
    fracExt = mean(abs(record.waveform(:,zIdx)) > 10*medAmp);
    if fracExt > 0.01
        issues{end+1} = sprintf('EXTREME_AMP_%.3f', fracExt); %#ok<AGROW>
        severity = max(severity, 1);
    end
end

% ── 9-10. Arrival within window ───────────────────────────────────────────
durSec = config.durationSec;
if isnan(record.p_arrival_sec) || record.p_arrival_sec < 0 || record.p_arrival_sec > durSec
    issues{end+1} = 'P_OUTSIDE_WINDOW'; %#ok<AGROW>
    severity = 3;
end
if isnan(record.s_arrival_sec) || record.s_arrival_sec < 0 || record.s_arrival_sec > durSec
    issues{end+1} = 'S_OUTSIDE_WINDOW'; %#ok<AGROW>
    severity = 3;
end

% ── 11. S after P ───────────────────────────────────────────────────────────
if ~isnan(record.p_arrival_sec) && ~isnan(record.s_arrival_sec)
    if record.s_arrival_sec <= record.p_arrival_sec
        qc_arrival_order = true;
        issues{end+1} = 'S_BEFORE_P'; %#ok<AGROW>
        severity = 3;
    end

    % ── 12. S-P time physically reasonable ─────────────────────────────────
    spTime = record.s_arrival_sec - record.p_arrival_sec;
    if spTime < config.minSPTimeSec || spTime > config.maxSPTimeSec
        issues{end+1} = sprintf('SP_TIME_%.2fs_OUT_OF_RANGE', spTime); %#ok<AGROW>
        severity = max(severity, 2);
    end
end

% ── 13. SNR estimate (if not already provided) ────────────────────────────
SNR = estimateSNRSimple(record.waveform(:,zIdx), record.p_arrival_sample_0based, fs);

% ── Final flag assignment ───────────────────────────────────────────────────
switch severity
    case 0
        qc_status = 'pass'; quality_flag = 'good';
    case 1
        qc_status = 'warning'; quality_flag = 'moderate';
    case 2
        qc_status = 'warning'; quality_flag = 'poor';
    case 3
        qc_status = 'fail'; quality_flag = 'rejected';
end

if isempty(issues)
    reasonsStr = 'PASS';
else
    reasonsStr = strjoin(issues, '; ');
end

qcResult.qc_status        = qc_status;
qcResult.quality_flag     = quality_flag;
qcResult.qc_nan_inf       = qc_nan_inf;
qcResult.qc_flatline      = qc_flatline;
qcResult.qc_length        = qc_length;
qcResult.qc_arrival_order = qc_arrival_order;
qcResult.reasons          = reasonsStr;
qcResult.channelStats     = chanStats;
qcResult.SNR              = SNR;

end

% =========================================================================

function r = makeRejectedResult(reason)
r.qc_status        = 'fail';
r.quality_flag      = 'rejected';
r.qc_nan_inf         = true;
r.qc_flatline        = true;
r.qc_length          = true;
r.qc_arrival_order   = true;
r.reasons            = reason;
r.channelStats       = struct();
r.SNR                = NaN;
end


function snr = estimateSNRSimple(zTrace, pSample0based, fs)
pSample  = round(pSample0based) + 1;  % convert to 1-based MATLAB index
noiseEnd = max(1, pSample - 1);
if noiseEnd < 10 || isnan(pSample)
    snr = NaN;
    return;
end
noiseWin = zTrace(1:noiseEnd);
sigStart = pSample + 1;
sigEnd   = min(numel(zTrace), pSample + round(fs));
if sigEnd <= sigStart
    snr = NaN;
    return;
end
sigWin    = zTrace(sigStart:sigEnd);
varNoise  = var(noiseWin);
varSignal = var(sigWin);
if varNoise < 1e-20
    snr = NaN;
else
    snr = 10*log10(varSignal/varNoise);
end
end

% =========================================================================
% qcWaveformDataset.m  (src/qc/)
% =========================================================================
% PURPOSE:
%   Apply qcSingleCSVWaveform.m to every record in a struct array, build
%   a QC report table, and produce an updated metadata master with QC
%   columns populated.
%
% INPUT:
%   records  - struct array, output of loadFilteredSTEADCSVFolder.m
%   metadata - table, metadata master corresponding to records
%   config   - struct, framework configuration
%
% OUTPUT:
%   recordsClean - struct array, records NOT flagged 'rejected'
%   qcReport     - table, full QC report (one row per input record)
%   metadataQC   - table, metadata master with QC columns filled in
%                  (qc_nan_inf, qc_flatline, qc_length, qc_arrival_order,
%                   qc_status, quality_flag)
% =========================================================================
