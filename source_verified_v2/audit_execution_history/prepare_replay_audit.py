from pathlib import Path
import csv,json,hashlib,datetime,re
w=Path(__file__).parent;o=w/'audit_replay_threshold_station_20260918';o.mkdir(exist_ok=True)
root=Path(r'D:\ICNN_source_verified_results\v2');pkg=Path(r'C:\Drive E\ICNN_MetaPicker_Curated_STEAD_MATLAB\ICNN_source_verified_v2')
def write(name,rows):
 with (o/name).open('w',newline='',encoding='utf-8') as f:
  wr=csv.DictWriter(f,fieldnames=list(rows[0]));wr.writeheader();wr.writerows(rows)
protocol={'frozen_at':datetime.datetime.now().astimezone().isoformat(),'training':False,'selection':'No configuration chosen using test performance; retain original primary decoder.','pick_peak_thresholds':[.2,.3,.4],'uncertain_multiplier':.5,'quality_thresholds_P_and_S':[2,3,4],'min_SP_seconds':.1,'max_SP_seconds':[20,30,40],'grid_configurations':27,'policies':['accepted','strict'],'primary_tolerance_ms':100,'models':'18 full stackers and 6 PhaseNet-style fits','resampling':'10000 paired source-cluster draws, seed42, conditional fixed models/split; report selected predeclared contrasts and all configurations, no multiplicity adjustment','station_key':'network_code + receiver_code; compare test keys seen in outer train, separately seen in train-or-validation; not station epochs','replay':'All 70 final test prediction sets; regenerate all original and augmented OOF tensors from 60 OOF checkpoints.'}
(o/'protocol_before_analysis.json').write_text(json.dumps(protocol,indent=2))
old=list(csv.DictReader((w/'audit_full_20260918/checkpoint_hashes.csv').open()));models=[]
for r in old:
 p=Path(r['file']);digest=hashlib.sha256(p.read_bytes()).hexdigest();assert digest==r['sha256'];mode,kind,fold,seed=re.match(r'(Full3C|Zonly)_(.+)_fold(-?\d+)_seed(\d+)\.mat',p.name).groups();base=42
 if 'base_43' in str(p):base=43
 if 'base_44' in str(p):base=44
 if kind=='PhaseNetMatched':base=int(seed)
 models.append(dict(path=str(p),sha256=digest,mode=mode,kind=kind,fold=int(fold),seed=int(seed),base=base))
assert len(models)==106;write('model_manifest.csv',models)
jobs=[]
for p in sorted(root.rglob('*_predictions.csv')):
 if '_unconstrained_' in p.name or 'audit_' in str(p):continue
 rel=p.relative_to(root).as_posix();mode='Full3C' if 'Full3C' in rel else 'Zonly';base=43 if 'base_43' in rel else 44 if 'base_44' in rel else 42;label=p.name.replace('_predictions.csv','');baseline='/baselines/' in rel
 if rel.startswith('strengthening/phasenet'):
  kind='PhaseNetMatched';seed=int(label.split('seed')[-1]);base=seed;group=mode+'_phasenet'
 else:
  group=f'{mode}_base{base}';kind=label.rsplit('_seed',1)[0] if not baseline else label;seed=int(label.rsplit('_seed',1)[-1]) if not baseline else base
 model_path='' if baseline else next(r['path'] for r in models if r['mode']==mode and r['base']==base and r['kind']==kind and r['seed']==seed and r['fold']==-1)
 jobs.append(dict(group=group,mode=mode,base=base,seed=seed,kind=kind,label=label,baseline=int(baseline),expected=str(p),model_path=model_path))
assert len(jobs)==70;write('test_jobs.csv',jobs)
code=[]
for p in sorted(pkg.rglob('*.m')):code.append(dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
write('code_before_replay.csv',code)
print(json.dumps({'models':len(models),'test_outputs':len(jobs),'code_files':len(code),'groups':sorted({r['group'] for r in jobs})}))
