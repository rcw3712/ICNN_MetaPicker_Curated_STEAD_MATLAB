from pathlib import Path
import csv,json,collections
w=Path(r'C:\Users\catur\.codex\visualizations\2026\09\11\01a08fc7-0cf1-7772-a384-020417c19593'); root=w/'cg_scope_20260916/reproducibility_20260916/inputs/training_inputs/results/splits'
sets={k:{r['source_id'] for r in csv.DictReader((root/(k+'_source_ids.csv')).open())} for k in ['train','val','test']}
old={r['event_id']:r for r in csv.DictReader((w/'cg_replay_20260916/metadata_waveform_identity_audit.csv').open())}
m=json.loads((w/'stead_identity_recovery/candidate_scan_result.json').read_text())['matches']; groups=collections.defaultdict(lambda:collections.defaultdict(list)); rows=[]
for event,ms in m.items():
 sources={str(x['source_id']) for x in ms}
 if len(sources)!=1:continue
 source=next(iter(sources)); splits=[k for k,s in sets.items() if old[event]['claimed_source_id'] in s]
 assert len(splits)==1
 split=splits[0];groups[source][split].append(event)
 rows.append({'event_id':event,'split':split,'old_source_id':old[event]['claimed_source_id'],'verified_source_id':source,'trace_name':ms[0]['trace_name'],'p_label_delta_samples':ms[0]['p_label_delta_samples'],'s_label_delta_samples':ms[0]['s_label_delta_samples']})
overlap={s:dict(g) for s,g in groups.items() if len(g)>1}
summary={'scope':'All 2234 historical CSVs have exact float32 waveform matches; candidate search stops on full coverage and is not exhaustive for duplicates elsewhere in STEAD','matched_csvs':len(rows),'verified_sources':len(groups),'changed_source_ids':sum(r['old_source_id']!=r['verified_source_id'] for r in rows),'sources_spanning_splits':len(overlap),'train_test_sources':sum('train' in g and 'test' in g for g in groups.values()),'train_val_sources':sum('train' in g and 'val' in g for g in groups.values()),'val_test_sources':sum('val' in g and 'test' in g for g in groups.values())}
(w/'stead_identity_recovery/interim_split_audit.json').write_text(json.dumps({'summary':summary,'overlap':overlap,'rows':rows},indent=2));print(json.dumps(summary));print(json.dumps(dict(list(overlap.items())[:3])))

