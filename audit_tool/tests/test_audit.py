import unittest,tempfile,hashlib,subprocess,sys,csv,json
from pathlib import Path
from seismic_eval_audit.core import *
def rows():return [{'record_id':str(i),'source_id':str(i//2),'split':'train' if i<14 else ('dev' if i<18 else 'test')} for i in range(24)]
class AuditTests(unittest.TestCase):
 def test_valid(self):self.assertEqual(audit_split(rows())['status'],'PASS')
 def test_overlap(self):
  x=rows();x[0]['split']='test';r=audit_split(x);self.assertEqual(r['shared_sources'],1);self.assertEqual(r['affected_records'],2)
 def test_empty(self):
  with self.assertRaises(AuditInputError):audit_split([])
 def test_missing(self):
  for v in ['',None,'nan',' 1']:
   x=rows();x[0]['source_id']=v
   with self.assertRaises(AuditInputError):audit_split(x)
 def test_duplicate_ambiguous(self):
  x=rows();x.append(dict(x[0],source_id='other'))
  with self.assertRaises(AuditInputError):audit_split(x)
 def test_exact_text_ids(self):
  x=[{'record_id':'a','source_id':'001','split':'train'},{'record_id':'b','source_id':'1','split':'test'}]
  self.assertEqual(audit_split(x)['sources'],2)
 def test_single_split_warning(self):self.assertEqual(audit_split([dict(x,split='train') for x in rows()])['status'],'WARNING')
 def test_grouped_order_independent(self):
  a=assign_split(rows());b=assign_split(list(reversed(rows())))
  self.assertEqual({r['record_id']:r['split'] for r in a},{r['record_id']:r['split'] for r in b});self.assertEqual(audit_split(a)['status'],'PASS')
 def test_bad_fractions(self):
  for v in [(.5,.5,0),(.5,.2,.2),(float('nan'),.2,.8)]:
   with self.assertRaises(AuditInputError):assign_split(rows(),fractions=v)
 def test_small_group_count(self):
  with self.assertRaises(AuditInputError):assign_split(rows()[:2])
 def test_parent(self):
  p=rows()[0];c=dict(p,record_id='aug',parent_id=p['record_id']);self.assertEqual(check_lineage([p],[c])['status'],'PASS');c['source_id']='wrong';self.assertEqual(check_lineage([p],[c])['status'],'FAIL')
 def test_parent_split(self):
  p=rows()[0];c=dict(p,record_id='aug',parent_id='0',split='test');self.assertEqual(check_lineage([p],[c])['status'],'FAIL')
 def test_missing_parent(self):
  c=dict(rows()[0],record_id='aug',parent_id='absent');self.assertEqual(check_lineage(rows(),[c])['status'],'FAIL')
 def test_oof(self):
  x=rows();self.assertEqual(check_oof(x[:2],x[2:4],x[4:6])['status'],'PASS');self.assertEqual(check_oof(x[:2],x[:1],[])['status'],'FAIL')
 def test_inner_oof(self):
  x=rows();self.assertEqual(check_oof(x[:2],x[2:4],x[:1])['status'],'FAIL')
 def test_schema(self):self.assertEqual(check_schema(['N','E','Z'],['E','N','Z'])['status'],'FAIL');self.assertEqual(check_schema(['E','N','Z'],['E','N','Z'])['status'],'PASS')
 def test_bytes(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'a';p.write_bytes(b'a');e=[{'path':'a','sha256':hashlib.sha256(b'a').hexdigest()}];self.assertEqual(check_artifacts(d,e)['status'],'PASS');p.write_bytes(b'b');self.assertEqual(check_artifacts(d,e)['status'],'FAIL')
 def test_path_escape(self):
  with self.assertRaises(AuditInputError):check_artifacts('.', [{'path':'../x','sha256':'0'*64}])
 def test_history_missing(self):self.assertEqual(audit_history(rows(),[])['status'],'WARNING')
 def test_cli(self):
  with tempfile.TemporaryDirectory() as t:
   f=Path(t)/'in.csv'
   with f.open('w',newline='') as z:
    w=csv.DictWriter(z,fieldnames=['record_id','source_id','split']);w.writeheader();w.writerows(rows())
   cmd=[sys.executable,'-m','seismic_eval_audit',str(f),'--output',str(Path(t)/'out')]
   a=subprocess.run(cmd,capture_output=True);self.assertEqual(a.returncode,0);self.assertTrue((Path(t)/'out/report.json').exists());b=subprocess.run(cmd,capture_output=True);self.assertEqual(b.returncode,2)
if __name__=='__main__':unittest.main()
