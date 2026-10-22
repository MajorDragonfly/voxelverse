import concurrent.futures, hashlib, json, sys, urllib.request
from pathlib import Path
items = json.load(sys.stdin)
out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
def fetch(a):
    name = f"{a['id']}-{a['name']}.zip"
    assert Path(name).name == name
    p = out/name
    expected = a['digest'].removeprefix('sha256:')
    if not p.exists() or hashlib.sha256(p.read_bytes()).hexdigest() != expected:
        data = urllib.request.urlopen(a['url'], timeout=30).read()
        assert hashlib.sha256(data).hexdigest() == expected
        p.write_bytes(data)
    return dict(id=a['id'], name=a['name'], run_id=a['run_id'], public_url=f"https://github.com/MajorDragonfly/voxelverse/actions/runs/{a['run_id']}/artifacts/{a['id']}", bytes=p.stat().st_size, sha256=expected, archive=p.name)
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    rows = list(pool.map(fetch, items))
p = out/'index.json'
old = json.loads(p.read_text()) if p.exists() else []
byid = {x['id']: x for x in old + rows}
p.write_text(json.dumps(list(byid.values()), indent=2) + '\n')
print(json.dumps(dict(verified=len(rows), ids=[x['id'] for x in rows])))
