% =========================================================================
% plotPickingResult.m  (src/visualization/)
% =========================================================================
% PURPOSE:
%   Fig 3 — Waveform + probability curves + pick annotations.
%   Kualitas publikasi C&G: 300 DPI, font Arial, layout 4-panel.
% =========================================================================

function plotPickingResult(waveform, sec, Ytrue, Ypred, picks, outputPath)

fig = figure('Visible','off','Color','white', ...
    'Units','centimeters','Position',[2 2 18 16]);

CP  = [0.122 0.467 0.706];   % biru (P)
CS  = [0.839 0.153 0.157];   % merah (S)
CWF = [0.3 0.3 0.3];          % abu waveform
compNames  = {'(a) East (E)', '(b) North (N)', '(c) Vertical (Z)'};
compColors = {[0.6 0.3 0.1], [0.2 0.5 0.2], CWF};
positions  = {[0.10 0.76 0.86 0.20], [0.10 0.53 0.86 0.20], ...
              [0.10 0.30 0.86 0.20], [0.10 0.05 0.86 0.22]};

for c = 1:3
    ax = axes('Position', positions{c}); %#ok
    plot(sec, waveform(:,c), 'Color', compColors{c}, 'LineWidth', 0.7);
    hold on;

    % True arrivals
    if ~isnan(picks.p_error_ms)
        pTrue = picks.p_pick_sec - picks.p_error_ms/1000;
        xline(pTrue,'--','Color',CP,'LineWidth',1.5,'Alpha',0.7);
    end
    if ~isnan(picks.s_error_ms)
        sTrue = picks.s_pick_sec - picks.s_error_ms/1000;
        xline(sTrue,'--','Color',CS,'LineWidth',1.5,'Alpha',0.7);
    end

    % Predicted arrivals
    if ~isnan(picks.p_pick_sec)
        xline(picks.p_pick_sec,'-','Color',CP,'LineWidth',2.0);
    end
    if ~isnan(picks.s_pick_sec)
        xline(picks.s_pick_sec,'-','Color',CS,'LineWidth',2.0);
    end

    ylabel('Ampl. (norm.)','FontSize',8,'FontName','Arial');
    title(compNames{c},'FontSize',9,'FontName','Arial','FontWeight','normal');
    set(ax,'FontSize',8,'FontName','Arial','Box','off','TickDir','out', ...
        'XTickLabel',{},'LineWidth',0.7); grid on; ax.GridAlpha=0.15;
    xlim([0 60]);
end

% Panel 4: Probability curves
ax4 = axes('Position', positions{4});
hold on;

if ~isempty(Ytrue)
    plot(sec, Ytrue(:,1),'--','Color',CP,'LineWidth',1.0,'DisplayName','P label');
    plot(sec, Ytrue(:,2),'--','Color',CS,'LineWidth',1.0,'DisplayName','S label');
end
if ~isempty(Ypred)
    plot(sec, Ypred.P,     '-','Color',CP,'LineWidth',2.0,'DisplayName','P (I-CNN)');
    plot(sec, Ypred.S,     '-','Color',CS,'LineWidth',2.0,'DisplayName','S (I-CNN)');
    fill([sec; flipud(sec)],[Ypred.Noise; zeros(size(sec))], ...
        [0.7 0.7 0.7],'EdgeColor','none','FaceAlpha',0.4,'DisplayName','Noise');
end

% Picks + error annotations
if ~isnan(picks.p_pick_sec)
    xline(picks.p_pick_sec,'-','Color',CP,'LineWidth',2.0);
    if ~isnan(picks.p_error_ms)
        text(picks.p_pick_sec, 1.05, sprintf('\\DeltaP=%.0fms',picks.p_error_ms), ...
            'FontSize',8,'Color',CP,'HorizontalAlignment','center','FontName','Arial');
    end
end
if ~isnan(picks.s_pick_sec)
    xline(picks.s_pick_sec,'-','Color',CS,'LineWidth',2.0);
    if ~isnan(picks.s_error_ms)
        text(picks.s_pick_sec, 1.05, sprintf('\\DeltaS=%.0fms',picks.s_error_ms), ...
            'FontSize',8,'Color',CS,'HorizontalAlignment','center','FontName','Arial');
    end
end

ylim([-0.05 1.15]);
xlabel('Time (s)','FontSize',9,'FontName','Arial');
ylabel('Probability','FontSize',9,'FontName','Arial');
title('(d) I-CNN Meta-Learner Output','FontSize',9,'FontName','Arial','FontWeight','normal');
legend('Location','northeast','FontSize',8,'FontName','Arial','Box','off', ...
    'NumColumns',2);
set(ax4,'FontSize',8,'FontName','Arial','Box','off','TickDir','out','LineWidth',0.7);
grid on; ax4.GridAlpha=0.15; xlim([0 60]);

% Quality scores
qStr = sprintf('Q_P=%.2f | Q_S=%.2f | P: %s | S: %s', ...
    picks.p_quality, picks.s_quality, picks.p_status, picks.s_status);
annotation('textbox',[0.10 0.0 0.86 0.04],'String',qStr, ...
    'FontSize',8,'FontName','Arial','EdgeColor','none', ...
    'HorizontalAlignment','center','Color',[0.4 0.4 0.4]);

ensureDir(fileparts(outputPath));
exportgraphics(fig, outputPath,'Resolution',300,'BackgroundColor','white');
close(fig);
end

function ensureDir(d)
if ~isempty(d) && ~isfolder(d); mkdir(d); end
end
