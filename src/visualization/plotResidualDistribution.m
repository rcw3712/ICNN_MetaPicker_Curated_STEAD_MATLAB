% =========================================================================
% plotResidualDistribution.m     Fig 06
% =========================================================================
% PURPOSE:
%   3-panel residual distribution: Histogram (  500ms zoom) + QQ-plot + Boxplot.
%   Dihasilkan dua versi: zoomed (  500ms) dan full range.
% =========================================================================

function caption = plotResidualDistribution(predTable, experimentName, outDir)

C = vizColors();
errP = safeNum(predTable,'p_error_ms');
errS = safeNum(predTable,'s_error_ms');

for version = {'zoomed','full'}
    ver = version{1};
    fig = figure('Visible','off','Color','white','Units','centimeters','Position',[2 2 22 18]);
    sgtitle(sprintf('Picking Residual Distribution - %s (%s)', experimentName, ver), ...
        'FontSize',16,'FontName','Arial','FontWeight','bold');

    for ci = 1:2
        comp = ternary(ci==1,'P','S');
        col  = ternary(ci==1, C.Pwave, C.Swave);
        err  = ternary(ci==1, errP, errS);
        valid= ~isnan(err);
        ev   = err(valid);
        if isempty(ev); continue; end

        absEv = abs(ev);
        xLim = ternary(strcmp(ver,'zoomed'), [-500 500], ...
            [max(-3000,min(ev)), min(3000,max(ev))]);

        %        Histogram                                                                                                                                                       
        ax1 = subplot(3, 2, (ci-1)+1);
        edges = linspace(xLim(1), xLim(2), 60);
        histogram(ev, edges, 'FaceColor',col,'EdgeColor','none','FaceAlpha',0.8, ...
            'Normalization','probability');
        hold on;
        xline(0,  'k-',  'LineWidth',1.5);
        xline(mean(ev),'--','Color',col*0.6,'LineWidth',1.5, ...
            'Label',sprintf('\\mu=%.0fms',mean(ev)),'FontSize',10,'LabelVerticalAlignment','top');
        xline(median(ev),':','Color',col*0.7,'LineWidth',1.5, ...
            'Label',sprintf('Med=%.0fms',median(ev)),'FontSize',10,'LabelVerticalAlignment','bottom');
        for tol=[50 100 200]
            if tol <= abs(xLim(2))
                xline(tol, ':','Color',[0.5 0.5 0.5],'LineWidth',0.8);
                xline(-tol,':','Color',[0.5 0.5 0.5],'LineWidth',0.8);
            end
        end
        xlim(xLim);
        xlabel(sprintf('%s Residual (ms)',comp),'FontSize',14,'FontName','Arial');
        ylabel('Probability','FontSize',14,'FontName','Arial');
        title(sprintf('(%s) %s-wave Histogram',char('a'+ci-1),comp), ...
            'FontSize',15,'FontName','Arial','FontWeight','bold');

        % Stats box
        rts = computeOutlierRates(ev);
        statsStr = sprintf('N=%d\nMAE=%.0f ms\nMedAE=%.0f ms\nRMSE=%.0f ms\nBias=%.0f ms\nSTD=%.0f ms\nP90=%.0f ms\nP95=%.0f ms\nOutl>1s=%.1f%%', ...
            numel(ev), mean(absEv), median(absEv), sqrt(mean(ev.^2)), ...
            mean(ev), std(ev), prctile(absEv,90), prctile(absEv,95), ...
            rts.rate_1000*100);
        text(0.97,0.97,statsStr,'Units','normalized','HorizontalAlignment','right', ...
            'VerticalAlignment','top','FontSize',9,'FontName','Arial', ...
            'BackgroundColor','white','EdgeColor',[0.7 0.7 0.7],'Margin',3);
        set(ax1,'FontSize',12,'FontName','Arial','Box','off'); grid on;

        %        QQ-plot                                                                                                                                                                   
        ax2 = subplot(3, 2, 2 + (ci-1)+1);
        qqplot(ev);
        ax2.Children(end).Color   = col;
        ax2.Children(end).MarkerSize = 4;
        ax2.Children(end-1).LineWidth = 1.5;
        xlabel('Standard Normal Quantiles','FontSize',13,'FontName','Arial');
        ylabel(sprintf('%s Error Quantiles (ms)',comp),'FontSize',13,'FontName','Arial');
        title(sprintf('(%s) %s-wave QQ-Plot',char('c'+ci-1),comp), ...
            'FontSize',15,'FontName','Arial','FontWeight','bold');
        set(ax2,'FontSize',12,'FontName','Arial','Box','off'); grid on;

        %        Boxplot                                                                                                                                                                   
        ax3 = subplot(3, 2, 4 + (ci-1)+1);
        bp = boxchart(ax3, ones(size(ev)), ev, 'BoxFaceColor',col, ...
            'WhiskerLineColor',col*0.7,'MarkerColor',col,'MarkerStyle','.','MarkerSize',4);
        hold on;
        yline(0,'k-','LineWidth',1.5);
        for tol=[50 100 200]
            yline(tol, ':','Color',[0.5 0.5 0.5],'LineWidth',0.8);
            yline(-tol,':','Color',[0.5 0.5 0.5],'LineWidth',0.8);
        end
        ylim(xLim);
        set(ax3,'XTick',[],'FontSize',12,'FontName','Arial','Box','off');
        ylabel(sprintf('%s Error (ms)',comp),'FontSize',13,'FontName','Arial');
        xlabel('','FontSize',1);
        title(sprintf('(%s) %s-wave Boxplot',char('e'+ci-1),comp), ...
            'FontSize',15,'FontName','Arial','FontWeight','bold');
        grid on;
    end

    suffix = ternary(strcmp(ver,'zoomed'),'_zoomed','_full');
    ensureDir(outDir);
    exportFigure300dpi(fig, outDir, ['Fig06_ResidualDistribution' suffix]);
    close(fig);
end

caption = ['Fig. 6. Picking residual distribution for P- and S-wave phases. ' ...
    'Top panels: histograms of timing residuals (zoomed to ±500 ms) with mean (dashed) ' ...
    'and median (dotted) lines indicated. Middle panels: quantile-quantile plots against ' ...
    'the standard normal distribution. Bottom panels: boxplots showing the interquartile range. ' ...
    'Vertical dotted lines indicate tolerance thresholds at ±50, ±100, and ±200 ms. ' ...
    'A full-range version is provided as supplementary material.'];
end

function rts = computeOutlierRates(ev)
absEv = abs(ev);
n = numel(absEv);
rts.rate_500  = sum(absEv>500)/n;
rts.rate_1000 = sum(absEv>1000)/n;
rts.rate_2000 = sum(absEv>2000)/n;
end
function v = safeNum(t,col)
idx=strcmpi(t.Properties.VariableNames,col);
if ~any(idx);v=nan(height(t),1);return;end
v=double(t.(t.Properties.VariableNames{find(idx,1)}));
end
function out=ternary(c,a,b);if c;out=a;else;out=b;end;end
function ensureDir(d);if ~isempty(d)&&~isfolder(d);mkdir(d);end;end
