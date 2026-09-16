"""Verify immutable package files using Python standard library only."""
from pathlib import Path
import csv,hashlib
root=Path(__file__).resolve().parent
rows=list(csv.DictReader((root/'SHA256SUMS.csv').open(encoding='utf-8',newline='')))
for row in rows:
 path=(root/row['path']).resolve()
 assert path.is_relative_to(root), 'Manifest path escapes package'
 assert path.is_file(), 'Missing: '+row['path']
 with path.open('rb') as stream:digest=hashlib.file_digest(stream,'sha256').hexdigest()
 assert digest==row['sha256'], 'Hash mismatch: '+row['path']
print(f'PASS: {len(rows)} package files match SHA-256 manifest.')
