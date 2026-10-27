"""Read frozen inputs and artifacts only. No model imports, training or inference.
STEAD memberships are adapted without changing identifiers. Lineage audit keys
are reconstructed from existing replay receipts, not claimed as training logs.
"""
from pathlib import Path
from collections import defaultdict,Counter
from itertools import combinations
import argparse,csv,json,hashlib
from seismic_eval_audit import *

def main():
 p=argparse.ArgumentParser();p.add_argument('--stead-root',type=Path,required=True);p.add_argument('--ethz',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 root=a.stead_root.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);inputs=[]
 def digest(path):
  h=hashlib.sha256()
  with path.open('rb') as f:
   for b in iter(lambda:f.read(1048576),b''):h.update(b)
  return h.hexdigest()
 def read(rel):
  q=root/rel;inputs.append({'path':rel,'sha256':digest(q),'bytes':q.stat().st_size});return read_csv(q)
 def dump(name,x):
  q=out/name;q.parent.mkdir(exist_ok=True,parents=True);q.write_text(json.dumps(x,indent=2),encoding='utf-8')
 def csvout(name,rows):
  q=out/name;q.parent.mkdir(exist_ok=True,parents=True)
  with q.open('w',encoding='utf-8',newline='') as f:
   w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
 current=[dict(record_id=r['event_id'],source_id=r['source_id'],split=r['split'],fold=r['fold']) for r in read('inputs/partition_membership.csv')]
 index={r['record_id']:r for r in current};assert len(index)==len(current)==2234
 mapping=read('inputs/recovered_mapping_2234.csv')
 assert {r['event_id'] for r in mapping}==set(index)
 historical=[dict(record_id=r['event_id'],source_id=r['verified_source_id'],split=r['split']) for r in mapping]
 assert all(index[r['record_id']]['source_id']==r['source_id'] for r in historical)
 for name,data in [('historical',historical),('corrected',current)]:
  result=audit_split(data);write_report(result,out/name);csvout(name+'/membership.csv',data)
  # Independent direct-set comparisons of each reported pair.
  for pair in result['pairs']:
   left=[r for r in data if r['split']==pair['a']];right=[r for r in data if r['split']==pair['b']]
   shared={r['source_id'] for r in left}&{r['source_id'] for r in right}
   assert pair['shared_sources']==len(shared)
   assert pair['a_records']==sum(r['source_id'] in shared for r in left)
   assert pair['b_records']==sum(r['source_id'] in shared for r in right)
 ht=[r for r in historical if r['split']=='test'];train={r['source_id'] for r in historical if r['split']=='train'};development={r['source_id'] for r in historical if r['split'] in ['train','val']}
 hist_counts={'test_records':len(ht),'test_records_sharing_train_source':sum(r['source_id'] in train for r in ht),'test_records_sharing_train_or_val_source':sum(r['source_id'] in development for r in ht)}
 assert list(hist_counts.values())==[335,151,168]
 dump('historical/test_exposure_counts.json',hist_counts)
 history=[dict(source_id=r['source_id'],role=r['split']) for r in historical]
 h=audit_history(current,history);dump('history/report.json',h)
 reference=read('audit/HistoricalRolesAndManual/source_role_memberships.csv')
 assert {r['source_id'] for r in reference}=={r['source_id'] for r in current}
 assert all(set(r['historical_roles'].split('|'))==set(hh['role'] for hh in history if hh['source_id']==r['source_id']) for r in reference)
 assert (h['categories']['prior_development']['sources'],h['categories']['prior_development']['records'])==(196,304)
 assert (h['categories']['prior_test_only']['sources'],h['categories']['prior_test_only']['records'])==(25,26)
 csvout('history/roles.csv',history)
 # Five actual inner-fold tables are shared by six mode/base configurations.
 inners={k:read(f'inputs/folds/inner_fold_{k}.csv') for k in range(1,6)}
 jobs=[]
 for base in [42,43,44]:
  for mode in ['Full3C','Zonly']:
   prefix='results/submission40' if base==42 else f'results/strengthening/base_{base}/{mode}'
   rel=f'{prefix}/{mode}/oof_membership.csv';members=read(rel);m={r['event_id']:r for r in members}
   assert len(m)==len(members)==1544 and set(m)=={r['record_id'] for r in current if r['split']=='train'}
   assert all(m[k]['source_id']==index[k]['source_id'] and m[k]['fold']==index[k]['fold'] for k in m)
   for fold in range(1,6):
    held=[index[k] for k,v in m.items() if int(v['fold'])==fold]
    inner=inners[fold];assert {r['role'] for r in inner}=={'fit','inner_val','held'}
    assert len({r['event_id'] for r in inner})==len(inner)
    assert {r['event_id'] for r in inner}==set(m)
    assert {r['event_id'] for r in inner if r['role']=='held'}=={r['record_id'] for r in held}
    assert all(index[r['event_id']]['source_id']==r['source_id'] for r in inner)
    fit=[index[r['event_id']] for r in inner if r['role']=='fit'];val=[index[r['event_id']] for r in inner if r['role']=='inner_val']
    q=check_oof(held,fit,val);q.update(mode=mode,base=base,fold=fold,held_records=len(held),fit_records=len(fit),inner_validation_records=len(val));jobs.append(q)
 dump('oof/report.json',{'status':'PASS' if all(x['status']=='PASS' for x in jobs) else 'FAIL','manifests':6,'distinct_fold_assignments':5,'configuration_fold_checks':len(jobs),'checks':jobs,'scope':'Saved membership and inner-fold tables; no new fitting or model execution'})
 receipts=read('audit/Replay/all_oof_replay_receipts.csv');groups=defaultdict(list)
 for r in receipts:groups[r['group']].append(r)
 lineage=[];children_all=[]
 for group,rr in sorted(groups.items()):
  assert len(rr)==3088 and Counter(r['augmented'] for r in rr)=={'0':1544,'1':1544}
  parents=[dict(index[k],record_id=group+'/'+k) for k in sorted(index) if index[k]['split']=='train']
  assert all(r['event_id'] in index and r['fold']==index[r['event_id']]['fold'] for r in rr)
  assert all(r['source_id']==index[r['event_id']]['source_id'] for r in rr if r['augmented']=='0')
  kids=[dict(record_id=group+'/'+r['event_id']+'/augmented',parent_id=group+'/'+r['event_id'],source_id=r['source_id'],split='train') for r in rr if r['augmented']=='1']
  q=check_lineage(parents,kids);q.update(group=group,children=len(kids));lineage.append(q);children_all+=kids
 dump('lineage/report.json',{'status':'PASS' if all(q['status']=='PASS' for q in lineage) else 'FAIL','checks':lineage,'children':len(children_all),'scope':'Audit keys and train labels reconstructed from OOF replay receipt context; source/fold checked against frozen parent table. Not an original training-time augmentation manifest; does not verify augmented waveform bytes.'})
 csvout('lineage/reconstructed_children.csv',children_all)
 models=read('model_manifest.csv');q=check_artifacts(root,models);q['files']=len(models);q['scope']='Actual checkpoint bytes against existing frozen SHA-256 values';dump('artifacts/checkpoints.json',q)
 code=read('provenance/code_copy_manifest.csv');entries=[dict(path=r['path'],sha256=r['public_sha256']) for r in code];q=check_artifacts(root,entries);q['files']=len(entries);q['scope']='Public code copies against previously recorded public_sha256; not comparison to pre-portability original bytes';dump('artifacts/code.json',q)
 # Public ETHZ supplied split, grouping by declared network/station key.
 raw=read_csv(a.ethz);assert digest(a.ethz)=='542d2e9cfc35847668521fe335bc955b00a42f59f06eaa921ffb92f6009a1dee'
 station=[dict(record_id=r['trace_name'],station_key=value(r,'station_network_code')+'.'+value(r,'station_code'),split=r['split']) for r in raw]
 q=audit_split(station,group='station_key');q['interpretation']='Overlap under an unseen-network/station evaluation contract; not an error in the supplied source-disjoint partition. Station key does not resolve deployment epochs or location codes.';write_report(q,out/'ethz_station');csvout('ethz_station/membership.csv',station)
 for pair in q['pairs']:
  a1={r['station_key'] for r in station if r['split']==pair['a']};b1={r['station_key'] for r in station if r['split']==pair['b']};assert len(a1&b1)==pair['shared_sources']
 dump('ethz_station/networks.json',dict(Counter(r['station_network_code'] for r in raw)))
 csvout('input_hashes.csv',inputs)
 dump('run_receipt.json',{'training_performed':False,'inference_performed':False,'ethz_input_sha256':digest(a.ethz),'historical_counts':hist_counts,'checks_complete':True,'schema_real_data_check':'Not performed; schema API remains supported by synthetic controls only','lineage_evidence':'Adapted from recorded OOF replay receipts, not a training-time lineage log'})
 print(json.dumps({'historical':hist_counts,'history_categories':{k:{a:b for a,b in v.items() if a!='source_ids'} for k,v in h['categories'].items()},'oof_checks':len(jobs),'lineage_children':len(children_all),'checkpoints':len(models),'code_files':len(entries),'station':{k:v for k,v in q.items() if k!='violations'}},indent=2))

if __name__=='__main__':main()
