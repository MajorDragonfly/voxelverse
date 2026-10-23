from pathlib import Path
import json,hashlib,zipfile
root=Path(__file__).resolve().parents[1];records=json.loads((root/'work/ci-downloaded-index.json').read_text());reports=[]
for a in records:
 if not a['name'].startswith('export-diagnostics-'):continue
 data=Path(a['local_path']).read_bytes();assert len(data)==a['size_in_bytes'] and hashlib.sha256(data).hexdigest()==a['digest'].removeprefix('sha256:')
 with zipfile.ZipFile(a['local_path']) as z:
  j=json.loads(z.read('results.json'));s=j['source'];p=j['provenance']
  assert j['passed'] and j['complete'] and len(j['checks'])==42
  assert s['complete'] and not s['tracked_worktree_dirty'] and s['tree']=='062f512579ac40e852ed617006edde879f5fea35'
  assert s['index_sha256']=='74fb7273c0062996ec6b77692f84fae96f3a0b25c94930b4d3be771c16b2a19d' and s['file_count']==10018 and s['bytes']==916018890
  assert p['reusable'] and p['status'] in ['stable','prepared']
  assert s['source_sha256']==p['start']['source_sha256']==p['end']['source_sha256']
  assert p['manifests']['start']['sha256']==p['manifests']['end']['sha256']
  assert len(j['probes'])==3 and all(p['passed'] for p in j['probes'])
  if j['platform']=='linux':
   assert p['manifests']['start']['sha256']=='93b8279e0e8e9147cccbb5d487db5b8b76b58915daac05a144fa35cbd3ed3d39'
  checked=[]
  for c in j['checks']:
   assert c['passed'],c
   if c.get('log_sha256'):
    filename=c['name'].replace('/','_')+'.log';matches=[n for n in z.namelist() if n==filename or n.endswith('/'+filename)];assert len(matches)==1,(c['name'],matches)
    digest=hashlib.sha256(z.read(matches[0])).hexdigest();assert digest==c['log_sha256']
    checked.append({'name':c['name'],'log_sha256':digest,'seconds':c.get('seconds')})
  reports.append({'platform':j['platform'],'passed':True,'complete':True,'checks':42,'log_hashes_verified':len(checked),'actual_checks':checked,'source':s,'provenance':{k:p[k] for k in ['status','reusable','manifests']},'probes':j['probes'],'release_archive':j['archive'],'artifact_id':a['id'],'note':'Raw export source JSONLs are not included in this upstream artifact; declared source hashes/manifests and all actual log bytes retained. Cross-OS raw source fingerprints are recorded separately.'})
assert len({j['platform'] for j in reports})==len(reports)
result={'complete':{j['platform'] for j in reports}=={'linux','windows'},'passed_so_far':True,'platforms':reports,'source_tree':'062f512579ac40e852ed617006edde879f5fea35'}
(root/'work/export-verification.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'complete':result['complete'],'platforms':[{'platform':j['platform'],'checks':j['checks'],'log_hashes_verified':j['log_hashes_verified'],'source_sha256':j['source']['source_sha256']} for j in reports]}))
