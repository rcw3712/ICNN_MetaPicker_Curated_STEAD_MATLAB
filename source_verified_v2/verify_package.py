from pathlib import Path
import csv,hashlib,json
root=Path(__file__).parent
rows=list(csv.DictReader((root/'SHA256_MANIFEST.csv').open(encoding='utf-8')))
for row in rows:
 p=(root/row['path']).resolve();assert p.is_relative_to(root.resolve())
 assert p.is_file() and p.stat().st_size==int(row['bytes']),row['path']
 assert hashlib.sha256(p.read_bytes()).hexdigest()==row['sha256'],row['path']
models=list(csv.DictReader((root/'model_manifest.csv').open(encoding='utf-8')));assert len(models)==106
for row in models:assert hashlib.sha256((root/row['path']).read_bytes()).hexdigest()==row['sha256'],row['path']
print(json.dumps({'files_verified':len(rows),'checkpoints':len(models),'mismatches':0},indent=2))
