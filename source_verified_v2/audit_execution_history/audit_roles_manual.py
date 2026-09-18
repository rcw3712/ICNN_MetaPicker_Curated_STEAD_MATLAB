from pathlib import Path
import sys,csv,json,collections,hashlib,math,statistics
w=Path(__file__).parent;sys.path.insert(0,str(w/'revision/pylibs'));import numpy as np
out=w/'audit_no_training_20260918';out.mkdir(exist_ok=True)
def read(p):
 with Path(p).open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def write(name,rows):
 if not rows:return
 with (out/name).open('w',encoding='utf-8',newline='') as f:
  wr=csv.DictWriter(f,fieldnames=list(rows[0]));wr.writeheader();wr.writerows(rows)
prep=Path(r'D:\STEAD_identity_recovery\prepared_source_v2');root=Path(r'D:\ICNN_source_verified_results\v2')
paths=[prep/'partition_membership.csv',prep/'metadata/metadata_verified.csv',Path(r'D:\STEAD_identity_recovery\audit_20260916\recovered_mapping_2234.csv')]
mem={r['event_id']:r for r in read(paths[0])};meta={r['event_id']:r for r in read(paths[1])};old={r['event_id']:r for r in read(paths[2])}
assert set(mem)==set(meta)==set(old) and len(mem)==2234
roles=['train','val','test'];oldroot=w/'cg_scope_20260916/reproducibility_20260916/inputs/training_inputs/results/splits'
oldsets={}
for role in roles:
 p=oldroot/(role+'_source_ids.csv');paths.append(p);oldsets[role]={r['source_id'] for r in read(p)}
history=collections.defaultdict(set);current=collections.defaultdict(set);records=[]
for event,r in mem.items():
 o=old[event];m=meta[event];assert r['source_id']==m['source_id']==o['verified_source_id']
 assert [s for s in roles if o['old_source_id'] in oldsets[s]]==[o['split']]
 history[r['source_id']].add(o['split']);current[r['source_id']].add(r['split'])
 records.append(dict(event_id=event,verified_source_id=r['source_id'],historical_role=o['split'],corrected_role=r['split'],p_status=m['p_status'],s_status=m['s_status'],both_manual=m['p_status']=='manual' and m['s_status']=='manual',station_key=m['network_code']+'.'+m['receiver_code']))
assert all(len(x)==1 for x in current.values())
oldpred=w/'sync_repo/submission_20260915/frozen/Full3C/evaluation/full15ch_seed42_predictions.csv';paths.append(oldpred)
assert {r['event_id'] for r in read(oldpred)}=={r['event_id'] for r in records if r['historical_role']=='test'}
for r in records:
 hist=history[r['verified_source_id']];r['historical_source_roles']='|'.join(s for s in roles if s in hist);r['source_historical_train_or_val']=bool(hist&{'train','val'})
write('record_role_transitions.csv',records)
write('record_role_matrix.csv',[dict(historical_role=a,**{b:sum(r['historical_role']==a and r['corrected_role']==b for r in records) for b in roles}) for a in roles])
write('source_role_nonexclusive_matrix.csv',[dict(historical_role=a,**{b:sum(a in history[s] and b in current[s] for s in history) for b in roles}) for a in roles])
patterns=sorted({r['historical_source_roles'] for r in records})
write('source_role_patterns_exclusive.csv',[dict(historical_roles=a,**{b:len({r['verified_source_id'] for r in records if r['historical_source_roles']==a and r['corrected_role']==b}) for b in roles}) for a in patterns])
write('source_role_memberships.csv',[dict(source_id=s,historical_roles='|'.join(x for x in roles if x in history[s]),corrected_role=next(iter(current[s])),historical_train='train' in history[s],historical_val='val' in history[s],historical_test='test' in history[s]) for s in sorted(history)])
test={r['event_id']:r for r in records if r['corrected_role']=='test'}
label=[]
for split in roles:
 rr=[r for r in records if r['corrected_role']==split];c=collections.Counter((r['p_status'],r['s_status']) for r in rr)
 for (p,s),n in sorted(c.items()):label.append(dict(split=split,p_status=p,s_status=s,records=n,sources=len({r['verified_source_id'] for r in rr if r['p_status']==p and r['s_status']==s}),fraction=n/len(rr)))
write('reference_status_by_split.csv',label)
subsets={'all_test':set(test),'manual_both':{e for e,r in test.items() if r['both_manual']},'includes_nonmanual':{e for e,r in test.items() if not r['both_manual']},'historical_test_records':{e for e,r in test.items() if r['historical_role']=='test'},'sources_without_historical_train_val':{e for e,r in test.items() if not r['source_historical_train_or_val']}}
subsets['manual_both_sources_without_historical_train_val']=subsets['manual_both']&subsets['sources_without_historical_train_val']
assert subsets['manual_both'].isdisjoint(subsets['includes_nonmanual']) and subsets['manual_both']|subsets['includes_nonmanual']==set(test)
ss=[dict(subset=k,records=len(v),sources=len({test[e]['verified_source_id'] for e in v}),development_naive_established=False) for k,v in subsets.items()]
write('subset_sizes.csv',ss)
def predpath(method,mode,b,m):
 if method=='PhaseNetMatched':return root/f'strengthening/phasenet/{mode}/seed_{b}/{mode}/evaluation/PhaseNetMatched_seed{b}_predictions.csv'
 prefix='submission40' if b==42 else f'strengthening/base_{b}/{mode}'
 return root/f'{prefix}/{mode}/evaluation/full15ch_seed{m}_predictions.csv'
preds={}
for method in ['Stack','PhaseNetMatched']:
 for mode in ['Full3C','Zonly']:
  for b in [42,43,44]:
   for m in ([42,43,44] if method=='Stack' else [b]):
    path=predpath(method,mode,b,m);paths.append(path);rr=read(path);assert len(rr)==330 and {r['event_id'] for r in rr}==set(test)
    for r in rr:
     assert r['source_id']==test[r['event_id']]['verified_source_id']
     for ph in ['p','s']:assert abs(float(r[ph+'_true_sec'])-float(meta[r['event_id']]['csv_'+ph+'_arrival_sec']))<1e-9
    preds[method,mode,b,m]=rr
metrics=[];summaries=[];boots=[]
for subset,ids in subsets.items():
 if not ids:continue
 sources=sorted({test[e]['verified_source_id'] for e in ids});index={s:i for i,s in enumerate(sources)}
 W=np.random.default_rng(42).multinomial(len(sources),np.full(len(sources),1/len(sources)),size=10000)
 draws={};point={}
 for key,rows in preds.items():
  rr=[r for r in rows if r['event_id'] in ids]
  for policy in ['accepted','strict']:
   for phase in ['P','S']:
    p=phase.lower();err=np.array([1000*(float(r[p+'_pred_sec'])-float(r[p+'_true_sec'])) for r in rr]);a=np.array([r[p+'_status'] in (['detected','uncertain'] if policy=='accepted' else ['detected']) for r in rr])&np.isfinite(err);ae=np.abs(err[a]);N=len(rr);na=int(a.sum())
    for tol in [50,100,200]:
     hit=a&(np.abs(err)<=tol+1e-7);tp=int(hit.sum());v=dict(subset=subset,Method=key[0],Mode=key[1],BaseSeed=key[2],MetaSeed=key[3] if key[0]=='Stack' else '',Policy=policy,Phase=phase,Tolerance_ms=tol,N=N,N_sources=len(sources),N_accepted=na,TP=tp,FP=na-tp,FN=N-tp,F1=2*tp/(N+na),Coverage=na/N,MAE_ms=float(ae.mean()) if na else math.nan,MedianAE_ms=float(np.median(ae)) if na else math.nan,RMSE_ms=float(np.sqrt(np.mean(ae**2))) if na else math.nan,P90AE_ms=float(np.quantile(ae,.9)) if na else math.nan,Outlier1s=float(np.mean(ae>1000)) if na else math.nan);metrics.append(v)
     if tol==100:
      z=np.zeros((len(sources),3),dtype=np.int64)
      for i,r in enumerate(rr):z[index[r['source_id']]]+=[1,int(a[i]),int(hit[i])]
      draws[key,policy,phase]=2*(W@z[:,2])/(W@(z[:,0]+z[:,1]));point[key,policy,phase]=v['F1']
 for method in ['Stack','PhaseNetMatched']:
  for mode in ['Full3C','Zonly']:
   for policy in ['accepted','strict']:
    for phase in ['P','S']:
     for tol in [50,100,200]:
      z=[r for r in metrics if r['subset']==subset and r['Method']==method and r['Mode']==mode and r['Policy']==policy and r['Phase']==phase and r['Tolerance_ms']==tol]
      d=dict(subset=subset,Method=method,Mode=mode,Policy=policy,Phase=phase,Tolerance_ms=tol,N=len(ids),N_sources=len(sources))
      for col in ['F1','Coverage','MAE_ms','MedianAE_ms','RMSE_ms','P90AE_ms','Outlier1s']:
       means=[statistics.mean(r[col] for r in z if r['BaseSeed']==b) for b in [42,43,44]];d['mean_'+col]=statistics.mean(means);d['between_base_SD_'+col]=statistics.stdev(means)
      summaries.append(d)
 def avg(method,mode,policy,phase):
  keys=[k for k in preds if k[:2]==(method,mode)]
  return np.mean([point[k,policy,phase] for k in keys]),np.mean([draws[k,policy,phase] for k in keys],axis=0)
 for policy in ['accepted','strict']:
  for phase in ['P','S']:
   for name,ma,moa,mb,mob in [('Stack Full3C minus Zonly','Stack','Full3C','Stack','Zonly'),('PhaseNet Full3C minus Zonly','PhaseNetMatched','Full3C','PhaseNetMatched','Zonly'),('Stack minus PhaseNet Full3C','Stack','Full3C','PhaseNetMatched','Full3C'),('Stack minus PhaseNet Zonly','Stack','Zonly','PhaseNetMatched','Zonly')]:
    a,aa=avg(ma,moa,policy,phase);b,bb=avg(mb,mob,policy,phase);ci=np.quantile(aa-bb,[.025,.975]);boots.append(dict(subset=subset,Policy=policy,Phase=phase,Comparison=name,N=len(ids),N_sources=len(sources),F1_A=float(a),F1_B=float(b),Delta=float(a-b),CI_low=float(ci[0]),CI_high=float(ci[1]),bootstrap_draws=10000))
 print('SUBSET DONE',subset,len(ids),len(sources),flush=True)
write('sensitivity_per_fit.csv',metrics);write('sensitivity_summary.csv',summaries);write('sensitivity_paired_bootstrap_100ms.csv',boots)
# All-test arithmetic must independently match the earlier complete audit.
oldsummary=read(w/'audit_full_20260918/expanded_summary.csv')
for a in [r for r in summaries if r['subset']=='all_test']:
 b=next(x for x in oldsummary if all(str(x[k])==str(a[k]) for k in ['Method','Mode','Policy','Phase','Tolerance_ms']))
 for col in ['F1','MAE_ms']:assert math.isclose(a['mean_'+col],float(b['mean_'+col]),abs_tol=1e-12)
oldboot=read(w/'audit_full_20260918/expanded_paired_bootstrap.csv')
for a in [r for r in boots if r['subset']=='all_test' and r['Policy']=='accepted']:
 b=next(x for x in oldboot if x['Comparison']==a['Comparison'] and x['Phase']==a['Phase'])
 for k in ['Delta','CI_low','CI_high']:assert math.isclose(a[k],float(b[k]),abs_tol=1e-12)
summary={'records':len(records),'sources':len(history),'current_test_record_history':dict(collections.Counter(r['historical_role'] for r in test.values())),'current_test_source_history_nonexclusive':{s:len({r['verified_source_id'] for r in test.values() if s in history[r['verified_source_id']]}) for s in roles},'current_test_records_from_sources_with_historical_train_val':sum(r['source_historical_train_or_val'] for r in test.values()),'current_test_sources_with_historical_train_val':len({r['verified_source_id'] for r in test.values() if r['source_historical_train_or_val']}),'sources_never_in_any_historical_role':len(set(current)-set(history)),'subsets':ss,'prior_all_test_summary_and_bootstrap_reproduced':True,'prediction_sets':len(preds),'metric_rows':len(metrics),'scope':'Historical roles refer to the archived pre-v2 experiment, not a complete reconstruction of every earlier development decision. No development-naive subset is established.'}
(out/'role_and_sensitivity_summary.json').write_text(json.dumps(summary,indent=2))
write('analysis_input_hashes.csv',[dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in paths])
print(json.dumps(summary,indent=2));print('MAIN',json.dumps([r for r in boots if r['subset'] in ['all_test','manual_both','includes_nonmanual','sources_without_historical_train_val'] and r['Policy']=='accepted' and r['Phase']=='S'],indent=2))
