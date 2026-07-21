% =========================================================================
% analyzeOutliers.m
% =========================================================================
% PURPOSE:
%   Mengidentifikasi event/record dengan error picking terbesar dan
%   menyimpan tabel outlier teratas beserta figurenya.
%
% INPUTS:
%   predTable      - table dari predictions CSV (sudah di-join)
%   experimentName - char, 'Full3C' atau 'Zonly'
%   config         - struct framework
%
% OUTPUTS:
%   outSummary - struct dengan field .P dan .S masing-masing berisi table
%   Saved files:
%     top20_P_outliers_<exp>.csv
%     top20_S_outliers_<exp>.csv
%     outlier_summary_<exp>.csv
%     p_error_outliers_scatter_<exp>.png
%     s_error_outliers_scatter_<exp>.png
%     error_boxplot_full3C_vs_Zonly.png  (dibuat oleh compareFull3CvZ)
% =========================================================================

function outSummary = analyzeOutliers(predTable, experimentName, config)

outDir    = fullfile(config.outputDiagnosticsFolder, 'outliers');
figDir    = fullfile(config.outputDiagnosticsFolder, 'figures');
ensureDir(outDir); ensureDir(figDir);

N = height(predTable);
errP  = safeGetNum(predTable, 'p_error_ms');
errS  = safeGetNum(predTable, 's_error_ms');

ratesP = computeOutlierRates(errP);
ratesS = computeOutlierRates(errS);

%        Build top-20 outlier tables                                                                                                                                  
outSummary.P = buildOutlierTable(predTable, errP, experimentName, 'P', config);
outSummary.S = buildOutlierTable(predTable, errS, experimentName, 'S', config);

topN = min(20, height(outSummary.P));
if topN > 0
    writetable(outSummary.P(1:topN,:), ...
        fullfile(outDir, sprintf('top20_P_outliers_%s.csv', experimentName)));
end
topN = min(20, height(outSummary.S));
if topN > 0
    writetable(outSummary.S(1:topN,:), ...
        fullfile(outDir, sprintf('top20_S_outliers_%s.csv', experimentName)));
end

%        Outlier summary table                                                                                                                                                    
sumT = table( ...
    {experimentName;experimentName}, {'P';'S'}, ...
    [N;N], ...
    [ratesP.n_valid; ratesS.n_valid], ...
    [ratesP.n_outlier_500;  ratesS.n_outlier_500], ...
    [ratesP.n_outlier_1000; ratesS.n_outlier_1000], ...
    [ratesP.n_outlier_2000; ratesS.n_outlier_2000], ...
    [ratesP.rate_500;  ratesS.rate_500], ...
    [ratesP.rate_1000; ratesS.rate_1000], ...
    [ratesP.rate_2000; ratesS.rate_2000], ...
    [ratesP.n_iqr_outlier; ratesS.n_iqr_outlier], ...
    [ratesP.iqr_threshold;  ratesS.iqr_threshold], ...
    'VariableNames', {'Experiment','Component','N_total','N_detected', ...
    'N_outlier_500ms','N_outlier_1000ms','N_outlier_2000ms', ...
    'Rate_500ms','Rate_1000ms','Rate_2000ms', ...
    'N_IQR_outlier','IQR_threshold_ms'});

writetable(sumT, fullfile(outDir, sprintf('outlier_summary_%s.csv', experimentName)));
fprintf('  [Outliers] Saved summary for %s.\n', experimentName);

%        Scatter figures                                                                                                                                                                         
for comp = {'P','S'}
    c = comp{1};
    if strcmp(c,'P'); err = errP; else; err = errS; end
    makeOutlierScatter(predTable, err, c, experimentName, figDir, config);
end

outSummary.rates.P = ratesP;
outSummary.rates.S = ratesS;
end

%        Build sorted outlier table                                                                                                                                        
function T = buildOutlierTable(predTable, err, expName, comp, config)
absErr = abs(err);
[sorted, idx] = sort(absErr, 'descend', 'MissingPlacement','last');
isOutlier = ~isnan(sorted);
idx = idx(isOutlier);

if isempty(idx); T = table(); return; end

cols = predTable.Properties.VariableNames;
wantCols = {'file_name','event_id','source_id', ...
    'p_true_sec','p_pred_sec','p_error_ms', ...
    's_true_sec','s_pred_sec','s_error_ms', ...
    'p_status','s_status', 'p_quality','s_quality', ...
    'SNR','source_magnitude','source_distance_km','sp_time_sec'};

% Fallback kolom nama alternatif
altNames = containers.Map( ...
    {'p_true_sec','p_pred_sec','s_true_sec','s_pred_sec'}, ...
    {'p_true_sec|true_p_arrival_sec|p_arrival_sec', ...
     'p_pred_sec|pred_p_arrival_sec', ...
     's_true_sec|true_s_arrival_sec|s_arrival_sec', ...
     's_pred_sec|pred_s_arrival_sec'});

rows = cell(numel(idx), numel(wantCols) + 2);
for i = 1:numel(idx)
    ri = idx(i);
    row = {};
    for w = wantCols
        col = findColAlt(predTable, w{1}, altNames);
        if ~isempty(col)
            v = predTable.(col)(ri);
            if iscell(v); v = v{1}; end
            row{end+1} = v; %#ok
        else
            row{end+1} = NaN; %#ok
        end
    end
    row{end+1} = expName;
    row{end+1} = comp;
    rows(i,:) = row;
end

T = cell2table(rows, 'VariableNames', [wantCols, {'experiment_mode','outlier_component'}]);
end

%        Scatter figure                                                                                                                                                                            
function makeOutlierScatter(predTable, err, comp, expName, figDir, config)
fig = figure('Visible','off','Color','white','Units','centimeters','Position',[2 2 16 10]);

absErr = abs(err);
hasSnr = any(strcmpi(predTable.Properties.VariableNames,'SNR'));
if hasSnr; snr = safeGetNum(predTable,'SNR'); else; snr = nan(numel(err),1); end

valid = ~isnan(err);
x = (1:height(predTable))';
col = [0.122 0.467 0.706];
if strcmp(comp,'S'); col = [0.839 0.153 0.157]; end

ax = axes(); hold on;

% Plot threshold reference lines SEBELUM colorbar (hindari konflik R2024a)
xl = [1 height(predTable)];
plot(xl, [500  500],  '--', 'Color',[0.8 0.4 0.1],'LineWidth',1.0);
plot(xl, [-500 -500], '--', 'Color',[0.8 0.4 0.1],'LineWidth',1.0);
plot(xl, [1000  1000],  ':', 'Color',[0.5 0.5 0.5],'LineWidth',0.8);
plot(xl, [-1000 -1000], ':', 'Color',[0.5 0.5 0.5],'LineWidth',0.8);
plot(xl, [0 0], 'k-', 'LineWidth', 1.2);

% Annotations manuals untuk threshold labels
text(xl(2)*0.98,  510, '+500ms', 'FontSize',8,'Color',[0.8 0.4 0.1], ...
    'HorizontalAlignment','right','FontName','Arial');
text(xl(2)*0.98, -490, '-500ms', 'FontSize',8,'Color',[0.8 0.4 0.1], ...
    'HorizontalAlignment','right','FontName','Arial');

% Scatter (colorbar dibuat SETELAH semua plot, hindari konflik yline)
if hasSnr && ~all(isnan(snr))
    scatter(x(valid), err(valid), 15, snr(valid), 'filled', ...
        'MarkerFaceAlpha', 0.6);
    colormap(ax, parula);
    cb = colorbar(ax);   % colorbar TERAKHIR setelah semua artists
    cb.Label.String = 'SNR (dB)';
else
    scatter(x(valid), err(valid), 15, col, 'filled', 'MarkerFaceAlpha', 0.6);
end

xlabel('Record index', 'FontSize',10,'FontName','Arial');
ylabel(sprintf('%s-wave Error (ms)', comp), 'FontSize',10,'FontName','Arial');
title(sprintf('%s-wave Picking Residuals     %s', comp, expName), ...
    'FontSize',10,'FontName','Arial','FontWeight','normal');
set(ax,'FontSize',9,'FontName','Arial','Box','off','TickDir','out');
grid on; ax.GridAlpha = 0.2;

outPath = fullfile(figDir, sprintf('%s_error_outliers_scatter_%s.png', lower(comp), expName));
exportgraphics(fig, outPath, 'Resolution',300,'BackgroundColor','white');
close(fig);
fprintf('  [Outliers] Saved: %s\n', outPath);
end

%        Helpers                                                                                                                                                                                              
function v = safeGetNum(t, col)
c = findColAlt(t, col, []);
if isempty(c); v = nan(height(t),1); return; end
v = double(t.(c));
end

function colName = findColAlt(t, name, altMap)
cols = t.Properties.VariableNames;
idx = strcmpi(cols, name);
if any(idx); colName = cols{find(idx,1)}; return; end
if isstruct(altMap) || isa(altMap,'containers.Map')
    if isKey(altMap, name)
        alts = strsplit(altMap(name),'|');
        for a = alts
            idx2 = strcmpi(cols, a{1});
            if any(idx2); colName = cols{find(idx2,1)}; return; end
        end
    end
end
colName = '';
end

function ensureDir(d)
if ~isempty(d) && ~isfolder(d); mkdir(d); end
end
