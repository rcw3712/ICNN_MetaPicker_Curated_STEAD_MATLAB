function metrics = evaluateClean(t,includeUncertain)
if nargin<2;includeUncertain=true;end
rows=cell(0,1);N=height(t);
for phase=["p","s"]
    status=string(t.(phase+"_status"));
    err=1000*(t.(phase+"_pred_sec")-t.(phase+"_true_sec"));
    assert(all(isfinite(t.(phase+"_true_sec"))),'Missing reference arrival.');
    accepted=isfinite(err)&(status=="detected" | (includeUncertain & status=="uncertain"));
    e=abs(err(accepted));nd=sum(accepted);
    for tol=[50 100 200]
        tp=sum(accepted & abs(err)<=tol+1e-7);fp=nd-tp;fn=N-tp;
        row=table(upper(phase),tol,N,nd,sum(status=="detected"&isfinite(err)),tp,fp,fn, ...
            tp/max(1,nd),tp/max(1,N),2*tp/max(1,N+nd),nd/max(1,N), ...
            mean(e),median(e),sqrt(mean(e.^2)),mean(e>1000), ...
            'VariableNames',{'Phase','Tolerance_ms','N','N_accepted','N_strict_detected', ...
            'TP','FP','FN','Precision','Recall','F1','AcceptedCoverage','MAE_ms','MedAE_ms','RMSE_ms','OutlierRate1s'});
        rows{end+1,1}=row; %#ok<AGROW>
    end
end
metrics=vertcat(rows{:});
end
