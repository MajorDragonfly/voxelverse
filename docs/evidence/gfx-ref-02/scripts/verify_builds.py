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
   records.append(dict(platform=platform,artifact=a,archive=expected,wrapper_and_inner_archive_verified=True,build_info=info,build_info_sha256=hashlib.sha256(inner.read(info_name)).hexdigest()))
(D/'desktop-build-verification.json').write_text(json.dumps(records,indent=2)+'\n')
print(json.dumps([dict(platform=r['platform'],artifact=r['artifact']['id'],archive_sha256=r['archive']['sha256'],build_info=r['build_info']) for r in records]))
