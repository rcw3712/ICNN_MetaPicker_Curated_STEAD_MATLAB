from pathlib import Path
import subprocess,sys,json,hashlib
P=Path(__file__).resolve().parents[1]
if '--verify' in sys.argv:
 manifest=json.loads((P/'SHA256_manifest.json').read_text())
 for path,want in manifest.items():
  assert hashlib.sha256((P/path).read_bytes()).hexdigest()==want,path
 print('Verified',len(manifest),'package hashes')
for name in ['audit_metrics.py','diagnostics.py','metadata_coverage.py','figures.py','metadata_figures.py','workflow_figure.py','tables.py']:
 subprocess.run([sys.executable,str(P/'analysis'/name)],check=True)
print('Complete. Outputs: regenerated/. Figure 12 additionally needs external waveform CSVs.')
