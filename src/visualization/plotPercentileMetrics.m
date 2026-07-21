% =========================================================================
% plotPercentileMetrics.m     Fig 10
% =========================================================================
% PURPOSE:
%   Grouped bar chart percentile error metrics (MedAE, P75, P90, P95, P99)
%   untuk Full3C vs Z-only dan P vs S.
% =========================================================================

function caption = plotPercentileMetrics(pctFull, pctZ, outDir)

C = vizColors();
if isempty(pctFull)
    fprintf('  [Fig10] Percentile metrics not available. Skipping.\n');
    caption=''; return;
end

pctCols = {'MedAE_ms','P75_ms','P90_ms','P95_ms','P99_ms'};
pctLabs = {'MedAE','P75','P90','P95','P99'};
hasZ    = ~isempty(pctZ) && height(pctZ) > 0;

fig = figure('Visible','off','Color','white','Units','centimeters','Position',[2 2 20 14]);
sgtitle('Percentile Error Metrics - Full3C vs. Z-only','FontSize',16,'FontName','Arial','FontWeight','bold');

for ci = 1:2
    comp = ternary(ci==1,'P','S');
    ax   = subplot(1,2,ci);
    hold on;

    rF = getComp(pctFull, comp);
    rZ = getComp(pctZ, comp);

    valsF = zeros(numel(pctCols),1);
    valsZ = zeros(numel(pctCols),1);
    for pi = 1:numel(pctCols)
        col = pctCols{pi};
        if ~isempty(rF) && any(strcmp(rF.Properties.VariableNames,col)); valsF(pi)=rF.(col); end
        if hasZ && ~isempty(rZ) && any(strcmp(rZ.Properties.VariableNames,col)); valsZ(pi)=rZ.(col); end
    end

    xPos = 1:numel(pctCols);
    if hasZ && ~isempty(rZ)
        b1 = bar(xPos-0.2, valsF, 0.35,'FaceColor',C.full3C,'EdgeColor','none','DisplayName','Full 3C');
        b2 = bar(xPos+0.2, valsZ, 0.35,'FaceColor',C.zonly, 'EdgeColor','none','DisplayName','Z-only');
    else
        bar(xPos, valsF, 0.55,'FaceColor',C.full3C,'EdgeColor','none','DisplayName','Full 3C');
    end

    % Annotate values
    for pi = 1:numel(pctCols)
        yv=valsF(pi); if yv>0; text(xPos(pi)-0.2,yv+5,sprintf('%.0f',yv),'HorizontalAlignment','center','FontSize',9,'FontName','Arial'); end
        if hasZ && ~isempty(rZ); yv2=valsZ(pi); if yv2>0; text(xPos(pi)+0.2,yv2+5,sprintf('%.0f',yv2),'HorizontalAlignment','center','FontSize',9,'FontName','Arial'); end; end
    end

    set(ax,'XTick',xPos,'XTickLabel',pctLabs,'FontSize',13,'FontName','Arial', ...
        'Box','off','TickDir','out');
    ylabel('Absolute Error (ms)','FontSize',14,'FontName','Arial');
    xlabel('Percentile Metric','FontSize',13,'FontName','Arial');
    title(sprintf('(%s) %s-wave Percentile Errors',char('a'+ci-1),ternary(ci==1,'P','S')), ...
        'FontSize',15,'FontName','Arial','FontWeight','bold');
    legend('Location','northwest','FontSize',13,'FontName','Arial','Box','off');
    grid on;
end

caption = ['Fig. 10. Percentile absolute error distribution for P-wave (a) and S-wave (b). ' ...
    'Bars show median absolute error (MedAE) and the 75th, 90th, 95th, and 99th ' ...
    'percentiles of the absolute timing error, comparing Full3C (green) and Z-only (orange) ' ...
    'experiments. Percentile metrics are less sensitive to extreme outliers than RMSE.'];

ensureDir(outDir);
exportFigure300dpi(fig, outDir, 'Fig10_PercentileMetrics');
close(fig);
end

function r = getComp(t,comp)
r=table();
if isempty(t)||~istable(t);return;end
if any(strcmpi(t.Properties.VariableNames,'Component'))
    mask=strcmp(t.Component,comp); if any(mask);r=t(mask,:);end
end
end
function out=ternary(c,a,b);if c;out=a;else;out=b;end;end
function ensureDir(d);if ~isempty(d)&&~isfolder(d);mkdir(d);end;end
