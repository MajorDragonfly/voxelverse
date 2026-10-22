import hashlib,json,socket,subprocess,sys,zipfile
from pathlib import Path
R=Path(__file__).resolve().parent;D=R/'gfx02-evidence/docs/evidence/gfx-ref-02'
with zipfile.ZipFile(next((R/'artifacts').glob('12438313129-*.zip'))) as z:
 x=json.loads(z.read('results.json'));m=x['provenance']['manifests']['start'];raw=z.read(m['path']);assert hashlib.sha256(raw).hexdigest()==m['sha256']
 manifest={o['path']:o for o in map(json.loads,raw.decode().splitlines())}
paths=['tools/art/build_benchmark.py','tests/tooling/foliage_authoring_test.py','assets/packs/temperate_forest_v1/manifest.json','assets/catalog/planet_material_slots.gd']
def verify():
 for name in paths:
  b=(R/'review-source'/name).read_bytes();assert hashlib.sha256(b).hexdigest()==manifest[name]['sha256'] and len(b)==manifest[name]['bytes']
verify()
assert hashlib.sha256((R/'old-builder.py').read_bytes()).hexdigest()=='e4b6d3a89126c4723b30dd8c5250dd7cbd7ea8716fc39be9596d0c55ba53b6bd'
records=[]
for name,command,cwd in [('positive',[sys.executable,'tests/tooling/foliage_authoring_test.py'],R/'review-source'),('negative',[sys.executable,str(R/'review_negative.py')],R)]:
 p=subprocess.run(command,cwd=cwd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60)
 assert p.returncode==0,p.stdout.decode()
 if name=='positive':assert b'Ran 4 tests' in p.stdout and b'OK' in p.stdout
 else:assert b'EXPECTED NEGATIVE' in p.stdout
 (D/f'review-fix-{name}.log').write_bytes(p.stdout)
 records.append(dict(name=name,command=command,exit_code=p.returncode,log_sha256=hashlib.sha256(p.stdout).hexdigest()))
verify()
(D/'authoring-recovery.json').write_text(json.dumps(dict(head='70b42cfb11868f47c4ffe94a581b54a62f7b2eb9',tree='d31860a0ed3a13f8a6c0c77a95d8f79fda212b97',host=socket.gethostname(),scope='Exact current copies of four authoring inputs; source hashes verified before/after against complete current CI manifest in artifact12438313129. This small recovery fixture is not a full-source SourceRun.',inputs=[manifest[n] for n in paths],positive_tests=4,expected_detected_old_regressions=2,records=records),indent=2)+'\n')
print('Authoring positive4/4; both expected old regressions detected; input hashes unchanged.')
