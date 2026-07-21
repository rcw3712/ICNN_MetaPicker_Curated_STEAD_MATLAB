% =========================================================================
% plotErrorHistogram.m  (src/visualization/)
% =========================================================================
% PURPOSE:
%   Fig 6 — Error distribution: histogram + box-whisker + tolerance lines.
% =========================================================================

function plotErrorHistogram(errorsP, errorsS, outputPath)

eP = errorsP(~isnan(errorsP));
eS = errorsS(~isnan(errorsS));

fig = figure('Visible','off','Color','white', ...
    'Units','centimeters','Position',[2 2 18 12]);

CP = [0.122 0.467 0.706];
CS = [0.839 0.153 0.157];

for k = 1:2
    if k==1; err=eP; col=CP; lbl='P-wave'; pan='(a)';
    else;     err=eS; col=CS; lbl='S-wave'; pan='(b)'; end

    % Histogram panel
    ax1 = axes('Position',[0.08+(k-1)*0.50, 0.38, 0.38, 0.52]); %#ok
    edges = linspace(prctile(err,1), prctile(err,99), 50);
    histogram(err, edges,'FaceColor',col,'EdgeColor','none','FaceAlpha',0.85, ...
        'Normalization','probability');
    hold on;
    xline(0,'k-','LineWidth',1.5);
    xline(mean(err),'--','Color',col*0.6,'LineWidth',1.5, ...
        'Label',sprintf('\\mu=%.1f ms',mean(err)),'FontSize',8);
    for tol=[50 100 200]
        xline(tol,':k','LineWidth',0.7); xline(-tol,':k','LineWidth',0.7);
    end

    % F1 per tolerance annotation
    tols=[50 100 200]; f1s=zeros(1,3);
    N=numel(err)+sum(isnan(errorsP));
    for ti=1:3
        TP=sum(abs(err)<=tols(ti)); FP=sum(abs(err)>tols(ti)); FN=N-numel(err);
        pr=TP/max(1,TP+FP); rc=TP/max(1,TP+FN);
        f1s(ti)=2*pr*rc/max(1e-10,pr+rc);
    end
    statsStr=sprintf('%s N=%d\nMAE=%.1f ms\nRMSE=%.1f ms\nBias=%.1f ms\nSTD=%.1f ms\nF1@50ms=%.3f\nF1@100ms=%.3f\nF1@200ms=%.3f', ...
        lbl,numel(err),mean(abs(err)),sqrt(mean(err.^2)),mean(err),std(err),f1s(1),f1s(2),f1s(3));
    text(0.97,0.97,statsStr,'Units','normalized', ...
        'HorizontalAlignment','right','VerticalAlignment','top', ...
        'FontSize',8,'FontName','Arial', ...
        'BackgroundColor','white','EdgeColor',[0.7 0.7 0.7],'Margin',3);

    xlabel('Residual (ms)','FontSize',9,'FontName','Arial');
    ylabel('Probability','FontSize',9,'FontName','Arial');
    title([pan ' ' lbl ' Residual Distribution'],'FontSize',9,'FontName','Arial', ...
        'FontWeight','normal');
    set(ax1,'FontSize',8,'FontName','Arial','Box','off','TickDir','out','LineWidth',0.8);
    grid on; ax1.GridAlpha=0.15;

    % Box-whisker panel di bawah
    ax2 = axes('Position',[0.08+(k-1)*0.50, 0.12, 0.38, 0.18]); %#ok
    boxchart(ax2, ones(size(err)), err, 'BoxFaceColor',col, ...
        'WhiskerLineColor',col,'MarkerColor',col,'MarkerStyle','.', ...
        'MarkerSize',4);
    hold on;
    yline(0,'k-','LineWidth',1.2);
    for tol=[50 100 200]
        yline(tol,':k','LineWidth',0.7); yline(-tol,':k','LineWidth',0.7);
    end
    set(ax2,'FontSize',8,'FontName','Arial','Box','off','TickDir','out', ...
        'XTick',[],'LineWidth',0.8);
    ylabel('Residual (ms)','FontSize',8,'FontName','Arial');
    grid on; ax2.GridAlpha=0.15;
end

ensureDir(fileparts(outputPath));
exportgraphics(fig, outputPath,'Resolution',300,'BackgroundColor','white');
close(fig);
fprintf('  Saved: %s\n', outputPath);
end

function ensureDir(d)
if ~isempty(d) && ~isfolder(d); mkdir(d); end
end
