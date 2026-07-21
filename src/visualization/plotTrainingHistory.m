% =========================================================================
% plotTrainingHistory.m     Fig Training
% =========================================================================
% PURPOSE:
%   Plot training curves dari deep.TrainingInfo R2024a.
%   Hanya dijalankan jika trainInfo tersedia dan mengandung data.
%   Tidak membuat figure kosong atau placeholder.
%
% R2024A COMPATIBILITY:
%   Di R2024a, deep.TrainingInfo menyimpan semua history di property
%   .TrainingHistory (MATLAB table) dengan kolom:
%     Epoch, Iteration, TimeElapsed, Loss, ValidationLoss, LearnRate, ...
%   BUKAN sebagai field .TrainingLoss atau .ValidationLoss secara langsung.
% =========================================================================

function caption = plotTrainingHistory(trainInfoOrPath, outDir)

caption = '';

%        Load trainInfo dari file jika path diberikan                                                                            
if ischar(trainInfoOrPath) || isstring(trainInfoOrPath)
    p = char(trainInfoOrPath);
    if ~isfile(p)
        fprintf('  [TrainingHistory] File not found: %s. Skipping.\n', p);
        return;
    end
    S = load(p);
    flds = fieldnames(S);
    % Cari di dalam struct model jika disimpan sebagai icnnModel.trainHistory
    trainInfo = [];
    for k = 1:numel(flds)
        candidate = S.(flds{k});
        if isstruct(candidate) && isfield(candidate,'trainHistory')
            trainInfo = candidate.trainHistory; break;
        elseif isstruct(candidate) && isfield(candidate,'TrainingHistory')
            trainInfo = candidate; break;
        elseif isobject(candidate)
            trainInfo = candidate; break;
        end
    end
    if isempty(trainInfo)
        fprintf('  [TrainingHistory] No trainInfo found in %s. Skipping.\n', p);
        return;
    end
else
    trainInfo = trainInfoOrPath;
end

%        Ekstrak history dari semua format                                                                                                             
[tLoss, vLoss, epochs, vEpochs, lrVec, lrEpochs] = extractHistory(trainInfo);

if isempty(tLoss) && isempty(vLoss)
    fprintf('  [TrainingHistory] No loss data available. Skipping figure.\n');
    return;
end

C = vizColors();
col = C.purple;

%        Determine layout                                                                                                                                                                
hasLR = ~isempty(lrVec) && ~all(isnan(lrVec));
nPanels = 2 + hasLR;
fig = figure('Visible','off','Color','white','Units','centimeters', ...
    'Position',[2 2 18 4*nPanels+2]);

%        Panel 1: Train + Validation Loss                                                                                                             
ax1 = subplot(nPanels,1,1);
hold on;
if ~isempty(tLoss) && ~isempty(epochs)
    tSmooth = smoothdata(tLoss,'movmean',max(1,round(numel(tLoss)/20)));
    plot(epochs, tSmooth, '-', 'Color',col, 'LineWidth',2.0,'DisplayName','Train loss (smoothed)');
    plot(epochs, tLoss,   '-', 'Color',[col, 0.3], 'LineWidth',0.8,'DisplayName','Train loss (raw)');
end
if ~isempty(vLoss) && ~isempty(vEpochs)
    plot(vEpochs, vLoss, 'o-','Color',col*0.6,'LineWidth',2.0, ...
        'MarkerSize',5,'MarkerFaceColor',col*0.6,'DisplayName','Validation loss');
    [~,bi]=min(vLoss);
    xline(vEpochs(bi),'--','Color',[0.5 0.5 0.5],'LineWidth',1.0, ...
        'Label',sprintf('Best ep%d (%.4f)',round(vEpochs(bi)),vLoss(bi)), ...
        'FontSize',9,'LabelVerticalAlignment','top');
end
xlabel('Epoch','FontSize',14,'FontName','Arial');
ylabel('Loss','FontSize',14,'FontName','Arial');
title('(a) I-CNN Meta-Learner: Training & Validation Loss', ...
    'FontSize',14,'FontName','Arial','FontWeight','bold');
legend('Location','northeast','FontSize',12,'FontName','Arial','Box','off');
set(ax1,'FontSize',13,'FontName','Arial','Box','off','TickDir','out'); grid on;

%        Panel 2: Validation Loss only (zoomed)                                                                                           
ax2 = subplot(nPanels,1,2);
if ~isempty(vLoss) && ~isempty(vEpochs)
    plot(vEpochs, vLoss,'o-','Color',col*0.6,'LineWidth',2.0, ...
        'MarkerSize',5,'MarkerFaceColor',col*0.6);
    [~,bi]=min(vLoss);
    xline(vEpochs(bi),'--','Color',[0.6 0.6 0.6],'LineWidth',1.0);
    text(vEpochs(bi)+0.5, vLoss(bi), sprintf('Best: %.4f',vLoss(bi)), ...
        'FontSize',10,'FontName','Arial','Color',col*0.6);
else
    text(0.5,0.5,'No validation loss data','Units','normalized', ...
        'HorizontalAlignment','center','FontSize',12,'Color',[0.6 0.6 0.6]);
end
xlabel('Epoch','FontSize',14,'FontName','Arial');
ylabel('Validation Loss','FontSize',14,'FontName','Arial');
title('(b) Validation Loss (per validation step)', ...
    'FontSize',14,'FontName','Arial','FontWeight','bold');
set(ax2,'FontSize',13,'FontName','Arial','Box','off','TickDir','out'); grid on;

%        Panel 3: Learning Rate                                                                                                                                              
if hasLR
    ax3 = subplot(nPanels,1,3);
    plot(lrEpochs, lrVec, '-', 'Color',C.orange,'LineWidth',2.0);
    xlabel('Epoch','FontSize',14,'FontName','Arial');
    ylabel('Learning Rate','FontSize',14,'FontName','Arial');
    title('(c) Learning Rate Schedule','FontSize',14,'FontName','Arial','FontWeight','bold');
    set(ax3,'FontSize',13,'FontName','Arial','Box','off','YScale','log'); grid on;
end

annotation('textbox',[0.01 0.0 0.98 0.04], ...
    'String','Note: CNN and TCN base picker training history is not saved per fold. I-CNN meta-learner only.', ...
    'FontSize',9,'FontName','Arial','EdgeColor','none', ...
    'HorizontalAlignment','center','Color',[0.5 0.5 0.5]);

caption = ['Fig. S1. Training history of the I-CNN meta-learner. ' ...
    '(a) Training loss (smoothed and raw) and validation loss per epoch. ' ...
    '(b) Validation loss detail per validation step; the dashed line indicates the ' ...
    'epoch at which the best validation loss was achieved (early stopping criterion). ' ...
    'Note: training histories for the level-1 base pickers (CNN and TCN) are not ' ...
    'retained between OOF folds and are therefore not shown.'];

ensureDir(outDir);
exportFigure300dpi(fig, outDir, 'FigS1_TrainingHistory');
close(fig);
end

% =========================================================================
% extractHistory     R2024a-aware extraction dari deep.TrainingInfo atau struct
% =========================================================================
function [tLoss, vLoss, epochs, vEpochs, lrVec, lrEpochs] = extractHistory(ti)
tLoss=[]; vLoss=[]; epochs=[]; vEpochs=[]; lrVec=[]; lrEpochs=[];
if isempty(ti); return; end

% Coba .TrainingHistory table (format UTAMA di R2024a)
tbl = [];
if isobject(ti)
    try; tbl = ti.TrainingHistory; catch; end
    if isempty(tbl)
        try
            props = properties(ti);
            for k=1:numel(props)
                v=ti.(props{k}); if istable(v); tbl=v; break; end
            end
        catch; end
    end
elseif isstruct(ti)
    if isfield(ti,'TrainingHistory') && istable(ti.TrainingHistory)
        tbl = ti.TrainingHistory;
    end
end

if ~isempty(tbl) && istable(tbl)
    % Ekstrak dari table
    tcols = lower(tbl.Properties.VariableNames);
    getT  = @(names) extractTableCol(tbl, tcols, names);

    rawLoss = getT({'loss','trainingloss','train_loss'});
    rawVL   = getT({'validationloss','val_loss','valloss'});
    rawEp   = getT({'epoch','trainingepoch'});
    rawLR   = getT({'learnrate','learningrate','lr'});

    % Training loss: hapus NaN, mapping ke epoch
    if ~isempty(rawLoss) && ~isempty(rawEp)
        validT = isfinite(rawLoss);
        tLoss  = rawLoss(validT);
        epochs = rawEp(validT);
    elseif ~isempty(rawLoss)
        validT = isfinite(rawLoss);
        tLoss  = rawLoss(validT);
        epochs = (1:sum(validT))';
    end

    % Validation loss: hanya baris di mana validasi dilakukan (bukan NaN)
    if ~isempty(rawVL)
        validV = isfinite(rawVL);
        if any(validV)
            vLoss = rawVL(validV);
            if ~isempty(rawEp); vEpochs = rawEp(validV);
            else; vEpochs = linspace(1,max([max(epochs),1]),sum(validV))';
            end
        end
    end

    % Learning rate
    if ~isempty(rawLR)
        validLR = isfinite(rawLR);
        if any(validLR)
            lrVec    = rawLR(validLR);
            lrEpochs = ternary(~isempty(rawEp), rawEp(validLR), (1:sum(validLR))');
        end
    end
    return;
end

% Fallback: struct dengan field langsung
if isstruct(ti)
    tLoss  = cleanVec(getField(ti,{'TrainingLoss','TrainLoss','Loss','training_loss'}));
    vLoss  = cleanVec(getField(ti,{'ValidationLoss','ValLoss','val_loss'}));
    epochs = cleanVec(getField(ti,{'Epoch','TrainingEpoch','epochs'}));
    vEpochs= cleanVec(getField(ti,{'ValidationEpoch','ValEpoch'}));
    lrVec  = cleanVec(getField(ti,{'LearnRate','LearningRate','lr'}));
    if isempty(epochs) && ~isempty(tLoss); epochs=(1:numel(tLoss))'; end
    if isempty(vEpochs) && ~isempty(vLoss)
        vEpochs=linspace(1,max([max(epochs),1]),numel(vLoss))';
    end
    lrEpochs = epochs;
end
end

function v = extractTableCol(tbl, tcols, names)
v = [];
for k=1:numel(names)
    idx = strcmp(tcols, names{k});
    if any(idx); v = double(tbl.(tbl.Properties.VariableNames{find(idx,1)})); return; end
end
end

function v = getField(s, names)
v=[];
for k=1:numel(names); if isfield(s,names{k}); v=s.(names{k}); return; end; end
end

function v = cleanVec(v)
if isempty(v); return; end
v = double(v(:));
v(~isfinite(v)) = NaN;
end

function out=ternary(c,a,b);if c;out=a;else;out=b;end;end
function ensureDir(d);if ~isempty(d)&&~isfolder(d);mkdir(d);end;end
