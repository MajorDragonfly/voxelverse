import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent
parser = argparse.ArgumentParser(description='Compare fixed-input native graphics recordings.')
parser.add_argument('--checks', type=Path, default=ROOT / 'checks')
parser.add_argument('--fixed-gl-close', action='store_true', help='Use the explicit canonical close-view replays; retain the original rejected comparison separately.')
args = parser.parse_args()
CHECKS = args.checks.resolve()
BASE = 'f4a1cb4bef93883a48df2368344c3a1f884b9d53'
CODE = 'fce1f0510947857b4f42b2cdbed0a0a436cd14f1'
failures = []
comparisons = []
nonvisual_differences = []


def same(label, before, after):
    if before != after:
        failures.append(label)


cases = [(renderer, 'campaign-before-' + renderer, 'campaign-after-' + renderer) for renderer in ['gl', 'forward']]
if args.fixed_gl_close:
    cases.append(('gl', 'close-before-gl', 'close-after-gl'))
for renderer, before_folder, after_folder in cases:
    folders = [CHECKS / before_folder, CHECKS / after_folder]
    reports = [json.loads((p / 'campaign-light.json').read_text()) for p in folders]
    results = [json.loads((p / 'results.json').read_text()) for p in folders]
    recipes = [json.loads((p / 'recipe.json').read_text()) for p in folders]
    for side, result, expected in zip(['before', 'after'], results, [BASE, CODE]):
        if not result['passed'] or result['source']['tree'] != expected or result['source']['tracked_worktree_dirty']:
            failures.append(renderer + '/' + side + ': rejected source or native run')
    for key in ['initial_save_text', 'region_blobs', 'views']:
        same(renderer + '/recipe/' + key, recipes[0][key], recipes[1][key])
    bodies = [json.loads(json.dumps(report['body'])) for report in reports]
    # The catalog's deferred search cursor is advanced during public loading.
    # It is not species data or a rendered placement. Keep its full difference
    # in the report while still requiring every other body field to match.
    searches = [body.get('fauna_catalog', {}).pop('surface_search', None) for body in bodies]
    if searches[0] != searches[1]:
        nonvisual_differences.append({'renderer': renderer, 'source_folders': [before_folder, after_folder],
                                     'path': 'body.fauna_catalog.surface_search', 'before': searches[0], 'after': searches[1]})
    same(renderer + '/actual-body', bodies[0], bodies[1])
    before = {c['id']: c for c in reports[0]['captures']}
    after = {c['id']: c for c in reports[1]['captures']}
    same(renderer + '/view-set', list(before), list(after))
    for label in before:
        if args.fixed_gl_close and after_folder == 'campaign-after-gl' and label.startswith('creature-close'):
            continue
        a, b = before[label], after[label]
        for key in ['clock', 'camera', 'camera_address', 'fov', 'size', 'palette', 'material_slots', 'debug_draw', 'tonemap']:
            same(renderer + '/' + label + '/' + key, a[key], b[key])
        for key in ['sun', 'ambient', 'exposure', 'white', 'sun_direction', 'sun_color', 'ambient_color', 'fog', 'ssao', 'bloom', 'preset', 'graphics']:
            same(renderer + '/' + label + '/lighting/' + key, a['lighting'][key], b['lighting'][key])
        if not a['view'] == b['view']:
            failures.append(renderer + '/' + label + ': mismatched view')
        paths = [p / (label + '.png') for p in folders]
        images = [Image.open(p).convert('RGB') for p in paths]
        same(renderer + '/' + label + '/physical-pixels', images[0].size, images[1].size)
        if images[0].size != (960, 540):
            failures.append(renderer + '/' + label + ': unexpected image size')
        comparisons.append({
            'renderer': renderer, 'view': label,
            'source_folders': [before_folder, after_folder],
            'before_png_sha256': hashlib.sha256(paths[0].read_bytes()).hexdigest(),
            'after_png_sha256': hashlib.sha256(paths[1].read_bytes()).hexdigest(),
            'changed_rgb_bytes': sum(x != y for x, y in zip(images[0].tobytes(), images[1].tobytes())),
            'before_draw_wall_ms': a['draw_wall_ms'], 'after_draw_wall_ms': b['draw_wall_ms'],
            'before_draw_calls': a['draw_calls'], 'after_draw_calls': b['draw_calls'],
            'before_primitives': a['primitives'], 'after_primitives': b['primitives'],
        })

report = {'passed': not failures, 'failures': failures, 'comparisons': comparisons,
          'nonvisual_differences': nonvisual_differences,
          'before_tree': BASE, 'product_tree': CODE,
          'scope': 'Exact fixed-input, camera, clock, lighting and palette comparison. Six retained paused force_draw samples per view on software Mesa; no target-PC or gameplay-FPS acceptance.'}
(CHECKS / 'native-comparison.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({'passed': report['passed'], 'comparisons': len(comparisons), 'failures': failures}))
raise SystemExit(0 if report['passed'] else 1)
