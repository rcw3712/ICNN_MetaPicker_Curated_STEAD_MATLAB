function diagTable = computeDatasetStratifiedAnalysis(predTable, outDir, config)
% computeDatasetStratifiedAnalysis.m  -- Module 6
% Performance grouped by: Magnitude, Distance, SNR, S-P Time.
% Output: results/diagnostics/dataset_diagnostics.csv + figures.

ensureDir(outDir);
figDir = fullfile(outDir,'figures');
ensureDir(figDir);

errP = safeNum(predTable,'p_error_ms');
errS = safeNum(predTable,'s_error_ms');
N    = height(predTable);
tolMs = config.toleranceMs;

% Attribute definitions
attrs = {
    'source_magnitude',   'Magnitude',  [1.5 2.5; 2.5 3.5; 3.5 6.0];
    'source_distance_km', 'Distance (km)', [0 5; 5 10; 10 15];
    'SNR',                'SNR (dB)',   [10 20; 20 40; 40 100];
    'sp_time_sec',        'SP Time (s)',[0 3; 3 6; 6 30];
};

allRows = {};

for ai = 1:size(attrs,1)
    attrCol  = attrs{ai,1};
    attrName = attrs{ai,2};
    bins     = attrs{ai,3};

    attrVals = safeNum(predTable, attrCol);
    if all(isnan(attrVals))
        fprintf('  [DatasetDiag] Column %s not found, skipping.\n', attrCol);
        continue;
    end

    for bi = 1:size(bins,1)
        lo = bins(bi,1); hi = bins(bi,2);
        inBin = attrVals >= lo & attrVals < hi;
        binLabel = sprintf('%.1f--%.1f', lo, hi);

        for comp = {'P','S'}
            c   = comp{1};
            err = ternary(strcmp(c,'P'), errP, errS);
            ev  = err(inBin & ~isnan(err));
            nB  = sum(inBin); nD = numel(ev);
            absE = abs(ev);

            if nD < 2
                mae=NaN; medAE=NaN; f1_100=NaN; dr=NaN; oR=NaN;
            else
                mae=mean(absE); medAE=median(absE); dr=nD/max(nB,1);
                oR=mean(absE>1000);
                TP=sum(absE<=100); FP=sum(absE>100); FN=nB-nD;
                pr=TP/max(1,TP+FP); rc=TP/max(1,TP+FN);
                f1_100=2*pr*rc/max(1e-10,pr+rc);
            end

            allRows{end+1} = table({attrName},{binLabel},{c},nB,nD,dr,...
                mae,medAE,f1_100,oR,...
                'VariableNames',{'Attribute','Bin','Component','N_bin','N_detected',...
                'DetRate','MAE_ms','MedAE_ms','F1_100ms','OutlierRate_1000ms'}); %#ok
        end
    end
end

if isempty(allRows)
    diagTable = table(); return;
end
diagTable = vertcat(allRows{:});
csvPath = fullfile(outDir, 'dataset_diagnostics.csv');
writetable(diagTable, csvPath);
fprintf('  [DatasetDiag] Saved: dataset_diagnostics.csv\n');

% Generate stratified figure
makeStratifiedFig(diagTable, figDir);
end

function makeStratifiedFig(t, figDir)
attrs = unique(t.Attribute,'stable');
nA    = numel(attrs);
if nA == 0; return; end

fig = figure('Visible','off','Color','white','Units','centimeters','Position',[2 2 22 12]);
for ai = 1:min(nA,4)
    attr = attrs{ai};
    rA   = t(strcmp(t.Attribute,attr),:);
    bins = unique(rA.Bin,'stable');
    nB   = numel(bins);

    ax = subplot(2,2,ai);
    f1P = zeros(nB,1); f1S = zeros(nB,1);
    for bi=1:nB
        rP=rA(strcmp(rA.Bin,bins{bi})&strcmp(rA.Component,'P'),:);
        rS=rA(strcmp(rA.Bin,bins{bi})&strcmp(rA.Component,'S'),:);
        if ~isempty(rP)&&any(strcmp(rP.Properties.VariableNames,'F1_100ms'))
            f1P(bi)=rP.F1_100ms; end
        if ~isempty(rS)&&any(strcmp(rS.Properties.VariableNames,'F1_100ms'))
            f1S(bi)=rS.F1_100ms; end
    end
    b=bar([f1P f1S],'grouped');
    b(1).FaceColor=[0.122 0.467 0.706]; b(1).DisplayName='P-wave';
    b(2).FaceColor=[0.839 0.153 0.157]; b(2).DisplayName='S-wave';
    set(ax,'XTickLabel',bins,'XTickLabelRotation',15,'FontSize',9,'FontName','Arial',...
        'Box','off','YLim',[0 1.05]);
    ylabel('F1@100ms','FontSize',10,'FontName','Arial');
    xlabel(attr,'FontSize',10,'FontName','Arial');
    title(sprintf('Performance by %s',attr),'FontSize',11,'FontName','Arial','FontWeight','bold');
    legend('Location','southeast','FontSize',9,'FontName','Arial','Box','off');
    grid on;
end
exportgraphics(fig, fullfile(figDir,'stratified_F1_by_attribute.png'),'Resolution',300,'BackgroundColor','white');
close(fig);
end

function v=safeNum(t,col)
idx=strcmpi(t.Properties.VariableNames,col);
if ~any(idx);v=nan(height(t),1);return;end
v=double(t.(t.Properties.VariableNames{find(idx,1)}));
end
function out=ternary(c,a,b);if c;out=a;else;out=b;end;end
function ensureDir(d);if ~isempty(d)&&~isfolder(d);mkdir(d);end;end
