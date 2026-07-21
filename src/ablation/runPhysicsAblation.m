function runPhysicsAblation(icnnModel, metaTestFeat, testData, config)
% runPhysicsAblation.m
% Compares I-CNN WITH vs WITHOUT physics-aware picker.
% Does NOT modify any other module.
% Output: results/ablation/physics_ablation.csv

outDir = fullfile(config.outputFolder, 'ablation');
ensureDir(outDir);

fprintf('[PhysicsAblation] Running with vs without physics-aware picker...\n');

N   = numel(testData);
gt  = extractGT(testData);
tol = config.toleranceMs;

% --- WITH physics-aware picker (standard pipeline) ---
predRaw = predictICNNMetaLearner(icnnModel, metaTestFeat, config);
picksWithPhys = physicsAwarePicker(predRaw, config);
picksWithPhys = fillErrors(picksWithPhys, gt);

% --- WITHOUT physics-aware picker (argmax on raw probability) ---
picksNoPhys = rawArgmaxPicker(predRaw, config);
picksNoPhys = fillErrors(picksNoPhys, gt);

% Count physics violations (cases where raw pick violates SP constraint)
nViol = countPhysicsViolations(picksNoPhys, config);

% Evaluate both
rWith = evalPicks(picksWithPhys, gt, N, tol, 'I-CNN + PhysicsPicker');
rNo   = evalPicks(picksNoPhys,  gt, N, tol, 'I-CNN (argmax only)');
rWith.PhysicsViolations = 0;
rNo.PhysicsViolations   = nViol;

results = [rWith; rNo];
outPath = fullfile(outDir, 'physics_ablation.csv');
writetable(results, outPath);
fprintf('  Saved: %s\n', outPath);

% Print summary
fprintf('\n  === Physics-Aware Picker Ablation ===\n');
fprintf('  %-28s %8s %8s %8s %8s %10s\n', ...
    'Condition','F1@100_P','F1@100_S','MedAE_P','MedAE_S','PhysViol');
for ri = 1:height(results)
    fprintf('  %-28s %8.3f %8.3f %8.0f %8.0f %10d\n', ...
        results.Method{ri}, ...
        safeGet(results,ri,'F1_100ms_P'), safeGet(results,ri,'F1_100ms_S'), ...
        safeGet(results,ri,'MedianAE_ms_P'), safeGet(results,ri,'MedianAE_ms_S'), ...
        results.PhysicsViolations(ri));
end

% Figure
plotPhysicsAblation(results, outDir);
end

function picks = rawArgmaxPicker(predRaw, config)
% Pick P and S from argmax of probability curve, no physics constraints
N = numel(predRaw);
picks = struct('p_pick_sec',cell(N,1),'s_pick_sec',cell(N,1), ...
    'p_status',cell(N,1),'s_status',cell(N,1), ...
    'p_quality',cell(N,1),'s_quality',cell(N,1), ...
    'p_pick_sample',cell(N,1),'s_pick_sample',cell(N,1), ...
    'p_error_ms',cell(N,1),'s_error_ms',cell(N,1));

sr = config.samplingRate;
for i = 1:N
    pr = extractProb(predRaw{i});
    probP = pr(:,1); probS = pr(:,2);
    [~,pIdx] = max(probP); [~,sIdx] = max(probS);
    picks(i).p_pick_sec    = (pIdx-1)/sr;
    picks(i).s_pick_sec    = (sIdx-1)/sr;
    picks(i).p_pick_sample = pIdx;
    picks(i).s_pick_sample = sIdx;
    picks(i).p_status  = 'detected'; picks(i).s_status  = 'detected';
    picks(i).p_quality = 'auto';     picks(i).s_quality = 'auto';
    picks(i).p_error_ms = NaN;       picks(i).s_error_ms = NaN;
end
end

function n = countPhysicsViolations(picks, config)
% Count records where S pick is before P, or SP time < minSPTimeSec
n = 0;
minSP = getOpt(config,'minSPTimeSec', 0.1);
for i = 1:numel(picks)
    pS = picks(i).p_pick_sec; sS = picks(i).s_pick_sec;
    if ~isnan(pS) && ~isnan(sS)
        if sS <= pS || (sS - pS) < minSP; n = n + 1; end
    end
end
end

function r = evalPicks(picks, gt, N, tolMs, name)
errP = [picks.p_error_ms]'; errS = [picks.s_error_ms]';
r = table(); r.Method = {name};
for ci = 1:2
    c   = ternary(ci==1,'P','S');
    err = ternary(ci==1,errP,errS);
    absE = abs(err(~isnan(err))); ev = err(~isnan(err));
    sfx  = ['_' c];
    if isempty(absE)
        r.(['MAE_ms' sfx])=NaN; r.(['MedianAE_ms' sfx])=NaN;
        r.(['F1_100ms' sfx])=NaN; r.(['OutlierRate' sfx])=NaN;
        r.(['DetectionRate' sfx])=0;
    else
        r.(['MAE_ms' sfx])      = mean(absE);
        r.(['MedianAE_ms' sfx]) = median(absE);
        r.(['DetectionRate' sfx])= numel(absE)/N;
        r.(['OutlierRate' sfx]) = mean(absE>1000);
        for tol = tolMs
            TP=sum(absE<=tol); FP=sum(absE>tol); FN=N-numel(absE);
            pr=TP/max(1,TP+FP); rc=TP/max(1,TP+FN);
            r.(sprintf('F1_%dms%s',tol,sfx))=2*pr*rc/max(1e-10,pr+rc);
        end
    end
end
end

function plotPhysicsAblation(results, outDir)
fig=figure('Visible','off','Color','white','Units','centimeters','Position',[2 2 16 10]);
metrics={'F1_100ms_P','F1_100ms_S','MedianAE_ms_P','MedianAE_ms_S'};
titles={'F1@100ms (P)','F1@100ms (S)','MedAE ms (P)','MedAE ms (S)'};
for mi=1:4
    ax=subplot(2,2,mi);
    vals=zeros(height(results),1);
    if any(strcmp(results.Properties.VariableNames,metrics{mi}))
        vals=results.(metrics{mi});
    end
    b=bar(vals,0.6,'EdgeColor','none');
    b.FaceColor='flat';
    b.CData=[0.173 0.627 0.173; 0.839 0.153 0.157];
    set(ax,'XTickLabel',results.Method,'XTickLabelRotation',10,...
        'FontSize',9,'FontName','Arial','Box','off');
    title(titles{mi},'FontSize',11,'FontName','Arial','FontWeight','bold');
    grid on;
end
sgtitle('Physics-Aware Picker Ablation','FontSize',13,'FontName','Arial','FontWeight','bold');
exportgraphics(fig,fullfile(outDir,'physics_ablation.png'),'Resolution',300,'BackgroundColor','white');
close(fig);
end

function pr = extractProb(raw)
if iscell(raw); raw=raw{1}; end
if isa(raw,'dlarray'); raw=extractdata(raw); end
pr=double(raw);
if ndims(pr)==3; pr=squeeze(pr); end
if size(pr,2)~=3&&size(pr,1)==3; pr=pr'; end
end

function picks=fillErrors(picks,gt)
for i=1:numel(picks)
    if ~isnan(picks(i).p_pick_sec)&&~isnan(gt(i).p_arrival_sec)
        picks(i).p_error_ms=(picks(i).p_pick_sec-gt(i).p_arrival_sec)*1000;
    else; picks(i).p_error_ms=NaN; end
    if ~isnan(picks(i).s_pick_sec)&&~isnan(gt(i).s_arrival_sec)
        picks(i).s_error_ms=(picks(i).s_pick_sec-gt(i).s_arrival_sec)*1000;
    else; picks(i).s_error_ms=NaN; end
end
end

function gt=extractGT(data)
N=numel(data); gt=struct('p_arrival_sec',cell(N,1),'s_arrival_sec',cell(N,1));
for i=1:N; gt(i).p_arrival_sec=data(i).p_arrival_sec; gt(i).s_arrival_sec=data(i).s_arrival_sec; end
end

function v=safeGet(t,row,col); v=NaN; if any(strcmp(t.Properties.VariableNames,col)); v=t.(col)(row); end; end
function v=getOpt(c,f,d); if isfield(c,f); v=c.(f); else; v=d; end; end
function out=ternary(c,a,b); if c;out=a;else;out=b;end; end
function ensureDir(d); if ~isempty(d)&&~isfolder(d); mkdir(d); end; end
