% =========================================================================
% plotGaussianLabelExample.m  (src/visualization/)
% =========================================================================
% PURPOSE:
%   Fig 4 — Gaussian label visualization: waveform Z + P/S/Noise mask.
%   Menampilkan intuisi labeling probabilistik yang digunakan framework.
%
% INPUT:
%   record     - struct, satu elemen data (waveform, sec, label, picks)
%   outputPath - char
% =========================================================================

function plotGaussianLabelExample(record, outputPath)

sec    = record.sec;
wf     = record.waveform;   % [T x 3]
label  = record.label;      % [T x 3]: P, S, Noise
pSec   = record.p_arrival_sec;
sSec   = record.s_arrival_sec;

zIdx = 3;   % Z channel

fig = figure('Visible','off','Color','white', ...
    'Units','centimeters','Position',[2 2 18 12]);

% ── Panel 1: Waveform Z ───────────────────────────────────────────────────
ax1 = axes('Position',[0.10 0.62 0.85 0.30]);
plot(sec, wf(:,zIdx), 'Color',[0.3 0.3 0.3], 'LineWidth', 0.7);
hold on;
xline(pSec, '-', 'Color',[0.122 0.467 0.706], 'LineWidth', 2.0, ...
    'Label','P_{true}', 'LabelHorizontalAlignment','right', 'FontSize',9);
xline(sSec, '-', 'Color',[0.839 0.153 0.157], 'LineWidth', 2.0, ...
    'Label','S_{true}', 'LabelHorizontalAlignment','right', 'FontSize',9);
ylabel('Amplitude (norm.)', 'FontSize',10,'FontName','Arial');
title('(a) Vertical Component (Z)', 'FontSize',10,'FontName','Arial', ...
    'FontWeight','normal');
set(ax1,'FontSize',9,'FontName','Arial','Box','off', ...
    'XTickLabel',{},'TickDir','out','LineWidth',0.8);
xlim([0 60]); grid on; ax1.GridAlpha = 0.15;

% ── Panel 2: Gaussian masks ────────────────────────────────────────────────
ax2 = axes('Position',[0.10 0.15 0.85 0.40]);
hold on;

% Noise mask sebagai area shading
fill([sec; flipud(sec)], [label(:,3); zeros(size(label,1),1)], ...
    [0.85 0.85 0.85], 'EdgeColor','none', 'FaceAlpha', 0.6, ...
    'DisplayName','Noise/Background');

% P dan S mask sebagai kurva tebal
plot(sec, label(:,1), '-', 'Color',[0.122 0.467 0.706], ...
    'LineWidth', 2.5, 'DisplayName', 'P mask');
plot(sec, label(:,2), '-', 'Color',[0.839 0.153 0.157], ...
    'LineWidth', 2.5, 'DisplayName', 'S mask');

% Vertikal lines
xline(pSec, '--', 'Color',[0.122 0.467 0.706], 'LineWidth', 1.5, 'Alpha', 0.6);
xline(sSec, '--', 'Color',[0.839 0.153 0.157], 'LineWidth', 1.5, 'Alpha', 0.6);

% Annotation sigma
sigP_sec = 6/100;   % sigmaP = 6 samples / 100 Hz
sigS_sec = 8/100;
annotation('doublearrow', ...
    [0.10 + (pSec-sigP_sec)/60*0.85, 0.10 + (pSec+sigP_sec)/60*0.85], ...
    [0.37 0.37], 'Color',[0.122 0.467 0.706], 'LineWidth',1.5);
text(pSec, 0.55, sprintf('2\\sigma_P=%dms', round(2*sigP_sec*1000)), ...
    'FontSize',8,'FontName','Arial','Color',[0.122 0.467 0.706], ...
    'HorizontalAlignment','center');

ylim([-0.05 1.15]);
xlabel('Time (s)', 'FontSize',10,'FontName','Arial');
ylabel('Probability', 'FontSize',10,'FontName','Arial');
title('(b) Gaussian Probability Labels', 'FontSize',10,'FontName','Arial', ...
    'FontWeight','normal');
legend('Location','northeast','FontSize',9,'FontName','Arial','Box','off');
set(ax2,'FontSize',9,'FontName','Arial','Box','off','TickDir','out','LineWidth',0.8);
xlim([0 60]); grid on; ax2.GridAlpha = 0.15;

ensureDir(fileparts(outputPath));
exportgraphics(fig, outputPath, 'Resolution', 300, 'BackgroundColor','white');
close(fig);
fprintf('  Saved: %s\n', outputPath);
end

function ensureDir(d)
if ~isempty(d) && ~isfolder(d); mkdir(d); end
end
