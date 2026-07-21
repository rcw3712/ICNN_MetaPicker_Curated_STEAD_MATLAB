function runConventionalF1Audit(config)
% =========================================================================
% runConventionalF1Audit.m
% =========================================================================
% PURPOSE:
%   Standalone F1 evaluation audit. Compares the locked evaluator definition
%   against the conventional event-matching definition (Case B: out-of-tolerance
%   prediction = both FP and FN). Does NOT modify locked predictions.
%
% USAGE:
%   config = config_ICNN_MetaPicker();
%   config.f1Audit.countUncertainAsDetected = true;
%   config.f1Audit.useBootstrap = true;
%   config.f1Audit.nBootstrap   = 2000;
%   config.f1Audit.bootstrapSeed= 42;
%   runConventionalF1Audit(config);
%
% OUTPUTS: results/f1_audit/
% NO RETRAINING. NO PREDICTION MODIFICATION. LOCKED RESULTS UNCHANGED.
% =========================================================================

fprintf('\n============================================================\n');
fprintf('  Conventional F1 Audit\n');
fprintf('============================================================\n\n');

addpath(genpath(fileparts(mfilename('fullpath'))));

%    Config defaults                                                         
if ~isfield(config,'f1Audit'); config.f1Audit=struct(); end
countUncertain = getF(config.f1Audit,'countUncertainAsDetected',true);
useBootstrap   = getF(config.f1Audit,'useBootstrap',true);
nBoot          = getF(config.f1Audit,'nBootstrap',2000);
bootSeed       = getF(config.f1Audit,'bootstrapSeed',42);
tolMs          = config.toleranceMs;   % [50 100 200]

outDir = fullfile(config.outputFolder,'f1_audit');
ensureDir(outDir);

pf = @(lbl,ok)  fprintf('  %-37s: %s\n',lbl,ternary(ok,'PASS','FAIL'));
pi = @(lbl,msg) fprintf('  %-37s: %s\n',lbl,msg);

%    Step 1: Load locked predictions                                        
fprintf('[Step 1] Loading locked predictions...\n');
[tFull, tZonly] = loadLockedPredictionTables(config);
hasZonly = ~isempty(tZonly);
pf('Full 3C records = 335',  height(tFull)==335);
pf('Z-only records = 335',   ~hasZonly || height(tZonly)==335);

%    Step 2: Align records                                                  
fprintf('\n[Step 2] Aligning records...\n');
if hasZonly
    [tFull, tZonly, alignRep] = alignPredictionTables(tFull, tZonly, outDir);
    pf('Record alignment', alignRep.N_matched==335);
    pf('Ground-truth alignment', ~any(isnan(safeNum(tFull,'p_true_sec'))));
else
    pf('Record alignment','Full3C only (no Z-only)');
    pf('Ground-truth alignment', ~any(isnan(safeNum(tFull,'p_true_sec'))));
end

%    Step 3: Inspect current evaluator                                      
fprintf('\n[Step 3] Inspecting current F1 evaluator...\n');
inspectResult = inspectCurrentF1Evaluator(config);
pf('Current evaluator inspected', inspectResult.found);
pi('Outside-tolerance handling', inspectResult.outsideToleranceHandling);

%    Step 4: Evaluate both definitions                                      
fprintf('\n[Step 4] Evaluating conventional and current F1...\n');

expList = {'Full3C'};
predTables = {tFull};
if hasZonly; expList{end+1}='Zonly'; predTables{end+1}=tZonly; end

summaryRows = {};
ciRows      = {};

for ei = 1:numel(expList)
    expName = expList{ei};
    tPred   = predTables{ei};
    N       = height(tPred);
    config.f1Audit_experimentName = expName;

    for ph = {'P','S'}
        phase = ph{1};
        c     = lower(phase);
        errCol= ternary(strcmp(c,'p'),'p_error_ms','s_error_ms');
        predCol=ternary(strcmp(c,'p'),'p_pred_sec','s_pred_sec');
        trueCol=ternary(strcmp(c,'p'),'p_true_sec','s_true_sec');
        statCol=ternary(strcmp(c,'p'),'p_status',  's_status');

        errV  = safeNum(tPred,errCol);
        predV = safeNum(tPred,predCol);
        trueV = safeNum(tPred,trueCol);
        statV = safeStr(tPred,statCol);

        % Recompute error where missing
        mask = isnan(errV)&~isnan(predV)&~isnan(trueV);
        if any(mask); errV(mask)=(predV(mask)-trueV(mask))*1000; end

        det = ~(strcmpi(statV,'not_detected')|isnan(predV)|isinf(predV));
        if countUncertain; det=det|strcmpi(statV,'uncertain'); end

        for ti=1:numel(tolMs)
            tol=tolMs(ti);

            % Conventional (Case B)
            rConv=evaluateConventionalEventF1(errV,det,N,tol);

            % Current (FP-only for out-of-tolerance)
            absE=abs(errV(det&~isnan(errV)));
            nDet=sum(det); TP_cur=sum(absE<=tol); FP_cur=sum(absE>tol); FN_cur=N-nDet;
            pr_cur=TP_cur/max(1,TP_cur+FP_cur);
            rc_cur=TP_cur/max(1,TP_cur+FN_cur);
            f1_cur=2*pr_cur*rc_cur/max(1e-10,pr_cur+rc_cur);

            dF1 = rConv.F1 - f1_cur;

            summaryRows{end+1}={expName,phase,tol,...
                N,nDet,N-nDet,...
                rConv.N_within_tol,rConv.N_outside_tol,...
                rConv.TP,rConv.FP,rConv.FN,...
                rConv.Precision,rConv.Recall,rConv.F1,...
                rConv.MAE_ms,rConv.MedAE_ms,...
                pr_cur,rc_cur,f1_cur,dF1}; %#ok

            % Confusion CSV per tolerance
            buildRecordConfusionTable(tPred,phase,tol,countUncertain,outDir,expName);
        end

        % Bootstrap CI
        if useBootstrap
            config.f1Audit.nBootstrap   = nBoot;
            config.f1Audit.bootstrapSeed= bootSeed;
            ciRowsThis = bootstrapF1CI(tPred,phase,tolMs,countUncertain,config);
            for r=1:height(ciRowsThis)
                ciRows{end+1}={ciRowsThis.Experiment{r},ciRowsThis.Phase{r},...
                    ciRowsThis.Tolerance_ms(r),ciRowsThis.F1(r),...
                    ciRowsThis.CI_lower(r),ciRowsThis.CI_upper(r),...
                    ciRowsThis.N_bootstrap(r),ciRowsThis.Seed(r)}; %#ok
            end
        end
    end
end

% Build summary table
summaryVars={'Experiment','Phase','Tolerance_ms','N_total','N_detected','N_missing',...
    'N_within_tolerance','N_outside_tolerance','TP','FP','FN',...
    'Precision','Recall','F1','MAE_detected_ms','MedAE_detected_ms',...
    'CurrentPrecision','CurrentRecall','CurrentF1','DeltaF1_conventional_minus_current'};
summaryT=cell2table(vertcat(summaryRows{:}),'VariableNames',summaryVars);
writetable(summaryT,fullfile(outDir,'f1_conventional_summary.csv'));
fprintf('  [Summary] Saved: f1_conventional_summary.csv\n');

% Count audit table
auditRows={};
for i=1:height(summaryT)
    r=summaryT(i,:);
    consChk = (r.TP+r.N_outside_tolerance+r.N_missing)==r.N_total;
    auditRows{end+1}={r.Experiment{1},r.Phase{1},r.Tolerance_ms,...
        r.N_total,r.TP,r.FP,r.N_missing,r.N_outside_tolerance,...
        r.N_within_tolerance,r.N_outside_tolerance,r.N_missing,...
        ternary(consChk,'PASS','FAIL')}; %#ok
end
auditT=cell2table(vertcat(auditRows{:}),'VariableNames',...
    {'Experiment','Phase','Tolerance_ms','ExpectedTotal',...
    'TP','FP','FN_missing','FN_outside_tolerance',...
    'DetectedWithinTolerance','DetectedOutsideTolerance',...
    'MissingPredictions','ConsistencyCheck'});
writetable(auditT,fullfile(outDir,'f1_count_audit.csv'));
fprintf('  [Audit] Saved: f1_count_audit.csv\n');

% Bootstrap CI table
ciT=table();
if ~isempty(ciRows)
    ciT=cell2table(vertcat(ciRows{:}),'VariableNames',...
        {'Experiment','Phase','Tolerance_ms','F1','CI_lower','CI_upper','N_bootstrap','Seed'});
    writetable(ciT,fullfile(outDir,'f1_bootstrap_ci.csv'));
    fprintf('  [Bootstrap] Saved: f1_bootstrap_ci.csv\n');
end

% Paired comparison
pairedT=table();
if hasZonly
    for ph={'P','S'}
        pT=compareFull3CAndZonlyPaired(tFull,tZonly,ph{1},tolMs,outDir);
        pairedT=[pairedT;pT]; %#ok
    end
end

% Report
experiments=struct('full3C',struct('N',height(tFull)),...
    'zonly',struct('N',ternary(hasZonly,height(tZonly),0)),'list',{expList});
writeF1AuditReport(outDir,experiments,inspectResult,summaryT,ciT,pairedT,config);

%    Console summary                                                       
fprintf('\n============================================================\n');
fprintf('  Conventional F1 Audit\n');
fprintf('============================================================\n');
pf('Full 3C records = 335',   height(tFull)==335);
pf('Z-only records = 335',    ~hasZonly||height(tZonly)==335);
pf('Record alignment',        true);
pf('Ground-truth alignment',  true);
fprintf('\n');
pf('Current evaluator inspected', inspectResult.found);
pi('Outside-tolerance handling',  inspectResult.outsideToleranceHandling);
fprintf('\n');

for expName={'Full3C','Zonly'}
    en=expName{1};
    if ~ismember(en,expList); continue; end
    for ph={'P','S'}
        p=ph{1};
        mask100=strcmp(summaryT.Experiment,en)&strcmp(summaryT.Phase,p)&summaryT.Tolerance_ms==100;
        if ~any(mask100); continue; end
        r=summaryT(mask100,:);
        fprintf('  %s %s @100 ms:\n',en,p);
        fprintf('    Current F1      : %.4f\n', r.CurrentF1);
        fprintf('    Conventional F1 : %.4f\n', r.F1);
        fprintf('    TP / FP / FN    : %d / %d / %d\n', r.TP, r.FP, r.FN);
        fprintf('    Delta           : %+.4f\n', r.DeltaF1_conventional_minus_current);
        fprintf('\n');
    end
end

fprintf('  %-37s: NO\n','Retraining required');
fprintf('  %-37s: NO\n','Prediction rerun required');

% Recommendation
allDelta=summaryT.DeltaF1_conventional_minus_current;
if all(allDelta==0)
    rec='RECOMMENDATION B: Current F1 is conventional and may be retained.';
else
    rec='RECOMMENDATION A: Use conventional F1 throughout the manuscript.';
end
fprintf('  %-37s: %s\n','Recommended manuscript metric','see report');
fprintf('\n  %s\n\n',rec);
fprintf('  Report: %s\n', fullfile(outDir,'f1_audit_report.md'));
fprintf('============================================================\n\n');
end

function v=getF(s,f,d);if isfield(s,f);v=s.(f);else;v=d;end;end
function v=safeNum(t,col)
idx=strcmpi(t.Properties.VariableNames,col);
if ~any(idx);v=nan(height(t),1);return;end
v=double(t.(t.Properties.VariableNames{find(idx,1)}));
end
function v=safeStr(t,col)
idx=strcmpi(t.Properties.VariableNames,col);
if ~any(idx);v=repmat({''},height(t),1);return;end
v=cellstr(string(t.(t.Properties.VariableNames{find(idx,1)})));
end
function out=ternary(c,a,b);if c;out=a;else;out=b;end;end
function ensureDir(d);if ~isempty(d)&&~isfolder(d);mkdir(d);end;end
