from pathlib import Path
import subprocess,json,time,csv,threading,concurrent.futures,shutil
w=Path(__file__).parent;r=w/'audit_replay_threshold_station_20260918';matlab=r'C:\Program Files\MATLAB\R2024a\bin\matlab.exe'
prior=json.loads((r/'runner_progress.json').read_text());completed=list(prior['completed']);assert len(completed)==10
for group in ['Full3C_base42_oof','Full3C_base43_oof']:
 a=list(csv.DictReader((r/group/'oof_replay_receipt.csv').open()));assert len(a)==3088 and all(float(x['MaxFeatureDifference'])<=1e-6 for x in a)
if (r/'oof_Full3C_44.log').exists():shutil.copy2(r/'oof_Full3C_44.log',r/'oof_Full3C_44_interrupted_for_parallel_audit.log')
lock=threading.Lock();running=[];start=time.time();failures=[]
def save():
 state=dict(complete=len(completed)==14 and not failures,failed=bool(failures),total=14,completed=completed,running=running,failures=failures,elapsed_seconds=time.time()-start,maximum_parallel_audit_processes=2)
 tmp=r/'runner_progress.tmp';tmp.write_text(json.dumps(state,indent=2));tmp.replace(r/'runner_progress.json')
def run(job):
 mode,base=job;label=f'oof_{mode}_{base}'
 with lock:running.append(label);save();print('START',label,flush=True)
 expr="addpath('"+str(w)+"');replay_audit_v2('oof','"+mode+"',"+str(base)+");"
 with (r/(label+'.log')).open('w',encoding='utf-8') as f:result=subprocess.run([matlab,'-batch',expr],stdout=f,stderr=subprocess.STDOUT,cwd=str(w),creationflags=subprocess.CREATE_NO_WINDOW)
 with lock:
  running.remove(label)
  if result.returncode:failures.append(dict(stage=label,exit_code=result.returncode));print('FAIL',label,flush=True)
  else:completed.append(label);print('PASS',label,flush=True)
  save()
 return result.returncode
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
 codes=list(pool.map(run,[('Full3C',44),('Zonly',42),('Zonly',43),('Zonly',44)]))
assert not any(codes),codes
print('ALL REPLAY STAGES COMPLETE',flush=True)
