% =========================================================================
% plotTrainingCurves.m  (src/visualization/)
% =========================================================================
% PURPOSE:
%   Fig 11 — Training loss curves untuk CNN, TCN, dan I-CNN meta-learner.
%   Menampilkan train dan validation loss per epoch.
%
% INPUT:
%   trainInfoCNN  - struct dengan field TrainingLoss / ValidationLoss, atau struct()
%   trainInfoTCN  - idem untuk TCN (opsional, struct() jika tidak tersedia)
%   trainInfoICNN - struct untuk I-CNN meta-learner
%   outputPath    - char, path output PNG
% =========================================================================

function plotTrainingCurves(trainInfoCNN, trainInfoTCN, trainInfoICNN, outputPath)

fig = figure('Visible','off', 'Color','white', ...
    'Units','centimeters', 'Position',[2 2 18 10]);

models     = {'(a) Baseline CNN (base picker)', ...
              '(b) Dilated TCN (base picker)', ...
              '(c) I-CNN Meta-Learner (level-2)'};
trainInfos = {trainInfoCNN, trainInfoTCN, trainInfoICNN};
colors     = {[0.122 0.467 0.706], [0.173 0.627 0.173], [0.580 0.404 0.741]};
positions  = {[0.07 0.18 0.27 0.72], [0.38 0.18 0.27 0.72], [0.69 0.18 0.27 0.72]};

for k = 1:3
    ax  = axes('Position', positions{k}); %#ok
    ti  = trainInfos{k};
    col = colors{k};

    % Ekstrak loss dengan berbagai kemungkinan nama field
    tLoss = extractField(ti, {'TrainingLoss','TrainLoss','Loss','training_loss'});
    vLoss = extractField(ti, {'ValidationLoss','ValLoss','val_loss'});
    vEp   = extractField(ti, {'ValidationEpoch','ValEpoch','EpochIndex'});

    % Bersihkan nilai NaN/Inf
    if ~isempty(tLoss)
        tLoss = double(tLoss(:));
        tLoss(~isfinite(tLoss)) = NaN;
        tLoss = tLoss(~isnan(tLoss));
    end
    if ~isempty(vLoss)
        vLoss = double(vLoss(:));
        vLoss(~isfinite(vLoss)) = NaN;
        validV = ~isnan(vLoss);
        vLoss = vLoss(validV);
        if ~isempty(vEp)
            vEp = double(vEp(:));
            vEp = vEp(validV);
        end
    end

    if isempty(tLoss) && isempty(vLoss)
        % Tidak ada data — tampilkan pesan informatif
        text(0.5, 0.5, 'Training history not saved', ...
            'Units','normalized', 'HorizontalAlignment','center', ...
            'FontSize', 9, 'FontName','Arial', 'Color',[0.5 0.5 0.5]);
        set(ax, 'XColor','none', 'YColor','none');
    else
        hold on;
        nEp = numel(tLoss);
        ep  = (1:nEp)';

        if ~isempty(tLoss)
            % Smooth ringan untuk readability
            tSmooth = smoothdata(tLoss, 'movmean', max(1, round(nEp/15)));
            plot(ep, tSmooth, '-', 'Color', col, 'LineWidth', 1.8, ...
                'DisplayName','Train loss');
        end

        if ~isempty(vLoss)
            if ~isempty(vEp) && numel(vEp)==numel(vLoss)
                xV = vEp;
            else
                xV = linspace(1, max(nEp,1), numel(vLoss))';
            end
            plot(xV, vLoss, 'o-', 'Color', col*0.65, 'LineWidth', 1.6, ...
                'MarkerSize', 4, 'MarkerFaceColor', col*0.65, ...
                'DisplayName','Val loss');

            % Best epoch marker
            [~, bestIdx] = min(vLoss);
            bestEpoch    = xV(bestIdx);
            xline(bestEpoch, '--', 'Color',[0.6 0.6 0.6], 'LineWidth', 0.9, ...
                'Label', sprintf('ep%d', round(bestEpoch)), ...
                'FontSize', 7, 'LabelVerticalAlignment','top');
        end

        xlabel('Epoch','FontSize',9,'FontName','Arial');
        ylabel('Loss','FontSize',9,'FontName','Arial');
        legend('Location','northeast','FontSize',8,'FontName','Arial','Box','off');
        set(ax,'FontSize',8,'FontName','Arial','Box','off','TickDir','out','LineWidth',0.8);
        grid on; ax.GridAlpha = 0.2;
    end

    title(models{k}, 'FontSize',9,'FontName','Arial','FontWeight','normal');
end

annotation('textbox',[0.03 0.00 0.94 0.06], ...
    'String',['Note: CNN and TCN are level-1 base pickers. ' ...
              'I-CNN is the level-2 meta-learner consuming base picker outputs.'], ...
    'FontSize',8,'FontName','Arial','EdgeColor','none', ...
    'HorizontalAlignment','center','Color',[0.5 0.5 0.5]);

ensureDir(fileparts(outputPath));
exportgraphics(fig, outputPath, 'Resolution',300, 'BackgroundColor','white');
close(fig);
fprintf('  Saved: %s\n', outputPath);
end

% ── Helpers ───────────────────────────────────────────────────────────────
function v = extractField(s, names)
v = [];
if isempty(s) || (~isstruct(s) && ~isobject(s)); return; end
for i = 1:numel(names)
    try
        val = s.(names{i});
        if ~isempty(val)
            v = val; return;
        end
    catch; end
end
end

function ensureDir(d)
if ~isempty(d) && ~isfolder(d); mkdir(d); end
end
