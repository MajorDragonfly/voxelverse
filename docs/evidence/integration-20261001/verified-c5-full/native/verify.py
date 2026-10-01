#!/usr/bin/env python3
"""Verify this compact evidence bundle offline using only the Python standard library."""
from pathlib import Path, PurePosixPath
from collections import Counter
import hashlib, json, re, tarfile

root = Path(__file__).resolve().parent
e = json.loads((root / 'evidence.json').read_bytes())
pin = e['evidence_for']
digest = lambda b: hashlib.sha256(b).hexdigest()
archive = root / e['raw_archive']['path']
assert digest(archive.read_bytes()) == e['raw_archive']['sha256']
assert archive.stat().st_size == e['raw_archive']['bytes']
with tarfile.open(archive, 'r:gz') as tar:
    index = json.loads(tar.extractfile('file-index.json').read())
    objects = {}
    for h, row in index['objects'].items():
        b = tar.extractfile(row['path']).read()
        assert digest(b) == h and len(b) == row['bytes']
        objects[h] = b
raw = {}
for name, row in index['files'].items():
    assert not name.endswith('.png')
    raw[name] = objects[row['sha256']]
    assert len(raw[name]) == row['bytes']
assert len(raw) == e['raw_archive']['logical_files']
assert len(objects) == e['raw_archive']['unique_raw_objects']
read_json = lambda p: json.loads(raw[p])
assert digest((root / e['native_summary']['path']).read_bytes()) == e['native_summary']['sha256']
native = json.loads((root / e['native_summary']['path']).read_bytes())
assert native['passed'] and native['head'] == pin['head'] and native['tree'] == pin['tree']
assert len(native['artifacts']) == native['native_jobs'] == 11
assert sum(a['png_count'] for a in native['artifacts']) == native['native_pngs'] == 202

def provenance(pv, base):
    assert pv['reusable']
    manifests = []
    for phase in ('start', 'end'):
        s = pv[phase]
        assert s['complete'] and not s['tracked_worktree_dirty']
        assert s['tree'] == pin['tree'] and s['commit'] == pin['ci_merge_commit']
        assert s['source_sha256'] == pin['source_sha256'] and s['file_count'] == 5448
        m = pv['manifests'][phase]
        b = raw[str(PurePosixPath(base) / m['path'])]
        assert digest(b) == m['sha256']
        rows = [json.loads(line) for line in b.splitlines()]
        assert len(rows) == 5448
        identity = [{k: v for k, v in row.items() if k not in {'tracked', 'godot_uid'}} for row in rows if row['kind'] != 'missing']
        canonical = json.dumps(identity, ensure_ascii=True, sort_keys=True, separators=(',', ':')).encode()
        assert digest(canonical) == pin['source_sha256']
        manifests.append(b)
    assert manifests[0] == manifests[1]
    return {r['path']: r['sha256'] for r in rows}

api = read_json('api/native-jobs-artifacts.json')
assert api['head'] == pin['head']
jobs = [j for row in api['records'] if row['kind'] == 'jobs' for j in row['data']['jobs']]
arts = [a for row in api['records'] if row['kind'] == 'artifacts' for a in row['data']['artifacts']]
assert len(jobs) == 11 and all(j['status'] == 'completed' and j['conclusion'] == 'success' for j in jobs)
assert sum(j['name'].startswith('INT30 ') for j in jobs) == 8
assert {a['id'] for a in arts} == {a['artifact_id'] for a in native['artifacts']}
for a in arts:
    assert a['workflow_run']['head_sha'] == pin['head']
    assert a['digest'] == next(n['digest'] for n in native['artifacts'] if n['artifact_id'] == a['id'])
for a in native['artifacts']:
    assert a['head'] == pin['head'] and a['tree'] == pin['tree'] and a['passed']
    if a['name'].startswith('int30-feature-'):
        d = read_json('native/' + a['name'] + '/results.json')
        assert d['passed'] and all(r['exit_code'] == 0 for r in d['records'])
        provenance(d['combined_source'], 'native/' + a['name'] + '/combined-source')

building = read_json('native/building-editor-review/building-editor-review/results.json')
assert building['passed'] and building['source_unchanged'] and not building['source']['dirty']
assert building['source']['tree'] == pin['tree'] and building['source']['commit'] == pin['ci_merge_commit']
feature = read_json('native/int30-feature-shipyard/results.json')
assert building['source']['file_hashes'] == provenance(feature['combined_source'], 'native/int30-feature-shipyard/combined-source')
assert [t['checks'] for t in building['test_results']] == [569, 2]
assert all(t['passed'] and not t['failures'] for t in building['test_results'])
assert len(building['images']) == 7
gallery = read_json('native/int30-community-gallery-review/gallery-render/report.json')
assert gallery['passed'] and gallery['source_unchanged'] and len(gallery['images']) == 45
provenance(gallery['source_provenance'], 'native/int30-community-gallery-review/gallery-render')
audio = read_json('native/audio-settings-review/audio-settings-review/results.json')
assert audio['passed'] and audio['source_unchanged'] and not audio['dirty'] and audio['tree'] == pin['tree']
assert len(audio['images']) == 12
appearance = read_json('native/int30-feature-appearance/native/results.json')
assert appearance['passed'] and appearance['applied_owner_tree'] == pin['tree']
assert appearance['source_commit'] == '0ab9d20b0f448864c6e104c093b3ce97532e95e5'
appearance_tests = read_json('native/int30-feature-appearance/native/validation/results.json')
assert appearance_tests['passed']
provenance(appearance_tests['provenance'], 'native/int30-feature-appearance/native/validation')
for name, b in raw.items():
    if name.startswith('native/') and name.endswith('.log'):
        assert not re.search(r'SCRIPT ERROR|(^|\s)ERROR:|ObjectDB instances leaked', b.decode(errors='replace'), re.M), name

images = read_json('derived/png-sha256-dimensions.json')
assert len(images) == 202 and len({(p['artifact_id'], p['path']) for p in images}) == 202
counts = Counter(p['artifact_id'] for p in images)
for a in native['artifacts']:
    assert counts[a['artifact_id']] == a['png_count']
for p in images:
    assert re.fullmatch('[a-f0-9]{64}', p['sha256']) and p['bytes'] > 0 and len(p['dimensions']) == 2 and min(p['dimensions']) > 1
image_lookup = {p['artifact_name'] + '/' + p['path']: p for p in images}
declared_hashes = 0
for name, b in raw.items():
    if not name.startswith('native/') or not name.endswith('.json'):
        continue
    d = json.loads(b)
    if not isinstance(d, dict):
        continue
    for key in ('images', 'screenshots'):
        vals = d.get(key, [])
        pairs = vals.items() if isinstance(vals, dict) else [(v['name'], v) for v in vals if isinstance(v, dict) and 'name' in v]
        for image_name, value in pairs:
            if not image_name.endswith('.png'):
                continue
            p = image_lookup[str(PurePosixPath(name.removeprefix('native/')).parent / image_name)]
            supplied = value.get('sha256') if isinstance(value, dict) else value
            if supplied:
                assert p['sha256'] == supplied
                declared_hashes += 1
            if isinstance(value, dict) and 'dimensions' in value:
                assert p['dimensions'] == value['dimensions']
assert declared_hashes >= 140

print(json.dumps({'passed': True, 'head': pin['head'], 'tree': pin['tree'], 'source_sha256': pin['source_sha256'], 'feature_jobs': 8, 'native_jobs': 11, 'PNG_hash_dimension_index': 202, 'complete_manifest_files': 5448, 'building_gui_restart_checks': [569, 2], 'scope': 'Native workflows only; no FULL acceptance claim.'}, indent=2))
