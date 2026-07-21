% =========================================================================
% plotSNRPerformance.m     Fig 09
% =========================================================================
% PURPOSE:
%   SNR-stratified performance: F1, MAE, DetectionRate per kelas SNR
%   untuk Full3C dan Z-only.
% =========================================================================

function caption = plotSNRPerformance(snrFull, snrZ, outDir)

C = vizColors();
if isempty(snrFull)
    fprintf('  [Fig09] SNR stratified data not available. Skipping.\n');
    caption = ''; return;
end

snrClasses = {'Low (10-20 dB)','Medium (20-40 dB)','High (>=40 dB)'};
snrShort   = {'Low','Medium','High'};
metricDefs = {
    'F1_100ms',       'F1@100ms',          [0 1.30],  'F1-score @ 100 ms';
    'MAE_ms',         'MAE (ms)',           [0 NaN],   'Mean Absolute Error (ms)';
    'DetectionRate',  'Detection Rate',     [0 1.30],  'Detection Rate'
};

hasZ = ~isempty(snrZ) && height(snrZ) > 0;

fig = figure('Visible','off','Color','white','Units','centimeters','Position',[2 2 22 16]);
sgtitle('SNR-Stratified Picking Performance','FontSize',16,'FontName','Arial','FontWeight','bold');

nMetrics = size(metricDefs,1);
panelIdx = 0;

for mi = 1:nMetrics
    metCol = metricDefs{mi,1};
    metLab = metricDefs{mi,2};
    metYlim= metricDefs{mi,3};

    for ci = 1:2
        comp = ternary(ci==1,'P','S');
        panelIdx = panelIdx + 1;
        ax = subplot(nMetrics, 2, panelIdx); %#ok
        hold on;

        valF = zeros(numel(snrClasses),1);
        valZ = zeros(numel(snrClasses),1);
        for si = 1:numel(snrClasses)
            cls = snrClasses{si};
            rF = snrFull(strcmp(snrFull.SNR_Class,cls) & strcmp(snrFull.Component,comp),:);
            if ~isempty(rF) && any(strcmp(rF.Properties.VariableNames,metCol))
                valF(si) = rF.(metCol);
            end
            if hasZ
                rZ = snrZ(strcmp(snrZ.SNR_Class,cls) & strcmp(snrZ.Component,comp),:);
                if ~isempty(rZ) && any(strcmp(rZ.Properties.VariableNames,metCol))
                    valZ(si) = rZ.(metCol);
                end
            end
        end

        xPos = 1:numel(snrClasses);
        if hasZ
            b1 = bar(xPos-0.2, valF, 0.35, 'FaceColor',C.full3C,'EdgeColor','none','DisplayName','Full 3C');
            b2 = bar(xPos+0.2, valZ, 0.35, 'FaceColor',C.zonly, 'EdgeColor','none','DisplayName','Z-only');
        else
            b1 = bar(xPos, valF, 0.5, 'FaceColor',C.full3C,'EdgeColor','none','DisplayName','Full 3C');
        end

        % Value labels on bars
        for si = 1:numel(snrClasses)
            yv = valF(si);
            if ~isnan(yv) && yv > 0
                text(xPos(si)-0.2, yv+0.01*max(valF), sprintf('%.3f',yv), ...
                    'HorizontalAlignment','center','FontSize',8,'FontName','Arial');
            end
            if hasZ
                yv2 = valZ(si);
                if ~isnan(yv2) && yv2 > 0
                    text(xPos(si)+0.2, yv2+0.01*max(valF), sprintf('%.3f',yv2), ...
                        'HorizontalAlignment','center','FontSize',8,'FontName','Arial');
                end
            end
        end

        set(ax,'XTick',xPos,'XTickLabel',snrShort,'FontSize',11,'FontName','Arial', ...
            'Box','off','TickDir','out');
        ylabel(metLab,'FontSize',13,'FontName','Arial');
        xlabel('SNR Class','FontSize',12,'FontName','Arial');
        if ~isnan(metYlim(2)); ylim(metYlim); end
        panelLetter = char('a' + panelIdx - 1);
        title(sprintf('(%s) %s-wave %s',panelLetter,comp,metLab), ...
            'FontSize',13,'FontName','Arial','FontWeight','bold');
        legend('Location','best','FontSize',11,'FontName','Arial','Box','off');
        grid on;
    end
end

caption = ['Fig. 9. SNR-stratified picking performance for P-wave (left column) ' ...
    'and S-wave (right column). Three SNR classes are evaluated: Low (10-20 dB), ' ...
    'Medium (20-40 dB), and High (>40 dB). Rows show F1-score at 100 ms tolerance, ' ...
    'mean absolute error (MAE), and detection rate for Full3C (green) and Z-only (orange). ' ...
    'Note: this dataset represents a curated high-SNR subset; results may not ' ...
    'generalise directly to lower-quality field recordings.'];

ensureDir(outDir);
exportFigure300dpi(fig, outDir, 'Fig09_SNRPerformance');
close(fig);
end

function out=ternary(c,a,b);if c;out=a;else;out=b;end;end
function ensureDir(d);if ~isempty(d)&&~isfolder(d);mkdir(d);end;end
