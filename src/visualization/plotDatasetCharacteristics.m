% =========================================================================
% plotDatasetCharacteristics.m     Fig 02
% =========================================================================
% PURPOSE:
%   Dataset Characteristics: 4-panel histogram dengan KDE overlay, statistik
%   deskriptif lengkap, dan bin otomatis (Freedman-Diaconis rule).
% INPUTS:
%   data   - struct array dari loadDatasetFromMetadata
%   outDir - char, direktori output
% =========================================================================

function caption = plotDatasetCharacteristics(data, outDir)

C = vizColors();
fig = figure('Visible','off','Color','white','Units','centimeters','Position',[2 2 20 16]);

fields = {'source_magnitude','source_distance_km','SNR','sp_time_sec'};
xlabs  = {'Source Magnitude (M_L)','Source Distance (km)', ...
          'Signal-to-Noise Ratio (dB)','S-P Time (s)'};
ttls   = {'(a) Magnitude Distribution','(b) Source Distance', ...
          '(c) Signal-to-Noise Ratio','(d) S-P Time'};
cols   = {C.blue, C.orange, C.green, C.purple};
positions = {[0.07 0.57 0.40 0.36],[0.57 0.57 0.40 0.36], ...
             [0.07 0.09 0.40 0.36],[0.57 0.09 0.40 0.36]};

statsAll = struct();
for k = 1:4
    fld = fields{k};
    ax  = axes('Position', positions{k}); %#ok
    col = cols{k};

    % Kumpulkan data
    v = [];
    for i = 1:numel(data)
        if isfield(data,fld) && ~isnan(data(i).(fld))
            v(end+1) = data(i).(fld); %#ok
        end
    end
    if isempty(v)
        text(0.5,0.5,sprintf('No data: %s',fld),'Units','normalized', ...
            'HorizontalAlignment','center','FontSize',12);
        title(ttls{k},'FontSize',16,'FontName','Arial','FontWeight','bold');
        continue;
    end
    v = v(:);

    % Freedman-Diaconis bin width
    iqrV = iqr(v);
    if iqrV > 0
        binW = 2 * iqrV * numel(v)^(-1/3);
        nBins = max(10, ceil((max(v)-min(v))/binW));
    else
        nBins = min(40, round(sqrt(numel(v))*2));
    end
    nBins = min(nBins, 60);

    % Histogram
    h = histogram(v, nBins, 'FaceColor', col, 'EdgeColor','none', ...
        'FaceAlpha', 0.75, 'Normalization','count');
    hold on;

    % KDE overlay
    xKDE = linspace(min(v)-0.1*range(v), max(v)+0.1*range(v), 200);
    [f, xi] = ksdensity(v, xKDE);
    binArea = (max(v)-min(v)) / nBins * numel(v);
    yyaxis right;
    plot(xi, f, '-', 'Color', col*0.6, 'LineWidth', 2.0);
    ylabel('Density','FontSize',14,'FontName','Arial','Color',col*0.6);
    ax.YAxis(2).Color = col*0.6;
    yyaxis left;

    % Statistik vertikal
    mn  = mean(v); md = median(v); sd = std(v);
    sk  = skewness(v); cv = sd/abs(mn)*100;
    p5  = prctile(v,5); p95 = prctile(v,95);

    xline(mn, '--', 'Color',[0.2 0.2 0.2], 'LineWidth', 1.5, ...
        'Label',sprintf('\\mu=%.2f',mn), 'FontSize',10, ...
        'LabelVerticalAlignment','top');
    xline(md, ':', 'Color', col*0.7, 'LineWidth', 1.5, ...
        'Label',sprintf('Med=%.2f',md), 'FontSize',10, ...
        'LabelVerticalAlignment','bottom');

    % Stats box
    statsStr = sprintf(['N=%d\nMean=%.2f\nMedian=%.2f\nStd=%.2f\n' ...
        'Min=%.2f\nMax=%.2f\nCV=%.1f%%\nSkew=%.2f'], ...
        numel(v), mn, md, sd, min(v), max(v), cv, sk);
    text(0.97, 0.97, statsStr, 'Units','normalized', ...
        'HorizontalAlignment','right','VerticalAlignment','top', ...
        'FontSize',10,'FontName','Arial', ...
        'BackgroundColor','white','EdgeColor',[0.7 0.7 0.7],'Margin',4);

    xlabel(xlabs{k},'FontSize',16,'FontName','Arial');
    ylabel('Count','FontSize',14,'FontName','Arial');
    title(ttls{k},'FontSize',16,'FontName','Arial','FontWeight','bold');
    set(ax,'FontSize',14,'FontName','Arial','Box','off','TickDir','out');

    statsAll.(fld) = struct('N',numel(v),'mean',mn,'median',md,'std',sd, ...
        'min',min(v),'max',max(v),'cv',cv,'skewness',sk);
end

caption = sprintf(['Fig. 2. Characteristics of the curated STEAD-derived dataset ' ...
    '(N=%d records). (a) Earthquake magnitude distribution. (b) Hypocentral distance. ' ...
    '(c) Signal-to-noise ratio (SNR). (d) S-P time. ' ...
    'Dashed lines indicate the mean; dotted lines the median. ' ...
    'Kernel density estimates (KDE) are overlaid on each histogram. ' ...
    'Bin widths were determined using the Freedman-Diaconis rule.'], numel(data));

ensureDir(outDir);
exportFigure300dpi(fig, outDir, 'Fig02_DatasetCharacteristics');
close(fig);
end

function ensureDir(d); if ~isempty(d)&&~isfolder(d); mkdir(d); end; end
