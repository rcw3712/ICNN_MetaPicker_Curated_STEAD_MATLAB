import unittest, tempfile, subprocess, sys, csv
from pathlib import Path
from seismic_eval_audit import audit_history, AuditInputError

class HistoryTests(unittest.TestCase):
 def current(self):
  return [dict(record_id=str(i),source_id=s,split='test') for i,s in enumerate(['A','A','B','C','D'])]
 def test_categories_are_exclusive_and_record_weighted(self):
  history=[dict(source_id=s,role=r) for s,r in [('A','train'),('A','test'),('B','test'),('D','review')]]
  x=audit_history(self.current(),history);c=x['categories']
  self.assertEqual(x['status'],'WARNING');self.assertEqual(c['prior_development']['sources'],1);self.assertEqual(c['prior_development']['records'],2)
  self.assertEqual(c['prior_test_only']['source_ids'],['B']);self.assertEqual(c['unknown']['source_ids'],['C']);self.assertEqual(c['other_documented_roles']['source_ids'],['D'])
  self.assertEqual(sum(v['records'] for v in c.values()),5)
 def test_duplicate_history_does_not_multiply_counts(self):
  h=[dict(source_id='A',role='val')]*3
  self.assertEqual(audit_history(self.current(),h)['categories']['prior_development']['records'],2)
 def test_empty_history_has_unknown_count(self):
  self.assertEqual(audit_history(self.current(),[])['categories']['unknown']['sources'],4)
 def test_no_test_rejected(self):
  with self.assertRaises(AuditInputError):audit_history([dict(record_id='a',source_id='A',split='train')],[])
 def test_custom_development_label(self):
  r=audit_history(self.current(),[dict(source_id='A',role='development')],development_roles=('development',))
  self.assertEqual(r['categories']['prior_development']['sources'],1)
 def test_bad_role_rejected(self):
  with self.assertRaises(AuditInputError):audit_history(self.current(),[dict(source_id='A',role=' ')])
 def test_strict_cli_warning(self):
  with tempfile.TemporaryDirectory() as t:
   f=Path(t)/'in.csv'
   with f.open('w',newline='') as z:
    w=csv.DictWriter(z,fieldnames=['record_id','source_id','split']);w.writeheader();w.writerows(self.current())
   cmd=[sys.executable,'-m','seismic_eval_audit',str(f),'--output',str(Path(t)/'out'),'--strict']
   r=subprocess.run(cmd,capture_output=True);self.assertEqual(r.returncode,1)
