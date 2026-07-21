function plotFull3CvsZonly(metricsTable, outputPath)
if isempty(metricsTable); fprintf('  plotFull3CvsZonly: empty table, skipping.\n'); return; end

condNames = unique(metricsTable.Condition, 'stable');
full3CName = condNames(contains(lower(condNames), 'full3c') | contains(lower(condNames),'full 3c'));
zonlyName  = condNames(contains(lower(condNames), 'zonly')  | contains(lower(condNames),'z-only'));

if isempty(full3CName) || isempty(zonlyName)
    fprintf('  plotFull3CvsZonly: could not identify Full3C/Zonly rows, skipping.\n');
    return;
end

rF3P = metricsTable(strcmp(metricsTable.Condition,full3CName{1}) & strcmp(metricsTable.Component,'P'),:);
rF3S = metricsTable(strcmp(metricsTable.Condition,full3CName{1}) & strcmp(metricsTable.Component,'S'),:);
rZoP = metricsTable(strcmp(metricsTable.Condition,zonlyName{1})  & strcmp(metricsTable.Component,'P'),:);
rZoS = metricsTable(strcmp(metricsTable.Condition,zonlyName{1})  & strcmp(metricsTable.Component,'S'),:);

f1Data  = [rF3P.F1_100ms(1), rZoP.F1_100ms(1); rF3S.F1_100ms(1), rZoS.F1_100ms(1)];
maeData = [rF3P.MAE_ms(1),   rZoP.MAE_ms(1);   rF3S.MAE_ms(1),   rZoS.MAE_ms(1)];
drData  = [rF3P.DetectionRate(1), rZoP.DetectionRate(1); rF3S.DetectionRate(1), rZoS.DetectionRate(1)];

fig = figure('Visible','off','Position',[50 50 1300 450],'Color','white');

subplot(1,3,1);
b = bar(f1Data);
b(1).FaceColor=[0.20 0.55 0.30]; b(2).FaceColor=[0.80 0.30 0.10];
set(gca,'XTickLabel',{'P-wave','S-wave'}); ylabel('F1-score @ 100 ms'); ylim([0 1]);
legend({'Full 3C','Z-only'},'Location','southwest');
title('F1-score','FontWeight','bold'); grid on; box off;

subplot(1,3,2);
b2 = bar(maeData);
b2(1).FaceColor=[0.20 0.55 0.30]; b2(2).FaceColor=[0.80 0.30 0.10];
set(gca,'XTickLabel',{'P-wave','S-wave'}); ylabel('MAE (ms)');
legend({'Full 3C','Z-only'},'Location','northwest');
title('Mean Absolute Error','FontWeight','bold'); grid on; box off;

subplot(1,3,3);
b3 = bar(drData);
b3(1).FaceColor=[0.20 0.55 0.30]; b3(2).FaceColor=[0.80 0.30 0.10];
set(gca,'XTickLabel',{'P-wave','S-wave'}); ylabel('Detection Rate'); ylim([0 1]);
legend({'Full 3C','Z-only'},'Location','southwest');
title('Detection Rate','FontWeight','bold'); grid on; box off;

sgtitle('Full 3C vs. Z-only Performance (PiGraf Limitation Simulation)', ...
    'FontSize',12,'FontWeight','bold');

ensureDir(fileparts(outputPath));
exportgraphics(fig, outputPath, 'Resolution', 200);
close(fig);
end

% ── Shared helper ──────────────────────────────────────────────────────────

function ensureDir(d)
if ~isempty(d) && ~isfolder(d); mkdir(d); end
end
