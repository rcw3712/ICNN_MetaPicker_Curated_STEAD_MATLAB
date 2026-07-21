% =========================================================================
% plotResidualVsAttribute.m  (src/visualization/)
% =========================================================================
% PURPOSE:
%   Fig 12 — Residual (picking error) vs geophysical attributes:
%   source distance dan source magnitude. Penting untuk interpretasi
%   geofisika: apakah error picking bergantung pada jarak atau magnitude?
%
% INPUT:
%   picks      - struct array, output physicsAwarePicker.m
%   groundTruth- struct array, dengan .p_arrival_sec, .s_arrival_sec
%   data       - struct array, dengan .source_distance_km, .source_magnitude
%   outputPath - char
% =========================================================================

function plotResidualVsAttribute(picks, groundTruth, data, outputPath)

N = numel(picks);
errP  = nan(N,1); errS  = nan(N,1);
dists = nan(N,1); mags  = nan(N,1); snrs = nan(N,1);

for i = 1:N
    if ~isnan(picks(i).p_pick_sec) && ~isnan(groundTruth(i).p_arrival_sec)
        errP(i) = (picks(i).p_pick_sec - groundTruth(i).p_arrival_sec)*1000;
    end
    if ~isnan(picks(i).s_pick_sec) && ~isnan(groundTruth(i).s_arrival_sec)
        errS(i) = (picks(i).s_pick_sec - groundTruth(i).s_arrival_sec)*1000;
    end
    if isfield(data,'source_distance_km'); dists(i) = data(i).source_distance_km; end
    if isfield(data,'source_magnitude');   mags(i)  = data(i).source_magnitude;   end
    if isfield(data,'SNR');                snrs(i)  = data(i).SNR;                end
end

fig = figure('Visible','off','Color','white', ...
    'Units','centimeters','Position',[2 2 18 14]);

CP = [0.122 0.467 0.706];
CS = [0.839 0.153 0.157];

% Layout: 2 baris (P dan S) x 2 kolom (dist dan mag)
poss = {[0.08 0.57 0.40 0.36], [0.57 0.57 0.40 0.36], ...
        [0.08 0.10 0.40 0.36], [0.57 0.10 0.40 0.36]};
errs    = {errP,  errP,  errS,  errS};
attrs   = {dists, mags,  dists, mags};
xlabs   = {'Source Distance (km)', 'Source Magnitude (M_L)', ...
           'Source Distance (km)', 'Source Magnitude (M_L)'};
cols    = {CP, CP, CS, CS};
panTitles = {'(a) P-wave residual vs. distance', ...
             '(b) P-wave residual vs. magnitude', ...
             '(c) S-wave residual vs. distance', ...
             '(d) S-wave residual vs. magnitude'};

for k = 1:4
    ax  = axes('Position', poss{k}); %#ok
    err = errs{k};
    att = attrs{k};
    col = cols{k};

    valid = ~isnan(err) & ~isnan(att);
    ev = err(valid); av = att(valid);

    if numel(av) < 5
        text(0.5,0.5,'Insufficient data','Units','normalized', ...
            'HorizontalAlignment','center'); continue;
    end

    % Scatter dengan warna SNR jika tersedia
    sv = snrs(valid);
    if ~all(isnan(sv))
        sc = scatter(av, ev, 10, sv, 'filled', 'MarkerFaceAlpha', 0.4); %#ok
        cb = colorbar; cb.Label.String = 'SNR (dB)'; cb.Label.FontSize=8;
        colormap(ax, parula);
        clim([10 min(60,prctile(sv(~isnan(sv)),95))]);
    else
        scatter(av, ev, 10, col, 'filled', 'MarkerFaceAlpha', 0.4);
    end
    hold on;

    % Zero line dan tolerance lines
    yline(0, 'k-', 'LineWidth', 1.2);
    yline(100,  ':','Color',[0.5 0.5 0.5],'LineWidth',0.8);
    yline(-100, ':','Color',[0.5 0.5 0.5],'LineWidth',0.8);

    % Running median (binned)
    nBins = min(8, floor(numel(av)/5));
    if nBins >= 3
        edges = linspace(min(av), max(av), nBins+1);
        binCenters = (edges(1:end-1)+edges(2:end))/2;
        binMed = arrayfun(@(lo,hi) median(ev(av>=lo & av<hi)), ...
            edges(1:end-1), edges(2:end));
        plot(binCenters, binMed, 'o-', 'Color', col*0.7, ...
            'LineWidth', 2, 'MarkerSize', 6, 'MarkerFaceColor', col*0.7, ...
            'DisplayName','Bin median');
    end

    xlabel(xlabs{k},'FontSize',9,'FontName','Arial');
    ylabel('Residual (ms)','FontSize',9,'FontName','Arial');
    title(panTitles{k},'FontSize',9,'FontName','Arial','FontWeight','normal');

    % Stats
    statsStr = sprintf('MAE=%.1f ms\nRMSE=%.1f ms\nr=%.3f', ...
        mean(abs(ev)), sqrt(mean(ev.^2)), corr(av,ev));
    text(0.97,0.97,statsStr,'Units','normalized', ...
        'HorizontalAlignment','right','VerticalAlignment','top', ...
        'FontSize',8,'FontName','Arial', ...
        'BackgroundColor','white','EdgeColor',[0.7 0.7 0.7],'Margin',2);

    set(ax,'FontSize',8,'FontName','Arial','Box','off','TickDir','out', ...
        'LineWidth',0.8); grid on; ax.GridAlpha=0.15;
    ylim([-500 500]);
end

ensureDir(fileparts(outputPath));
exportgraphics(fig, outputPath,'Resolution',300,'BackgroundColor','white');
close(fig);
fprintf('  Saved: %s\n', outputPath);
end

function ensureDir(d)
if ~isempty(d) && ~isfolder(d); mkdir(d); end
end
