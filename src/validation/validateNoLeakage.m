function validateNoLeakage(trainIds, valIds, testIds)
% validateNoLeakage.m  -- Module 7
% Verifies zero source_id overlap across train/val/test splits.
% Stops execution with error if any overlap is detected.
% Must be called at the start of every experiment script.
%
% INPUTS:
%   trainIds - cell array of source_id strings for training set
%   valIds   - cell array of source_id strings for validation set
%   testIds  - cell array of source_id strings for test set

fprintf('  [LeakageValidation] Checking source_id overlap...\n');

tvOverlap  = intersect(trainIds, valIds);
ttOverlap  = intersect(trainIds, testIds);
vtOverlap  = intersect(valIds,   testIds);

ok = true;
if ~isempty(tvOverlap)
    fprintf('  [ERROR] Train x Val overlap: %d source_ids\n', numel(tvOverlap));
    ok = false;
end
if ~isempty(ttOverlap)
    fprintf('  [ERROR] Train x Test overlap: %d source_ids\n', numel(ttOverlap));
    ok = false;
end
if ~isempty(vtOverlap)
    fprintf('  [ERROR] Val x Test overlap: %d source_ids\n', numel(vtOverlap));
    ok = false;
end

if ~ok
    error('[LeakageValidation] FAILED: Source-level data leakage detected. Stopping execution.');
end

fprintf('  [LeakageValidation] PASS -- Train=%d | Val=%d | Test=%d | Zero overlap confirmed.\n',...
    numel(trainIds), numel(valIds), numel(testIds));
end
