from seismic_eval_audit import read_csv,audit_split,assign_split,write_report
from pathlib import Path
import argparse,json,time,csv,hashlib,platform
p=argparse.ArgumentParser();p.add_argument('--metadata',required=True,type=Path);p.add_argument('--output',required=True,type=Path);a=p.parse_args()
a.output.mkdir(parents=True,exist_ok=False)
x=[{'record_id':r['trace_name'],'source_id':r['source_id'],'split':r['split']} for r in read_csv(a.metadata)]
summary={}
for name,data in [('provided',x),('record_random',assign_split(x,False)),('grouped',assign_split(x,True))]:
 t=time.perf_counter();r=audit_split(data);r['audit_seconds']=time.perf_counter()-t
 write_report(r,a.output/name)
 with (a.output/name/'membership.csv').open('w',newline='',encoding='utf-8') as f:
  w=csv.DictWriter(f,fieldnames=['record_id','source_id','split']);w.writeheader();w.writerows(data)
 summary[name]={k:v for k,v in r.items() if k!='violations'}
summary['provenance']={'input_sha256':hashlib.sha256(a.metadata.read_bytes()).hexdigest(),'python':platform.python_version(),'seed':42,'fractions':[.7,.15,.15],'training':False,'inference':False}
(a.output/'summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
print(json.dumps(summary,indent=2))
