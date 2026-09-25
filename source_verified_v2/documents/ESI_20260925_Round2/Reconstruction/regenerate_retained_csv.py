"""Regenerate retained STEAD CSV files with the verified retained-export serialization profile.
Requires numpy, pandas, h5py. No training. Original selection procedure is not reconstructed.
"""
from pathlib import Path
import argparse,csv,hashlib,json,platform,time
import numpy as np
import pandas as pd
import h5py

def sha(b):return hashlib.sha256(b).hexdigest()
def reconstruct(ds):
 x=np.asarray(ds[:],dtype='<f4')
 if x.shape!=(6000,3) or not np.isfinite(x).all():raise ValueError('Invalid waveform shape/values')
 df=pd.DataFrame(x,columns=['E','N','Z'])
 df.insert(0,'sec',np.arange(6000,dtype=np.float64)*0.01)
 df.insert(0,'time',[f'00:00:{i//100:02d}.{(i%100)*10:03d}' for i in range(6000)])
 for ph in ['p','s']:
  sample=float(ds.attrs[ph+'_arrival_sample'])
  if not np.isfinite(sample) or not 0<=sample<6000:raise ValueError('Invalid arrival')
  df[ph+'_arrival']=int(sample)*0.01
 return x,df.to_csv(index=False,lineterminator='\r\n').encode('utf-8')

def main():
 ap=argparse.ArgumentParser(description=__doc__)
 ap.add_argument('--hdf5',required=True,type=Path);ap.add_argument('--package',required=True,type=Path)
 ap.add_argument('--output',required=True,type=Path);ap.add_argument('--limit',type=int,default=0)
 ap.add_argument('--write-csv',action='store_true',help='Write only files whose bytes match the frozen hash')
 args=ap.parse_args();root=args.package.resolve();out=args.output.resolve()
 if out==root or root in out.parents:raise ValueError('Output must be outside frozen package')
 out.mkdir(parents=True,exist_ok=False)
 mapping=list(csv.DictReader((root/'inputs/partition_membership.csv').open(encoding='utf-8-sig')))
 hashes={v['event_id']:v for v in csv.DictReader((root/'inputs/waveform_hashes.csv').open(encoding='utf-8-sig'))}
 if args.limit: mapping=mapping[:args.limit]
 results=[];started=time.time()
 with h5py.File(args.hdf5,'r') as h:
  for j,m in enumerate(mapping):
   eid=m['event_id'];res={'event_id':eid,'trace_name':m['trace_name'],'source_match':False,'waveform_match':False,'csv_byte_match':False,'error':''}
   try:
    if Path(eid).name!=eid:raise ValueError('Unsafe event identifier')
    ds=h['data/'+m['trace_name']];source=ds.attrs['source_id'];source=source.decode() if isinstance(source,bytes) else str(source)
    res['source_match']=source==m['source_id']
    x,b=reconstruct(ds);res['waveform_match']=sha(x.tobytes(order='F'))==hashes[eid]['waveform_f32_sha256']
    res['csv_byte_match']=sha(b)==hashes[eid]['sha256'];res['regenerated_csv_sha256']=sha(b)
    if args.write_csv and all(res[k] for k in ['source_match','waveform_match','csv_byte_match']):
     with (out/(eid+'.csv')).open('xb') as f:f.write(b)
   except Exception as exc:res['error']=str(exc)
   results.append(res)
   if (j+1)%200==0:print(f'Checked {j+1}/{len(mapping)}',flush=True)
 summary={'records':len(results),'source_matches':sum(v['source_match'] for v in results),'waveform_matches':sum(v['waveform_match'] for v in results),'csv_byte_matches':sum(v['csv_byte_match'] for v in results),'errors':sum(bool(v['error']) for v in results),'elapsed_seconds':round(time.time()-started,2),'write_csv':args.write_csv,'training_performed':False,'profile':'float32 E/N/Z; float64 arange(6000)*0.01; int(arrival_sample)*0.01; pandas default float serialization; UTF-8 CRLF','environment':{'python':platform.python_version(),'numpy':np.__version__,'pandas':pd.__version__,'h5py':h5py.__version__},'scope':'Reconstructs retained CSV bytes from supplied trace mapping in tested HDF5; does not reconstruct original selection/filtering or assert another archive version.'}
 (out/'summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
 with (out/'records.csv').open('w',newline='',encoding='utf-8') as f:
  wr=csv.DictWriter(f,fieldnames=list(dict.fromkeys(k for v in results for k in v)));wr.writeheader();wr.writerows(results)
 print(json.dumps(summary,indent=2));return 0 if all(all(v[k] for k in ['source_match','waveform_match','csv_byte_match']) and not v['error'] for v in results) else 2
if __name__=='__main__':raise SystemExit(main())
