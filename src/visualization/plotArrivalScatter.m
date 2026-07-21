% =========================================================================
% plotArrivalScatter.m     Fig 07
% =========================================================================
% PURPOSE:
%   Scatter plot predicted vs true arrival time dengan 1:1 line,
%     50/100 ms bands, outlier markers, regression line, dan R  /slope/intercept.
% =========================================================================

function caption = plotArrivalScatter(predTable, outDir)

C = vizColors();
fig = figure('Visible','off','Color','white','Units','centimeters','Position',[2 2 20 9]);

comps = {'P','S'};
for ci = 1:2
    comp  = comps{ci};
    col   = ternary(ci==1, C.Pwave, C.Swave);
    pTrue = safeNum(predTable, ternary(ci==1,'p_true_sec','s_true_sec'));
    pPred = safeNum(predTable, ternary(ci==1,'p_pred_sec','s_pred_sec'));
    snrV  = safeNum(predTable,'SNR');
    errMs = safeNum(predTable, ternary(ci==1,'p_error_ms','s_error_ms'));

    valid = ~isnan(pTrue) & ~isnan(pPred);
    tv = pTrue(valid); pv = pPred(valid); sv = snrV(valid); ev = errMs(valid);

    if numel(tv) < 5; continue; end

    ax = axes('Position',[0.07 + (ci-1)*0.50, 0.14, 0.40, 0.78]); %#ok
    hold on;

    % Tolerance bands
    xl = [min(tv)*0.95, max(tv)*1.05];
    fill([xl(1) xl(2) xl(2) xl(1)], ...
         [xl(1)+0.2 xl(2)+0.2 xl(2)-0.2 xl(1)-0.2], ...
         [0.8 0.8 0.8],'EdgeColor','none','FaceAlpha',0.3,'DisplayName','\pm200 ms');
    fill([xl(1) xl(2) xl(2) xl(1)], ...
         [xl(1)+0.1 xl(2)+0.1 xl(2)-0.1 xl(1)-0.1], ...
         [0.6 0.6 0.6],'EdgeColor','none','FaceAlpha',0.3,'DisplayName','\pm100 ms');
    fill([xl(1) xl(2) xl(2) xl(1)], ...
         [xl(1)+0.05 xl(2)+0.05 xl(2)-0.05 xl(1)-0.05], ...
         [0.4 0.4 0.4],'EdgeColor','none','FaceAlpha',0.3,'DisplayName','\pm50 ms');

    % 1:1 line
    plot(xl, xl, 'k-', 'LineWidth', 1.8, 'DisplayName','1:1 line');

    % Scatter: SNR-coloured
    if ~all(isnan(sv))
        sc = scatter(tv, pv, 25, sv, 'filled','MarkerFaceAlpha',0.55, ...
            'DisplayName','Records');
        cb = colorbar; cb.Label.String = 'SNR (dB)';
        cb.Label.FontSize = 12; cb.FontSize = 11;
        colormap(ax, parula);
        clim([10 min(60,prctile(sv(~isnan(sv)),95))]);
    else
        scatter(tv, pv, 25, col, 'filled','MarkerFaceAlpha',0.55,'DisplayName','Records');
    end

    % Outliers (|error| > 1000 ms)
    outMask = ~isnan(ev) & abs(ev) > 1000;
    if any(outMask)
        scatter(tv(outMask), pv(outMask), 60, 'r', '^', ...
            'LineWidth',1.5,'DisplayName','Outlier >1s');
    end

    % Regression line
    p = polyfit(tv, pv, 1);
    xr = linspace(xl(1),xl(2),100);
    yr = polyval(p, xr);
    plot(xr, yr, '--', 'Color', col, 'LineWidth', 2.0, 'DisplayName','Regression');

    % Stats
    r2 = corr(tv,pv)^2;
    statsStr = sprintf('N = %d\nR^2 = %.4f\nSlope = %.4f\nIntercept = %.3f s\nMAE = %.1f ms\nMedAE = %.1f ms', ...
        numel(tv), r2, p(1), p(2), mean(abs(ev(~isnan(ev)))), ...
        median(abs(ev(~isnan(ev)))));
    text(0.03, 0.97, statsStr, 'Units','normalized','VerticalAlignment','top', ...
        'FontSize',10,'FontName','Arial','BackgroundColor','white', ...
        'EdgeColor',[0.7 0.7 0.7],'Margin',4);

    xlim(xl); ylim(xl); axis square;
    xlabel(sprintf('True %s Arrival (s)', comp),'FontSize',16,'FontName','Arial');
    ylabel(sprintf('Predicted %s Arrival (s)', comp),'FontSize',16,'FontName','Arial');
    title(sprintf('(%s) %s-wave: Predicted vs. True',char('a'+ci-1),comp), ...
        'FontSize',16,'FontName','Arial','FontWeight','bold');
    legend('Location','southeast','FontSize',12,'FontName','Arial','Box','off','NumColumns',1);
    set(ax,'FontSize',14,'FontName','Arial','Box','on','TickDir','out'); grid on;
end

caption = ['Fig. 7. Predicted versus true phase arrival times for (a) P-wave and (b) S-wave. ' ...
    'Scatter points are coloured by signal-to-noise ratio (SNR). The 1:1 reference line ' ...
    '(black solid) and linear regression line (dashed) are shown. Shaded bands indicate ' ...
    'tolerance windows of ±50 ms (dark), ±100 ms (medium), and ±200 ms (light). ' ...
    'Triangular markers indicate picks with |error| > 1000 ms (outliers). ' ...
    'R², slope, and intercept of the regression are annotated.'];

ensureDir(outDir);
exportFigure300dpi(fig, outDir, 'Fig07_ArrivalScatter');
close(fig);
end

function v=safeNum(t,col)
idx=strcmpi(t.Properties.VariableNames,col);
if ~any(idx);v=nan(height(t),1);return;end
v=double(t.(t.Properties.VariableNames{find(idx,1)}));
end
function out=ternary(c,a,b);if c;out=a;else;out=b;end;end
function ensureDir(d);if ~isempty(d)&&~isfolder(d);mkdir(d);end;end
