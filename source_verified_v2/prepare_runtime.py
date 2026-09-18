from pathlib import Path
import argparse,csv,hashlib,json,shutil
parser=argparse.ArgumentParser(description='Relocate a copy of the frozen protocol for an intentional new run; no training.')
parser.add_argument('--waveforms',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
root=Path(__file__).parent;source=root/'inputs';assert not args.output.exists(),'Use a new output directory.'
rows=list(csv.DictReader((source/'waveform_hashes.csv').open(encoding='utf-8')))
assert len(rows)==2234 and len(list(args.waveforms.glob('*.csv')))==2234
for row in rows:
 p=args.waveforms/(row['event_id']+'.csv');assert hashlib.sha256(p.read_bytes()).hexdigest()==row['sha256'],str(p)
protocol=json.loads((source/'protocol.json').read_text())
for row in protocol['files']:assert hashlib.sha256((source/row['relative_path']).read_bytes()).hexdigest()==row['sha256']
shutil.copytree(source,args.output);protocol['waveform_dir']=str(args.waveforms.resolve())
(args.output/'protocol.json').write_text(json.dumps(protocol,indent=2),encoding='utf-8')
receipt={'original_protocol_sha256':hashlib.sha256((source/'protocol.json').read_bytes()).hexdigest(),'relocated_protocol_sha256':hashlib.sha256((args.output/'protocol.json').read_bytes()).hexdigest(),'membership_changed':False,'waveform_files_verified':2234,'training_performed':False,'note':'Path relocation changes run signatures. Use a new result directory; never overwrite archived runs.'}
(args.output/'relocation_receipt.json').write_text(json.dumps(receipt,indent=2));print(json.dumps(receipt,indent=2))
