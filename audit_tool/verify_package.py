"""Verify the public package manifest without third-party dependencies."""
from pathlib import Path
import json
from seismic_eval_audit import check_artifacts,read_csv
root=Path(__file__).resolve().parent
entries=read_csv(root/'CHECKSUMS.csv')
report=check_artifacts(root,entries);report['files']=len(entries)
print(json.dumps(report))
raise SystemExit(0 if report['status']=='PASS' else 1)
