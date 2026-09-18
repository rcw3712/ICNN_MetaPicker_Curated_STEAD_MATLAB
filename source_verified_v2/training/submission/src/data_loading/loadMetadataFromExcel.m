% Numerical implementation from the source-verified v2 run.
% See USER_GUIDE.md for inputs, labels, inert legacy fields and current protocol.

function metadata = loadMetadataFromExcel(metadataPath, config)

if ~isfile(metadataPath)
    error('loadMetadataFromExcel:fileNotFound', ...
        'Metadata file not found: %s\nLetakkan metadata_master_filled.xlsx di folder: %s', ...
        metadataPath, fileparts(metadataPath));
end

fprintf('  Loading metadata from: %s\n', metadataPath);
[~, ~, ext] = fileparts(metadataPath);

tic;
if strcmpi(ext, '.xlsx') || strcmpi(ext, '.xls')
    try
        opts = detectImportOptions(metadataPath);
        opts.VariableNamingRule = 'preserve';
        metadata = readtable(metadataPath, opts);
    catch
        metadata = readtable(metadataPath, 'VariableNamingRule','preserve');
    end
else
    try
        opts=detectImportOptions(metadataPath,'VariableNamingRule','preserve');
        opts=setvartype(opts,{'event_id','source_id','trace_name'},'string');
        metadata=readtable(metadataPath,opts);
    catch
        metadata = readtable(metadataPath, 'VariableNamingRule','preserve');
    end
end
elapsed = toc;
fprintf('  Metadata loaded: %d rows x %d columns (%.1f s)\n', ...
    height(metadata), width(metadata), elapsed);

REQUIRED = {'event_id', 'source_id', 'quality_flag', ...
            'p_arrival_sec', 's_arrival_sec'};
missingCols = setdiff(REQUIRED, metadata.Properties.VariableNames);
if ~isempty(missingCols)
    error('loadMetadataFromExcel:missingCols', ...
        'Metadata missing required column(s): %s', strjoin(missingCols, ', '));
end

csvFolder = config.csvFolder;
fprintf('  Building file_name and file_path from event_id + csvFolder: %s\n', csvFolder);

nRows = height(metadata);
fileNames  = string(metadata.event_id) + ".csv";
filePaths  = string(csvFolder) + filesep + fileNames;

metadata.file_name = fileNames;
metadata.file_path = filePaths;

qfCol = string(metadata.quality_flag);
nBad  = sum(strcmpi(qfCol, 'bad') | strcmpi(qfCol, 'rejected') | strcmpi(qfCol, 'poor'));
if nBad > 0
    fprintf('  Removing %d records with quality_flag bad/rejected/poor\n', nBad);
    keepMask = ~(strcmpi(qfCol,'bad') | strcmpi(qfCol,'rejected') | strcmpi(qfCol,'poor'));
    metadata = metadata(keepMask, :);
    fprintf('  Records after quality filter: %d\n', height(metadata));
end

if isfield(config, 'filterExistingCSVOnly') && config.filterExistingCSVOnly
    fprintf('  Checking which CSV files exist on disk...\n');
    existsMask = arrayfun(@(p) isfile(char(p)), metadata.file_path);
    nMissing   = sum(~existsMask);
    if nMissing > 0
        fprintf('  WARNING: %d CSV files not found on disk, removing from metadata\n', nMissing);
        metadata = metadata(existsMask, :);
    end
    fprintf('  Records with CSV on disk: %d\n', height(metadata));
end

nUniqueSrc = numel(unique(string(metadata.source_id)));
fprintf('  Final metadata: %d traces, %d unique source_id (events)\n', ...
    height(metadata), nUniqueSrc);

sids = string(metadata.source_id);
eids = string(metadata.event_id);
fracSame = mean(sids == eids);
if fracSame > 0.99
    warning('loadMetadataFromExcel:sourceIDFallback', ...
        ['source_id appears identical to event_id (%.0f%% of rows). ' ...
         'Strict source-level split requires original STEAD source_id.'], ...
        fracSame*100);
else
    fprintf('  source_id validation: %.1f%% unique from event_id (STEAD source_id OK)\n', ...
        (1-fracSame)*100);
end

end
