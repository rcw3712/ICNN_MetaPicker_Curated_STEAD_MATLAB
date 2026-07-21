% =========================================================================
% plotFailureWaveforms.m     Fig 12
% =========================================================================
% PURPOSE:
%   Automatically selects and plots the top failure cases:
%   top-10 P outliers, top-10 S outliers, top-10 S uncertain/not_detected.
% =========================================================================

function caption = plotFailureWaveforms(predTable, csvDir, experimentName, outDir)

C = vizColors();
nCasesEach = 10;
figDir = fullfile(outDir, 'failure_cases', experimentName);
ensureDir(figDir);

errP  = safeNum(predTable,'p_error_ms');
errS  = safeNum(predTable,'s_error_ms');
statS = safeStr(predTable,'s_status');
fnames = safeStr(predTable,'file_name');
eids   = safeStr(predTable,'event_id');

% Select cases
[~,topP] = sort(abs(errP),'descend','MissingPlacement','last');
[~,topS] = sort(abs(errS),'descend','MissingPlacement','last');
notDetIdx  = find(strcmp(statS,'not_detected'));
uncertainIdx= find(strcmp(statS,'uncertain'));

cases = [
    arrayfun(@(k) struct('idx',topP(k),'type','P_outlier','rank',k), 1:min(nCasesEach,sum(~isnan(errP(topP))))),...
    arrayfun(@(k) struct('idx',topS(k),'type','S_outlier','rank',k), 1:min(nCasesEach,sum(~isnan(errS(topS))))),...
    arrayfun(@(k) struct('idx',notDetIdx(k),'type','S_not_detected','rank',k), 1:min(nCasesEach,numel(notDetIdx))),...
    arrayfun(@(k) struct('idx',uncertainIdx(k),'type','S_uncertain','rank',k), 1:min(5,numel(uncertainIdx)))
];

nPlotted = 0;
for ci = 1:numel(cases)
    cs = cases(ci);
    ri = cs.idx;

    csvPath = findCSV(fnames{ri}, eids{ri}, csvDir);
    if isempty(csvPath); continue; end

    try
        wf = readtable(csvPath,'VariableNamingRule','preserve');
    catch; continue; end

    row = predTable(ri,:);
    figName = sprintf('failure_%s_%s_rank%02d_%s.png', ...
        experimentName, cs.type, cs.rank, ...
        regexprep(fnames{ri},'[^a-zA-Z0-9_]','_'));
    figPath = fullfile(figDir, figName);

    plotOneCase(wf, row, cs, experimentName, C, figPath);
    nPlotted = nPlotted + 1;
end

fprintf('  [FailureWaveforms] Saved %d failure case figures to: %s\n', nPlotted, figDir);

caption = sprintf(['Fig. 12. Waveform-level failure inspection for the %s experiment. ' ...
    'Panels show the three-component (E, N, Z) seismograms and true versus predicted ' ...
    'arrival times for representative failure cases: top-10 P-wave outliers, top-10 S-wave ' ...
    'outliers, S-wave not-detected cases, and S-wave uncertain cases. ' ...
    'Blue lines indicate P arrivals; red lines indicate S arrivals. ' ...
    'Dashed lines show true arrivals; solid lines show predicted arrivals.'], experimentName);
end

function plotOneCase(wf, row, cs, expName, C, figPath)
cols = lower(wf.Properties.VariableNames);
secC = findCI(wf,'sec'); if isempty(secC); secC=findCI(wf,'time_sec'); end
eC   = findCI(wf,'E');   nC=findCI(wf,'N'); zC=findCI(wf,'Z');
if isempty(secC); return; end
sec = double(wf.(secC));

chanData = {}; chanNames = {};
if ~isempty(eC); chanData{end+1}=double(wf.(eC)); chanNames{end+1}='E'; end
if ~isempty(nC); chanData{end+1}=double(wf.(nC)); chanNames{end+1}='N'; end
if ~isempty(zC); chanData{end+1}=double(wf.(zC)); chanNames{end+1}='Z'; end
if isempty(chanData); return; end

nCh = numel(chanData);
fig = figure('Visible','off','Color','white','Units','centimeters','Position',[2 2 18 4+3*nCh]);

pT = getScalar(row,'p_true_sec'); sT = getScalar(row,'s_true_sec');
pP = getScalar(row,'p_pred_sec'); sP = getScalar(row,'s_pred_sec');
pE = getScalar(row,'p_error_ms'); sE = getScalar(row,'s_error_ms');
pSt= getStr(row,'p_status');      sSt=getStr(row,'s_status');
snr= getScalar(row,'SNR');         mag=getScalar(row,'source_magnitude');
dist=getScalar(row,'source_distance_km');
eid=getStr(row,'event_id');

for ch = 1:nCh
    ax = subplot(nCh,1,ch);
    plot(sec, chanData{ch}, 'Color',[0.3 0.3 0.3],'LineWidth',0.8); hold on;
    if ~isnan(pT); xline(pT,'--','Color',C.Pwave,'LineWidth',1.5,'Alpha',0.7); end
    if ~isnan(sT); xline(sT,'--','Color',C.Swave,'LineWidth',1.5,'Alpha',0.7); end
    if ~isnan(pP); xline(pP,'-','Color',C.Pwave,'LineWidth',2.0,...
            'Label',sprintf('P_{pred}=%.0fms',pE),'FontSize',8); end
    if ~isnan(sP); xline(sP,'-','Color',C.Swave,'LineWidth',2.0,...
            'Label',sprintf('S_{pred}=%.0fms',sE),'FontSize',8); end
    ylabel(chanNames{ch},'FontSize',12,'FontName','Arial');
    set(ax,'FontSize',10,'FontName','Arial','Box','off');
    if ch<nCh; set(ax,'XTickLabel',{}); end
    grid on; ax.GridAlpha=0.15;
end
xlabel('Time (s)','FontSize',12,'FontName','Arial');

tt = sprintf('[%s | %s] %s: P_err=%.0fms (%s)  S_err=%.0fms (%s)', ...
    expName, cs.type, eid, pE, pSt, sE, sSt);
if ~isnan(snr); tt=[tt sprintf('  SNR=%.1fdB',snr)]; end
if ~isnan(mag);  tt=[tt sprintf('  M=%.1f',mag)]; end
if ~isnan(dist); tt=[tt sprintf('  D=%.1fkm',dist)]; end
sgtitle(tt,'FontSize',9,'FontName','Arial','Interpreter','none');

exportgraphics(fig, figPath,'Resolution',300,'BackgroundColor','white');
close(fig);
end

function p = findCSV(fname, eid, csvDir)
p='';
for c = {fname,[fname '.csv'],[eid '.csv']}
    fp=fullfile(csvDir,c{1}); if isfile(fp);p=fp;return;end
end
end
function c=findCI(t,n)
idx=strcmpi(t.Properties.VariableNames,n);
if any(idx);c=t.Properties.VariableNames{find(idx,1)};else;c='';end
end
function v=safeNum(t,col)
idx=strcmpi(t.Properties.VariableNames,col);
if ~any(idx);v=nan(height(t),1);return;end;v=double(t.(t.Properties.VariableNames{find(idx,1)}));
end
function v=safeStr(t,col)
idx=strcmpi(t.Properties.VariableNames,col);
if ~any(idx);v=repmat({''},height(t),1);return;end
v=cellstr(string(t.(t.Properties.VariableNames{find(idx,1)})));
end
function v=getScalar(row,col)
idx=strcmpi(row.Properties.VariableNames,col);if ~any(idx);v=NaN;return;end
v=double(row.(row.Properties.VariableNames{find(idx,1)}));if iscell(v);v=v{1};end
end
function v=getStr(row,col)
idx=strcmpi(row.Properties.VariableNames,col);if ~any(idx);v='';return;end
v=row.(row.Properties.VariableNames{find(idx,1)});if iscell(v);v=v{1};end;v=char(string(v));
end
function ensureDir(d);if ~isempty(d)&&~isfolder(d);mkdir(d);end;end
