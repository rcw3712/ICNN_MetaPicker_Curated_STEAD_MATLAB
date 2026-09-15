from pathlib import Path
import pandas as pd,numpy as np,json
O=Path(__file__).resolve().parents[1]/'regenerated';O.mkdir(exist_ok=True);R=O.parent/'frozen'
rows=[];gates=[]
for mode in ['Full3C','Zonly']:
 for seed in [42,43,44]:
  t=pd.read_csv(R/mode/'evaluation'/f'full15ch_seed{seed}_predictions.csv')
  u=pd.read_csv(R/mode/'evaluation'/f'full15ch_seed{seed}_unconstrained_predictions.csv')
  for phase in ['p','s']:
   e=abs(t[phase+'_pred_sec']-t[phase+'_true_sec'])*1000
   a=t[phase+'_status'].eq('detected')&e.notna();tp=(a&(e<=100+1e-7)).sum();n=len(t);nd=a.sum()
   rows.append(dict(Mode=mode,Seed=seed,Phase=phase.upper(),N=n,Accepted=int(nd),TP=int(tp),FP=int(nd-tp),FN=int(n-tp),F1=2*tp/(n+nd),MAE_ms=e[a].mean(),Coverage=100*nd/n))
  pa=t.p_status.ne('not_detected')&t.p_pred_sec.notna();pc=pa&((t.p_pred_sec-t.p_true_sec).abs()<=.10000001)
  se=abs(t.s_pred_sec-t.s_true_sec)*1000;sa=t.s_status.ne('not_detected')&se.notna()
  ue=abs(u.s_pred_sec-u.s_true_sec)*1000;ua=u.s_status.ne('not_detected')&ue.notna()
  for label,mask in [('P accepted',pa),('P within 100 ms',pc)]:
   n=mask.sum();nd=(sa&mask).sum();tp=(sa&mask&(se<=100+1e-7)).sum()
   gates.append(dict(Mode=mode,Seed=seed,Subset=label,N=int(n),S_accepted=int(nd),S_TP=int(tp),S_F1=2*tp/(n+nd),S_MAE_ms=se[mask&sa].mean(),P_gate_failures=int((~pa).sum()),Ungated_S_correct_among_P_failures=int(((~pa)&ua&(ue<=100+1e-7)).sum())))
pd.DataFrame(rows).to_csv(O/'detected_only_runs.csv',index=False)
summary=pd.DataFrame(rows).groupby(['Mode','Phase']).agg(F1_mean=('F1','mean'),F1_SD=('F1','std'),MAE_mean=('MAE_ms','mean'),MAE_SD=('MAE_ms','std'),Coverage_mean=('Coverage','mean')).reset_index()
summary.to_csv(O/'detected_only_summary.csv',index=False);pd.DataFrame(gates).to_csv(O/'p_gate_diagnostics.csv',index=False)
print(summary.to_string(index=False));print(pd.DataFrame(gates).to_string(index=False))
