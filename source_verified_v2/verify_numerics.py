from pathlib import Path
import csv,json,math,statistics,hashlib,argparse
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

parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);args=parser.parse_args();root=Path(__file__).parent
membership=read(root/'inputs/partition_membership.csv');test={r['event_id']:r for r in membership if r['split']=='test'}
sets={s:{r['source_id'] for r in membership if r['split']==s} for s in ['train','val','test']}
assert [len(sets[s]) for s in ['train','val','test']]==[1034,222,221]
assert not(sets['train']&sets['val'] or sets['train']&sets['test'] or sets['val']&sets['test'])
reported={(r['evaluation'],r['policy'],r['Phase'],int(r['Tolerance_ms'])):r for r in read(root/'audit/PriorNumericalReference/recomputed_all_metrics.csv')}
rows=[]
for job in read(root/'test_jobs.csv'):
 f=root/job['expected'];key=Path(job['expected']).relative_to('results').as_posix().replace('_predictions.csv','')
 for policy in ['accepted','strict','unconstrained']:
  pred=read(f if policy!='unconstrained' else f.with_name(f.name.replace('_predictions.csv','_unconstrained_predictions.csv')))
  assert len(pred)==330 and {r['event_id'] for r in pred}==set(test)
  assert all(r['source_id']==test[r['event_id']]['source_id'] for r in pred)
  for a in calc(pred,policy=='strict'):
   b=reported[(key,policy,a['Phase'],a['Tolerance_ms'])]
   for col in a.keys()-{'Phase'}:
    x=a[col];y=num(b[col]);assert (math.isnan(x) and math.isnan(y)) or math.isclose(x,y,abs_tol=1e-6,rel_tol=1e-10),(key,policy,col,x,y)
   rows.append(dict(evaluation=key,policy=policy,**a))
assert len(rows)==1260
args.output.mkdir(parents=True,exist_ok=True);write(args.output/'recomputed_metrics.csv',rows)
receipt={'metric_rows':len(rows),'prediction_sets':70,'records_per_set':330,'sources':221,'discrepancies':0,'training_performed':False}
(args.output/'receipt.json').write_text(json.dumps(receipt,indent=2));print(json.dumps(receipt,indent=2))
