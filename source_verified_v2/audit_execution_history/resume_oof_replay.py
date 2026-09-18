from pathlib import Path
import subprocess,json,time,sys,csv
w=Path(__file__).parent;o=w/'audit_replay_threshold_station_20260918'
matlab=r'C:\Program Files\MATLAB\R2024a\bin\matlab.exe'
steps=[('test',m,b) for m in ['Full3C','Zonly'] for b in [42,43,44]]+[('phasenet',m,42) for m in ['Full3C','Zonly']]+[('oof',m,b) for m in ['Full3C','Zonly'] for b in [42,43,44]]
start=time.time();prior=json.loads((o/"runner_progress.json").read_text());receipts=prior["completed"];assert len(receipts)==8
for group in [m+"_base"+str(b) for m in ["Full3C","Zonly"] for b in [42,43,44]]+[m+"_phasenet" for m in ["Full3C","Zonly"]]:
 rr=list(csv.DictReader((o/group/"prediction_replay_receipt.csv").open()));assert all(int(x["Records"])==330 and int(x["StatusMismatches"])==0 and int(x["PickMismatches"])==0 for x in rr)
for i,(stage,mode,base) in enumerate(steps,1):
 label=f'{stage}_{mode}_{base}'
 if label in receipts:continue
 state=dict(complete=False,failed=False,index=i,total=len(steps),stage=stage,mode=mode,base=base,elapsed_seconds=time.time()-start,completed=receipts)
 (o/'runner_progress.json').write_text(json.dumps(state,indent=2));print('START',label,flush=True)
 expr="addpath('"+str(w).replace("'","''")+"');replay_audit_v2('"+stage+"','"+mode+"',"+str(base)+");"
 with (o/(label+'.log')).open('w',encoding='utf-8') as log:
  run=subprocess.run([matlab,'-batch',expr],stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW,cwd=str(w))
 if run.returncode:
  state.update(failed=True,exit_code=run.returncode);(o/'runner_progress.json').write_text(json.dumps(state,indent=2));print('FAILED',label,run.returncode,flush=True);sys.exit(run.returncode)
 receipts.append(label);print('PASS',label,flush=True)
(o/'runner_progress.json').write_text(json.dumps(dict(complete=True,failed=False,completed=receipts,elapsed_seconds=time.time()-start),indent=2));print('ALL REPLAY STAGES COMPLETE',flush=True)
