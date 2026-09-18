from pathlib import Path
import os,sys,csv,json,math,statistics,itertools
os.environ['OPENBLAS_NUM_THREADS']='2'
w=Path(__file__).parent;sys.path.insert(0,str(w/'revision/pylibs'));import numpy as np
root=w/'audit_replay_threshold_station_20260918';out=root/'threshold';out.mkdir(exist_ok=True)
def read(p):
 with Path(p).open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def write(name,rows):
 with (out/name).open('w',newline='',encoding='utf-8') as f:
  wr=csv.DictWriter(f,fieldnames=list(rows[0]));wr.writeheader();wr.writerows(rows)
jobs=[r for r in read(root/'test_jobs.csv') if r['kind'] in ['full15ch','PhaseNetMatched']];assert len(jobs)==24
rows=[]
for j in jobs:
 rr=read(root/j['group']/(j['label']+'_threshold_statistics.csv'));assert len(rr)==330;rows.append(rr)
events=[r['event_id'] for r in rows[0]];sources=[r['source_id'] for r in rows[0]]
assert len(set(events))==330
for rr in rows:assert [r['event_id'] for r in rr]==events and [r['source_id'] for r in rr]==sources
u=sorted(set(sources));idx=np.array([u.index(s) for s in sources]);W=np.random.default_rng(42).multinomial(len(u),np.full(len(u),1/len(u)),size=10000).astype(float)
def col(name):return np.array([[float(r[name]) for r in rr] for rr in rows]).T
p_peak=col('p_peak');p_quality=col('p_quality');pt=col('p_time');ptrue=col('p_true_sec');strue=col('s_true_sec')
metrics=[];summaries=[];boots=[];seedrows=[];invariance={};baseline_checks=[]
def classify(peak,quality,threshold,q):return np.where((peak>=threshold)&(quality>=q),2,np.where(peak>=threshold*.5,1,0))
groups={(method,mode):[i for i,j in enumerate(jobs) if ('Stack' if j['kind']=='full15ch' else 'PhaseNetMatched')==method and j['mode']==mode] for method in ['Stack','PhaseNetMatched'] for mode in ['Full3C','Zonly']}
for peak,q,mx in itertools.product([.2,.3,.4],[2,3,4],[20,30,40]):
 ps=classify(p_peak,p_quality,peak,q);st=col(f's_time_{mx}');sp=col(f's_peak_{mx}');sq=col(f's_quality_{mx}');ss=classify(sp,sq,peak,q);ss=np.where(ps>0,ss,0)
 if peak==.3 and q==3 and mx==30:
  for j,job in enumerate(jobs):
   actual=read(root/job['group']/(job['label']+'_replayed.csv'));assert [r['event_id'] for r in actual]==events
   for ph,status,times in [('p',ps,pt),('s',ss,st)]:
    names=['not_detected','uncertain','detected'];assert [names[x] for x in status[:,j]]==[r[ph+'_status'] for r in actual]
    for k,r in enumerate(actual):
     a=times[k,j] if status[k,j]>0 else math.nan;b=float(r[ph+'_pred_sec']);assert (math.isnan(a) and math.isnan(b)) or abs(a-b)<1e-9
   baseline_checks.append(dict(group=job['group'],label=job['label'],records=330,status_and_pick_match=True))
 for policy in ['accepted','strict']:
  for phase,status,times,true in [('P',ps,pt,ptrue),('S',ss,st,strue)]:
   a=(status>= (1 if policy=='accepted' else 2))&np.isfinite(times);err=np.abs(1000*(times-true));hit=a&(err<=100+1e-7);point=2*hit.sum(axis=0)/(330+a.sum(axis=0));zN=np.zeros((len(u),24));zA=zN.copy();zT=zN.copy();np.add.at(zN,idx,np.ones((330,24)));np.add.at(zA,idx,a.astype(float));np.add.at(zT,idx,hit.astype(float));draw=2*(W@zT)/(W@(zN+zA))
   if policy=='accepted':
    key=(peak,mx,phase)
    if key in invariance:assert np.array_equal(a,invariance[key])
    else:invariance[key]=a.copy()
   cfg=dict(peak_threshold=peak,quality_threshold=q,max_SP_seconds=mx,Policy=policy,Phase=phase,Tolerance_ms=100)
   modelmetrics=[]
   for j,job in enumerate(jobs):
    ae=err[a[:,j],j];r=dict(**cfg,Method='Stack' if job['kind']=='full15ch' else 'PhaseNetMatched',Mode=job['mode'],BaseSeed=int(job['base']),MetaSeed=int(job['seed']) if job['kind']=='full15ch' else '',N=330,N_accepted=int(a[:,j].sum()),TP=int(hit[:,j].sum()),F1=float(point[j]),Coverage=float(a[:,j].mean()),MAE_ms=float(ae.mean()) if len(ae) else math.nan);metrics.append(r);modelmetrics.append(r)
   for (method,mode),ii in groups.items():
    r=dict(**cfg,Method=method,Mode=mode)
    for c in ['F1','Coverage','MAE_ms']:
     means=[statistics.mean(modelmetrics[j][c] for j in ii if int(jobs[j]['base'])==b) for b in [42,43,44]];r['mean_'+c]=statistics.mean(means);r['between_base_SD_'+c]=statistics.stdev(means)
    summaries.append(r)
   for name,ka,kb in [('Stack Full3C minus Zonly',('Stack','Full3C'),('Stack','Zonly')),('PhaseNet Full3C minus Zonly',('PhaseNetMatched','Full3C'),('PhaseNetMatched','Zonly')),('Stack minus PhaseNet Full3C',('Stack','Full3C'),('PhaseNetMatched','Full3C')),('Stack minus PhaseNet Zonly',('Stack','Zonly'),('PhaseNetMatched','Zonly'))]:
    ia=groups[ka];ib=groups[kb];d=draw[:,ia].mean(axis=1)-draw[:,ib].mean(axis=1);lo,hi=np.quantile(d,[.025,.975]);boots.append(dict(**cfg,Comparison=name,F1_A=float(point[ia].mean()),F1_B=float(point[ib].mean()),Delta=float(point[ia].mean()-point[ib].mean()),CI_low=float(lo),CI_high=float(hi)))
   for method in ['Stack','PhaseNetMatched']:
    for b in [42,43,44]:
     for m in ([42,43,44] if method=='Stack' else [b]):
      def ix(mode):return next(i for i,j in enumerate(jobs) if i in groups[method,mode] and int(j['base'])==b and int(j['seed'])==m)
      seedrows.append(dict(**cfg,Method=method,BaseSeed=b,MetaSeed=m if method=='Stack' else '',Delta=float(point[ix('Full3C')]-point[ix('Zonly')])))
 print('GRID',peak,q,mx,flush=True)
write('threshold_per_fit.csv',metrics);write('threshold_summary.csv',summaries);write('threshold_paired_bootstrap.csv',boots);write('threshold_paired_seed_differences.csv',seedrows);write('primary_decoder_reconstruction_checks.csv',baseline_checks)
old=read(w/'audit_full_20260918/expanded_paired_bootstrap.csv')
for r in [x for x in boots if x['peak_threshold']==.3 and x['quality_threshold']==3 and x['max_SP_seconds']==30 and x['Policy']=='accepted']:
 z=next(x for x in old if x['Comparison']==r['Comparison'] and x['Phase']==r['Phase'])
 for c in ['Delta','CI_low','CI_high']:assert abs(float(z[c])-r[c])<1e-12
ranges=[]
for policy in ['accepted','strict']:
 for phase in ['P','S']:
  for comparison in sorted({x['Comparison'] for x in boots}):
   rr=[r for r in boots if r['Policy']==policy and r['Phase']==phase and r['Comparison']==comparison];ranges.append(dict(Policy=policy,Phase=phase,Comparison=comparison,min_delta=min(r['Delta'] for r in rr),max_delta=max(r['Delta'] for r in rr),min_CI_low=min(r['CI_low'] for r in rr),max_CI_high=max(r['CI_high'] for r in rr),positive_point_configurations=sum(r['Delta']>0 for r in rr),CI_above_zero_configurations=sum(r['CI_low']>0 for r in rr),configurations=len(rr)))
write('threshold_range_summary.csv',ranges);(out/'verification.json').write_text(json.dumps({'grid_configurations':27,'primary_decoder_output_sets_reproduced':len(baseline_checks),'records_per_set':330,'primary_paired_bootstrap_reproduced':True,'accepted_quality_invariance_verified':True,'configuration_selected':False,'training_performed':False,'confidence_scope':'Pointwise exploratory source-cluster intervals, not simultaneous familywise intervals'},indent=2));print(json.dumps(ranges,indent=2))
