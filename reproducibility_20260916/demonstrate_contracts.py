"""Run without MATLAB or external data: python demonstrate_contracts.py."""
from pathlib import Path
import hashlib,json,csv
from pipeline_contracts import *
root=Path(__file__).parent;out=root/'verification';out.mkdir(exist_ok=True)
records=[{'event_id':f'synthetic_{s}_{r}','source_id':f'source_{s:02}'} for s in range(20) for r in range(3)]
train,val,test=split_sources(records);aug=[augment_identity(r,1) for r in train]
for child,parent in zip(aug,train):validate_parent(child,parent)
fit=train+aug;folds=grouped_folds(fit)
for k,held in enumerate(folds):validate_oof(held,[r for j,f in enumerate(folds) if j!=k for r in f])
validate_features(FEATURES,[0.1]*12+[0,0,1]);negative=[]
def rejected(name,fn):
 try:fn()
 except ValueError as e:negative.append({'case':name,'rejected':True,'reason':str(e)})
 else:raise AssertionError('Expected rejection: '+name)
rejected('record_random_source_overlap',lambda:assert_disjoint([records[0]],[records[1]]))
rejected('augmentation_parent_mismatch',lambda:validate_parent(dict(aug[0],source_id='wrong'),train[0]))
rejected('OOF_fit_contains_held_source',lambda:validate_oof(folds[0],folds[0]))
swapped=list(FEATURES);swapped[0],swapped[3]=swapped[3],swapped[0]
rejected('feature_order_swap',lambda:validate_features(swapped,[0]*15))
rejected('changed_artifact_bytes',lambda:verify_bytes(b'changed',hashlib.sha256(b'original').hexdigest()))
# Also verify the actual published test identities across all 24 output tables.
identities=None;sets=0
for file in sorted((root/'expected').glob('*.csv')):
 rows=list(csv.DictReader(open(file,encoding='utf-8-sig')))
 current=sorted((r['event_id'],r['source_id'],r['p_true_sec'],r['s_true_sec']) for r in rows)
 if identities is None:identities=current
 assert current==identities;sets+=1
assert len(identities)==335 and len({r[1] for r in identities})==317 and sets==24
summary=summarize_crossed_seed({42:[1,3],43:[5,7],44:[9,11]})
assert summary['base_means']==[2,6,10] and summary['mean']==6 and summary['between_base_sd']==4
receipt={'crossed_seed_example':summary,'synthetic_records':len(records),'synthetic_sources':20,'outer_source_counts':[len(source_set(g)) for g in [train,val,test]],'OOF_folds':len(folds),'augmentation_lineage_checks':len(aug),'negative_controls':negative,'published_prediction_sets':sets,'published_test_records':335,'published_test_sources':317,'purpose':'Executable workflow invariants, not evidence of predictive improvement or new-source generalization.'}
(out/'contract_demo.json').write_text(json.dumps(receipt,indent=2))
print(json.dumps(receipt,indent=2))
