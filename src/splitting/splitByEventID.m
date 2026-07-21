function [trainData, valData, testData, splitInfo] = splitByEventID(dataClean, config)

fprintf('  Split key: event_id (explicit)\n');
[trainData, valData, testData, splitIDs] = splitByGenericID(dataClean, 'event_id', config);

splitInfo.keyUsed    = 'event_id';
splitInfo.isFallback = true;
splitInfo.trainIDs   = splitIDs.trainIDs;
splitInfo.valIDs     = splitIDs.valIDs;
splitInfo.testIDs    = splitIDs.testIDs;

outDir = fullfile(config.outputFolder, 'splits');
ensureDir(outDir);
writeIDList(splitIDs.trainIDs, fullfile(outDir, 'train_source_ids.csv'), 'event_id');
writeIDList(splitIDs.valIDs,   fullfile(outDir, 'val_source_ids.csv'),   'event_id');
writeIDList(splitIDs.testIDs,  fullfile(outDir, 'test_source_ids.csv'),  'event_id');

end

% =========================================================================
% INTERNAL SHARED IMPLEMENTATION
% =========================================================================


function validateNoLeakage(trainIDs, valIDs, testIDs, keyField)
overlapTV = intersect(trainIDs, valIDs);
overlapTT = intersect(trainIDs, testIDs);
overlapVT = intersect(valIDs,   testIDs);

leak = false;
if ~isempty(overlapTV)
    warning('splitByGenericID:leakage', '%d %s overlap between train and val!', numel(overlapTV), keyField);
    leak = true;
end
if ~isempty(overlapTT)
    warning('splitByGenericID:leakage', '%d %s overlap between train and test!', numel(overlapTT), keyField);
    leak = true;
end
if ~isempty(overlapVT)
    warning('splitByGenericID:leakage', '%d %s overlap between val and test!', numel(overlapVT), keyField);
    leak = true;
end

if leak
    error('splitByGenericID:leakageDetected', ...
        'Data leakage detected in %s split. Aborting pipeline.', keyField);
else
    fprintf('  Leakage validation: PASS — zero %s overlap across subsets.\n', keyField);
end
end


function writeIDList(ids, outPath, keyField)
T = table(string(ids), 'VariableNames', {keyField});
writetable(T, outPath);
end


function out = ternary(cond, a, b)
if cond; out = a; else; out = b; end
end


function ensureDir(d)
if ~isempty(d) && ~isfolder(d); mkdir(d); end
end
