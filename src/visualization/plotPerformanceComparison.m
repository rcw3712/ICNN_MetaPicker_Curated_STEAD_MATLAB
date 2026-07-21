% =========================================================================
% plotPerformanceComparison.m     Fig 05
% =========================================================================
% PURPOSE:
%   Grouped bar chart perbandingan Full3C vs Z-only, dengan metrik lengkap:
%   F1@50/100/200ms, Precision, Recall, DetRate, MAE, MedAE, P95, OutlierRate.
%   Nilai ditampilkan di atas setiap bar.
% INPUTS:
%   f1Conv  - table dari results/f1_audit/f1_conventional_summary.csv
%             (post-audit source of truth for F1/Precision/Recall/DetRate)
%   pctFull - table dari percentile_metrics_Full3C.csv (MAE/MedAE/P95/OutlierRate)
%   pctZ    - table dari percentile_metrics_Zonly.csv
%   outDir  - char
% =========================================================================

function caption = plotPerformanceComparison(f1Conv, pctFull, pctZ, outDir)

C = vizColors();
fig = figure('Visible','off','Color','white','Units','centimeters','Position',[2 2 26 16]);

comps    = {'P','S'};
compTitles = {'P-wave','S-wave'};
colors   = {C.full3C, C.zonly};
legNames = {'Full 3C','Z-only'};

for ci = 1:2
    comp = comps{ci};

    % Ambil metrik dari tables
    pF = getRow(pctFull, comp);
    pZ = getRow(pctZ,    comp);

    % Daftar metrik yang akan ditampilkan
    metrics = buildMetricList(f1Conv, comp, pF, pZ);

    ax = axes('Position', panelPos(ci, 2)); %#ok
    hold on;

    nM = numel(metrics);
    xPos = 1:nM;
    barW = 0.35;

    bars = zeros(nM, 2);
    for mi = 1:nM
        bars(mi,:) = [metrics(mi).full, metrics(mi).zonly];
    end

    bar(xPos - barW/2, bars(:,1)', barW, 'FaceColor',colors{1}, ...
        'EdgeColor','none', 'DisplayName', legNames{1});
    bar(xPos + barW/2, bars(:,2)', barW, 'FaceColor',colors{2}, ...
        'EdgeColor','none', 'DisplayName', legNames{2});

    % Nilai di atas bar
    for mi = 1:nM
        for col = 1:2
            xc = xPos(mi) + (col-1.5)*barW;
            yv = bars(mi, col);
            if isnan(yv); continue; end
            fmt = metrics(mi).fmt;
            text(xc, yv + 0.01*max(bars(:)), sprintf(fmt, yv), ...
                'HorizontalAlignment','center','VerticalAlignment','bottom', ...
                'FontSize',8,'FontName','Arial','Color',[0.2 0.2 0.2]);
        end
    end

    set(ax,'XTick',xPos,'XTickLabel',{metrics.label}, ...
        'XTickLabelRotation',30,'FontSize',11,'FontName','Arial', ...
        'Box','off','TickDir','out');
    ylabel('Metric Value','FontSize',14,'FontName','Arial');
    title(sprintf('(%s) %s Performance', char('a'+ci-1), compTitles{ci}), ...
        'FontSize',16,'FontName','Arial','FontWeight','bold');
    legend('Location','northeast','FontSize',13,'FontName','Arial','Box','off');
    grid on;

    % Horizontal baseline untuk unitless metrics (F1, rate)
    yline(0,'k-','LineWidth',0.5);
end

caption = ['Fig. 5. Comprehensive performance comparison between Full3C and Z-only ' ...
    'experiments for (a) P-wave and (b) S-wave phase picking. Metrics include ' ...
    'conventional F1-scores at 50, 100, and 200 ms tolerance, Precision, Recall, ' ...
    'Detection Rate, Mean Absolute Error (MAE), Median Absolute Error (MedAE), ' ...
    '95th-percentile absolute error (P95), and outlier rate (picks with |error|>1000 ms). ' ...
    'F1/Precision/Recall/Detection Rate are taken from the audited conventional-F1 summary; ' ...
    'error-based metrics are normalised by a fixed factor for display on a common axis.'];

ensureDir(outDir);
exportFigure300dpi(fig, outDir, 'Fig05_PerformanceComparison');
close(fig);
end

%        Build metric list from available tables
function metrics = buildMetricList(f1Conv, comp, pF, pZ)
metrics = struct('label',{},'full',{},'zonly',{},'fmt',{});

    function addMetric(lab,vF,vZ,fmt)
        metrics(end+1) = struct('label',lab,'full',vF,'zonly',vZ,'fmt',fmt); %#ok<AGROW>
    end

r50F  = getF1Row(f1Conv,'Full3C',comp,50);
r100F = getF1Row(f1Conv,'Full3C',comp,100);
r200F = getF1Row(f1Conv,'Full3C',comp,200);
r50Z  = getF1Row(f1Conv,'Zonly', comp,50);
r100Z = getF1Row(f1Conv,'Zonly', comp,100);
r200Z = getF1Row(f1Conv,'Zonly', comp,200);

if ~isempty(r100F) && ~isempty(r100Z)
    addMetric('F1@50ms',   gv(r50F,'F1'),  gv(r50Z,'F1'),  '%.3f');
    addMetric('F1@100ms',  gv(r100F,'F1'), gv(r100Z,'F1'), '%.3f');
    addMetric('F1@200ms',  gv(r200F,'F1'), gv(r200Z,'F1'), '%.3f');
    addMetric('Precision', gv(r100F,'Precision'), gv(r100Z,'Precision'),'%.3f');
    addMetric('Recall',    gv(r100F,'Recall'),    gv(r100Z,'Recall'),   '%.3f');
    addMetric('DetRate',   gv(r100F,'N_detected')/gv(r100F,'N_total'), ...
                            gv(r100Z,'N_detected')/gv(r100Z,'N_total'), '%.3f');
end

% Error metrics normalised to [0,1] range for display     show raw in label
if ~isempty(pF) && ~isempty(pZ)
    addMetric('MedAE/100',  gv(pF,'MedAE_ms')/100,   gv(pZ,'MedAE_ms')/100,  '%.2f');
    addMetric('MAE/100',    gv(pF,'MAE_ms')/100,      gv(pZ,'MAE_ms')/100,    '%.2f');
    addMetric('P95/1000',   gv(pF,'P95_ms')/1000,     gv(pZ,'P95_ms')/1000,   '%.3f');
    addMetric('Outl>1s',    gv(pF,'OutlierRate_1000ms'), gv(pZ,'OutlierRate_1000ms'),'%.3f');
elseif ~isempty(r100F) && ~isempty(r100Z)
    addMetric('MAE/100',    gv(r100F,'MAE_detected_ms')/100, gv(r100Z,'MAE_detected_ms')/100, '%.2f');
end
end

function r = getF1Row(t, expName, comp, tolMs)
r = table();
if isempty(t) || ~istable(t); return; end
need = {'Experiment','Phase','Tolerance_ms'};
if ~all(ismember(need, t.Properties.VariableNames)); return; end
mask = strcmpi(t.Experiment, expName) & strcmpi(t.Phase, comp) & (t.Tolerance_ms == tolMs);
if any(mask); r = t(mask,:); end
end

function v = gv(t, col)
v = NaN;
if isempty(t) || ~istable(t); return; end
idx = strcmpi(t.Properties.VariableNames, col);
if any(idx); v = t.(t.Properties.VariableNames{find(idx,1)}); end
end

function r = getRow(t, comp)
r = table();
if isempty(t) || ~istable(t); return; end
if any(strcmpi(t.Properties.VariableNames,'Component'))
    mask = strcmp(t.Component, comp);
    if any(mask); r = t(mask,:); end
end
end

function pos = panelPos(ci, nPanels)
margin = 0.08; gap = 0.06;
w = (1 - 2*margin - (nPanels-1)*gap) / nPanels;
x = margin + (ci-1)*(w + gap);
pos = [x, 0.14, w, 0.78];
end

function ensureDir(d); if ~isempty(d)&&~isfolder(d); mkdir(d); end; end
