import argparse,json,hashlib,sys
from .core import read_csv,audit_split,write_report,AuditInputError

def main():
    p=argparse.ArgumentParser(description="Audit supplied source IDs; no model execution")
    p.add_argument('metadata');p.add_argument('--record',default='record_id');p.add_argument('--group',default='source_id');p.add_argument('--split',default='split');p.add_argument('--output',required=True)
    p.add_argument('--strict',action='store_true',help='Return exit 1 also for WARNING')
    a=p.parse_args()
    try:
        r=audit_split(read_csv(a.metadata),a.record,a.group,a.split)
        with open(a.metadata,'rb') as f:r['input_sha256']=hashlib.sha256(f.read()).hexdigest()
        write_report(r,a.output)
    except (AuditInputError,OSError) as e:
        print('ERROR: '+str(e),file=sys.stderr);return 2
    print(json.dumps({k:v for k,v in r.items() if k!='violations'}));return 1 if r['status']=='FAIL' or (a.strict and r['status']=='WARNING') else 0
