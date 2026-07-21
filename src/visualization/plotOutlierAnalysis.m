function caption = plotOutlierAnalysis(predTable, outDir)
% plotOutlierAnalysis.m -- Fig 11
% 4-panel outlier analysis. Pure ASCII. No yline after colorbar.
% Fix: all threshold lines drawn with plot() BEFORE colorbar to avoid
% R2024a ColorBar/yline conflict (Attempt to modify tree during update).

C = vizColors();
fig = figure('Visible','off','Color','white','Units','centimeters','Position',[2 2 30 16]);
sgtitle('Outlier Analysis -- Picking Error Distribution',...
    'FontSize',16,'FontName','Arial','FontWeight','bold');

comps = {'P','S'};
for ci = 1:2
    comp  = comps{ci};
    col   = ternary(ci==1, C.Pwave, C.Swave);
    errMs = safeNum(predTable, ternary(ci==1,'p_error_ms','s_error_ms'));
    absEv = abs(errMs(~isnan(errMs)));
    ev    = errMs(~isnan(errMs));
    if isempty(ev); continue; end

    % (a,e) Histogram log-scale
    ax1 = subplot(2,4,(ci-1)*4+1);
    histogram(absEv,50,'FaceColor',col,'EdgeColor','none','FaceAlpha',0.8,'Normalization','count');
    hold on;
    yl = get(ax1,'YLim');
    for thr = [500 1000 2000]
        plot([thr thr],[yl(1) max(yl(2),1)],'--k','LineWidth',1.0);
    end
    set(ax1,'YScale','log');
    text(520, exp(log(max(absEv))*0.7),  '>500ms','FontSize',7,'FontName','Arial');
    text(1020,exp(log(max(absEv))*0.55), '>1s',   'FontSize',7,'FontName','Arial');
    text(2020,exp(log(max(absEv))*0.4),  '>2s',   'FontSize',7,'FontName','Arial');
    xlabel('|Error| (ms)','FontSize',13,'FontName','Arial');
    ylabel('Count (log)','FontSize',12,'FontName','Arial');
    title(sprintf('(%s) %s-wave |Error| Histogram',char('a'+(ci-1)*4),comp),...
        'FontSize',12,'FontName','Arial','FontWeight','bold');
    set(ax1,'FontSize',11,'FontName','Arial','Box','off'); grid on;

    % (b,f) Cumulative distribution
    ax2 = subplot(2,4,(ci-1)*4+2);
    absS = sort(absEv);
    cdf  = (1:numel(absS))'/numel(absS);
    plot(absS,cdf*100,'-','Color',col,'LineWidth',2.5);
    hold on;
    for tol = [50 100 200 500 1000]
        pct = mean(absEv<=tol)*100;
        plot([tol tol],[0 105],'--','Color',[0.6 0.6 0.6],'LineWidth',0.7);
        text(tol+30,pct-2,sprintf('%.1f%%',pct),'FontSize',7,'FontName','Arial','Color',col*0.7);
    end
    xlabel('|Error| Threshold (ms)','FontSize',13,'FontName','Arial');
    ylabel('Cumulative %','FontSize',12,'FontName','Arial');
    title(sprintf('(%s) %s-wave Cumulative',char('b'+(ci-1)*4),comp),...
        'FontSize',12,'FontName','Arial','FontWeight','bold');
    xlim([0 3000]); ylim([0 105]);
    set(ax2,'FontSize',11,'FontName','Arial','Box','off'); grid on;

    % (c,g) Outlier rates at thresholds
    ax3 = subplot(2,4,(ci-1)*4+3);
    thrs  = [500 1000 2000];
    rates = arrayfun(@(t) mean(absEv>t)*100, thrs);
    bar(rates,'FaceColor',col,'EdgeColor','none');
    for bi=1:3
        text(bi,rates(bi)+0.3,sprintf('%.1f%%',rates(bi)),...
            'HorizontalAlignment','center','FontSize',9,'FontName','Arial');
    end
    set(ax3,'XTick',1:3,'XTickLabel',{'>500ms','>1s','>2s'},...
        'FontSize',11,'FontName','Arial','Box','off');
    ylabel('Outlier Rate (%)','FontSize',12,'FontName','Arial');
    title(sprintf('(%s) %s-wave Outlier Rates',char('c'+(ci-1)*4),comp),...
        'FontSize',12,'FontName','Arial','FontWeight','bold');
    grid on;

    % (d,h) Top-20 outliers scatter
    % CRITICAL: draw all plot() elements BEFORE colorbar to avoid R2024a conflict
    ax4 = subplot(2,4,(ci-1)*4+4);
    [~,sortIdx] = sort(abs(errMs),'descend','MissingPlacement','last');
    top20 = min(20, sum(~isnan(errMs)));
    idxTop = sortIdx(1:top20);
    snrVal = safeNum(predTable,'SNR');
    xT = (1:top20)';
    yT = errMs(idxTop);
    sv = snrVal(idxTop);

    % Reference lines with plot() -- NOT yline (causes colorbar conflict)
    hold on;
    xl = [0.5 top20+0.5];
    plot(xl,[0    0   ],'k-', 'LineWidth',1.4);
    plot(xl,[1000  1000],'--','Color',[0.5 0.5 0.5],'LineWidth',0.9);
    plot(xl,[-1000 -1000],'--','Color',[0.5 0.5 0.5],'LineWidth',0.9);
    plot(xl,[500   500 ],':' ,'Color',[0.7 0.7 0.7],'LineWidth',0.7);
    plot(xl,[-500  -500],':' ,'Color',[0.7 0.7 0.7],'LineWidth',0.7);

    % Scatter AFTER reference lines, colorbar LAST
    if ~all(isnan(sv))
        scatter(xT, yT, 60, sv, 'filled','MarkerFaceAlpha',0.85);
        colormap(ax4, parula);
        drawnow;
        cb = colorbar(ax4);
        drawnow;
        cb.Label.String = 'SNR (dB)'; cb.Label.FontSize = 10;
    else
        scatter(xT, yT, 60, col, 'filled','MarkerFaceAlpha',0.85);
    end

    xlabel('Rank (1=largest)','FontSize',13,'FontName','Arial');
    ylabel('Signed Error (ms)','FontSize',12,'FontName','Arial');
    title(sprintf('(%s) %s-wave Top-20 Outliers',char('d'+(ci-1)*4),comp),...
        'FontSize',12,'FontName','Arial','FontWeight','bold');
    set(ax4,'FontSize',11,'FontName','Arial','Box','off'); grid on;
end

caption = ['Fig. 11. Outlier analysis of picking residuals for P-wave (top row) ' ...
    'and S-wave (bottom row). (a,e) Log-scaled histograms of absolute errors. ' ...
    '(b,f) Cumulative distribution of absolute errors. ' ...
    '(c,g) Outlier rates at fixed thresholds. ' ...
    '(d,h) Signed errors of the 20 largest outliers, coloured by SNR.'];

ensureDir(outDir);
exportFigure300dpi(fig, outDir, 'Fig11_OutlierAnalysis');
close(fig);
end

function v=safeNum(t,col)
idx=strcmpi(t.Properties.VariableNames,col);
if ~any(idx);v=nan(height(t),1);return;end
v=double(t.(t.Properties.VariableNames{find(idx,1)}));
end
function out=ternary(c,a,b);if c;out=a;else;out=b;end;end
function ensureDir(d);if ~isempty(d)&&~isfolder(d);mkdir(d);end;end
