% =========================================================================
% plotDatasetStatistics.m  (src/visualization/)
% =========================================================================
% PURPOSE:
%   Fig 2 — Dataset statistics: 4-panel histogram distribusi magnitude,
%   jarak, SNR, dan S-P time dari dataset curated STEAD.
%   Standar C&G: 300 DPI, font Arial 10pt, single/double column width.
%
% INPUT:
%   data       - struct array, output loadDatasetFromMetadata.m
%   outputPath - char, path output PNG/PDF
% =========================================================================

function plotDatasetStatistics(data, outputPath)

mags  = [data.source_magnitude];
dists = [data.source_distance_km];
snrs  = [data.SNR];

% Hitung S-P time dari data (detik)
sps = arrayfun(@(d) d.s_arrival_sec - d.p_arrival_sec, data);

% Hapus NaN
mags(isnan(mags))   = [];
dists(isnan(dists)) = [];
snrs(isnan(snrs))   = [];
sps(isnan(sps))     = [];

fig = figure('Visible','off', 'Color','white', ...
    'Units','centimeters', 'Position',[2 2 18 14]);

C1 = [0.122 0.467 0.706];  % biru C&G
C2 = [0.839 0.153 0.157];  % merah
C3 = [0.173 0.627 0.173];  % hijau
C4 = [0.580 0.404 0.741];  % ungu

subplots = {[0.07 0.58 0.40 0.35], [0.57 0.58 0.40 0.35], ...
            [0.07 0.10 0.40 0.35], [0.57 0.10 0.40 0.35]};
datas    = {mags, dists, snrs, sps};
xlabels  = {'Source Magnitude (M_L)', 'Source Distance (km)', ...
             'Signal-to-Noise Ratio (dB)', 'S–P Time (s)'};
colors   = {C1, C2, C3, C4};
subtitles = {'(a)', '(b)', '(c)', '(d)'};

for k = 1:4
    ax = axes('Position', subplots{k}); %#ok
    d  = datas{k};

    nBins = min(40, round(sqrt(numel(d))*2));
    histogram(d, nBins, 'FaceColor', colors{k}, 'EdgeColor', 'none', ...
        'FaceAlpha', 0.85);
    hold on;

    % Mean line
    xline(mean(d), '--k', 'LineWidth', 1.2, ...
        'Label', sprintf('\\mu=%.2f', mean(d)), ...
        'LabelVerticalAlignment','top', 'FontSize', 8);

    xlabel(xlabels{k}, 'FontSize', 10, 'FontName','Arial');
    ylabel('Count', 'FontSize', 10, 'FontName','Arial');

    % Stats box
    statsStr = sprintf('N=%d\nMean=%.2f\nStd=%.2f\nMin=%.2f\nMax=%.2f', ...
        numel(d), mean(d), std(d), min(d), max(d));
    text(0.97, 0.97, statsStr, 'Units','normalized', ...
        'HorizontalAlignment','right', 'VerticalAlignment','top', ...
        'FontSize', 7.5, 'FontName','Arial', ...
        'BackgroundColor','white', 'EdgeColor',[0.7 0.7 0.7], ...
        'Margin', 3);

    title(subtitles{k}, 'FontSize', 10, 'FontName','Arial', ...
        'FontWeight','normal', 'HorizontalAlignment','left');

    set(ax, 'FontSize', 9, 'FontName','Arial', 'Box','off', ...
        'TickDir','out', 'LineWidth', 0.8);
    grid on; ax.GridAlpha = 0.2;
end

% Super title
annotation('textbox', [0 0.97 1 0.03], ...
    'String', sprintf('Dataset Characteristics (N = %d records)', numel(data)), ...
    'HorizontalAlignment','center', 'VerticalAlignment','top', ...
    'FontSize', 11, 'FontName','Arial', 'FontWeight','bold', ...
    'EdgeColor','none');

ensureDir(fileparts(outputPath));
exportgraphics(fig, outputPath, 'Resolution', 300, 'BackgroundColor','white');
close(fig);
fprintf('  Saved: %s\n', outputPath);
end

function ensureDir(d)
if ~isempty(d) && ~isfolder(d); mkdir(d); end
end
