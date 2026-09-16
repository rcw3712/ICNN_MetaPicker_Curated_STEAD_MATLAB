from pathlib import Path
import csv,json,hashlib,math,statistics,sys
sys.path.insert(0,str(Path(__file__).parent/'revision/pylibs'))
import numpy as np
w=Path(__file__).parent; out=w/'audit_20260916';out.mkdir(exist_ok=True)
r=Path(r'C:\Drive E\ICNN_strengthening_results\v1');old=Path(r'C:\Drive E\ICNN_submission_results\submission40_v5_oofstream')
issues=[];checks=0;hashcache={};pred={};allmetrics=[]
def read(p):return list(csv.DictReader(open(p,encoding='utf-8-sig')))
def h(p):
 p=str(p)
 if p not in hashcache:hashcache[p]=hashlib.file_digest(open(p,'rb'),'sha256').hexdigest()
 return hashcache[p]
for manifest in r.rglob('manifest.csv'):
 for a in read(manifest):
  checks+=1
  if h(a['files'])!=a['hashes'].lower():issues.append('manifest '+a['files'])
ref=None
for method in ['Stack','PhaseNetMatched']:
 for mode in ['Full3C','Zonly']:
  for b in [42,43,44]:
   for s in ([42,43,44] if method=='Stack' else [b]):
    folder=(old/mode/'evaluation' if b==42 else r/f'base_{b}'/mode/mode/'evaluation') if method=='Stack' else r/'phasenet'/mode/f'seed_{b}'/mode/'evaluation'
    stem=f'full15ch_seed{s}' if method=='Stack' else f'PhaseNetMatched_seed{s}'
    data=sorted(read(folder/(stem+'_predictions.csv')),key=lambda x:x['event_id'])
    ids=[(a['event_id'],a['source_id'],a['p_true_sec'],a['s_true_sec']) for a in data]
    if ref is None:ref=ids
    assert ids==ref and len(ids)==335 and len(set(a[1] for a in ids))==317
    pred[(method,mode,b,s)]=data
    for policy in ['accepted','strict']:
     metrics=read(folder/(stem+f'_{policy}_metrics.csv'))
     for a in metrics:
      ph=a['Phase'].lower();tol=float(a['Tolerance_ms']);e=np.array([1000*(float(x[ph+'_pred_sec'])-float(x[ph+'_true_sec'])) for x in data]);status=np.array([x[ph+'_status'] for x in data]);acc=np.isfinite(e)&np.isin(status,['detected','uncertain'] if policy=='accepted' else ['detected']);v=np.abs(e[acc]);n=int(acc.sum());tp=int((acc&(np.abs(e)<=tol+1e-7)).sum())
      calc={'N':335,'N_accepted':n,'N_strict_detected':int((np.isfinite(e)&(status=='detected')).sum()),'TP':tp,'FP':n-tp,'FN':335-tp,'Precision':tp/max(1,n),'Recall':tp/335,'F1':2*tp/(335+n),'AcceptedCoverage':n/335,'MAE_ms':v.mean(),'MedAE_ms':np.median(v),'RMSE_ms':np.sqrt((v*v).mean()),'OutlierRate1s':(v>1000).mean()}
      for k,val in calc.items():
       if not math.isclose(float(a[k]),val,rel_tol=1e-8,abs_tol=1e-7):issues.append(f'{method} {mode} {b} {s} {policy} {ph} {tol} {k}')
      allmetrics.append(dict(Method=method,Mode=mode,BaseSeed=b,MetaSeed=s if method=='Stack' else '',Policy=policy,Phase=ph.upper(),Tolerance_ms=int(tol),**calc))
with open(out/'recomputed_metrics.csv','w',newline='') as f:
 wr=csv.DictWriter(f,fieldnames=list(allmetrics[0]));wr.writeheader();wr.writerows(allmetrics)
# Average per-fit F1 in each bootstrap, never pool counts or treat meta fits as independent.
sources=sorted(set(a[1] for a in ref));index={v:i for i,v in enumerate(sources)};g=np.array([index[a[1]] for a in ref]);K=len(sources)
rng=np.random.default_rng(42);draws=rng.integers(0,K,size=(10000,K));mult=np.zeros((10000,K),dtype=np.int16)
for i,d in enumerate(draws):mult[i]=np.bincount(d,minlength=K)
N=np.bincount(g,minlength=K);boot={};points={}
for key,data in pred.items():
 for ph in ['P','S']:
  low=ph.lower();e=np.array([abs(1000*(float(a[low+'_pred_sec'])-float(a[low+'_true_sec']))) for a in data]);acc=np.array([a[low+'_status'] in ['detected','uncertain'] for a in data])&np.isfinite(e)
  for tol in [50,100,200]:
   tp=acc&(e<=tol+1e-7);ac=np.bincount(g,weights=acc,minlength=K);tc=np.bincount(g,weights=tp,minlength=K)
   boot[key+(ph,tol)]=2*(mult@tc)/(mult@(N+ac));points[key+(ph,tol)]=2*tp.sum()/(335+acc.sum())
summary=[];ci=[]
for mode in ['Full3C','Zonly']:
 for ph in ['P','S']:
  for tol in [50,100,200]:
   for method in ['Stack','PhaseNetMatched']:
    a=[x for x in allmetrics if x['Method']==method and x['Mode']==mode and x['Phase']==ph and x['Tolerance_ms']==tol and x['Policy']=='accepted']
    basemeans=[statistics.mean(x['F1'] for x in a if x['BaseSeed']==b) for b in [42,43,44]]
    summary.append(dict(Method=method,Mode=mode,Phase=ph,Tolerance_ms=tol,F1=statistics.mean(x['F1'] for x in a),SD_between_base_means=statistics.stdev(basemeans),Minimum=min(x['F1'] for x in a),Maximum=max(x['F1'] for x in a),MAE_ms=statistics.mean(x['MAE_ms'] for x in a),Coverage=statistics.mean(x['AcceptedCoverage'] for x in a)))
def group(method,mode,ph,tol):
 keys=[k for k in pred if k[0]==method and k[1]==mode]
 return np.mean([boot[k+(ph,tol)] for k in keys],axis=0),statistics.mean(points[k+(ph,tol)] for k in keys)
for ph in ['P','S']:
 for tol in [50,100,200]:
  for label,A,B in [('Stack Full3C minus Zonly',('Stack','Full3C'),('Stack','Zonly')),('PhaseNetMatched Full3C minus Zonly',('PhaseNetMatched','Full3C'),('PhaseNetMatched','Zonly')),('Stack minus PhaseNetMatched Full3C',('Stack','Full3C'),('PhaseNetMatched','Full3C')),('Stack minus PhaseNetMatched Zonly',('Stack','Zonly'),('PhaseNetMatched','Zonly'))]:
   ba,pa=group(*A,ph,tol);bb,pb=group(*B,ph,tol);lo,hi=np.quantile(ba-bb,[.025,.975]);ci.append(dict(Comparison=label,Phase=ph,Tolerance_ms=tol,Delta=pa-pb,Low=float(lo),High=float(hi)))
for name,rows in [('summary',summary),('paired_intervals',ci)]:
 with open(out/(name+'.csv'),'w',newline='') as f:
  wr=csv.DictWriter(f,fieldnames=list(rows[0]));wr.writeheader();wr.writerows(rows)
result=dict(issues=issues,manifest_entries_checked=checks,unique_hashed_files=len(hashcache),prediction_tables=len(pred),metric_rows_checked=len(allmetrics),summary=summary,intervals=ci)
(out/'audit.json').write_text(json.dumps(result,indent=2))
print(json.dumps({k:v for k,v in result.items() if k not in ['summary','intervals']}))
for x in summary:
 if x['Tolerance_ms']==100:print(x)
for x in ci:
 if x['Tolerance_ms']==100:print(x)
assert not issues
