from pathlib import Path
import json,hashlib,re,zipfile
root=Path(__file__).resolve().parents[1]
records=json.loads((root/'work/ci-downloaded-index.json').read_text())
TREE='062f512579ac40e852ed617006edde879f5fea35'
SOURCE='5fe23854e06a05a11a274873f8913b9db357b243c87e27994ec3288fe398bcc4'
def raw_zip(a):
 p=Path(a['local_path']);data=p.read_bytes()
 assert len(data)==a['size_in_bytes']
 assert hashlib.sha256(data).hexdigest()==a['digest'].removeprefix('sha256:')
 return zipfile.ZipFile(p)
def result(z):
 matches=[n for n in z.namelist() if n=='results.json' or n.endswith('/results.json')]
 assert len(matches)==1,matches
 return json.loads(z.read(matches[0]))
def logs(z,j):
 actual=[]
 for c in j['checks']:
  assert c['passed'],c
  if c.get('log_sha256'):
   filename=c['name'].replace('/','_')+'.log'
   matches=[n for n in z.namelist() if n==filename or n.endswith('/'+filename)]
   assert len(matches)==1,(c['name'],matches)
   digest=hashlib.sha256(z.read(matches[0])).hexdigest()
   assert digest==c['log_sha256'],c['name']
   actual.append({'name':c['name'],'log_sha256':digest,'seconds':c.get('seconds'),'kind':c.get('kind')})
 return actual
def source(z,j):
 s=j['source'];p=j['provenance']
 assert j['passed'] and s['complete'] and not s['tracked_worktree_dirty'] and s['tree']==TREE
 assert p['reusable'] and p['status'] in ['stable','prepared']
 assert s['source_sha256']==p['start']['source_sha256']==p['end']['source_sha256']==SOURCE
 assert s['file_count']==10018 and s['bytes']==916018890
 assert p['manifests']['start']['sha256']==p['manifests']['end']['sha256']
 for phase in ['start','end']:
  manifest=p['manifests'][phase];data=z.read(manifest['path']);assert hashlib.sha256(data).hexdigest()==manifest['sha256']
  rows=[json.loads(line) for line in data.splitlines()];assert len(rows)==10018 and sum(row['bytes'] for row in rows)==916018890
plan_rec=next(a for a in records if a['name'].startswith('ci-plan-contracts-'))
with raw_zip(plan_rec) as z:plan=json.loads(z.read('ci-plan.json'))
assert plan['mode']=='full' and plan['source'] and plan['runtime'] and plan['acceptance'] and plan['selected_tests']==plan['registered_tests']==298
expected=[name for group in plan['matrix']['include'] for name in group['tests']]
assert len(expected)==len(set(expected))==298
sources=[a for a in records if re.fullmatch(r'voxelverse-validate-source-\d+-pull_request',a['name'])]
seen=[];verified=[]
for a in sources:
 with raw_zip(a) as z:
  j=result(z);source(z,j);checked=logs(z,j);selected=j['selected_tests']
  assert len(selected)==len(set(selected))
  actual=[c['name'] for c in j['checks'] if c.get('kind')=='headless_godot']
  assert set(actual)==set(selected) and len(actual)==len(selected)
  assert set(selected)<=set(expected)
  seen+=selected;verified.append({'artifact_id':a['id'],'selected_tests':selected,'checks':checked,'source':j['source'],'provenance_status':j['provenance']['status']})
assert len(seen)==len(set(seen))
runtime=next(a for a in records if a['name']=='voxelverse-validate-runtime-pull_request')
with raw_zip(runtime) as z:
 j=result(z);source(z,j);rlogs=logs(z,j);assert len(j['checks'])==27
 runtime_result={'passed':True,'checks':27,'logs_verified':len(rlogs),'artifact_id':runtime['id'],'source':j['source'],'provenance_status':j['provenance']['status']}
complete=len(sources)==8 and set(seen)==set(expected)
report={'complete':complete,'passed_so_far':True,'expected_tests':298,'actual_unique_passed':len(seen),'shards':len(sources),'source_tree':TREE,'source_sha256':SOURCE,'runtime':runtime_result,'source_artifacts':verified}
(root/'work/source-verification.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='source_artifacts'}))
