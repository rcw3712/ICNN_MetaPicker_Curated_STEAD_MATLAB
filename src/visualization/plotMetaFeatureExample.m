function plotMetaFeatureExample(metaFeatureTensor, outputPath)
if isempty(metaFeatureTensor); fprintf('  plotMetaFeatureExample: empty tensor, skipping.\n'); return; end

C = size(metaFeatureTensor, 2);
T = size(metaFeatureTensor, 1);
t = (0:T-1)';

labels = {'P_{STA}','S_{STA}','N_{STA}','P_{AIC}','S_{AIC}','N_{AIC}', ...
          'P_{CNN}','S_{CNN}','N_{CNN}','P_{TCN}','S_{TCN}','N_{TCN}', ...
          'E_{ctx}','N_{ctx}','Z_{ctx}'};
nShow = min(C, numel(labels));

fig = figure('Visible','off','Position',[50 50 1100 800],'Color','white');
for c = 1:nShow
    subplot(nShow,1,c);
    plot(t, metaFeatureTensor(:,c), 'LineWidth',0.8, 'Color',[0.18+c/40, 0.3, 0.65]);
    ylabel(labels{c},'Rotation',0,'HorizontalAlignment','right','FontSize',7);
    set(gca,'XTickLabel',[],'YTick',[]); box off;
end
xlabel('Sample index');
sgtitle('Meta-Feature Tensor Example [T \times C_{meta}]','FontSize',11,'FontWeight','bold');

ensureDir(fileparts(outputPath));
exportgraphics(fig, outputPath, 'Resolution', 200);
close(fig);
end

% =========================================================================
% plotFull3CvsZonly.m  (src/visualization/)
% =========================================================================
% PURPOSE:
%   Side-by-side comparison of Full3C vs Z-only picking performance,
%   visualising the cost of losing horizontal-channel information — the
%   key figure supporting the PiGraf single-channel limitation discussion.
%
% INPUT:
%   metricsTable - table with 'Condition' column containing values like
%                  'Full3C' and 'Zonly' (or similar), plus 'Component',
%                  'F1_100ms', 'MAE_ms', 'DetectionRate'
%   outputPath   - char, path to save PNG figure
% =========================================================================


function ensureDir(d)
if ~isempty(d) && ~isfolder(d); mkdir(d); end
end
