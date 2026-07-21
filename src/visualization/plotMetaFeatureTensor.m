% =========================================================================
% plotMetaFeatureTensor.m     Fig 04
% =========================================================================
% PURPOSE:
%   Visualisasi meta-feature tensor Z_meta [T x C_meta] dengan grouping
%   per base picker (STA/LTA, AIC, CNN, TCN) dan background berbeda.
%   Menggunakan data nyata dari buildMetaFeatureFromModels, bukan dummy.
% =========================================================================

function caption = plotMetaFeatureTensor(metaFeat, record, config, outDir)
% metaFeat: [T x C_meta] double (output buildMetaFeatureFromModels)
% record:   struct dengan .sec, .p_arrival_sec, .s_arrival_sec

C      = vizColors();
T      = size(metaFeat, 1);
C_meta = size(metaFeat, 2);
sec    = record.sec;
pSec   = record.p_arrival_sec;
sSec   = record.s_arrival_sec;

% Nama channel: tiap base picker menyumbang 3 channel (P,S,N)
% STA/LTA: 1-3, AIC: 4-6, CNN: 7-9, TCN: 10-12, (optional: extra)
basePickerNames = {'STA/LTA','AIC','Baseline CNN','Dilated TCN'};
nPickers  = min(4, floor(C_meta/3));
groupColors = {C.gray, C.amber, C.blue, C.purple};
chanPerPicker = 3;
chanNames  = {'P','S','Noise'};

fig = figure('Visible','off','Color','white','Units','centimeters', ...
    'Position',[2 2 20 max(9, nPickers*3.7 + 4)]);

totalRows = nPickers + 1;   % +1 untuk waveform Z di atas

%        Panel 0: Waveform Z                                                                                                                                                          
ax0 = subplot(totalRows, 1, 1);
wfZ = [];
if isfield(record,'waveform'); wfZ = record.waveform(:,3); end
if ~isempty(wfZ)
    plot(sec, wfZ, 'Color',[0.3 0.3 0.3], 'LineWidth',1.2);
    hold on;
    xline(pSec,'-','Color',C.Pwave,'LineWidth',2,'Label','P','FontSize',10);
    xline(sSec,'-','Color',C.Swave,'LineWidth',2,'Label','S','FontSize',10);
end
ylabel('Z (norm.)','FontSize',13,'FontName','Arial');
title('(a) Seismic Record (Z component)','FontSize',15,'FontName','Arial','FontWeight','bold');
set(ax0,'FontSize',12,'FontName','Arial','Box','off','XTickLabel',{});
xlim([0 max(sec)]); grid on;

%        Panels per base picker                                                                                                                                                 
for pk = 1:nPickers
    ax = subplot(totalRows, 1, pk+1);
    colBase = (pk-1)*chanPerPicker + 1;
    colEnd  = min(colBase + chanPerPicker - 1, C_meta);

    bgCol = groupColors{pk} * 0.1 + [0.92 0.92 0.92];
    set(ax,'Color', bgCol);
    hold on;

    lineStyles = {'-','--',':'};
    lineColors = {C.Pwave, C.Swave, C.gray};
    for ch = 1:(colEnd - colBase + 1)
        ci = colBase + ch - 1;
        plot(sec, metaFeat(:,ci), lineStyles{ch}, ...
            'Color', lineColors{ch}, 'LineWidth', 1.8, ...
            'DisplayName', sprintf('%s %s', basePickerNames{pk}, chanNames{ch}));
    end

    xline(pSec,'--','Color',C.Pwave,'LineWidth',1.2,'Alpha',0.6,'HandleVisibility','off');
    xline(sSec,'--','Color',C.Swave,'LineWidth',1.2,'Alpha',0.6,'HandleVisibility','off');

    ylabel(sprintf('%s\nProb.',basePickerNames{pk}),'FontSize',12,'FontName','Arial');
    ylim([-0.05 1.15]);

    if pk < nPickers
        set(ax,'XTickLabel',{});
    else
        xlabel('Time (s)','FontSize',14,'FontName','Arial');
    end
    set(ax,'FontSize',12,'FontName','Arial','Box','off');
    legend('Location','east','FontSize',11,'FontName','Arial','Box','off','NumColumns',1);

    % Bracket annotation di sisi kiri
    annotation('textbox', [0.01, (totalRows-pk-0.5)/totalRows, 0.05, 1/totalRows], ...
        'String', basePickerNames{pk}, 'FontSize', 9, 'FontName','Arial', ...
        'Rotation',90, 'HorizontalAlignment','center','VerticalAlignment','middle', ...
        'EdgeColor','none','Color',groupColors{pk},'FontWeight','bold');
    grid on;
end

sgtitle({sprintf('Meta-Feature Tensor Z_{meta} [T \\times %d]', C_meta), 'Base Picker Outputs'}, ...
    'FontSize',16,'FontName','Arial','FontWeight','bold');

caption = sprintf(['Fig. 4. Meta-feature tensor Z_{meta} input to the I-CNN meta-learner. ' ...
    'Each row group shows the three-channel probability output (P, S, Noise) from one ' ...
    'level-1 base picker: (b) STA/LTA, (c) AIC, (d) Baseline CNN, and (e) Dilated TCN. ' ...
    'The I-CNN meta-learner receives the full [T × %d] tensor as input. ' ...
    'Dashed vertical lines indicate true P- and S-wave arrivals.'], C_meta);

ensureDir(outDir);
exportFigure300dpi(fig, outDir, 'Fig04_MetaFeatureTensor');
close(fig);
end

function ensureDir(d); if ~isempty(d)&&~isfolder(d); mkdir(d); end; end
