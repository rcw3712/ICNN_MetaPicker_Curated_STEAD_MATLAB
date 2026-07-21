% =========================================================================
% inspectFailureWaveforms.m
% =========================================================================
% PURPOSE:
%   Plot waveform E,N,Z untuk kasus failure/outlier teratas agar penyebab
%   sinyal dari kesalahan picking dapat dianalisis secara visual.
%   Dihasilkan tanpa inference ulang     hanya menggunakan waveform CSV asli
%   dan picks yang sudah tersimpan di predictions CSV.
%
% INPUTS:
%   predTable      - table dari predictions CSV (sudah di-join)
%   experimentName - char, 'Full3C' atau 'Zonly'
%   config         - struct framework
%     config.numFailureCasesToPlot  (default 20)
%     config.csvWaveformFolder
%
% OUTPUTS:
%   failureSummary - table, kasus yang dipilih untuk inspeksi
%   Saved figures:
%     results/diagnostics/failure_cases/<exp>/failure_<exp>_P_outlier_rank<N>_<id>.png
%     results/diagnostics/failure_cases/<exp>/failure_<exp>_S_outlier_rank<N>_<id>.png
%     results/diagnostics/failure_cases/<exp>/failure_<exp>_S_not_detected_rank<N>_<id>.png
%   Saved CSV:
%     failure_cases_selected_<exp>.csv
% =========================================================================

function failureSummary = inspectFailureWaveforms(predTable, experimentName, config)

nPlot  = getOpt(config, 'numFailureCasesToPlot', 20);

% Resolve waveform folder     coba semua kemungkinan nama field
if isfield(config, 'csvWaveformFolder') && ~isempty(config.csvWaveformFolder)
    csvDir = config.csvWaveformFolder;
elseif isfield(config, 'csvFolder') && ~isempty(config.csvFolder)
    csvDir = config.csvFolder;
else
    csvDir = fullfile('data', 'csv_stead_filtered');
end
outDir = fullfile(config.outputDiagnosticsFolder, 'failure_cases', experimentName);
sumDir = fullfile(config.outputDiagnosticsFolder, 'failure_cases');
ensureDir(outDir); ensureDir(sumDir);

errP  = safeGetNum(predTable, 'p_error_ms');
errS  = safeGetNum(predTable, 's_error_ms');
statP = safeGetStr(predTable, 'p_status');
statS = safeGetStr(predTable, 's_status');
fnames = safeGetStr(predTable, 'file_name');
eids   = safeGetStr(predTable, 'event_id');

%        Pilih kasus untuk diinspeksi                                                                                                                               
[~, topP] = sort(abs(errP), 'descend', 'MissingPlacement','last');
[~, topS] = sort(abs(errS), 'descend', 'MissingPlacement','last');
notDetS   = find(strcmp(statS,'not_detected'));
uncertainS = find(strcmp(statS,'uncertain'));

cases = struct('rank',{}, 'idx',{}, 'type',{}, 'component',{});
for k = 1:min(nPlot, sum(~isnan(errP(topP))))
    cases(end+1) = struct('rank',k,'idx',topP(k),'type','P_outlier','component','P'); %#ok
end
for k = 1:min(nPlot, sum(~isnan(errS(topS))))
    cases(end+1) = struct('rank',k,'idx',topS(k),'type','S_outlier','component','S'); %#ok
end
for k = 1:min(10, numel(notDetS))
    cases(end+1) = struct('rank',k,'idx',notDetS(k),'type','S_not_detected','component','S'); %#ok
end
for k = 1:min(5, numel(uncertainS))
    cases(end+1) = struct('rank',k,'idx',uncertainS(k),'type','S_uncertain','component','S'); %#ok
end

fprintf('  [FailureInspect] Inspecting %d failure cases for %s...\n', numel(cases), experimentName);

%        Plot tiap kasus                                                                                                                                                                      
summaryRows = {};
for ci = 1:numel(cases)
    cs  = cases(ci);
    ri  = cs.idx;
    row = predTable(ri,:);

    % Cari file waveform
    fname  = fnames{ri};
    csvPath = findWaveformFile(fname, eids{ri}, csvDir);

    if isempty(csvPath)
        fprintf('    [Skip] Waveform not found for %s\n', fname);
        continue;
    end

    try
        wf = readtable(csvPath, 'VariableNamingRule','preserve');
    catch
        fprintf('    [Skip] Cannot read %s\n', csvPath);
        continue;
    end

    % Identitas record
    figName = sprintf('failure_%s_%s_rank%02d_%s.png', ...
        experimentName, cs.type, cs.rank, ...
        regexprep(fname, '[^a-zA-Z0-9_]', '_'));
    figPath = fullfile(outDir, figName);

    plotFailureWaveform(wf, row, cs, experimentName, figPath, config);
    summaryRows{end+1} = buildSummaryRow(row, cs, experimentName, figName); %#ok
end

%        Save summary CSV                                                                                                                                                                   
if ~isempty(summaryRows)
    failureSummary = vertcat(summaryRows{:});
    writetable(failureSummary, ...
        fullfile(sumDir, sprintf('failure_cases_selected_%s.csv', experimentName)));
    fprintf('  [FailureInspect] Saved %d failure case figures.\n', numel(summaryRows));
else
    failureSummary = table();
    fprintf('  [FailureInspect] No failure cases plotted (waveform files not found?).\n');
end
end

%        Plot one failure waveform                                                                                                                                           
function plotFailureWaveform(wf, row, cs, expName, figPath, config)
cols = lower(wf.Properties.VariableNames);
secCol = findColCI(wf,'sec'); if isempty(secCol); secCol = findColCI(wf,'time_sec'); end
eCol   = findColCI(wf,'E');   nCol = findColCI(wf,'N');   zCol = findColCI(wf,'Z');

if isempty(secCol); warning('No time column found'); return; end
sec = double(wf.(secCol));

% Channel data
chanData = {};
chanNames = {};
if ~isempty(eCol); chanData{end+1} = double(wf.(eCol)); chanNames{end+1} = 'E'; end
if ~isempty(nCol); chanData{end+1} = double(wf.(nCol)); chanNames{end+1} = 'N'; end
if ~isempty(zCol); chanData{end+1} = double(wf.(zCol)); chanNames{end+1} = 'Z'; end
if isempty(chanData); return; end

nChan = numel(chanData);
fig = figure('Visible','off','Color','white','Units','centimeters', ...
    'Position',[2 2 18 4*nChan]);

CP = [0.122 0.467 0.706];   % biru = P
CS = [0.839 0.153 0.157];   % merah = S

for ch = 1:nChan
    ax = subplot(nChan, 1, ch);
    plot(sec, chanData{ch}, 'Color',[0.3 0.3 0.3], 'LineWidth', 0.6);
    hold on;

    pTrue = safeScalar(row, 'p_true_sec');
    sTrue = safeScalar(row, 's_true_sec');
    pPred = safeScalar(row, 'p_pred_sec');
    sPred = safeScalar(row, 's_pred_sec');
    pErr  = safeScalar(row, 'p_error_ms');
    sErr  = safeScalar(row, 's_error_ms');

    if ~isnan(pTrue); xline(pTrue,'--','Color',CP,'LineWidth',1.5,'Alpha',0.7,'Label','P_{true}'); end
    if ~isnan(sTrue); xline(sTrue,'--','Color',CS,'LineWidth',1.5,'Alpha',0.7,'Label','S_{true}'); end
    if ~isnan(pPred); xline(pPred,'-','Color',CP,'LineWidth',2.0,'Label',sprintf('P_{pred} (  %.0fms)',pErr)); end
    if ~isnan(sPred); xline(sPred,'-','Color',CS,'LineWidth',2.0,'Label',sprintf('S_{pred} (  %.0fms)',sErr)); end

    ylabel(chanNames{ch},'FontSize',9,'FontName','Arial');
    set(ax,'FontSize',8,'FontName','Arial','Box','off','TickDir','out');
    if ch < nChan; set(ax,'XTickLabel',{}); end
    grid on; ax.GridAlpha = 0.15;
end

xlabel('Time (s)','FontSize',9,'FontName','Arial');

% Annotate dengan metadata
pStat = safeStr(row,'p_status'); sStat = safeStr(row,'s_status');
snrV  = safeScalar(row,'SNR');   mag   = safeScalar(row,'source_magnitude');
dist  = safeScalar(row,'source_distance_km');
fid   = safeStr(row,'event_id');

titleStr = sprintf('[%s | %s] %s       P_err=%.0fms (%s)  S_err=%.0fms (%s)', ...
    expName, cs.type, fid, pErr, pStat, sErr, sStat);
if ~isnan(snrV); titleStr = [titleStr sprintf('  SNR=%.1fdB',snrV)]; end
if ~isnan(mag);  titleStr = [titleStr sprintf('  M=%.1f',mag)]; end
if ~isnan(dist); titleStr = [titleStr sprintf('  D=%.1fkm',dist)]; end

sgtitle(titleStr,'FontSize',8,'FontName','Arial','Interpreter','none');

% Z-only annotation
if strcmpi(expName,'Zonly')
    annotation('textbox',[0.01 0.0 0.98 0.03], ...
        'String','Z-only mode: E and N channels zeroed during inference (shown here as reference only)', ...
        'FontSize',7,'FontName','Arial','Color',[0.6 0.3 0.0],'EdgeColor','none', ...
        'HorizontalAlignment','center');
end

exportgraphics(fig, figPath,'Resolution',300,'BackgroundColor','white');
close(fig);
end

%        Build one summary row                                                                                                                                                       
function t = buildSummaryRow(row, cs, expName, figName)
% Semua nilai string WAJIB dibungkus dalam cell array {} agar table() tidak error
% ketika nilainya berupa char vector (mis. 'stead_event_01178')
eid  = {safeStr(row,'event_id')};
sid  = {safeStr(row,'source_id')};
fn   = {safeStr(row,'file_name')};
exp  = {expName};
typ  = {cs.type};
comp = {cs.component};
pSt  = {safeStr(row,'p_status')};
sSt  = {safeStr(row,'s_status')};
fig  = {figName};

t = table( ...
    eid, sid, fn, exp, typ, comp, cs.rank, ...
    safeScalar(row,'p_error_ms'), safeScalar(row,'s_error_ms'), ...
    pSt, sSt, ...
    safeScalar(row,'SNR'), safeScalar(row,'source_magnitude'), ...
    safeScalar(row,'source_distance_km'), fig, ...
    'VariableNames',{'event_id','source_id','file_name', ...
    'experiment','case_type','component','rank', ...
    'p_error_ms','s_error_ms','p_status','s_status', ...
    'SNR','source_magnitude','source_distance_km','figure_file'});
end

%        Helpers                                                                                                                                                                                              
function p = findWaveformFile(fname, eid, csvDir)
p = '';
candidates = {fname, [fname '.csv'], [eid '.csv'], [eid '_waveform.csv']};
for c = candidates
    fp = fullfile(csvDir, c{1});
    if isfile(fp); p = fp; return; end
end
end

function colName = findColCI(t, name)
idx = strcmpi(t.Properties.VariableNames, name);
if any(idx); colName = t.Properties.VariableNames{find(idx,1)};
else; colName = ''; end
end

function v = safeScalar(row, col)
idx = strcmpi(row.Properties.VariableNames, col);
if ~any(idx); v = NaN; return; end
v = double(row.(row.Properties.VariableNames{find(idx,1)}));
if iscell(v); v = v{1}; end
end

function v = safeStr(row, col)
idx = strcmpi(row.Properties.VariableNames, col);
if ~any(idx); v = ''; return; end
val = row.(row.Properties.VariableNames{find(idx,1)});
if iscell(val); v = val{1}; elseif isnumeric(val); v = num2str(val);
else; v = char(string(val)); end
end

function v = safeGetNum(t, col)
idx = strcmpi(t.Properties.VariableNames, col);
if ~any(idx); v = nan(height(t),1); return; end
v = double(t.(t.Properties.VariableNames{find(idx,1)}));
end

function v = safeGetStr(t, col)
idx = strcmpi(t.Properties.VariableNames, col);
if ~any(idx); v = repmat({''},height(t),1); return; end
v = cellstr(string(t.(t.Properties.VariableNames{find(idx,1)})));
end

function v = getOpt(cfg, fname, def)
if isfield(cfg, fname); v = cfg.(fname); else; v = def; end
end

function ensureDir(d)
if ~isempty(d) && ~isfolder(d); mkdir(d); end
end
