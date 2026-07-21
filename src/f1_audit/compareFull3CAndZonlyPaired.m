function pairedT = compareFull3CAndZonlyPaired(tFull, tZonly, phase, tolMs, outDir)
% compareFull3CAndZonlyPaired.m
% PURPOSE: Paired comparison of Full3C vs Z-only at record level.
%          Valid because both use IDENTICAL 335 test records.
% OUTPUTS: pairedT -- table with paired counts per tolerance

N = height(tFull);
c = lower(phase);
errF = safeErr(tFull, c); detF = safeDetected(tFull, c);
errZ = safeErr(tZonly, c); detZ = safeDetected(tZonly, c);

rows={};
for ti=1:numel(tolMs)
    tol=tolMs(ti);
    f3c_ok = detF & abs(errF)<=tol;
    zon_ok = detZ & abs(errZ)<=tol;
    both    = sum(f3c_ok & zon_ok);
    f3c_only= sum(f3c_ok & ~zon_ok);
    zon_only= sum(~f3c_ok & zon_ok);
    neither = sum(~f3c_ok & ~zon_ok);
    rows{end+1}={phase,tol,N,both,f3c_only,zon_only,neither}; %#ok
end

pairedT=cell2table(vertcat(rows{:}),'VariableNames',...
    {'Phase','Tolerance_ms','N_total','Both_correct',...
    'Full3C_only','Zonly_only','Neither_correct'});
ensureDir(outDir);
writetable(pairedT, fullfile(outDir,'paired_full3C_vs_Zonly.csv'));
fprintf('  [Paired] Saved: paired_full3C_vs_Zonly.csv\n');
end

function err=safeErr(t,c)
col=ternary(strcmp(c,'p'),'p_error_ms','s_error_ms');
idx=strcmpi(t.Properties.VariableNames,col);
if ~any(idx);err=nan(height(t),1);return;end
err=double(t.(t.Properties.VariableNames{find(idx,1)}));
pC=ternary(strcmp(c,'p'),'p_pred_sec','s_pred_sec');
tC=ternary(strcmp(c,'p'),'p_true_sec','s_true_sec');
iP=strcmpi(t.Properties.VariableNames,pC); iT=strcmpi(t.Properties.VariableNames,tC);
if any(iP)&&any(iT)
    pV=double(t.(t.Properties.VariableNames{find(iP,1)}));
    tV=double(t.(t.Properties.VariableNames{find(iT,1)}));
    mask=isnan(err)&~isnan(pV)&~isnan(tV);
    err(mask)=(pV(mask)-tV(mask))*1000;
end
end
function det=safeDetected(t,c)
sCol=ternary(strcmp(c,'p'),'p_status','s_status');
pCol=ternary(strcmp(c,'p'),'p_pred_sec','s_pred_sec');
idx=strcmpi(t.Properties.VariableNames,sCol);
if any(idx)
    st=cellstr(string(t.(t.Properties.VariableNames{find(idx,1)})));
    det=~strcmpi(st,'not_detected');
else
    idx2=strcmpi(t.Properties.VariableNames,pCol);
    pV=double(t.(t.Properties.VariableNames{find(idx2,1)}));
    det=~isnan(pV)&~isinf(pV);
end
end
function out=ternary(c,a,b);if c;out=a;else;out=b;end;end
function ensureDir(d);if ~isempty(d)&&~isfolder(d);mkdir(d);end;end
