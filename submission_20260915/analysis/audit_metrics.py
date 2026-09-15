from pathlib import Path
import pandas as pd, numpy as np, json, hashlib
R=Path(__file__).resolve().parents[1]/'frozen'
O=Path(__file__).resolve().parents[1]/'regenerated';O.mkdir(exist_ok=True)
checks=[]; rows=[]; physics=[]; tables={}
def check(name,ok,detail=''): checks.append(dict(check=name,pass_check=bool(ok),detail=str(detail)))
def calc(t,strict=False):
 out=[]
 for p in ['P','S']:
  q=p.lower(); e=1000*(t[q+'_pred_sec']-t[q+'_true_sec']).to_numpy(); s=t[q+'_status']; a=np.isfinite(e)&s.isin(['detected'] if strict else ['detected','uncertain']).to_numpy(); ae=np.abs(e[a]); n=len(t); nd=a.sum()
  for tol in [50,100,200]:
   tp=(a&(np.abs(e)<=tol+1e-7)).sum()
   out.append(dict(Phase=p,Tolerance_ms=tol,N=n,N_accepted=nd,N_strict_detected=(s=='detected').sum(),TP=tp,FP=nd-tp,FN=n-tp,Precision=tp/max(1,nd),Recall=tp/n,F1=2*tp/max(1,n+nd),AcceptedCoverage=nd/n,MAE_ms=ae.mean() if nd else np.nan,MedAE_ms=np.median(ae) if nd else np.nan,RMSE_ms=np.sqrt(np.mean(ae**2)) if nd else np.nan,OutlierRate1s=np.mean(ae>1000) if nd else np.nan))
 return pd.DataFrame(out)
ref=None
for f in sorted(R.glob('*/*/*_predictions.csv')):
 if '_unconstrained_' in f.name: continue
 key=str(f.relative_to(R)).replace(chr(92),'/').replace('_predictions.csv','').replace('/',chr(92)); t=pd.read_csv(f); tables[key]=t
 ids=t[['event_id','source_id','p_true_sec','s_true_sec']].sort_values('event_id').reset_index(drop=True)
 if ref is None: ref=ids
 check(key+' population',ids.equals(ref) and len(t)==335 and t.event_id.is_unique)
 for typ,df,strict in [('accepted',t,False),('strict',t,True),('unconstrained',pd.read_csv(str(f).replace('_predictions.csv','_unconstrained_predictions.csv')),False)]:
  c=calc(df,strict); reported=pd.read_csv(str(f).replace('_predictions.csv','_'+typ+'_metrics.csv'))
  for col in c.columns[1:]: check(key+' '+typ+' '+col,np.allclose(c[col],reported[col],atol=1e-6,rtol=1e-10,equal_nan=True))
  c.insert(0,'Evaluation',key);c.insert(1,'Policy',typ);rows.extend(c.to_dict('records'))
 u=pd.read_csv(str(f).replace('_predictions.csv','_unconstrained_predictions.csv'))
 for p in ['p','s']:
  both=t[p+'_status'].isin(['detected','uncertain'])&u[p+'_status'].isin(['detected','uncertain'])
  changed=~np.isclose(t[p+'_pred_sec'],u[p+'_pred_sec'],atol=1e-8,equal_nan=True)
  physics.append(dict(Evaluation=key,Phase=p.upper(),Changed_time_or_availability=int(changed.sum()),Changed_among_both_accepted=int((changed&both).sum()),Changed_status=int((t[p+'_status']!=u[p+'_status']).sum())))
A=pd.DataFrame(rows); A.to_csv(O/'recomputed_metrics.csv',index=False); pd.DataFrame(physics).to_csv(O/'decoder_comparison.csv',index=False)
runs=pd.read_csv(R/'multiseed_runs_clean.csv')
for _,row in runs.iterrows():
 key=f"{row.Mode}\\evaluation\\{row.Variant}_seed{row.Seed}"
 c=A[(A.Evaluation==key)&(A.Policy=='accepted')&(A.Phase==row.Phase)&(A.Tolerance_ms==row.Tolerance_ms)]
 check('multiseed '+key+' '+row.Phase+str(row.Tolerance_ms),len(c)==1 and all(np.isclose(c.iloc[0][col],row[col],atol=1e-6) for col in ['F1','MAE_ms','TP','FP','FN']))
# Recalculate mean and sample SD, preserving n=1 uncertainty as unavailable.
summ=runs.groupby(['Mode','Variant','Phase','Tolerance_ms']).agg(n=('Seed','size'),F1_mean=('F1','mean'),F1_SD=('F1','std'),MAE_mean=('MAE_ms','mean'),MAE_SD=('MAE_ms','std'),Coverage_mean=('AcceptedCoverage','mean')).reset_index(); summ.to_csv(O/'replacement_multiseed_summary.csv',index=False)
check('test source count',ref.source_id.nunique()==317)
counts=ref.source_id.value_counts(); print('repeated test sources',int((counts>1).sum()),'max records',counts.max())
for mode in ['Full3C','Zonly']:
 t=pd.read_csv(R/mode/'oof_membership.csv'); check(mode+' OOF source grouped',t.groupby('source_id').fold.nunique().max()==1); check(mode+' OOF/test disjoint',not set(t.source_id)&set(ref.source_id)); print(mode,'OOF',len(t),t.source_id.nunique())
# New paired source bootstrap: mean F1 across meta seeds, fixed base networks and test split.
clusters=sorted(ref.source_id.unique()); rng=np.random.default_rng(42); W=rng.multinomial(len(clusters),np.full(len(clusters),1/len(clusters)),size=10000); boot=[]
def stats(key,p):
 t=tables[key]; e=abs(1000*(t[p+'_pred_sec']-t[p+'_true_sec'])); a=t[p+'_status'].isin(['detected','uncertain'])&e.notna(); z=pd.DataFrame({'source':t.source_id,'n':1,'a':a.astype(int),'tp':(a&(e<=100+1e-7)).astype(int)}).groupby('source').sum().reindex(clusters).to_numpy(); point=2*z[:,2].sum()/(z[:,0].sum()+z[:,1].sum()); draws=2*(W@z[:,2])/(W@(z[:,0]+z[:,1])); return point,draws
for comparator in ['Zonly','probonly12','waveonly3','nodilation','logistic','TCN','weighted_ensemble']:
 for p in ['p','s']:
  aa=[];bb=[];ap=[];bp=[]
  for seed in [42,43,44]:
   k=f'Full3C\\evaluation\\full15ch_seed{seed}'
   b=f'Zonly\\evaluation\\full15ch_seed{seed}' if comparator=='Zonly' else f'Full3C\\baselines\\{comparator}' if comparator in ['TCN','weighted_ensemble'] else f'Full3C\\evaluation\\{comparator}_seed{42 if comparator=="logistic" else seed}'
   x,y=stats(k,p);ap.append(x);aa.append(y);x,y=stats(b,p);bp.append(x);bb.append(y)
  d=np.mean(aa,axis=0)-np.mean(bb,axis=0);lo,hi=np.quantile(d,[.025,.975]); boot.append(dict(Comparison='Full15 - '+comparator,Phase=p.upper(),Tolerance_ms=100,Mean_A=np.mean(ap),Mean_B=np.mean(bp),Delta=np.mean(ap)-np.mean(bp),CI_low=lo,CI_high=hi))
pd.DataFrame(boot).to_csv(O/'paired_bootstrap_mean_F1.csv',index=False)
pd.DataFrame(checks).to_csv(O/'audit_checks.csv',index=False)
print('checks',len(checks),'failed',sum(not x['pass_check'] for x in checks));print('FAILURES',[x for x in checks if not x['pass_check']][:10])
print('BASELINES100\n',A[(A.Evaluation.str.contains('baselines'))&(A.Policy=='accepted')&(A.Tolerance_ms==100)][['Evaluation','Phase','F1','MAE_ms','AcceptedCoverage']].to_string(index=False))
print('PHYSICS MAIN\n',pd.DataFrame(physics)[pd.DataFrame(physics).Evaluation.str.contains('full15ch')].to_string(index=False))
print('BOOTSTRAP\n',pd.DataFrame(boot).to_string(index=False))

assert all(x["pass_check"] for x in checks), "Metric or population audit failed"
