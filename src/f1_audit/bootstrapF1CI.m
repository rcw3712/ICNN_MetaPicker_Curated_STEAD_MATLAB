function ciT = bootstrapF1CI(predTable, phase, tolMs, countUncertain, config)
% bootstrapF1CI.m
% PURPOSE: Nonparametric bootstrap confidence intervals for F1 at multiple
%          tolerances, sampling at the RECORD level.
% INPUTS:
%   predTable     -- locked prediction table
%   phase         -- 'P' or 'S'
%   tolMs         -- [1 x K] tolerance array
%   countUncertain-- logical
%   config        -- must contain f1Audit.nBootstrap, f1Audit.bootstrapSeed
% OUTPUT: ciT -- table with F1, CI_lower, CI_upper per tolerance

nBoot = config.f1Audit.nBootstrap;
seed  = config.f1Audit.bootstrapSeed;
rng(seed,'twister');
expName = getfield_safe(config,'f1Audit_experimentName','Unknown');

N = height(predTable);
c = lower(phase);
errCol = ternary(strcmp(c,'p'),'p_error_ms','s_error_ms');
statCol= ternary(strcmp(c,'p'),'p_status',  's_status');
predCol= ternary(strcmp(c,'p'),'p_pred_sec','s_pred_sec');
trueCol= ternary(strcmp(c,'p'),'p_true_sec','s_true_sec');

errV  = safeNum(predTable, errCol);
predV = safeNum(predTable, predCol);
trueV = safeNum(predTable, trueCol);
statV = safeStr(predTable, statCol);

% Recompute error if missing
mask = isnan(errV)&~isnan(predV)&~isnan(trueV);
if any(mask); errV(mask)=(predV(mask)-trueV(mask))*1000; end

det = ~(strcmpi(statV,'not_detected') | isnan(predV) | isinf(predV));
if countUncertain; det = det | strcmpi(statV,'uncertain'); end

rows = {};
for ti = 1:numel(tolMs)
    tol = tolMs(ti);
    f1boot = zeros(nBoot,1);
    for b = 1:nBoot
        idx = randi(N, N, 1);  % record-level bootstrap
        eB = errV(idx); dB = det(idx);
        TP=0;FP=0;FN=0;
        for i=1:N
            if ~dB(i); FN=FN+1;
            elseif abs(eB(i))<=tol; TP=TP+1;
            else; FP=FP+1; FN=FN+1; end
        end
        pr=TP/max(1,TP+FP); rc=TP/max(1,TP+FN);
        f1boot(b)=2*pr*rc/max(1e-10,pr+rc);
    end
    % Observed F1
    TP=0;FP=0;FN=0;
    for i=1:N
        if ~det(i); FN=FN+1;
        elseif abs(errV(i))<=tol; TP=TP+1;
        else; FP=FP+1; FN=FN+1; end
    end
    pr=TP/max(1,TP+FP); rc=TP/max(1,TP+FN);
    f1obs=2*pr*rc/max(1e-10,pr+rc);
    rows{end+1}={expName,phase,tol,f1obs,...
        prctile(f1boot,2.5),prctile(f1boot,97.5),nBoot,seed}; %#ok
end

ciT=cell2table(vertcat(rows{:}),'VariableNames',...
    {'Experiment','Phase','Tolerance_ms','F1','CI_lower','CI_upper','N_bootstrap','Seed'});
end

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
function v=getfield_safe(s,f,d);if isfield(s,f);v=s.(f);else;v=d;end;end
function out=ternary(c,a,b);if c;out=a;else;out=b;end;end
