function [recordsClean, qcReport, metadataQC] = qcWaveformDataset(records, metadata, config)

N = numel(records);
fprintf('  QC: checking %d records...\n', N);

qcStatusList    = strings(N,1);
qualityFlagList = strings(N,1);
reasonsList     = strings(N,1);
nanInfList      = false(N,1);
flatlineList    = false(N,1);
lengthList      = false(N,1);
arrivalOrdList  = false(N,1);
snrList         = nan(N,1);

for i = 1:N
    qr = qcSingleCSVWaveform(records(i), config);

    qcStatusList(i)    = string(qr.qc_status);
    qualityFlagList(i) = string(qr.quality_flag);
    reasonsList(i)     = string(qr.reasons);
    nanInfList(i)       = qr.qc_nan_inf;
    flatlineList(i)      = qr.qc_flatline;
    lengthList(i)        = qr.qc_length;
    arrivalOrdList(i)    = qr.qc_arrival_order;
    snrList(i)           = qr.SNR;

    records(i).quality_flag = char(qualityFlagList(i));
    records(i).SNR_estimated = qr.SNR;

    if config.verbose && mod(i,200)==0
        fprintf('    ... QC %d / %d\n', i, N);
    end
end

eventIDs  = {records.event_id}';
fileNames = {records.file_name}';

qcReport = table(string(fileNames), string(eventIDs), qcStatusList, ...
    qualityFlagList, reasonsList, nanInfList, flatlineList, lengthList, ...
    arrivalOrdList, snrList, ...
    'VariableNames', {'file_name','event_id','qc_status','quality_flag', ...
        'reasons','qc_nan_inf','qc_flatline','qc_length', ...
        'qc_arrival_order','SNR'});

keepMask     = qualityFlagList ~= "rejected";
recordsClean = records(keepMask);

fprintf('  QC complete: good=%d, moderate=%d, poor=%d, rejected=%d (of %d)\n', ...
    sum(qualityFlagList=="good"), sum(qualityFlagList=="moderate"), ...
    sum(qualityFlagList=="poor"), sum(qualityFlagList=="rejected"), N);

% ── Update metadata master with QC results (matched by file_name) ────────
metadataQC = metadata;
if ismember('file_name', metadataQC.Properties.VariableNames)
    [tf, loc] = ismember(string(metadataQC.file_name), string(fileNames));
    for i = 1:height(metadataQC)
        if tf(i)
            j = loc(i);
            metadataQC.qc_nan_inf(i)        = string(mat2str(nanInfList(j)));
            metadataQC.qc_flatline(i)       = string(mat2str(flatlineList(j)));
            metadataQC.qc_length(i)          = string(mat2str(lengthList(j)));
            metadataQC.qc_arrival_order(i)   = string(mat2str(arrivalOrdList(j)));
            metadataQC.qc_status(i)          = qcStatusList(j);
            metadataQC.quality_flag(i)       = qualityFlagList(j);
        end
    end
end

end


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
