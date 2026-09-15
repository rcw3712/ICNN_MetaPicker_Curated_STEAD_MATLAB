from pathlib import Path
import pandas as pd,numpy as np,json
P=Path(__file__).resolve().parents[1];O=P/'regenerated';O.mkdir(exist_ok=True);T=O/'Tables';T.mkdir(exist_ok=True)
def save(name,df):df.to_csv(T/(name+'.csv'),index=False)
m=pd.read_excel(P/'inputs/metadata/metadata_master_2234_final.xlsx')
s=pd.read_csv(O/'replacement_multiseed_summary.csv');a=pd.read_csv(O/'recomputed_metrics.csv');b=pd.read_csv(O/'paired_bootstrap_mean_F1.csv')
save('Table1',pd.DataFrame({'Item':['Records','Sources','Sampling Hz','Samples','Minimum SNR dB'],'Value':[len(m),m.source_id.nunique(),100,6000,m.min_snr_db.min()]}))
parts=[]
for part in ['train','val','test']:
 ids=pd.read_csv(P/'inputs/results/splits'/f'{part}_source_ids.csv').iloc[:,0];parts.append([part,len(ids),m.source_id.isin(ids).sum()])
save('Table2',pd.DataFrame(parts,columns=['Subset','Sources','Records']))
save('Table3',pd.read_csv(P/'derived/configuration_table.csv'))
save('Table4',s[(s.Variant=='full15ch')&(s.Tolerance_ms==100)])
save('Table5',b[b.Comparison=='Full15 - Zonly'])
save('TableS1',pd.read_csv(P/'derived/tensor_stats.csv'))
save('TableS2',pd.read_csv(O/'bootstrap_all.csv'))
desc=pd.read_csv(O/'error_descriptives.csv');save('TableS3',desc[desc.Seed==42])
save('TableS4',pd.read_csv(P/'derived/workflow_settings.csv'))
base=a[(a.Evaluation.str.startswith('Full3C'))&(a.Evaluation.str.contains('baselines'))&(a.Policy=='accepted')]
control=s[(s.Mode=='Full3C')&(s.Variant=='full15ch')].copy();control['Evaluation']='I-CNN mean';control['F1']=control.F1_mean
save('TableS5',pd.concat([base,control],ignore_index=True))
ss=s[s.Mode=='Full3C'].merge(b,left_on=['Phase','Tolerance_ms'],right_on=['Phase','Tolerance_ms'],how='left')
# Keep matching comparator intervals; full control has no self-comparison.
rows=[]
for r in s[s.Mode=='Full3C'].to_dict('records'):
 q=b[(b.Comparison=='Full15 - '+r['Variant'])&(b.Phase==r['Phase'])&(b.Tolerance_ms==r['Tolerance_ms'])]
 if len(q):r.update(q.iloc[0][['Delta','CI_low','CI_high']].to_dict())
 rows.append(r)
save('TableS6',pd.DataFrame(rows))
save('TableS7',a[(a.Evaluation.str.contains('evaluation\\\\full15ch_seed42'))&(a.Policy=='accepted')&(a.Tolerance_ms==100)])
save('TableS8',pd.read_csv(P/'derived/data_roles.csv'))
plan=pd.read_csv(P/'frozen/training_plan_40.csv');save('TableS9',plan.groupby(['mode','kind']).size().reset_index(name='Fits'))
save('TableS10',pd.read_csv(O/'detected_only_summary.csv'))
save('TableS11',pd.read_csv(O/'p_gate_diagnostics.csv'))
c=json.loads((O/'metadata_coverage.json').read_text());save('TableS12',pd.DataFrame(c['subsets']).drop(columns='Network_counts'))
assert len(list(T.glob('*.csv')))==17
print('Exported 17 numeric/configuration table sources. Table S1 uses the supplied full-cache statistics receipt; see docs/REPRODUCTION.md.')
