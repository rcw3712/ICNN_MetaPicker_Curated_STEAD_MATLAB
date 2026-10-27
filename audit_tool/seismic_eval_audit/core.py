"""Checks are conditional on supplied identifiers; never infer event identity."""
import csv, hashlib, json, math, random
from pathlib import Path
from collections import Counter, defaultdict
from itertools import combinations

class AuditInputError(ValueError): pass

def value(row, key):
    x = row.get(key)
    if x is None or not isinstance(x, str) or not x.strip() or x.lower() in {"nan", "none", "null"}:
        raise AuditInputError(f"Missing/invalid text identifier: {key}")
    if x != x.strip(): raise AuditInputError(f"Whitespace in identifier: {key}")
    return x

def validate_records(rows, record="record_id", group="source_id", split=None):
    rows = list(rows)
    if not rows: raise AuditInputError("Empty input cannot pass")
    seen=set()
    for row in rows:
        rid=value(row, record); value(row, group)
        if rid in seen: raise AuditInputError("Duplicate or ambiguous record: " + rid)
        seen.add(rid)
        if split: value(row, split)
    return rows

def audit_split(rows, record="record_id", group="source_id", split="split"):
    rows=validate_records(rows,record,group,split)
    membership=defaultdict(set); bysplit=defaultdict(list)
    for row in rows:
        membership[row[group]].add(row[split]); bysplit[row[split]].append(row)
    shared={s:sorted(v) for s,v in membership.items() if len(v)>1}
    pairs=[]
    for a,b in combinations(sorted(bysplit),2):
        overlap={s for s,v in membership.items() if a in v and b in v}
        pairs.append({"a":a,"b":b,"shared_sources":len(overlap),
          "a_records":sum(r[group] in overlap for r in bysplit[a]),
          "b_records":sum(r[group] in overlap for r in bysplit[b])})
    affected=[{"record_id":r[record],"source_id":r[group],"split":r[split]} for r in rows if r[group] in shared]
    return {"status":"FAIL" if shared else ("PASS" if len(bysplit)>1 else "WARNING"),
      "scope":"Exact equality of supplied group identifiers only", "group_column":group,
      "records":len(rows),"sources":len(membership),"shared_sources":len(shared),
      "affected_records":len(affected),"pairs":pairs,"violations":affected,
      "splits":{k:{"records":len(v),"sources":len({r[group] for r in v})} for k,v in sorted(bysplit.items())}}

def assign_split(rows, grouped=True, record="record_id", group="source_id", seed=42, fractions=(.7,.15,.15)):
    rows=validate_records(rows,record,group)
    if len(fractions)!=3 or any(not math.isfinite(v) or v<=0 for v in fractions) or not math.isclose(sum(fractions),1):
        raise AuditInputError("Three positive fractions must sum to one")
    key=group if grouped else record
    keys=sorted({r[key] for r in rows})
    n=len(keys); a=int(n*fractions[0]); b=a+int(n*fractions[1])
    if not 0<a<b<n: raise AuditInputError("Too few units for three nonempty partitions")
    random.Random(seed).shuffle(keys)
    m={s:("train" if i<a else "dev" if i<b else "test") for i,s in enumerate(keys)}
    return [dict(r,split=m[r[key]]) for r in rows]

def check_lineage(parents,children):
    parents=validate_records(parents,split="split");children=validate_records(children,split="split")
    index={r['record_id']:r for r in parents}; failures=[]
    for c in children:
        pid=value(c,'parent_id');p=index.get(pid)
        if c['record_id'] in index or p is None or any(c[k]!=p[k] for k in ['source_id','split']): failures.append(c['record_id'])
    return {"status":"FAIL" if failures else "PASS","violations":failures}

def check_oof(held,fit,inner_validation):
    # Empty inner validation is allowed; empty held/fit is not.
    h={r['source_id'] for r in validate_records(held)}
    f={r['source_id'] for r in validate_records(fit)}
    v={r['source_id'] for r in validate_records(inner_validation)} if inner_validation else set()
    overlaps={"held_fit":sorted(h&f),"held_inner_validation":sorted(h&v),"fit_inner_validation":sorted(f&v)}
    return {"status":"FAIL" if any(overlaps.values()) else "PASS","violations":overlaps}

def check_schema(actual,expected):
    if not expected or len(set(expected))!=len(expected) or any(not isinstance(x,str) or not x.strip() for x in expected):
        raise AuditInputError("Invalid reference schema")
    return {"status":"PASS" if list(actual)==list(expected) else "FAIL","actual":list(actual),"expected":list(expected)}

def check_artifacts(root,entries):
    root=Path(root).resolve();entries=list(entries)
    if not entries: raise AuditInputError("Empty manifest")
    failures=[];seen=set()
    for e in entries:
        name=value(e,'path');expected=value(e,'sha256')
        if len(expected)!=64 or any(c not in '0123456789abcdef' for c in expected):raise AuditInputError("Invalid SHA256")
        if name in seen:raise AuditInputError("Duplicate artifact path")
        seen.add(name);p=(root/name).resolve()
        if p==root or root not in p.parents: raise AuditInputError("Path outside artifact root")
        h=hashlib.sha256()
        if not p.is_file():failures.append(name);continue
        with p.open('rb') as f:
            for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
        if h.hexdigest()!=expected:failures.append(name)
    return {"status":"FAIL" if failures else "PASS","violations":failures}

def audit_history(current,history,development_roles=('train','val'),test_label='test'):
    current=validate_records(current,split='split')
    tests=[r for r in current if r['split']==test_label]
    if not tests:raise AuditInputError('No current test records')
    if not development_roles or any(not isinstance(x,str) or not x.strip() or x!=x.strip() for x in development_roles):raise AuditInputError('Invalid development roles')
    roles=defaultdict(set)
    for r in history:roles[value(r,'source_id')].add(value(r,'role'))
    test={r['source_id'] for r in tests}
    exposed={s:sorted(roles[s]) for s in test if s in roles}
    dev={s for s in test if roles.get(s,set()) & set(development_roles)}
    only_test={s for s in test if roles.get(s)=={test_label}}
    unknown=test-set(roles)
    other=test-dev-only_test-unknown
    groups={'prior_development':dev,'prior_test_only':only_test,'unknown':unknown,'other_documented_roles':other}
    return {"status":"WARNING", "test_sources":len(test),"test_records":len(tests),
      "development_roles":list(development_roles),
      "categories":{k:{'sources':len(v),'records':sum(r['source_id'] in v for r in tests),'source_ids':sorted(v)} for k,v in groups.items()},
      "documented_prior_roles":exposed,"unknown_history_sources":sorted(test-set(roles)),
      "scope":"Historical roles describe documented use; no category certifies independent confirmation"}

def read_csv(path):
    with open(path,newline='',encoding='utf-8-sig') as f:return list(csv.DictReader(f))

def write_report(report,out):
    out=Path(out);out.mkdir(parents=True,exist_ok=False)
    (out/'report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    with (out/'violations.csv').open('w',newline='',encoding='utf-8') as f:
        w=csv.DictWriter(f,fieldnames=['record_id','source_id','split']);w.writeheader();w.writerows(report.get('violations',[]))
    (out/'report.md').write_text('# Source membership audit\n\nStatus: '+report['status']+'\n\n'+
      '\n'.join(f'- {k}: {report[k]}' for k in ['records','sources','shared_sources','affected_records'] if k in report)+
      '\n\nPASS applies only to supplied identifiers. Missing checks, catalogue correctness, near duplicates and historical independence are not certified.\n',encoding='utf-8')
