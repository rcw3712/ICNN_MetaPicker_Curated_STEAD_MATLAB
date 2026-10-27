import argparse,hashlib,urllib.request
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--output',required=True,type=Path);a=p.parse_args()
url='https://hifis-storage.desy.de/Helmholtz/HelmholtzAI/SeisBench/datasets/ethz/metadata.csv'
expected='542d2e9cfc35847668521fe335bc955b00a42f59f06eaa921ffb92f6009a1dee'
with urllib.request.urlopen(url,timeout=60) as r:b=r.read(50*1024*1024)
if hashlib.sha256(b).hexdigest()!=expected:raise SystemExit('Metadata hash differs; inspect upstream version, do not silently accept')
with a.output.open('xb') as f:f.write(b)
print('Verified ETHZ metadata',expected)
