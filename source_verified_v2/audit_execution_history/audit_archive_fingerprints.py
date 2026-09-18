from pathlib import Path
import sys,csv,json,hashlib,time,sqlite3,collections,os,threading,ctypes
w=Path(__file__).parent;sys.path.insert(0,str(w/'revision/pylibs'))
import numpy as np,h5py
out=w/'audit_no_training_20260918';out.mkdir(exist_ok=True)
fpath=Path(r'D:\STEAD_identity_recovery\merge.hdf5')
mpath=Path(r'D:\STEAD_identity_recovery\audit_20260916\recovered_mapping_2234.csv')
rows=list(csv.DictReader(mpath.open(encoding='utf-8-sig')))
targets=collections.defaultdict(list)
for r in rows:targets[r['waveform_f32_sha256']].append(r['event_id'])
start=time.time();st=fpath.stat()
(out/'fingerprint_pid.txt').write_text(str(os.getpid()))
prefetch_position=[0];prefetch_stop=threading.Event()
def prefetch():
 with fpath.open('rb') as raw:
  while not prefetch_stop.is_set():
   if raw.tell()<prefetch_position[0]+256*1024**2:
    if not raw.read(8*1024**2):break
   else:prefetch_stop.wait(.05)
threading.Thread(target=prefetch,daemon=True).start()
con=sqlite3.connect(out/'archive_fingerprint_index_f32F.sqlite')
con.execute('CREATE TABLE IF NOT EXISTS fingerprints (trace_name TEXT PRIMARY KEY, sha256 TEXT, shape TEXT, source_id TEXT, category TEXT, error TEXT)')
con.execute('CREATE TABLE IF NOT EXISTS state (key TEXT PRIMARY KEY, value TEXT)')
identity=json.dumps({'path':str(fpath),'bytes':st.st_size,'mtime_ns':st.st_mtime_ns},sort_keys=True)
old=con.execute("SELECT value FROM state WHERE key='archive'").fetchone()
assert old is None or old[0]==identity,'Archive changed'
con.execute('INSERT OR REPLACE INTO state VALUES (?,?)',('archive',identity));con.commit()
done={r[0] for r in con.execute('SELECT trace_name FROM fingerprints')};initial=len(done)
print('Opening archive',flush=True)
def val(v):
 if isinstance(v,bytes):return v.decode('utf-8')
 if isinstance(v,np.ndarray):return str(v.tolist())
 return str(v)
with h5py.File(fpath,'r') as h:
 print('Root objects',list(h.keys()),flush=True)
 config=h.id.get_mdc_config();config.set_initial_size=1;config.initial_size=16*1024**2;config.max_size=32*1024**2;h.id.set_mdc_config(config)
 g=h['data'];total=len(g);print('Trace objects',total,'already indexed',initial,flush=True)
 batch=[];errors=0;matched=0
 refs=[];index_path=out/'hdf5_object_addresses.csv'
 if index_path.exists():
  with index_path.open(newline='',encoding='utf-8') as fp:refs=[(r['trace_name'],int(r['object_address'])) for r in csv.DictReader(fp)]
 else:
  def link_callback(name,info):
   assert info.type==h5py.h5l.TYPE_HARD,'Non-hard link in data group'
   refs.append((name.decode('utf-8'),info.u))
  g.id.links.iterate(link_callback,info=True)
  refs.sort(key=lambda x:x[1])
  with index_path.open('w',newline='',encoding='utf-8') as fp:
   wr=csv.writer(fp);wr.writerow(['trace_name','object_address']);wr.writerows(refs)
 assert len(refs)==total and len({n for n,a in refs})==total
 lib=ctypes.CDLL(str(w/'revision/pylibs/h5py/hdf5.dll'));open_address=lib.H5Oopen_by_addr
 open_address.argtypes=[ctypes.c_longlong,ctypes.c_ulonglong];open_address.restype=ctypes.c_longlong
 print('Address index ready',len(refs),flush=True)
 for i,(name,address) in enumerate(refs):
  if name in done:continue
  try:
   identifier=open_address(h.id.id,address)
   assert identifier>=0,'Cannot open object by address'
   ds=h5py.Dataset(h5py.h5i.wrap_identifier(identifier))
   assert isinstance(ds,h5py.Dataset)
   offset=ds.id.get_offset()
   if offset is not None:prefetch_position[0]=offset
   a=np.asarray(ds[()],dtype='<f4',order='C');shape=json.dumps(list(a.shape))
   digest=hashlib.sha256(a.tobytes(order='F')).hexdigest()
   sid='';cat=''
   if digest in targets:
    sid=val(ds.attrs.get('source_id',''));cat=val(ds.attrs.get('trace_category',''))
    assert name==val(ds.attrs['trace_name']),'Address index and attribute trace name disagree'
   ds.id.close()
   batch.append((name,digest,shape,sid,cat,''));matched+=digest in targets
  except Exception as e:
   batch.append((name,'','','','',repr(e)));errors+=1
  if len(batch)>=1000:
   con.executemany('INSERT INTO fingerprints VALUES (?,?,?,?,?,?)',batch);con.commit();batch=[]
   elapsed=time.time()-start
   progress={'complete':False,'examined':i+1,'total':total,'resumed_rows':initial,'elapsed_seconds':elapsed,'session_matches':matched,'session_errors':errors,'rate_per_sec':con.execute('SELECT COUNT(*) FROM fingerprints').fetchone()[0]/max(elapsed,.001)}
   (out/'fingerprint_progress.json').write_text(json.dumps(progress,indent=2))
   print(json.dumps(progress),flush=True)
 assert i+1==total,(i+1,total)
 if batch:con.executemany('INSERT INTO fingerprints VALUES (?,?,?,?,?,?)',batch);con.commit()
prefetch_stop.set()
assert fpath.stat().st_mtime_ns==st.st_mtime_ns and fpath.stat().st_size==st.st_size
n=con.execute('SELECT COUNT(*) FROM fingerprints').fetchone()[0]
errors=con.execute("SELECT COUNT(*) FROM fingerprints WHERE error!=''").fetchone()[0]
assert n==total,(n,total)
con.execute('CREATE INDEX IF NOT EXISTS hash_index ON fingerprints(sha256)');con.commit()
results=[];matches=[]
for r in rows:
 ms=con.execute('SELECT trace_name,source_id,category,shape FROM fingerprints WHERE sha256=?',(r['waveform_f32_sha256'],)).fetchall()
 ss={m[1] for m in ms};expected=any(m[0]==r['trace_name'] and m[1]==r['verified_source_id'] for m in ms)
 results.append(dict(event_id=r['event_id'],sha256=r['waveform_f32_sha256'],matches=len(ms),distinct_source_ids=len(ss),expected_mapping_found=expected,expected_trace=r['trace_name'],expected_source=r['verified_source_id'],matched_sources='|'.join(sorted(ss))))
 for m in ms:matches.append(dict(event_id=r['event_id'],trace_name=m[0],source_id=m[1],trace_category=m[2],shape=m[3],sha256=r['waveform_f32_sha256']))
for name,rr in [('fingerprint_multiplicity.csv',results),('fingerprint_all_matches.csv',matches)]:
 with (out/name).open('w',newline='',encoding='utf-8') as f:
  writer=csv.DictWriter(f,fieldnames=list(rr[0]));writer.writeheader();writer.writerows(rr)
summary={'complete':errors==0,'scope':'Every direct dataset in /data of the local extracted merge.hdf5, including noise; no arrival-label or metadata selection filter. Not a claim about other STEAD archive versions.','archive':json.loads(identity),'datasets_total':total,'datasets_indexed':n,'read_errors':errors,'selected_records':len(rows),'selected_unique_fingerprints':len(targets),'records_unique_match':sum(r['matches']==1 for r in results),'records_multiple_matches':sum(r['matches']>1 for r in results),'records_conflicting_source_ids':sum(r['distinct_source_ids']>1 for r in results),'expected_mapping_found':sum(r['expected_mapping_found'] for r in results),'elapsed_seconds':time.time()-start,'hash_definition':'SHA256 of all samples, column-major E/N/Z, little-endian float32; shape retained separately. No normalization.'}
(out/'fingerprint_summary.json').write_text(json.dumps(summary,indent=2));(out/'fingerprint_progress.json').write_text(json.dumps(summary,indent=2));con.close();print('FINAL',json.dumps(summary),flush=True)
