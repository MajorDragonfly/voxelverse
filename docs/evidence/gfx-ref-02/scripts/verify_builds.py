import hashlib,io,json,zipfile
from pathlib import Path
R=Path(__file__).resolve().parent;D=R/'gfx02-evidence/docs/evidence/gfx-ref-02/ci/current'
items=json.loads((R/'artifacts/index.json').read_text());records=[]
for platform in ['windows','linux']:
 a=next(x for x in items if x['run_id']==39805398953 and x['name']==f'voxelverse-{platform}-pull_request')
 p=R/'artifacts'/a['archive'];assert hashlib.sha256(p.read_bytes()).hexdigest()==a['sha256']
 diagnostic=json.loads((D/f'export-{platform}/results.json').read_text())
 assert diagnostic['passed'] and diagnostic['complete'] and diagnostic['source']['tree']=='d31860a0ed3a13f8a6c0c77a95d8f79fda212b97'
 with zipfile.ZipFile(p) as outer:
  expected=diagnostic['archive'];raw=outer.read(expected['name'])
  assert len(raw)==expected['bytes'] and hashlib.sha256(raw).hexdigest()==expected['sha256']
  sums=outer.read('SHA256SUMS.txt').decode();assert expected['sha256'] in sums and expected['name'] in sums
  with zipfile.ZipFile(io.BytesIO(raw)) as inner:
   info_name=next(n for n in inner.namelist() if n.endswith('/BUILD_INFO.json'))
   info=json.loads(inner.read(info_name))
   fp='2af9efa71e15f64c7c17269993dc30a963db2ae769abdec3bc2bfad9ce66587e' if platform=='windows' else 'f4eeb33da6ced083efe6e5e062a7ec649a07d63680849ffa9d94be890b19ce5f'
   assert info['platform']==platform and info['source_inputs_complete'] and info['acceptance']=='native_headless_release_and_exact_pck' and info['checks_passed']==41 and info['target_pc_acceptance'] is False
   for key in ['source','export_source','validation_source']:
    s=info[key];assert s['commit']=='3df6727ef184af3d13772aa4e2cf5bf9990399f5' and s['tree']=='d31860a0ed3a13f8a6c0c77a95d8f79fda212b97' and s['source_sha256']==fp and s['complete'] and not s['tracked_worktree_dirty'] and s['file_count']==10014
   records.append(dict(platform=platform,artifact=a,archive=expected,wrapper_and_inner_archive_verified=True,build_info=info,build_info_sha256=hashlib.sha256(inner.read(info_name)).hexdigest()))
(D/'desktop-build-verification.json').write_text(json.dumps(records,indent=2)+'\n')
print(json.dumps([dict(platform=r['platform'],artifact=r['artifact']['id'],archive_sha256=r['archive']['sha256'],source_tree=r['build_info']['source']['tree'],target_pc_acceptance=False) for r in records]))
