function diagTable = computeExtendedDiagnostics(predTable, experimentName, config)
% computeExtendedDiagnostics.m  -- Module 5
% Extends existing diagnostics with: MedianAE, P90AE, P95AE,
% OutlierRate>1000ms, Skewness, Kurtosis.
% Output: results/diagnostics/prediction_diagnostics.csv

outDir = fullfile(config.outputDiagnosticsFolder,'extended');
ensureDir(outDir);

errP = safeNum(predTable,'p_error_ms');
errS = safeNum(predTable,'s_error_ms');
N    = height(predTable);

rows = {};
for comp = {'P','S'}
    c   = comp{1};
    err = ternary(strcmp(c,'P'), errP, errS);
    ev  = err(~isnan(err));
    absE= abs(ev);
    nD  = numel(ev);

    if nD < 2
        rows{end+1} = buildNaN(c, experimentName, N); %#ok
        continue;
    end

    mae   = mean(absE);
    medAE = median(absE);
    rmse  = sqrt(mean(ev.^2));
    bias  = mean(ev);
    sd    = std(ev);
    p90   = prctile(absE,90);
    p95   = prctile(absE,95);
    p99   = prctile(absE,99);
    oR1k  = mean(absE>1000);
    oR500 = mean(absE>500);
    sk    = skewness(ev);
    ku    = kurtosis(ev);
    dr    = nD/N;

    rows{end+1} = table({c},{experimentName},N,nD,dr,...
        mae,medAE,rmse,bias,sd,p90,p95,p99,oR500,oR1k,sk,ku,...
        'VariableNames',{'Component','Experiment','N_total','N_detected',...
        'DetectionRate','MAE_ms','MedAE_ms','RMSE_ms','Bias_ms','STD_ms',...
        'P90_ms','P95_ms','P99_ms','OutlierRate_500ms','OutlierRate_1000ms',...
        'Skewness','Kurtosis'}); %#ok
end

diagTable = vertcat(rows{:});
outPath = fullfile(outDir, sprintf('prediction_diagnostics_%s.csv', experimentName));
writetable(diagTable, outPath);
fprintf('  [ExtDiag] Saved: %s\n', outPath);
end

function r = buildNaN(c, expName, N)
r = table({c},{expName},N,0,0,...
    NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,...
    'VariableNames',{'Component','Experiment','N_total','N_detected',...
    'DetectionRate','MAE_ms','MedAE_ms','RMSE_ms','Bias_ms','STD_ms',...
    'P90_ms','P95_ms','P99_ms','OutlierRate_500ms','OutlierRate_1000ms',...
    'Skewness','Kurtosis'});
end
function v=safeNum(t,col)
idx=strcmpi(t.Properties.VariableNames,col);
if ~any(idx);v=nan(height(t),1);return;end
v=double(t.(t.Properties.VariableNames{find(idx,1)}));
end
function out=ternary(c,a,b);if c;out=a;else;out=b;end;end
function ensureDir(d);if ~isempty(d)&&~isfolder(d);mkdir(d);end;end
