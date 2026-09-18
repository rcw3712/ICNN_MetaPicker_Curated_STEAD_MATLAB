from pathlib import Path
import csv,json,hashlib,argparse,math,re,sys

def sha(p):
 h=hashlib.sha256()
 with Path(p).open('rb') as f:
  for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
 return h.hexdigest()
def rank(ids,seed,stage):return sorted(ids,key=lambda s:(hashlib.sha256(f'{stage}|{seed}|{s}'.encode()).hexdigest(),s))
def write_csv(p,rows,fields=None):
 p.parent.mkdir(parents=True,exist_ok=True)
 with p.open('w',newline='',encoding='utf-8') as f:
  w=csv.DictWriter(f,fieldnames=fields or list(rows[0]));w.writeheader();w.writerows(rows)
def read(p):
 with Path(p).open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def assignments(mapping):
 ids=rank({r['verified_source_id'] for r in mapping},42,'outer');n=len(ids);ntr=math.floor(.7*n+.5);nv=math.floor(.15*n+.5)
 split={s:('train' if i<ntr else 'val' if i<ntr+nv else 'test') for i,s in enumerate(ids)}
 train=rank(ids[:ntr],42,'oof');fold={s:i%5+1 for i,s in enumerate(train)}
 inner={}
 for k in range(1,6):
  remaining=rank([s for s in train if fold[s]!=k],100+k,'inner');nv=max(1,min(len(remaining)-1,math.floor(.15*len(remaining)+.5)));inner[k]=set(remaining[:nv])
 return split,fold,inner

def prepare(a):
 import numpy as np
 out=Path(a.output)
 if out.exists():raise FileExistsError('Use a fresh output directory; never replace an existing protocol: '+str(out))
 m=read(Path(a.audit)/'recovered_mapping_2234.csv');meta={r['event_id']:r for r in read(Path(a.audit)/'recovered_stead_metadata_2234.csv')}
 assert len(m)==2234 and len({r['event_id'] for r in m})==2234 and len({r['trace_name'] for r in m})==2234
 assert len({r['verified_source_id'] for r in m})==1477
 assert all(r['verified_source_id'].strip() and r['verified_source_id'].lower() not in ('nan','none','null') for r in m)
 split,fold,inner=assignments(m);members=[];metadata=[];waves=[]
 # Validate everything before publishing the prepared protocol.
 for i,r in enumerate(sorted(m,key=lambda r:r['event_id'])):
  event=r['event_id'];raw=meta[event];source=r['verified_source_id'];assert raw['source_id']==source and raw['trace_name']==r['trace_name']
  p=Path(a.waveforms)/(event+'.csv');b=np.loadtxt(p,delimiter=',',skiprows=1,usecols=(1,2,3,4,5,6))
  assert b.shape==(6000,6) and np.isfinite(b).all(),event
  assert np.allclose(b[:,0],np.arange(6000)/100,rtol=0,atol=1e-9),event
  digest=hashlib.sha256(np.asarray(b[:,1:4],dtype='<f4').tobytes(order='F')).hexdigest();assert digest==r['waveform_f32_sha256'],event
  ps=[int(r['csv_p_arrival_sample']),int(r['csv_s_arrival_sample'])]
  assert np.allclose(b[:,4:],np.array(ps)/100,rtol=0,atol=1e-9),event
  assert 0<=ps[0]<ps[1]<6000
  assert ps==[math.floor(float(r['hdf5_p_arrival_sample'])),math.floor(float(r['hdf5_s_arrival_sample']))]
  members.append(dict(event_id=event,source_id=source,trace_name=r['trace_name'],split=split[source],fold=fold.get(source,0)))
  snr=[float(v) for v in re.findall(r'[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?',raw['snr_db'])]
  record={k:v for k,v in raw.items() if k not in ('historical_split','waveform_f32_sha256')}
  record.update(source_id=source,file_name=p.name,file_path=str(p.resolve()),quality_flag='good',processing_level='waveform_identity_verified_v2',p_arrival_sec=float(r['hdf5_p_arrival_sample'])/100,s_arrival_sec=float(r['hdf5_s_arrival_sample'])/100,csv_p_arrival_sec=ps[0]/100,csv_s_arrival_sec=ps[1]/100,min_snr_db=min(snr) if snr else 'NaN',sp_time_sec=(ps[1]-ps[0])/100)
  metadata.append(record);waves.append(dict(event_id=event,sha256=sha(p),waveform_f32_sha256=digest))
  if (i+1)%250==0:print(f'Verified {i+1}/2234 CSVs',flush=True)
 out.mkdir(parents=True)
 write_csv(out/'metadata/metadata_verified.csv',metadata);write_csv(out/'partition_membership.csv',members);write_csv(out/'waveform_hashes.csv',waves)
 for name in ('train','val','test'):write_csv(out/f'results/splits/{name}_source_ids.csv',[{'source_id':s} for s in sorted(split) if split[s]==name])
 folds=[]
 for k in range(1,6):
  roles=[dict(event_id=r['event_id'],source_id=r['source_id'],role='held' if r['fold']==k else 'inner_val' if r['source_id'] in inner[k] else 'fit') for r in members if r['split']=='train']
  write_csv(out/f'folds/inner_fold_{k}.csv',roles)
  groups={role:{r['source_id'] for r in roles if r['role']==role} for role in ('fit','inner_val','held')}
  assert not(groups['fit']&groups['inner_val'] or groups['fit']&groups['held'] or groups['held']&groups['inner_val'])
  folds.append({'fold':k,'records':{role:sum(r['role']==role for r in roles) for role in groups},'sources':{role:len(s) for role,s in groups.items()}})
 summary={'records':len(m),'sources':len(split),'outer':{name:{'records':sum(r['split']==name for r in members),'sources':sum(s==name for s in split.values())} for name in ('train','val','test')},'folds':folds,'source_overlap_pairs':0,'deterministic_under_reversed_input':assignments(list(reversed(m)))==assignments(m)}
 write_csv(out/'recovered_mapping_2234.csv',m)
 (out/'split_audit.json').write_text(json.dumps(summary,indent=2))
 files=[{'relative_path':str(p.relative_to(out)).replace('\\','/'),'sha256':sha(p)} for p in sorted(out.rglob('*')) if p.is_file()]
 protocol={'schema':'stead-source-verified-v2','records':2234,'sources':1477,'waveform_dir':str(Path(a.waveforms).resolve()),'outer_seed':42,'oof_seed':42,'oof_folds':5,'source_proportions':[.7,.15,.15],'assignment_algorithm':'SHA256(stage|seed|source_id) rank; outer source counts rounded; OOF round-robin; inner 15 percent of remaining sources','label_policy':'Preserve historical CSV labels: floor(HDF5 arrival sample)/100','audit_mapping_sha256':sha(Path(a.audit)/'recovered_mapping_2234.csv'),'files':files}
 (out/'protocol.json').write_text(json.dumps(protocol,indent=2));print(json.dumps(summary,indent=2))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--audit',required=True);p.add_argument('--waveforms',required=True);p.add_argument('--output',required=True);prepare(p.parse_args())
