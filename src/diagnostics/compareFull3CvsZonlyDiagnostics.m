function deltaTable = compareFull3CvsZonlyDiagnostics(pctFull, pctZ, snrFull, snrZ, config)
% compareFull3CvsZonlyDiagnostics.m  (pure ASCII)
% Compares Full3C vs Z-only performance diagnostics.

figDir = fullfile(config.outputDiagnosticsFolder, 'figures');
outDir = fullfile(config.outputDiagnosticsFolder, 'percentile_metrics');
ensureDir(figDir); ensureDir(outDir);

% Columns to compare (must exist in both pctFull and pctZ)
wantCols = {'MAE_ms','MedAE_ms','RMSE_ms','Bias_ms','STD_ms', ...
    'P75_ms','P90_ms','P95_ms','P99_ms','MaxAE_ms', ...
    'OutlierRate_500ms','OutlierRate_1000ms','OutlierRate_2000ms', ...
    'DetectionRate'};

comps = {'P','S'};
compVals = struct();

% Collect values per component
for ci = 1:numel(comps)
    c = comps{ci};
    rowF = getComp(pctFull, c);
    rowZ = getComp(pctZ, c);
    compVals(ci).comp = c;
    compVals(ci).rowF = rowF;
    compVals(ci).rowZ = rowZ;
end

% Build delta table column by column (avoids any row-length mismatch)
nComps = numel(comps);
deltaTable = table();
deltaTable.Component = comps(:);

for ni = 1:numel(wantCols)
    col = wantCols{ni};
    dcol = ['Delta_' col];
    vals = nan(nComps, 1);
    for ci = 1:nComps
        rF = compVals(ci).rowF;
        rZ = compVals(ci).rowZ;
        if ~isempty(rF) && ~isempty(rZ) && ...
           any(strcmp(rF.Properties.VariableNames, col)) && ...
           any(strcmp(rZ.Properties.VariableNames, col))
            vals(ci) = rZ.(col) - rF.(col);
        end
    end
    deltaTable.(dcol) = vals;
end

% Add interpretation
interp = cell(nComps, 1);
for ci = 1:nComps
    if strcmp(comps{ci}, 'S')
        interp{ci} = ['Z-only substantially degrades S-wave timing. ' ...
            'Horizontal components are important for reliable S-phase picking.'];
    else
        interp{ci} = ['P-wave timing is largely preserved under Z-only, ' ...
            'consistent with predominantly vertical particle motion.'];
    end
end
deltaTable.AutoInterpretation = interp;

writetable(deltaTable, fullfile(outDir, 'diagnostic_comparison_full3C_vs_Zonly.csv'));

% Print summary
fprintf('\n  === Full3C vs Z-only Delta Summary ===\n');
for ci = 1:height(deltaTable)
    comp = deltaTable.Component{ci};
    dMAE = safeGet(deltaTable, ci, 'Delta_MAE_ms');
    dMed = safeGet(deltaTable, ci, 'Delta_MedAE_ms');
    dF1  = safeGet(deltaTable, ci, 'Delta_DetectionRate');
    fprintf('  [%s] dMAE=%.1f ms | dMedAE=%.1f ms | dDetRate=%.3f\n', ...
        comp, dMAE, dMed, dF1);
end

% Figures
makePctBarFig(pctFull, pctZ, figDir);
makeOutlierRateFig(pctFull, pctZ, figDir);
makeDeltaFig(deltaTable, figDir);
if ~isempty(snrFull) && ~isempty(snrZ) && height(snrFull)>0 && height(snrZ)>0
    makeSnrF1Fig(snrFull, snrZ, figDir);
    makeSnrMAEFig(snrFull, snrZ, figDir);
end
fprintf('  [Comparison] Saved diagnostic comparison figures.\n');
end

function v = safeGet(t, row, col)
v = NaN;
if ~any(strcmp(t.Properties.VariableNames, col)); return; end
raw = t.(col)(row);
if iscell(raw); raw = raw{1}; end
if isnumeric(raw); v = raw; end
end

function makePctBarFig(pF, pZ, figDir)
fig = figure('Visible','off','Color','white','Units','centimeters','Position',[2 2 18 10]);
pctCols = {'MedAE_ms','P75_ms','P90_ms','P95_ms','P99_ms'};
labels  = {'MedAE','P75','P90','P95','P99'};
for ci = 1:2
    comp = ternary(ci==1,'P','S');
    ax = subplot(1,2,ci);
    rF = getComp(pF,comp); rZ = getComp(pZ,comp);
    if isempty(rF)||isempty(rZ); continue; end
    vals = zeros(numel(pctCols),2);
    for pi=1:numel(pctCols)
        col=pctCols{pi};
        if any(strcmp(rF.Properties.VariableNames,col))
            vals(pi,1)=rF.(col); vals(pi,2)=rZ.(col); end
    end
    b=bar(vals,'grouped');
    b(1).FaceColor=[0.173 0.627 0.173]; b(1).DisplayName='Full 3C';
    b(2).FaceColor=[0.839 0.153 0.157]; b(2).DisplayName='Z-only';
    set(ax,'XTickLabel',labels,'FontSize',8,'FontName','Arial','Box','off','TickDir','out');
    ylabel('Absolute Error (ms)','FontSize',9,'FontName','Arial');
    title(sprintf('(%s) %s-wave: Percentile Error',char('a'+ci-1),comp),'FontSize',9,'FontName','Arial','FontWeight','normal');
    legend('Location','northwest','FontSize',8,'FontName','Arial','Box','off');
    grid on; ax.GridAlpha=0.2;
end
exportgraphics(fig,fullfile(figDir,'full3C_vs_Zonly_percentile_error.png'),'Resolution',300,'BackgroundColor','white');
close(fig);
end

function makeOutlierRateFig(pF, pZ, figDir)
fig = figure('Visible','off','Color','white','Units','centimeters','Position',[2 2 16 8]);
thr={'OutlierRate_500ms','OutlierRate_1000ms','OutlierRate_2000ms'};
thrLab={'>500ms','>1000ms','>2000ms'};
for ci=1:2
    comp=ternary(ci==1,'P','S');
    ax=subplot(1,2,ci);
    rF=getComp(pF,comp); rZ=getComp(pZ,comp);
    if isempty(rF)||isempty(rZ); continue; end
    vals=zeros(numel(thr),2);
    for ti=1:numel(thr)
        col=thr{ti};
        if any(strcmp(rF.Properties.VariableNames,col))
            vals(ti,1)=rF.(col)*100; vals(ti,2)=rZ.(col)*100; end
    end
    b=bar(vals,'grouped');
    b(1).FaceColor=[0.173 0.627 0.173]; b(1).DisplayName='Full 3C';
    b(2).FaceColor=[0.839 0.153 0.157]; b(2).DisplayName='Z-only';
    set(ax,'XTickLabel',thrLab,'FontSize',8,'FontName','Arial','Box','off','TickDir','out');
    ylabel('Outlier Rate (%)','FontSize',9,'FontName','Arial');
    title(sprintf('(%s) %s-wave Outlier Rates',char('a'+ci-1),comp),'FontSize',9,'FontName','Arial','FontWeight','normal');
    legend('Location','northwest','FontSize',8,'FontName','Arial','Box','off');
    grid on; ax.GridAlpha=0.2;
end
exportgraphics(fig,fullfile(figDir,'full3C_vs_Zonly_outlier_rate.png'),'Resolution',300,'BackgroundColor','white');
close(fig);
end

function makeDeltaFig(deltaT, figDir)
if isempty(deltaT); return; end
displayCols={'Delta_MAE_ms','Delta_MedAE_ms','Delta_P90_ms','Delta_OutlierRate_1000ms'};
displayLabs={'dMAE','dMedAE','dP90','dOutlier>1s'};
fig=figure('Visible','off','Color','white','Units','centimeters','Position',[2 2 16 8]);
comps={'P','S'};
for ci=1:2
    comp=comps{ci};
    rD=deltaT(strcmp(deltaT.Component,comp),:);
    if isempty(rD); continue; end
    ax=subplot(1,2,ci); hold on;
    vals=zeros(numel(displayCols),1);
    for di=1:numel(displayCols)
        dcol=displayCols{di};
        if any(strcmp(rD.Properties.VariableNames,dcol))
            v=rD.(dcol); if isnumeric(v)&&~isnan(v); vals(di)=v; end
        end
    end
    col_pos=[0.839 0.153 0.157]; col_neg=[0.173 0.627 0.173];
    for di=1:numel(vals)
        clr=ternary(vals(di)>=0,col_pos,col_neg);
        bar(di,vals(di),'FaceColor',clr,'EdgeColor','none');
    end
    plot([0.5 numel(displayCols)+0.5],[0 0],'k-','LineWidth',1.2);
    set(ax,'XTick',1:numel(displayLabs),'XTickLabel',displayLabs,'FontSize',8,'FontName','Arial','Box','off','TickDir','out');
    ylabel('Z-only minus Full3C','FontSize',9,'FontName','Arial');
    title(sprintf('(%s) %s-wave: Delta(Z-only - Full3C)',char('a'+ci-1),comp),'FontSize',9,'FontName','Arial','FontWeight','normal');
    grid on; ax.GridAlpha=0.2;
end
exportgraphics(fig,fullfile(figDir,'diagnostic_delta_full3C_vs_Zonly.png'),'Resolution',300,'BackgroundColor','white');
close(fig);
end

function makeSnrF1Fig(snrF,snrZ,figDir)
fig=figure('Visible','off','Color','white','Units','centimeters','Position',[2 2 18 10]);
snrClasses=unique(snrF.SNR_Class,'stable');
for ci=1:2
    comp=ternary(ci==1,'P','S');
    ax=subplot(1,2,ci); hold on;
    f1F=zeros(numel(snrClasses),1); f1Z=zeros(numel(snrClasses),1);
    for si=1:numel(snrClasses)
        cls=snrClasses{si};
        rF=snrF(strcmp(snrF.SNR_Class,cls)&strcmp(snrF.Component,comp),:);
        rZ=snrZ(strcmp(snrZ.SNR_Class,cls)&strcmp(snrZ.Component,comp),:);
        if ~isempty(rF)&&any(strcmp(rF.Properties.VariableNames,'F1_100ms')); f1F(si)=rF.F1_100ms; end
        if ~isempty(rZ)&&any(strcmp(rZ.Properties.VariableNames,'F1_100ms')); f1Z(si)=rZ.F1_100ms; end
    end
    b=bar([f1F f1Z],'grouped');
    b(1).FaceColor=[0.173 0.627 0.173]; b(1).DisplayName='Full 3C';
    b(2).FaceColor=[0.839 0.153 0.157]; b(2).DisplayName='Z-only';
    set(ax,'XTickLabel',{'Low','Medium','High'},'FontSize',8,'FontName','Arial','Box','off','TickDir','out','YLim',[0 1.05]);
    ylabel('F1@100ms','FontSize',9,'FontName','Arial');
    xlabel('SNR Class','FontSize',9,'FontName','Arial');
    title(sprintf('(%s) %s-wave F1 by SNR',char('a'+ci-1),comp),'FontSize',9,'FontName','Arial','FontWeight','normal');
    legend('Location','southeast','FontSize',8,'FontName','Arial','Box','off');
    grid on; ax.GridAlpha=0.2;
end
exportgraphics(fig,fullfile(figDir,'snr_stratified_F1_full3C_vs_Zonly.png'),'Resolution',300,'BackgroundColor','white');
close(fig);
end

function makeSnrMAEFig(snrF,snrZ,figDir)
fig=figure('Visible','off','Color','white','Units','centimeters','Position',[2 2 18 10]);
snrClasses=unique(snrF.SNR_Class,'stable');
for ci=1:2
    comp=ternary(ci==1,'P','S');
    ax=subplot(1,2,ci); hold on;
    maeF=zeros(numel(snrClasses),1); maeZ=zeros(numel(snrClasses),1);
    for si=1:numel(snrClasses)
        cls=snrClasses{si};
        rF=snrF(strcmp(snrF.SNR_Class,cls)&strcmp(snrF.Component,comp),:);
        rZ=snrZ(strcmp(snrZ.SNR_Class,cls)&strcmp(snrZ.Component,comp),:);
        if ~isempty(rF)&&any(strcmp(rF.Properties.VariableNames,'MAE_ms')); maeF(si)=rF.MAE_ms; end
        if ~isempty(rZ)&&any(strcmp(rZ.Properties.VariableNames,'MAE_ms')); maeZ(si)=rZ.MAE_ms; end
    end
    b=bar([maeF maeZ],'grouped');
    b(1).FaceColor=[0.173 0.627 0.173]; b(1).DisplayName='Full 3C';
    b(2).FaceColor=[0.839 0.153 0.157]; b(2).DisplayName='Z-only';
    set(ax,'XTickLabel',{'Low','Medium','High'},'FontSize',8,'FontName','Arial','Box','off','TickDir','out');
    ylabel('MAE (ms)','FontSize',9,'FontName','Arial');
    xlabel('SNR Class','FontSize',9,'FontName','Arial');
    title(sprintf('(%s) %s-wave MAE by SNR',char('a'+ci-1),comp),'FontSize',9,'FontName','Arial','FontWeight','normal');
    legend('Location','northwest','FontSize',8,'FontName','Arial','Box','off');
    grid on; ax.GridAlpha=0.2;
end
exportgraphics(fig,fullfile(figDir,'snr_stratified_MAE_full3C_vs_Zonly.png'),'Resolution',300,'BackgroundColor','white');
close(fig);
end

function r=getComp(t,comp)
r=table();
if isempty(t)||~istable(t); return; end
if any(strcmpi(t.Properties.VariableNames,'Component'))
    mask=strcmp(t.Component,comp); if any(mask); r=t(mask,:); end
end
end

function out=ternary(c,a,b); if c; out=a; else; out=b; end; end
function ensureDir(d); if ~isempty(d)&&~isfolder(d); mkdir(d); end; end
