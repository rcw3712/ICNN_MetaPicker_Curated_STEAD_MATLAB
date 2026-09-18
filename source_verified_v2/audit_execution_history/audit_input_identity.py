from pathlib import Path
import sys,csv,json,time
w=Path(__file__).parent;sys.path.insert(0,str(w/'revision/pylibs'));import numpy as np,openpyxl
s=w/'cg_replay_20260916';p=s/'reproducibility_20260916';sh=openpyxl.load_workbook(p/'inputs/training_inputs/metadata/metadata_master_2234_final.xlsx',read_only=True,data_only=True).active
it=iter(sh.values);h=next(it);rows=[];refs=[];start=time.monotonic();root=Path(r'C:\Drive E\ICNN_MetaPicker_Curated_STEAD_MATLAB\data\csv_stead_filtered')
import hashlib
for j,row in enumerate(it):
 m=dict(zip(h,row));event=m['event_id'];a=np.loadtxt(root/(event+'.csv'),delimiter=',',skiprows=1,usecols=(1,2,3,4,5,6));wave=a[:,1:4]
 ps=[int(round(a[0,k]*100)) for k in [4,5]];mp=[int(m[k]) for k in ['p_arrival_sample_0based','s_arrival_sample_0based']]
 stats=[np.abs(wave[:,k]).max() for k in range(3)];ms=[m[k+'_absmax'] for k in ['E','N','Z']]
 stats_ok=bool(np.allclose(stats,ms,rtol=1e-5,atol=1e-5));pair=ps==mp
 rows.append(dict(event_id=event,claimed_trace_name=m['trace_name'],claimed_source_id=m['source_id'],csv_p_sample=ps[0],csv_s_sample=ps[1],metadata_p_sample=mp[0],metadata_s_sample=mp[1],p_matches=ps[0]==mp[0],s_matches=ps[1]==mp[1],pair_matches=pair,three_component_absmax_matches=stats_ok))
 refs.append(dict(event_id=event,n_samples=6000,sampling_rate_hz=100,p_sample=ps[0],s_sample=ps[1],waveform_f32_sha256=hashlib.sha256(np.asarray(wave,dtype='<f4').tobytes(order='F')).hexdigest(),historical_parsed_f64_sha256=hashlib.sha256(np.asarray(wave,dtype='<f8').tobytes(order='F')).hexdigest()))
 if j%500==0:print(j,round(time.monotonic()-start,1),flush=True)
for file,data in [('metadata_waveform_identity_audit.csv',rows),('numerical_waveform_manifest.csv',refs)]:
 with (s/file).open('w',newline='',encoding='utf-8') as f:
  wr=csv.DictWriter(f,fieldnames=list(data[0]));wr.writeheader();wr.writerows(data)
summary={key:sum(r[key] for r in rows) for key in ['p_matches','s_matches','pair_matches','three_component_absmax_matches']};summary['records']=len(rows);summary['interpretation']='Metadata-to-waveform mapping must be established before interpreting source IDs as physical source identities.'
(s/'metadata_waveform_identity_audit.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary),flush=True)
