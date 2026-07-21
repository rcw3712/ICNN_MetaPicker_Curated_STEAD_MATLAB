function [trainData, valData, testData, splitIDs] = splitByGenericID(dataClean, keyField, config)

trainR = config.trainRatio;
valR   = config.valRatio;

allIDs    = {dataClean.(keyField)}';
uniqueIDs = unique(allIDs, 'stable');
nIDs      = numel(uniqueIDs);

fprintf('  Unique %s values: %d | Total records: %d\n', ...
    keyField, nIDs, numel(dataClean));
fprintf('  Ratios -> train: %.0f%% | val: %.0f%% | test: %.0f%%\n', ...
    trainR*100, valR*100, (1-trainR-valR)*100);

shuffleIdx = randperm(nIDs);
uniqueIDs  = uniqueIDs(shuffleIdx);

nTrain = round(trainR * nIDs);
nVal   = round(valR   * nIDs);

trainIDs = uniqueIDs(1            : nTrain);
valIDs   = uniqueIDs(nTrain+1     : nTrain+nVal);
testIDs  = uniqueIDs(nTrain+nVal+1 : end);

fprintf('  IDs -> train: %d | val: %d | test: %d\n', ...
    numel(trainIDs), numel(valIDs), numel(testIDs));

trainMask = ismember(allIDs, trainIDs);
valMask   = ismember(allIDs, valIDs);
testMask  = ismember(allIDs, testIDs);

trainData = dataClean(trainMask);
valData   = dataClean(valMask);
testData  = dataClean(testMask);

validateNoLeakage(trainIDs, valIDs, testIDs, keyField);

fprintf('  Records -> train: %d | val: %d | test: %d\n', ...
    numel(trainData), numel(valData), numel(testData));

splitIDs.trainIDs = trainIDs;
splitIDs.valIDs   = valIDs;
splitIDs.testIDs  = testIDs;

end


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
