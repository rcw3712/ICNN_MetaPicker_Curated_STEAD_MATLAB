"""Reusable checks for source identity, OOF provenance and feature interfaces.
These checks expose workflow invariants; they are not new splitting algorithms.
"""
import hashlib,random,statistics
FEATURES=tuple(f'{model}_{phase}' for model in ['STA','AIC','CNN','TCN'] for phase in ['P','S','Noise'])+('E','N','Z')
def source_set(records):return {r['source_id'] for r in records}
def assert_disjoint(*groups):
 sets=[source_set(g) for g in groups]
 for i,a in enumerate(sets):
  for b in sets[i+1:]:
   if a&b:raise ValueError('Source overlap: '+','.join(sorted(a&b)))
def split_sources(records,seed=42):
 ids=sorted(source_set(records));random.Random(seed).shuffle(ids)
 a=max(1,int(.7*len(ids)));b=max(a+1,int(.85*len(ids)))
 result=[[r for r in records if r['source_id'] in set(keys)] for keys in [ids[:a],ids[a:b],ids[b:]]]
 assert_disjoint(*result);return result

def augment_identity(record,copy_id):
 return dict(record,event_id=record['event_id']+'__aug'+str(copy_id),parent_event_id=record['event_id'])
def validate_parent(child,parent):
 if child['parent_event_id']!=parent['event_id'] or child['source_id']!=parent['source_id']:raise ValueError('Augmentation changed lineage')
def grouped_folds(records,n=3):
 ids=sorted(source_set(records));assignment={s:i%n for i,s in enumerate(ids)}
 return [[r for r in records if assignment[r['source_id']]==k] for k in range(n)]
def validate_oof(held_out,fit_records):assert_disjoint(held_out,fit_records)
def validate_features(names,values):
 if tuple(names)!=FEATURES or len(values)!=15:raise ValueError('Canonical feature order/width mismatch')
 if any(v!=v or abs(v)==float('inf') for v in values):raise ValueError('Nonfinite feature')
def verify_bytes(data,expected):
 if hashlib.sha256(data).hexdigest()!=expected:raise ValueError('Artifact hash mismatch')
def summarize_crossed_seed(values):
 means=[statistics.mean(v) for _,v in sorted(values.items())]
 return {'base_means':means,'mean':statistics.mean(means),'between_base_sd':statistics.stdev(means),'independent_base_initializations':len(means)}
