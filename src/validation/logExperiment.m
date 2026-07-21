function logExperiment(experimentName, config, metrics, trainingTimeSec, outDir)
% logExperiment.m  -- Module 9
% Saves experiment configuration, metrics, timing, and environment info
% to experiment_log.txt for full reproducibility.
%
% INPUTS:
%   experimentName  - char, e.g. 'Full3C', 'Zonly', 'Benchmark'
%   config          - struct, framework configuration
%   metrics         - table or struct with evaluation metrics
%   trainingTimeSec - double, total training time in seconds
%   outDir          - char, output directory

ensureDir(outDir);
logPath = fullfile(outDir, 'experiment_log.txt');

fid = fopen(logPath, 'a');  % append mode
if fid < 0
    warning('[logExperiment] Cannot open %s for writing.', logPath);
    return;
end

sep = repmat('=',1,60);
fprintf(fid, '\n%s\n', sep);
fprintf(fid, 'EXPERIMENT: %s\n', experimentName);
fprintf(fid, 'Timestamp : %s\n', datestr(now,'yyyy-mm-dd HH:MM:SS'));
fprintf(fid, '%s\n', sep);

% MATLAB environment
fprintf(fid, '\nENVIRONMENT:\n');
fprintf(fid, '  MATLAB version : %s\n', version);
fprintf(fid, '  Platform       : %s\n', computer);
try
    fprintf(fid, '  GPU available  : %d\n', canUseGPU());
catch; fprintf(fid, '  GPU available  : unknown\n'); end

% Reproducibility
fprintf(fid, '\nREPRODUCIBILITY:\n');
if isfield(config,'randomSeed')
    fprintf(fid, '  Random seed    : %d\n', config.randomSeed);
end
if isfield(config,'splitKey')
    fprintf(fid, '  Split key      : %s\n', config.splitKey);
end

% Configuration
fprintf(fid, '\nCONFIGURATION:\n');
cfgFields = {'kFold','augFactor','toleranceMs','samplingRate','nSamples',...
    'gaussianSigmaP','gaussianSigmaS','useGPU'};
for k=1:numel(cfgFields)
    fn=cfgFields{k};
    if isfield(config,fn)
        v=config.(fn);
        if isnumeric(v); fprintf(fid,'  %-22s: %s\n',fn,num2str(v));
        elseif islogical(v); fprintf(fid,'  %-22s: %d\n',fn,v);
        else; fprintf(fid,'  %-22s: %s\n',fn,char(string(v))); end
    end
end

% Training time
fprintf(fid, '\nTRAINING:\n');
fprintf(fid, '  Training time  : %.1f s (%.1f min)\n', trainingTimeSec, trainingTimeSec/60);

% Metrics
fprintf(fid, '\nMETRICS:\n');
if istable(metrics)
    cols = metrics.Properties.VariableNames;
    for ri=1:height(metrics)
        for ci=1:numel(cols)
            v=metrics.(cols{ci})(ri);
            if iscell(v); v=v{1}; end
            if isnumeric(v); fprintf(fid,'  %-30s: %.4f\n',cols{ci},v);
            else; fprintf(fid,'  %-30s: %s\n',cols{ci},char(string(v))); end
        end
    end
elseif isstruct(metrics)
    fn=fieldnames(metrics);
    for k=1:numel(fn)
        v=metrics.(fn{k});
        if isnumeric(v); fprintf(fid,'  %-30s: %.4f\n',fn{k},v); end
    end
end

fprintf(fid, '\n%s\n', sep);
fclose(fid);
fprintf('  [logExperiment] Appended to: %s\n', logPath);
end
function ensureDir(d);if ~isempty(d)&&~isfolder(d);mkdir(d);end;end
