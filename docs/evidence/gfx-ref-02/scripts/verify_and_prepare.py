import hashlib, json, re, subprocess, zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parent
REPO=ROOT/'gfx02-evidence'; D=REPO/'docs/evidence/gfx-ref-02'; A=ROOT/'artifacts'
HEAD='70b42cfb11868f47c4ffe94a581b54a62f7b2eb9'
BASE='ca7ac06b671abceec54a110682c70746bfddde45'
TREE='d31860a0ed3a13f8a6c0c77a95d8f79fda212b97'
MERGE='3df6727ef184af3d13772aa4e2cf5bf9990399f5'
FP='f4eeb33da6ced083efe6e5e062a7ec649a07d63680849ffa9d94be890b19ce5f'
def git(*args):return subprocess.check_output(['git','--no-pager',*args],cwd=REPO,timeout=45)
def save(path,obj):
 p=D/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(obj,indent=2)+'\n')
index=json.loads((A/'index.json').read_text())
sources=[];native=[];exports={};archives=[]
for item in index:
 data=(A/item['archive']).read_bytes();assert hashlib.sha256(data).hexdigest()==item['sha256']
 with zipfile.ZipFile(A/item['archive']) as z:
  names=z.namelist();hashes={hashlib.sha256(z.read(n)).hexdigest():n for n in names if not n.endswith('/')}
  if re.search(r'validate-(source|runtime)-',item['name']):
   raw=z.read('results.json');x=json.loads(raw);current=x['source']['tree']==TREE
   assert x['source']['tree']==(TREE if current else '4d73ada2d4bc9e28b01f05b431b6b954b8bb013c')
   assert x['source']['commit']==(MERGE if current else '7fa54b52d552c38734ccbb325d7006ae8645db13')
   assert x['source']['source_sha256']==(FP if current else '2366470eef62994757e4930806cb8df3d3bc4dfc6766da29ad6b1ee393052bb3')
   assert x['source']['complete'] and x['source']['file_count']==10014 and not x['source']['tracked_worktree_dirty']
   assert x['provenance']['reusable']==bool(x['passed'])
   for c in x['checks']:
    if c.get('log_sha256'):assert c['log_sha256'] in hashes,c['name']
   for m in x['provenance']['manifests'].values():assert hashlib.sha256(z.read(m['path'])).hexdigest()==m['sha256']
   if x['passed']:assert all(c['passed'] for c in x['checks'])
   else:assert item['id']==12433473396
   folder='ci/current' if current else 'ci/reviewed-4d73'
   (D/folder).mkdir(parents=True,exist_ok=True)
   kind='source-'+re.search(r'source-(\d+)-',item['name'])[1] if 'source-' in item['name'] else 'runtime'
   (D/folder/(kind+('' if x['passed'] else '-negative-attempt1')+'-results.json')).write_bytes(raw)
   tests=[c for c in x['checks'] if c['kind']=='headless_godot' and c.get('contract')]
   if kind.startswith('source-'):
    assert x['execution']=='headless_source_project'
    assert len(tests)==len(x['selected_tests'])
    if x['passed']:
     assert all(c['passed'] and c['process_passed'] and c['exit_code']==0 and c['source_status']=='unchanged' and c['source_sha256']==x['source']['source_sha256'] and '--headless' in c['command'] for c in tests)
    sources.append(dict(artifact=item,tree=x['source']['tree'],shard=int(kind[7:]),passed=x['passed'],names=[c['name'] for c in tests],all_log_hashes_verified=True,source_manifest_hashes_verified=True))
   else:assert len(x['checks'])==27
  elif 'export-diagnostics-' in item['name']:
   raw=z.read('results.json');x=json.loads(raw);current=x['source']['tree']==TREE
   assert x['passed'] and x['complete'] and len(x['checks'])==42 and all(c['passed'] for c in x['checks'])
   assert x['source']['tree']==(TREE if current else '4d73ada2d4bc9e28b01f05b431b6b954b8bb013c')
   assert x['source']['commit']==(MERGE if current else '7fa54b52d552c38734ccbb325d7006ae8645db13') and x['source']['complete'] and x['source']['file_count']==10014
   assert x['export_source']['tree']==x['source']['tree'] and x['export_source']['commit']==x['source']['commit'] and x['export_source']['source_sha256']==x['source']['source_sha256'] and not x['export_source']['tracked_worktree_dirty']
   assert x['provenance']['reusable'] and not x['source']['tracked_worktree_dirty']
   for c in x['checks']:
    if c.get('log_sha256'):assert c['log_sha256'] in hashes,c['name']
   assert len(x['probes'])==3 and all(t['passed'] and t['save_round_trip'] for t in x['probes'])
   platform='windows' if 'windows' in item['name'] else 'linux'
   folder=D/('ci/current' if current else 'ci/reviewed-4d73')/('export-'+platform);folder.mkdir(parents=True,exist_ok=True)
   (folder/'results.json').write_bytes(raw)
   exports[('current-' if current else 'reviewed-')+platform]=dict(artifact=item,source=x['source'],archive=x['archive'],checks=42,probes=x['probes'],all_log_hashes_verified=True)
  elif 'environment-review-' in item['name']:
   renderer='forward' if 'forward_plus' in item['name'] else 'gl';folder=D/('ci/environment-'+renderer);folder.mkdir(parents=True,exist_ok=True)
   raw=z.read('render-import/results.json');x=json.loads(raw)
   assert x['passed'] and x['source']['tree']==TREE and x['source']['source_sha256']==FP and x['provenance']['reusable']
   (folder/'import-results.json').write_bytes(raw)
   raw=z.read('environment-review/results.json');assert json.loads(raw)['passed'];(folder/'capture-results.json').write_bytes(raw)
   selected=[]
   for n in names:
    if n.endswith('.png') and any(f in n for f in ['grass_tuft','fern_cluster','flower_cluster']):
     rel=Path(n).relative_to('environment-review');dest=folder/rel;dest.parent.mkdir(parents=True,exist_ok=True);d=z.read(n);dest.write_bytes(d);selected.append(dict(path=str(rel),sha256=hashlib.sha256(d).hexdigest()))
   save(f'ci/environment-{renderer}/artifact-index.json',dict(artifact=item,selected=selected));native.append(item)
  elif 'ground-material-review-' in item['name']:
   renderer='forward' if 'forward_plus' in item['name'] else 'gl';folder=D/('ci/current/ground-'+renderer);folder.mkdir(parents=True,exist_ok=True)
   x=json.loads(z.read('capture.json'));assert x['passed'] and len(x['samples'])==15
   for n in ['capture.json','shader_comparison.json']:(folder/n).write_bytes(z.read(n))
   native.append(item)
  elif 'spherical-campaign-review-' in item['name']:
   renderer='forward' if 'forward_plus' in item['name'] else 'gl';folder=D/('ci/current/campaign-'+renderer);folder.mkdir(parents=True,exist_ok=True)
   for n in names:
    if n.endswith('.png'):(folder/Path(n).name).write_bytes(z.read(n))
   native.append(item)
 if any(k in item['name'] for k in ['validate-source-','validate-runtime-','export-diagnostics-','ground-material-review-']):
  parts=[]
  for off in range(0,len(data),2*1024*1024):
   d=data[off:off+2*1024*1024];name=f"originals/current-ci/{item['id']}.zip"+(f'.part{off//(2*1024*1024)+1:02d}' if len(data)>2*1024*1024 else '')
   p=D/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(d);parts.append(dict(path=name,bytes=len(d),sha256=hashlib.sha256(d).hexdigest()))
  archives.append(dict(**item,parts=parts))
accepted={x['shard']:x for x in sources if x['tree']==TREE and x['passed']}
actual=[n for s in accepted.values() for n in s['names']]
registry=json.loads(git('show',f'{HEAD}:tools/validation/contracts.json'))
expected={n for c in registry['contracts'] for n in c['tests']}
assert len(expected)==298 and len(actual)==len(set(actual)) and set(actual)<=expected
save('ci/current/source-execution.json',dict(head=HEAD,ci_commit=MERGE,tree=TREE,source_sha256=FP,executed_unique=len(actual),full_acceptance=len(accepted)==8 and set(actual)==expected,accepted_shards=list(accepted.values()),historical_negative=[x for x in sources if not x['passed']]))
save('ci/current/native-artifacts.json',native);save('ci/current/export-verification.json',exports);save('ci/current/original-archives.json',archives)
files=json.loads((ROOT/'bound-product-files.json').read_text())['files']
with zipfile.ZipFile(next(A.glob('12438313129-*.zip'))) as z:
 x=json.loads(z.read('results.json'));m=x['provenance']['manifests']['start'];raw=z.read(m['path'])
 assert hashlib.sha256(raw).hexdigest()==m['sha256']
 observations={o['path']:o for o in map(json.loads,raw.decode().splitlines())}
 for f in files:
  o=observations[f['path']];assert o['bytes']==f['size'] and o['tracked'] and o['kind']=='file'
  if f.get('sha256'):assert f['sha256']==o['sha256']
  f['sha256']=o['sha256'];f.pop('sha256_status',None)
assert len(files)==43
save('product-files.json',dict(base_commit=BASE,base_tree='dd8d5aa1676ba320a37d267d5cf0893134130109',published_commit=HEAD,tree=TREE,files=files))
save('geometry-costs.json',{tier:dict(before=a,after=b,change_percent=(b/a-1)*100) for tier,a,b in [('near',56160,52160),('mid',17242,16426),('far',5402,5428)]})
save('ci/current/merge-source.json',dict(head=HEAD,merge=MERGE,tree=TREE,parents=[BASE,HEAD],linux_source_sha256=FP))
save('current-proof-scope.json',dict(current_head=HEAD,current_tree=TREE,current_originals='ci/current/ and originals/current-ci/',historical_originals='original-archives.json; candidate eed4d10328eb9646fc2e979c7feb039849f14837 / tree 2ab6fafd7e850b28cda48fbdb3b31371c23f0095',observed_lost_raw_receipts=dict(reviewed_tree='4d73ada2d4bc9e28b01f05b431b6b954b8bb013c',local_exact_campaign_pairs=16,comparison_failures=0,origin_probe_renderers=2,terrain_original_case_seconds=84.315,status='Successfully observed before temporary-host cleanup. These final local raw archives are unavailable and are not replaced by historical raw archives.'),unchanged_shader=dict(blob=git('rev-parse',f'{HEAD}:world/surface/visuals/living_ground.gdshader').decode().strip(),sha256=next(f['sha256'] for f in files if f['path']=='world/surface/visuals/living_ground.gdshader'),same_as_archived_candidate=git('rev-parse',f'{HEAD}:world/surface/visuals/living_ground.gdshader')==git('rev-parse','eed4d10328eb9646fc2e979c7feb039849f14837:world/surface/visuals/living_ground.gdshader'))))
print(json.dumps(dict(source_unique=len(actual),full_source=len(accepted)==8 and set(actual)==expected,native_artifacts=len(native),exports=list(exports),original_archives=len(archives),product_files=len(files))))
