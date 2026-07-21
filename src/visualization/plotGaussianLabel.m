% =========================================================================
% plotGaussianLabel.m     Fig 03
% =========================================================================
% PURPOSE:
%   Visualisasi Gaussian probability label dengan nama legenda yang benar,
%   annotation formula, dan waveform Z overlay.
% =========================================================================

function caption = plotGaussianLabel(record, config, outDir)

C = vizColors();
sec    = record.sec;
wf     = record.waveform;    % [T x 3] E N Z
label  = record.label;       % [T x 3] P S Noise
pSec   = record.p_arrival_sec;
sSec   = record.s_arrival_sec;
sigP   = config.gaussianSigmaP / config.samplingRate;  % sec
sigS   = config.gaussianSigmaS / config.samplingRate;

fig = figure('Visible','off','Color','white','Units','centimeters','Position',[2 2 18 13]);

%        Panel 1: Waveform Z                                                                                                                                                          
ax1 = axes('Position',[0.10 0.62 0.86 0.31]);
plot(sec, wf(:,3), 'Color',[0.35 0.35 0.35], 'LineWidth', 1.0);
hold on;
xline(pSec, '-', 'Color',C.Pwave, 'LineWidth', 2.5, ...
    'Label','True P Arrival', 'LabelHorizontalAlignment','right','FontSize',11);
xline(sSec, '-', 'Color',C.Swave, 'LineWidth', 2.5, ...
    'Label','True S Arrival', 'LabelHorizontalAlignment','right','FontSize',11);
ylabel('Amplitude (norm.)','FontSize',16,'FontName','Arial');
title('(a) Vertical Component (Z)','FontSize',16,'FontName','Arial','FontWeight','bold');
set(ax1,'FontSize',14,'FontName','Arial','Box','off','XTickLabel',{});
xlim([0 max(sec)]); grid on;

%        Panel 2: Gaussian probability labels                                                                                                       
ax2 = axes('Position',[0.10 0.10 0.86 0.44]);
hold on;

% Noise mask sebagai area
fill([sec; flipud(sec)], [label(:,3); zeros(numel(sec),1)], ...
    [0.80 0.80 0.80], 'EdgeColor','none', 'FaceAlpha',0.55, ...
    'DisplayName','Noise Mask');

% P dan S Gaussian
plot(sec, label(:,1), '-', 'Color',C.Pwave,  'LineWidth',2.5, 'DisplayName','P Gaussian');
plot(sec, label(:,2), '-', 'Color',C.Swave,   'LineWidth',2.5, 'DisplayName','S Gaussian');

% True arrival lines
xline(pSec, '--', 'Color',C.Pwave, 'LineWidth',1.8, 'Alpha',0.7, 'DisplayName','True P Arrival');
xline(sSec, '--', 'Color',C.Swave, 'LineWidth',1.8, 'Alpha',0.7, 'DisplayName','True S Arrival');

% Formula annotation
formulaStr = sprintf('g_P(t) = exp(-(t-\\mu_P)^2/2\\sigma_P^2),  \\sigma_P=%.0f ms', sigP*1000);
text(0.02, 0.96, formulaStr, 'Units','normalized', 'FontSize',11, 'FontName','Arial', ...
    'VerticalAlignment','top', 'Color',C.Pwave);
formulaStr2 = sprintf('g_S(t) = exp(-(t-\\mu_S)^2/2\\sigma_S^2),  \\sigma_S=%.0f ms', sigS*1000);
text(0.02, 0.84, formulaStr2, 'Units','normalized', 'FontSize',11, 'FontName','Arial', ...
    'VerticalAlignment','top', 'Color',C.Swave);

ylim([-0.05 1.20]);
xlabel('Time (s)','FontSize',16,'FontName','Arial');
ylabel('Probability','FontSize',16,'FontName','Arial');
title('(b) Gaussian Probability Labels','FontSize',16,'FontName','Arial','FontWeight','bold');
legend('Location','east','FontSize',13,'FontName','Arial','Box','off');
set(ax2,'FontSize',14,'FontName','Arial','Box','off');
xlim([0 max(sec)]); grid on;

caption = ['Fig. 3. Gaussian probability label formulation. ' ...
    '(a) Vertical (Z) seismic component with true P- and S-wave arrival markers. ' ...
    '(b) Gaussian probability masks used as training targets for the I-CNN meta-learner. ' ...
    'The P-wave mask (blue) and S-wave mask (red) are centred on their respective ' ...
    'true arrival times with standard deviations σ_P and σ_S (in samples). ' ...
    'The noise/background mask (grey) occupies the complement of the phase windows.'];

ensureDir(outDir);
exportFigure300dpi(fig, outDir, 'Fig03_GaussianLabel');
close(fig);
end

function ensureDir(d); if ~isempty(d)&&~isfolder(d); mkdir(d); end; end
