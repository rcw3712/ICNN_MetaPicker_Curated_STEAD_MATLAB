
function [record, ok] = loadSingleSTEADCSV(filePath, config)

ok     = false;
record = struct();

if ~isfile(filePath)
    warning('loadSingleSTEADCSV:fileNotFound', 'CSV file not found: %s', filePath);
    return;
end

try
    T = readtable(filePath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
catch ME
    warning('loadSingleSTEADCSV:readFailed', ...
        'Failed to read CSV "%s": %s', filePath, ME.message);
    return;
end

requiredCols = {'sec','E','N','Z','p_arrival','s_arrival'};
missingCols  = setdiff(requiredCols, T.Properties.VariableNames);
if ~isempty(missingCols)
    warning('loadSingleSTEADCSV:missingColumns', ...
        'CSV "%s" missing required column(s): %s', ...
        filePath, strjoin(missingCols, ', '));
    return;
end

secVec = double(T.sec);
E      = double(T.E);
N      = double(T.N);
Z      = double(T.Z);

pArrivalSec = double(T.p_arrival(1));
sArrivalSec = double(T.s_arrival(1));

fs = config.samplingRate;

[~, fileNameNoExt, ~] = fileparts(filePath);

record.waveform                = [E(:), N(:), Z(:)];   % [T x 3]
record.sec                     = secVec(:);
record.p_arrival_sec           = pArrivalSec;
record.s_arrival_sec           = sArrivalSec;
record.p_arrival_sample_0based = round(pArrivalSec * fs);
record.s_arrival_sample_0based = round(sArrivalSec * fs);
record.p_arrival_sample_1based = record.p_arrival_sample_0based + 1;
record.s_arrival_sample_1based = record.s_arrival_sample_0based + 1;
record.file_name               = [fileNameNoExt '.csv'];
record.event_id                = char(fileNameNoExt);
record.samplingRate            = fs;

record.source_id          = '';
record.source_magnitude   = NaN;
record.source_distance_km = NaN;
record.SNR                = NaN;
record.quality_flag       = 'unknown';

ok = true;

end
