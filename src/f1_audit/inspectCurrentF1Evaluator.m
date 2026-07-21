function report = inspectCurrentF1Evaluator(config)
% inspectCurrentF1Evaluator.m
% PURPOSE: Inspect the existing computeDetectionMetrics.m to determine
%          exactly how TP/FP/FN are counted for out-of-tolerance predictions.
%          Does NOT modify any code.
% OUTPUTS: report -- struct describing the current definition
% NOTES:   Reads source code directly from src/evaluation/.

report = struct();
report.inspectionDate = datestr(now,'yyyy-mm-dd HH:MM:SS');

% Locate the evaluator
candidates = {
    fullfile('src','evaluation','computeDetectionMetrics.m');
    fullfile('src','evaluation','evaluatePickingPerformance.m');
};

srcFile = '';
for k=1:numel(candidates)
    if isfile(candidates{k}); srcFile=candidates{k}; break; end
end

if isempty(srcFile)
    report.found = false;
    report.outsideToleranceHandling = 'UNKNOWN -- evaluator file not found';
    fprintf('  [Inspect] evaluator source not found at known paths.\n');
    return;
end

report.found     = true;
report.sourceFile= srcFile;
fprintf('  [Inspect] Reading evaluator: %s\n', srcFile);

fid = fopen(srcFile,'r');
src = fread(fid,'*char')';
fclose(fid);

% Extract TP/FP/FN assignment logic
lines = strsplit(src, newline);
tpLines  = lines(contains(lines,'TP'));
fpLines  = lines(contains(lines,'FP'));
fnLines  = lines(contains(lines,'FN'));

report.TP_lines = strjoin(tpLines, ' | ');
report.FP_lines = strjoin(fpLines, ' | ');
report.FN_lines = strjoin(fnLines, ' | ');

% Key diagnostic: does FN depend on abs(error) > tol 
% If FN = N - nDet only (missing predictions), it is FP-only for out-of-tolerance
fnUsesTol   = any(contains(fnLines, 'tol')) || any(contains(fnLines,'abs'));
fpCountsOut = any(contains(fpLines, 'tol')) || any(contains(fpLines,'abs'));

if fnUsesTol
    report.outsideToleranceHandling = 'FP_AND_FN (conventional event-matching)';
    report.isFPonly = false;
else
    report.outsideToleranceHandling = 'FP_ONLY (FN counts only missing predictions, not out-of-tolerance)';
    report.isFPonly = true;
end

% Extract denominator for F1
if contains(src, 'N - nDet') || contains(src, 'N-nDet')
    report.FN_denominator = 'FN = N_total - N_detected (missing picks only)';
else
    report.FN_denominator = 'UNKNOWN -- inspect source manually';
end

fprintf('  [Inspect] Outside-tolerance handling: %s\n', report.outsideToleranceHandling);
fprintf('  [Inspect] FN denominator: %s\n', report.FN_denominator);
end
