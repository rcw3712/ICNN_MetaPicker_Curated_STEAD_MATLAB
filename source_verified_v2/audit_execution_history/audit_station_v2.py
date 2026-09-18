from pathlib import Path
import sys,csv,json,collections,math,statistics,hashlib
w=Path(__file__).parent;sys.path.insert(0,str(w/'revision/pylibs'));import numpy as np
out=w/'audit_replay_threshold_station_20260918/station';out.mkdir(parents=True,exist_ok=True)
def read(p):
 with Path(p).open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def write(n,rows):
 if not rows:return
 with (out/n).open('w',newline='',encoding='utf-8') as f:
  wr=csv.DictWriter(f,fieldnames=list(rows[0]));wr.writeheader();wr.writerows(rows)
root=Path(r'D:\ICNN_source_verified_results\v2');prep=Path(r'D:\STEAD_identity_recovery\prepared_source_v2');paths=[prep/'partition_membership.csv',prep/'metadata/metadata_verified.csv'];mem=read(paths[0]);meta={r['event_id']:r for r in read(paths[1])}
keys={r['event_id']:meta[r['event_id']]['network_code']+'.'+meta[r['event_id']]['receiver_code'] for r in mem};assert all(meta[r['event_id']]['network_code'] and meta[r['event_id']]['receiver_code'] for r in mem)
sets={s:{keys[r['event_id']] for r in mem if r['split']==s} for s in ['train','val','test']}
write('station_key_intersections.csv',[dict(split_a=a,split_b=b,intersection=len(sets[a]&sets[b]),keys_a=len(sets[a]),keys_b=len(sets[b])) for a in sets for b in sets])
test={r['event_id']:dict(verified_source_id=r['source_id']) for r in mem if r['split']=='test'}
rows=[dict(event_id=e,source_id=r['verified_source_id'],station_key=keys[e],seen_in_train=keys[e] in sets['train'],seen_in_validation=keys[e] in sets['val']) for e,r in test.items()];write('test_station_membership.csv',rows)
subsets={'all_test':set(test),'station_seen_train':{r['event_id'] for r in rows if r['seen_in_train']},'station_unseen_train':{r['event_id'] for r in rows if not r['seen_in_train']},'station_unseen_train_and_val':{r['event_id'] for r in rows if not r['seen_in_train'] and not r['seen_in_validation']}}
sizes=[dict(subset=k,records=len(v),sources=len({test[e]['verified_source_id'] for e in v}),station_keys=len({keys[e] for e in v})) for k,v in subsets.items()];write('station_subset_sizes.csv',sizes)
code=(w/'audit_roles_manual.py').read_text(encoding='utf-8-sig');code=code[code.index('def predpath('):code.index("summary={'records'")];exec(compile(code,'station_reused_metric_calculator','exec'))
summary={'key_definition':'network_code.receiver_code; not station epochs','counts':{s:len(v) for s,v in sets.items()},'test_keys_seen_train':len(sets['test']&sets['train']),'test_keys_unseen_train':len(sets['test']-sets['train']),'test_keys_unseen_train_and_val':len(sets['test']-(sets['train']|sets['val'])),'subsets':sizes,'scope':'Retrospective station-stratified diagnostics within the fixed source-held-out test; no station-held-out design, no causal domain effect.'}
(out/'station_summary.json').write_text(json.dumps(summary,indent=2));write('input_hashes.csv',[dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in paths]);print(json.dumps(summary,indent=2))
