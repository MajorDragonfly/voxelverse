#!/usr/bin/env python3
"""Apply only the INT30-11 owner appends in an isolated R33 verification tree.

R33-01 applies the same additions serially, preserving concurrent entries.
Usage: python3 .../apply_append.py PATH_TO_ISOLATED_CHECKOUT
"""
import json
from pathlib import Path
import subprocess
import sys
root = Path(sys.argv[1]).resolve()
patches = Path(__file__).resolve().parent
catalog = root / 'localization/catalog.json'
data = json.loads(catalog.read_text())
by_key = {row['key']: row for row in data['messages']}
for key, values in json.loads((patches / 'localization-append.json').read_text()).items():
    row = {'key': key, **values}
    if key in by_key:
        if by_key[key] != row: raise SystemExit('Conflicting catalog entry: ' + key)
    else: data['messages'].append(row)
catalog.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
subprocess.run([sys.executable, 'tools/localization/catalog.py'], cwd=root, check=True)
append = json.loads((patches / 'registry-append.json').read_text())
registry = root / 'tools/validation/contracts.json'
data = json.loads(registry.read_text())
owner = next(c for c in data['contracts'] if c['id'] == append['contract'])
for test in append['tests']:
    owners = [c for c in data['contracts'] if test in c['tests']]
    if owners and owners != [owner]: raise SystemExit('Duplicate/conflicting test owner: ' + test)
    if test not in owner['tests']: owner['tests'].append(test)
registry.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
runner = root / 'tools/validate_godot.py'
s = runner.read_text()
line = 'LONG_TESTS.update(' + repr(set(append['long_tests'])) + ')  # INT30-11 cold campaign/map restart'
if line not in s:
    s = s.replace('\nERROR = re.compile', '\n' + line + '\n\nERROR = re.compile')
runner.write_text(s)
print('Applied 10 catalog entries, 2 disjoint registrations and existing long-test budget.')

# Existing locale probe assumed synchronous *unfiltered* archive paging. Keep
# its assertions and budgets; await the same bounded query at those boundaries.
probe = root / 'tests/world_map_localization_test.gd'
s = probe.read_text()
if 'func _int30_wait_page()' not in s:
    s = s.replace('map._refresh_places()\n', 'map._refresh_places()\n\tawait _int30_wait_page()\n')
    s = s.replace('map._place_next.pressed.emit()\n', 'map._place_next.pressed.emit()\n\tawait _int30_wait_page()\n')
    # Preserve indentation for the nested layout fixture, not just top-level calls.
    lines = s.splitlines()
    for i, line in enumerate(lines):
        if line.strip() == 'await _int30_wait_page()':
            previous = lines[i-1]
            lines[i] = previous[:len(previous)-len(previous.lstrip())] + 'await _int30_wait_page()'
    s = '\n'.join(lines) + '\n\nfunc _int30_wait_page() -> void:\n\tfor frame in range(1000):\n\t\tif not map._place_query.active: return\n\t\tawait process_frame\n\t_expect(false, "INT30 bounded visibility page did not finish")\n'
    probe.write_text(s)
# Same async contract for the existing 3105-place paging UI fixture. The saved
# living ally fixture explicitly visits its habitat before asking to show it.
probe = root / 'tests/atlas_places_test.gd'
s = probe.read_text()
if 'func _int30_wait_page(map:' not in s:
    s = s.replace('_expect(map.open_map(), "Cannot open map with paged places.")\n', '_expect(map.open_map(), "Cannot open map with paged places.")\n\tawait _int30_wait_page(map)\n')
    for action in ['_place_next', '_place_previous']:
        s = s.replace('map.' + action + '.pressed.emit()\n', 'map.' + action + '.pressed.emit()\n\tawait _int30_wait_page(map)\n')
    s = s.replace('\tatlas.remember(marker)\n', '\tatlas.reveal(marker.address)  # Existing known-habitat requirement.\n\tatlas.remember(marker)\n')
    s += '\nfunc _int30_wait_page(map: CanvasLayer) -> void:\n\tfor frame in range(1000):\n\t\tif not map._place_query.active: return\n\t\tawait process_frame\n\t_expect(false, "INT30 bounded visibility page did not finish")\n'
    probe.write_text(s)
