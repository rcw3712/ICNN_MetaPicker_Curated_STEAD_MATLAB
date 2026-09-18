from pathlib import Path
import csv,json,math
w=Path(__file__).parent;r=w/'audit_replay_threshold_station_20260918'
jobs=list(csv.DictReader((r/'test_jobs.csv').open()));peak=[];quality=[]
for j in jobs:
 if j['kind'] not in ['full15ch','PhaseNetMatched']:continue
 rows=list(csv.DictReader((r/j['group']/(j['label']+'_threshold_statistics.csv')).open()))
 for x in rows:
  for c in ['p_peak','s_peak_20','s_peak_30','s_peak_40']:
   v=float(x[c])
   if math.isfinite(v):peak.append(min(abs(v-k) for k in [.1,.15,.2,.3,.4]))
  for c in ['p_quality','s_quality_20','s_quality_30','s_quality_40']:
   v=float(x[c])
   if math.isfinite(v):quality.append(min(abs(v-k) for k in [2,3,4]))
a=dict(min_peak_distance_to_any_grid_cutoff=min(peak),min_quality_distance_to_any_grid_cutoff=min(quality),cutoff_margin_tolerance=1e-10,passed=min(peak)>1e-10 and min(quality)>1e-10)
assert a['passed'];(r/'threshold/csv_precision_margin_check.json').write_text(json.dumps(a,indent=2));print(json.dumps(a,indent=2))
