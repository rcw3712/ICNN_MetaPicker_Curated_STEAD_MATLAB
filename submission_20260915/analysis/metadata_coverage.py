from pathlib import Path
import pandas as pd,json
P=Path(__file__).resolve().parents[1];O=P/'regenerated';O.mkdir(exist_ok=True)
m=pd.read_excel(P/'inputs/metadata/metadata_master_2234_final.xlsx')
m['network_from_trace']=m.trace_name.str.extract(r'^[^.]+\.([^_]+)_')[0]
m['station_key']=m.network_from_trace.fillna('unknown')+'.'+m.receiver_code.astype(str)
ss={};out=[]
for part in ['train','val','test']:
 ids=pd.read_csv((P/'inputs/results/splits')/(part+'_source_ids.csv')).iloc[:,0]
 z=m[m.source_id.isin(ids)];ss[part]=set(z.station_key)
 out.append(dict(Subset=part,Records=len(z),Sources=z.source_id.nunique(),Station_keys=z.station_key.nunique(),Network_codes=z.network_from_trace.nunique(),Network_counts=z.network_from_trace.value_counts().to_dict()))
report={'subsets':out,'test_station_keys_shared_with_training':len(ss['test']&ss['train']),'test_station_keys_total':len(ss['test']),'coordinate_columns_available':False}
(O/'metadata_coverage.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
