function plotAblationResults(metricsTable, outputPath)
if isempty(metricsTable); fprintf('  plotAblationResults: empty table, skipping.\n'); return; end

conditions = unique(metricsTable.Condition, 'stable');
nCond = numel(conditions);
f1P = zeros(nCond,1); f1S = zeros(nCond,1);
maeP = zeros(nCond,1); maeS = zeros(nCond,1);

for c = 1:nCond
    mask = strcmp(metricsTable.Condition, conditions{c});
    rP = metricsTable(mask & strcmp(metricsTable.Component,'P'), :);
    rS = metricsTable(mask & strcmp(metricsTable.Component,'S'), :);
    if ~isempty(rP); f1P(c)=rP.F1_100ms(1); maeP(c)=rP.MAE_ms(1); end
    if ~isempty(rS); f1S(c)=rS.F1_100ms(1); maeS(c)=rS.MAE_ms(1); end
end

fig = figure('Visible','off','Position',[50 50 1200 500],'Color','white');

subplot(1,2,1);
b = bar([f1P, f1S]);
b(1).FaceColor=[0.18 0.46 0.71]; b(2).FaceColor=[0.75 0.15 0.15];
set(gca,'XTick',1:nCond,'XTickLabel',conditions,'XTickLabelRotation',30, ...
    'FontSize',9,'TickLabelInterpreter','none');
ylabel('F1-score @ 100 ms'); ylim([0 1]);
legend({'P-wave','S-wave'},'Location','southwest');
title('F1-score by Condition','FontWeight','bold'); grid on; box off;

subplot(1,2,2);
b2 = bar([maeP, maeS]);
b2(1).FaceColor=[0.18 0.46 0.71]; b2(2).FaceColor=[0.75 0.15 0.15];
set(gca,'XTick',1:nCond,'XTickLabel',conditions,'XTickLabelRotation',30, ...
    'FontSize',9,'TickLabelInterpreter','none');
ylabel('MAE (ms)');
legend({'P-wave','S-wave'},'Location','northwest');
title('MAE by Condition','FontWeight','bold'); grid on; box off;

sgtitle('Ablation Study Results','FontSize',12,'FontWeight','bold');
ensureDir(fileparts(outputPath));
exportgraphics(fig, outputPath, 'Resolution', 200);
close(fig);
end

% =========================================================================
% plotSNRPerformance.m  (src/visualization/)
% =========================================================================

function ensureDir(d)
if ~isempty(d) && ~isfolder(d); mkdir(d); end
end
