from pathlib import Path
import sys,csv,json,math,statistics,hashlib,collections,re
w=Path(__file__).parent;sys.path.insert(0,str(w/'revision/pylibs'))
import numpy as np
import h5py
exec((w/'audit_interim_results_v2.py').read_text().split('checks=[]')[0].split('new=Path')[0])
out=w/'audit_full_20260918';out.mkdir(exist_ok=True)
exec((w/'audit_interim_results_v2.py').read_text().split('def read(p):')[1].split('checks=[]')[0].join(['def read(p):','']))
root=Path(r'D:\ICNN_source_verified_results\v2');prep=Path(r'D:\STEAD_identity_recovery\prepared_source_v2')
mem=read(prep/'partition_membership.csv');test={r['event_id']:r for r in mem if r['split']=='test'};meta={r['event_id']:r for r in read(prep/'metadata/metadata_verified.csv')}
sets={s:{r['source_id'] for r in mem if r['split']==s} for s in ['train','val','test']};assert all(not sets[a]&sets[b] for a,b in [('train','val'),('train','test'),('val','test')])
allrows=[];preds={};met={};mismatches=[];input_hashes=[]
for f in sorted(root.rglob('*_predictions.csv')):
 if 'audit_' in str(f) or '_unconstrained_' in f.name:continue
 key=f.relative_to(root).as_posix().replace('_predictions.csv','');t=read(f);preds[key]=t
 assert len(t)==330 and {r['event_id'] for r in t}==set(test),key
 for r in t:
  assert r['source_id']==test[r['event_id']]['source_id'],key
  for ph in ['p','s']:assert abs(num(r[ph+'_true_sec'])-num(meta[r['event_id']]['csv_'+ph+'_arrival_sec']))<1e-9
 for policy in ['accepted','strict','unconstrained']:
  pf=f if policy!='unconstrained' else f.with_name(f.name.replace('_predictions.csv','_unconstrained_predictions.csv'))
  tt=read(pf);assert [(r['event_id'],r['source_id'],r['p_true_sec'],r['s_true_sec']) for r in tt]==[(r['event_id'],r['source_id'],r['p_true_sec'],r['s_true_sec']) for r in t]
  c=calc(tt,policy=='strict');rf=f.with_name(f.name.replace('_predictions.csv','_'+policy+'_metrics.csv'));reported=read(rf)
  for a,b in zip(c,reported):
   assert a['Phase']==b['Phase']
   for col in a.keys()-{'Phase'}:
    x=a[col];y=num(b[col]);ok=(math.isnan(x) and math.isnan(y)) or math.isclose(x,y,abs_tol=1e-6,rel_tol=1e-10)
    if not ok:mismatches.append([key,policy,col,x,y])
  met[key,policy]=c;allrows.extend(dict(evaluation=key,policy=policy,**r) for r in c)
  for path in [pf,rf]:input_hashes.append(dict(path=str(path),sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
assert not mismatches,mismatches[:5]
write(out/'recomputed_all_metrics.csv',allrows);write(out/'audited_input_hashes.csv',list({r['path']:r for r in input_hashes}.values()))
def key(mode,b=42,m=42,method='Stack'):
 if method=='PhaseNetMatched':return f'strengthening/phasenet/{mode}/seed_{b}/{mode}/evaluation/PhaseNetMatched_seed{b}'
 prefix='submission40' if b==42 else f'strengthening/base_{b}/{mode}'
 return f'{prefix}/{mode}/evaluation/full15ch_seed{m}'
def metric(k,ph,tol=100,policy='accepted'):return next(r for r in met[k,policy] if r['Phase']==ph and r['Tolerance_ms']==tol)
for r in read(root/'strengthening/strengthening_metrics.csv'):
 k=key(r['Mode'],int(r['BaseSeed']),int(r['MetaSeed']) if r['Method']=='Stack' else 42,r['Method']);a=metric(k,r['Phase'],int(r['Tolerance_ms']))
 for col in a.keys()-{'Phase'}:
  assert math.isclose(a[col],num(r[col]),abs_tol=1e-6,rel_tol=1e-10),(k,col)
summary=[];within=[]
for method in ['Stack','PhaseNetMatched']:
 for mode in ['Full3C','Zonly']:
  for policy in ['accepted','strict']:
   for ph in ['P','S']:
    for tol in [50,100,200]:
     base=[]
     for b in [42,43,44]:
      rows=[metric(key(mode,b,m,method),ph,tol,policy) for m in ([42,43,44] if method=='Stack' else [b])]
      z=dict(Method=method,Mode=mode,Policy=policy,Phase=ph,Tolerance_ms=tol,BaseSeed=b)
      for col in ['F1','MAE_ms','AcceptedCoverage','MedAE_ms','RMSE_ms','OutlierRate1s']:z[col]=statistics.mean(r[col] for r in rows)
      z['meta_F1_SD']=statistics.stdev(r['F1'] for r in rows) if len(rows)>1 else 0
      within.append(z);base.append(z)
     z=dict(Method=method,Mode=mode,Policy=policy,Phase=ph,Tolerance_ms=tol)
     for col in ['F1','MAE_ms','AcceptedCoverage','MedAE_ms','RMSE_ms','OutlierRate1s']:
      z['mean_'+col]=statistics.mean(r[col] for r in base);z['SD_'+col]=statistics.stdev(r[col] for r in base)
     summary.append(z)
write(out/'expanded_summary.csv',summary);write(out/'within_base_summary.csv',within)
for r in read(root/'strengthening/stack_meta_averages_within_base.csv'):
 a=next(z for z in within if z['Method']=='Stack' and z['Policy']=='accepted' and z['Mode']==r['Mode'] and z['BaseSeed']==int(r['BaseSeed']) and z['Phase']==r['Phase'] and z['Tolerance_ms']==int(r['Tolerance_ms']))
 for col in ['F1','MAE_ms','AcceptedCoverage']:assert math.isclose(a[col],num(r['mean_'+col]),abs_tol=1e-6,rel_tol=1e-10)
# Common source resampling across every fitted method; no pseudo-replication of meta fits.
u=sorted(sets['test']);idx={s:i for i,s in enumerate(u)};W=np.random.default_rng(42).multinomial(len(u),np.full(len(u),1/len(u)),size=10000);cache={}
def stat(k,ph,tol=100):
 if (k,ph,tol) in cache:return cache[k,ph,tol]
 z=np.zeros((len(u),3),dtype=np.int64)
 for r in preds[k]:
  e=abs(1000*(num(r[ph.lower()+'_pred_sec'])-num(r[ph.lower()+'_true_sec'])));a=math.isfinite(e) and r[ph.lower()+'_status'] in ['detected','uncertain'];z[idx[r['source_id']]]+=[1,int(a),int(a and e<=tol+1e-7)]
 v=(2*z[:,2].sum()/(z[:,0]+z[:,1]).sum(),2*(W@z[:,2])/(W@(z[:,0]+z[:,1])))
 cache[k,ph,tol]=v;return v
def avg(keys,ph,tol=100):
 v=[stat(k,ph,tol) for k in keys];return np.mean([a for a,b in v]),np.mean([b for a,b in v],axis=0)
def keys(method,mode):return [key(mode,b,m,method) for b in [42,43,44] for m in ([42,43,44] if method=='Stack' else [b])]
boot=[]
for ph in ['P','S']:
 for name,ka,kb in [('Stack Full3C minus Zonly',keys('Stack','Full3C'),keys('Stack','Zonly')),('PhaseNet Full3C minus Zonly',keys('PhaseNetMatched','Full3C'),keys('PhaseNetMatched','Zonly'))]+[(f'Stack minus PhaseNet {mode}',keys('Stack',mode),keys('PhaseNetMatched',mode)) for mode in ['Full3C','Zonly']]:
  a,aa=avg(ka,ph);b,bb=avg(kb,ph);lo,hi=np.quantile(aa-bb,[.025,.975]);boot.append(dict(Comparison=name,Phase=ph,F1_A=a,F1_B=b,Delta=a-b,CI_low=lo,CI_high=hi))
write(out/'expanded_paired_bootstrap.csv',boot)
baseboot=[]
for ph in ['P','S']:
 for tol in [50,100,200]:
  a,aa=avg([key('Full3C',42,m) for m in [42,43,44]],ph,tol);b,bb=avg([key('Zonly',42,m) for m in [42,43,44]],ph,tol)
  for name,p,draw in [('Full3C',a,aa),('Zonly',b,bb),('Full3C minus Zonly',a-b,aa-bb)]:
   lo,hi=np.quantile(draw,[.025,.975]);baseboot.append(dict(Comparison=name,Phase=ph,Tolerance_ms=tol,Estimate=p,CI_low=lo,CI_high=hi))
write(out/'base42_bootstrap.csv',baseboot)
# Audit actual OOF manifests.
oofs=list(root.rglob('oof_membership.csv'));expected={r['event_id']:r for r in mem if r['split']=='train'}
for f in oofs:
 rr=read(f);assert len(rr)==1544
 assert {r['event_id'] for r in rr}==set(expected)
 for r in rr:assert r['source_id']==expected[r['event_id']]['source_id'] and r['fold']==expected[r['event_id']]['fold']
# Verify every unique file referenced by every fit manifest once, compare all occurrences.
manifests=list(root.rglob('manifest.csv'));print('manifest example',read(manifests[0])[0],flush=True)
# Population descriptions use recovered metadata, not the invalid ordinal join.
pop={}
for s in ['all','train','val','test']:
 rr=list(meta.values()) if s=='all' else [meta[r['event_id']] for r in mem if r['split']==s]
 def arr(c):return np.array([num(r[c]) for r in rr])
 networks=collections.Counter(r['network_code'] for r in rr);stations={r['network_code']+'.'+r['receiver_code'] for r in rr}
 pop[s]=dict(records=len(rr),sources=len({r['source_id'] for r in rr}),networks=dict(networks),station_keys=len(stations),aic_late_P=int(sum(arr('csv_p_arrival_sec')>9.99)),aic_late_S=int(sum(arr('csv_s_arrival_sec')>9.99)),distance_le15=int(sum(arr('source_distance_km')<=15)),magnitude_ge1p5=int(sum(arr('source_magnitude')>=1.5)),snr_ge10=int(sum(arr('min_snr_db')>=10)),all_three_filters=int(sum((arr('source_distance_km')<=15)&(arr('source_magnitude')>=1.5)&(arr('min_snr_db')>=10))))
 for c in ['source_distance_km','source_magnitude','min_snr_db','sp_time_sec']:pop[s][c]=dict(min=float(np.nanmin(arr(c))),max=float(np.nanmax(arr(c))),median=float(np.nanmedian(arr(c))))
(out/'population.json').write_text(json.dumps(pop,indent=2));(out/'metric_audit.json').write_text(json.dumps(dict(prediction_sets=len(preds),metric_rows=len(allrows),mismatches=len(mismatches),test_records=330,test_sources=221,oof_manifests=len(oofs),source_overlap=0),indent=2))
print('SUMMARY',json.dumps([r for r in summary if r['Tolerance_ms']==100 and r['Policy']=='accepted'],indent=2));print('BOOT',json.dumps(boot,indent=2));print('POP',json.dumps(pop['all'],indent=2))

