from pathlib import Path
import csv,json,math,statistics,collections,sys
w=Path(r'C:\Users\catur\.codex\visualizations\2026\09\11\01a08fc7-0cf1-7772-a384-020417c19593');sys.path.insert(0,str(w/'revision/pylibs'));import numpy as np
new=Path(r'D:\ICNN_source_verified_results\v2\submission40');old=w/'sync_repo/submission_20260915/frozen';out=w/'interim_results_audit_20260917';out.mkdir(exist_ok=True)
def read(p):
 with Path(p).open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def write(p,rows):
 with p.open('w',encoding='utf-8',newline='') as f:
  writer=csv.DictWriter(f,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
def num(s):return float(s) if s and s.strip().lower() not in ('nan','na') else float('nan')
def calc(t,strict=False):
 rows=[]
 for phase in ('P','S'):
  q=phase.lower();e=[1000*(num(r[q+'_pred_sec'])-num(r[q+'_true_sec'])) for r in t];accepted=[math.isfinite(v) and r[q+'_status'] in (['detected'] if strict else ['detected','uncertain']) for v,r in zip(e,t)];ae=[abs(v) for v,a in zip(e,accepted) if a];n=len(t);nd=len(ae)
  for tol in (50,100,200):
   tp=sum(a and abs(v)<=tol+1e-7 for a,v in zip(accepted,e));rows.append(dict(Phase=phase,Tolerance_ms=tol,N=n,N_accepted=nd,N_strict_detected=sum(r[q+'_status']=='detected' and math.isfinite(v) for r,v in zip(t,e)),TP=tp,FP=nd-tp,FN=n-tp,Precision=tp/max(1,nd),Recall=tp/n,F1=2*tp/max(1,n+nd),AcceptedCoverage=nd/n,MAE_ms=statistics.mean(ae) if nd else float('nan'),MedAE_ms=statistics.median(ae) if nd else float('nan'),RMSE_ms=math.sqrt(statistics.mean(v*v for v in ae)) if nd else float('nan'),OutlierRate1s=sum(v>1000 for v in ae)/nd if nd else float('nan')))
 return rows
checks=[];tables={};metrics={};allrows=[]
for label,root,n in [('old',old,335),('new',new,330)]:
 for f in sorted(root.glob('*/*/*_predictions.csv')):
  if '_unconstrained_' in f.name:continue
  key=f.relative_to(root).as_posix().replace('_predictions.csv','');t=read(f);tables[(label,key)]=t
  assert len(t)==n and len({r['event_id'] for r in t})==n
  for policy,strict in [('accepted',False),('strict',True),('unconstrained',False)]:
   pred=t if policy!='unconstrained' else read(f.with_name(f.name.replace('_predictions.csv','_unconstrained_predictions.csv')))
   c=calc(pred,strict);reported=read(f.with_name(f.name.replace('_predictions.csv','_'+policy+'_metrics.csv')))
   assert len(c)==len(reported)==6
   for a,b in zip(c,reported):
    assert a['Phase']==b['Phase']
    for col in a.keys()-{'Phase'}:
     x=a[col];y=num(b[col]);ok=(math.isnan(x) and math.isnan(y)) or math.isclose(x,y,abs_tol=1e-6,rel_tol=1e-10)
     if not ok:checks.append(dict(run=label,evaluation=key,policy=policy,column=col,expected=x,reported=y))
   metrics[(label,key,policy)]=c
   allrows.extend(dict(run=label,evaluation=key,policy=policy,**r) for r in c)
assert not checks,checks[:5]
write(out/'recomputed_metrics.csv',allrows)
comparison=[]
keys=sorted({k for label,k,policy in metrics if label=='new'})
for key in keys:
 for policy in ['accepted','strict']:
  for phase in ['P','S']:
   a=next(r for r in metrics[('old',key,policy)] if r['Phase']==phase and r['Tolerance_ms']==100);b=next(r for r in metrics[('new',key,policy)] if r['Phase']==phase and r['Tolerance_ms']==100)
   comparison.append(dict(evaluation=key,policy=policy,phase=phase,old_F1=a['F1'],new_F1=b['F1'],delta_F1=b['F1']-a['F1'],old_MAE_ms=a['MAE_ms'],new_MAE_ms=b['MAE_ms'],old_MedAE_ms=a['MedAE_ms'],new_MedAE_ms=b['MedAE_ms'],old_coverage=a['AcceptedCoverage'],new_coverage=b['AcceptedCoverage']))
write(out/'old_new_per_fit_100ms.csv',comparison)
summary=[]
for mode in ['Full3C','Zonly']:
 variants=['full15ch','probonly12','waveonly3','nodilation','logistic'] if mode=='Full3C' else ['full15ch']
 for variant in variants:
  seeds=[42] if variant=='logistic' else [42,43,44]
  for policy in ['accepted','strict']:
   for phase in ['P','S']:
    z={'mode':mode,'variant':variant,'policy':policy,'phase':phase,'meta_seed_count':len(seeds)}
    for label in ['old','new']:
     vals=[next(r for r in metrics[(label,f'{mode}/evaluation/{variant}_seed{s}',policy)] if r['Phase']==phase and r['Tolerance_ms']==100) for s in seeds]
     z[label+'_F1']=statistics.mean(r['F1'] for r in vals);z[label+'_F1_SD']=statistics.stdev(r['F1'] for r in vals) if len(vals)>1 else None
     for col in ['MAE_ms','MedAE_ms','AcceptedCoverage','OutlierRate1s']:z[label+'_'+col]=statistics.mean(r[col] for r in vals)
    z['delta_F1']=z['new_F1']-z['old_F1'];summary.append(z)
write(out/'old_new_meta_seed_summary_100ms.csv',summary)
# Verify saved aggregate tables independently.
for label,root in [('old',old),('new',new)]:
 for row in read(root/'multiseed_summary_clean.csv'):
  seeds=[42] if row['Variant']=='logistic' else [42,43,44];vals=[next(r for r in metrics[(label,f"{row['Mode']}/evaluation/{row['Variant']}_seed{s}",'accepted')] if r['Phase']==row['Phase'] and r['Tolerance_ms']==int(row['Tolerance_ms'])) for s in seeds]
  for col in ['F1','MAE_ms','AcceptedCoverage']:assert math.isclose(statistics.mean(r[col] for r in vals),num(row['mean_'+col]),rel_tol=1e-10,abs_tol=1e-6)
# Validate actual prediction populations and OOF versus prepared protocol.
prepared=Path(r'D:\STEAD_identity_recovery\prepared_source_v2');membership=read(prepared/'partition_membership.csv');test={r['event_id']:r for r in membership if r['split']=='test'};meta={r['event_id']:r for r in read(prepared/'metadata/metadata_verified.csv')};sources={s:{r['source_id'] for r in membership if r['split']==s} for s in ['train','val','test']}
assert not(sources['train']&sources['test'] or sources['train']&sources['val'] or sources['test']&sources['val'])
for (label,key),t in tables.items():
 if label!='new':continue
 assert {r['event_id'] for r in t}==set(test)
 for r in t:
  assert r['source_id']==test[r['event_id']]['source_id']
  assert math.isclose(num(r['p_true_sec']),num(meta[r['event_id']]['csv_p_arrival_sec']),abs_tol=1e-9)
  assert math.isclose(num(r['s_true_sec']),num(meta[r['event_id']]['csv_s_arrival_sec']),abs_tol=1e-9)
for mode in ['Full3C','Zonly']:
 actual=read(new/mode/'oof_membership.csv');expected={r['event_id']:r for r in membership if r['split']=='train'};assert len(actual)==len(expected)==1544
 for r in actual:assert r['source_id']==expected[r['event_id']]['source_id'] and r['fold']==expected[r['event_id']]['fold']
oldtest={r['event_id'] for r in tables[('old','Full3C/evaluation/full15ch_seed42')]};newtest=set(test)
# Paired cluster bootstrap is only within the NEW fixed split and fitted base seed42.
u=sorted(sources['test']);idx={s:i for i,s in enumerate(u)};rng=np.random.default_rng(42);W=rng.multinomial(len(u),np.full(len(u),1/len(u)),size=10000)
def stat(key,phase):
 t=tables[('new',key)];z=np.zeros((len(u),3),dtype=np.int64)
 for r in t:
  e=abs(1000*(num(r[phase+'_pred_sec'])-num(r[phase+'_true_sec'])));a=math.isfinite(e) and r[phase+'_status'] in ['detected','uncertain'];j=idx[r['source_id']];z[j]+=[1,int(a),int(a and e<=100+1e-7)]
 return 2*z[:,2].sum()/(z[:,0]+z[:,1]).sum(),2*(W@z[:,2])/(W@(z[:,0]+z[:,1]))
boots=[]
for comparator in ['Zonly','TCN','CNN','weighted_ensemble','mean_ensemble','probonly12','waveonly3','nodilation','logistic']:
 for phase in ['p','s']:
  ap=[];bp=[];aa=[];bb=[]
  for seed in [42,43,44]:
   ak=f'Full3C/evaluation/full15ch_seed{seed}'
   bk=f'Zonly/evaluation/full15ch_seed{seed}' if comparator=='Zonly' else f'Full3C/baselines/{comparator}' if comparator in ['TCN','CNN','weighted_ensemble','mean_ensemble'] else f"Full3C/evaluation/{comparator}_seed{42 if comparator=='logistic' else seed}"
   a,b=stat(ak,phase);ap.append(a);aa.append(b);a,b=stat(bk,phase);bp.append(a);bb.append(b)
  d=np.mean(aa,axis=0)-np.mean(bb,axis=0);lo,hi=np.quantile(d,[.025,.975]);boots.append(dict(comparison='Full3C stacker minus '+comparator,phase=phase.upper(),F1_A=float(np.mean(ap)),F1_B=float(np.mean(bp)),delta=float(np.mean(ap)-np.mean(bp)),CI_low=float(lo),CI_high=float(hi)))
write(out/'new_split_paired_bootstrap_100ms.csv',boots)
report={'prediction_sets_per_run':len(keys),'metric_policy_sets_per_run':len(keys)*3,'recomputed_metric_rows':len(allrows),'numeric_discrepancies':len(checks),'new_test_records':len(test),'new_test_sources':len(u),'old_test_records':len(oldtest),'shared_test_records':len(newtest&oldtest),'new_test_records_not_in_old_test':len(newtest-oldtest),'actual_oof_matches_frozen_protocol':True,'all_new_prediction_identities_and_reference_labels_verified':True,'outer_source_overlap':0,'bootstrap_draws':10000,'bootstrap_scope':'Paired within new test sources, mean across meta seeds42/43/44, fixed base seed42; exploratory unadjusted 95% intervals. Not a paired old/new split comparison.','strengthening_complete':False}
(out/'audit_summary.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2));print('MAIN',json.dumps([r for r in summary if r['variant']=='full15ch'],indent=2));print('BOOT',json.dumps(boots,indent=2))
