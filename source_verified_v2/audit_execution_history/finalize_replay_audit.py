from pathlib import Path
import csv,json,hashlib,datetime
w=Path(__file__).parent;r=w/'audit_replay_threshold_station_20260918'
def read(p):
 with Path(p).open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def write(name,rows):
 with (r/name).open('w',newline='',encoding='utf-8') as f:
  c=csv.DictWriter(f,fieldnames=list(rows[0]));c.writeheader();c.writerows(rows)
def sha(p):
 h=hashlib.sha256()
 with Path(p).open('rb') as f:
  while b:=f.read(8*1024*1024):h.update(b)
 return h.hexdigest()
progress=json.loads((r/'runner_progress.json').read_text());assert progress['complete'] and not progress.get('failed',False)
pred=[];oof=[];test=[];models=[]
for mode in ['Full3C','Zonly']:
 for b in [42,43,44]:
  group=f'{mode}_base{b}';p=read(r/group/'prediction_replay_receipt.csv')
  assert len(p)==(38 if mode=='Full3C' and b==42 else 18)
  pred+=p;models+=read(r/group/'loaded_models.csv')
  t=read(r/group/'test_tensor_replay.csv');assert len(t)==330
  test += [dict(group=group,**x) for x in t]
  group+='_oof';o=read(r/group/'oof_replay_receipt.csv');assert len(o)==3088
  assert len({x['event_id'] for x in o})==1544 and sum(int(x['augmented']) for x in o)==1544
  oof += [dict(group=group,**x) for x in o];models+=read(r/group/'loaded_models.csv')
 group=f'{mode}_phasenet';p=read(r/group/'prediction_replay_receipt.csv');assert len(p)==6
 pred+=p;models+=read(r/group/'loaded_models.csv')
assert len(pred)==140 and all(int(x['Records'])==330 for x in pred)
assert all(int(x['StatusMismatches'])==0 and int(x['PickMismatches'])==0 for x in pred)
assert len(oof)==18528 and len(test)==1980
assert all(float(x['MaxFeatureDifference'])<=1e-6 for x in oof+test)
expected=read(r/'model_manifest.csv');unique={x['path']:x for x in models};assert len(unique)==106
assert set(unique)=={x['path'] for x in expected}
for x in expected:
 assert unique[x['path']]['sha256']==x['sha256'];assert sha(x['path'])==x['sha256'],x['path']
code=read(r/'code_before_replay.csv')
for x in code:assert sha(x['path'])==x['sha256'],x['path']
prior_inputs=read(w/'audit_full_20260918/audited_input_hashes.csv')+read(w/'audit_no_training_20260918/analysis_input_hashes.csv')
for x in prior_inputs:assert sha(x['path'])==x['sha256'],x['path']
write('prior_audit_input_integrity.csv',prior_inputs)
write('all_prediction_replay_receipts.csv',pred);write('all_oof_replay_receipts.csv',oof);write('all_test_tensor_replay_receipts.csv',test);write('all_loaded_models.csv',list(unique.values()))
v=dict(passed=True,completed_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),test_prediction_sets=70,records_per_prediction_set=330,decoders=['constrained','unconstrained'],status_mismatches=0,pick_mismatches=0,max_pick_difference_seconds=max(float(x['MaxPickDifferenceSec']) for x in pred),max_quality_difference=max(float(x['MaxQualityDifference']) for x in pred),oof_tensors=len(oof),test_meta_tensors=len(test),max_oof_feature_difference=max(float(x['MaxFeatureDifference']) for x in oof),max_test_feature_difference=max(float(x['MaxFeatureDifference']) for x in test),unique_checkpoints=len(unique),checkpoint_hashes_unchanged=True,code_files=len(code),code_hashes_unchanged=True,prior_audit_input_hash_entries=len(prior_inputs),prior_audit_inputs_unchanged=True,training_performed=False,checkpoint_selection_performed=False,ensemble_weights_refitted=False)
(r/'replay_verification.json').write_text(json.dumps(v,indent=2));print(json.dumps(v,indent=2))
