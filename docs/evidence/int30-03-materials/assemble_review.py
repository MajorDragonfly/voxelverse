"""Assemble exact native images, pose checks and render-cost tables.

No gameplay code, image retouching or pass/fail threshold changes. Run after the
six native jobs, with Pillow installed; --capture-root is their parent folder.
"""
import argparse
import csv
import hashlib
import html
import json
from pathlib import Path
import shutil
import statistics
import subprocess
import tempfile
import zipfile

from PIL import Image, ImageDraw, ImageFont

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--capture-root', type=Path, required=True)
args = parser.parse_args()
root = args.capture_root.resolve()
out = Path(__file__).resolve().parent
font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 16)
rows = []
checks = {}
gallery = []
selected = ['forest_day_12m', 'stone_day_12m', 'ground_day_12m', 'forest_night_12m',
            'forest_day_110m', 'campaign_day-route-3-200m']

def load(name):
    data = json.loads((root / name / 'capture.json').read_text())
    assert data['passed'] and not data['failures'], name
    return data

def copy_job(name, target, archive_pngs=False):
    destination = out / target
    destination.mkdir(parents=True, exist_ok=True)
    if archive_pngs:
        contents = []
        with zipfile.ZipFile(destination / 'original-frames.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
            for path in sorted((root / name).glob('*.png')):
                archive.write(path, path.name)
                contents.append({'file': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
        (destination / 'archive-contents.json').write_text(json.dumps(contents, indent=2) + '\n')
        for path in destination.glob('*.png'):
            if path.name != 'comparison-strip.png':
                path.unlink()
    for path in (root / name).glob('*'):
        if path.suffix in ('.png', '.json'):
            if archive_pngs and path.suffix == '.png':
                continue
            shutil.copyfile(path, destination / path.name)
    shutil.copyfile(root / (name + '.log'), destination / 'runtime.log')

def pair(left, right, target, label):
    a, b = Image.open(out / left).convert('RGB'), Image.open(out / right).convert('RGB')
    assert a.size == b.size == (960, 540)
    canvas = Image.new('RGB', (1920, 576), '#17212b')
    canvas.paste(a, (0, 36))
    canvas.paste(b, (960, 36))
    draw = ImageDraw.Draw(canvas)
    draw.text((12, 9), 'VORHER | ' + label, fill='white', font=font)
    draw.text((972, 9), 'NACHHER | gleiche Kamera und Sonne', fill='white', font=font)
    destination = out / target
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.stem in selected:
        canvas.save(destination)
    gallery.append((label, target, left, right))

def cost(kind, renderer, version, view, sample):
    rows.append({'scope': kind, 'renderer': renderer, 'version': version, 'view': view,
                 **{f'{metric}_{quantile}': sample[metric][quantile]
                    for metric in ('frame_ms', 'render_cpu_ms', 'render_gpu_ms')
                    for quantile in ('p50', 'p95')},
                 'measured_frames': sample['frame_ms']['count'],
                 'draw_calls': sample['draw_calls'], 'primitives': sample['primitives']})

for renderer in ('gl', 'forward'):
    name = 'final-materials-' + renderer
    target = 'materials/' + renderer
    copy_job(name, target)
    data = load(name)
    checks[name] = {'passed': data['passed'], 'probes': data['probes'],
                    'shader_sha256': data['shader_sha256'], 'views': len(data['samples'])}
    for sample in data['samples']:
        label = '%s_%s_%dm' % (sample['category'], sample['phase'], sample['distance_m'])
        assert sample['before']['draw_calls'] == sample['after']['draw_calls']
        assert sample['before']['primitives'] == sample['after']['primitives']
        for version in ('before', 'after'):
            cost('material fixture', renderer, version, label, sample[version])
        pair(target + '/' + label + '_before.png', target + '/' + label + '_after.png',
             'comparisons/' + renderer + '/' + label + '.png', renderer + ' | ' + label)

    before = load('campaign-' + renderer + '-before')
    after = load('campaign-' + renderer + '-after')
    assert before['geometry'] == after['geometry']
    assert before['seed'] == after['seed'] == 15838
    assert before['renderer'] == after['renderer']
    common = ['label', 'camera_transform', 'origin', 'campaign_seconds', 'sun_direction',
              'sun_energy', 'ambient_energy']
    different = []
    for version in ('before', 'after'):
        copy_job('campaign-' + renderer + '-' + version, 'campaign/' + renderer + '/' + version)
    assert len(before['samples']) == len(after['samples']) == 16
    for a, b in zip(before['samples'], after['samples']):
        for key in common:
            assert a[key] == b[key], (renderer, a['label'], key, a[key], b[key])
        for key in ('instances', 'batches', 'cells', 'ready', 'workers', 'staged_sets'):
            if a['scenery'][key] != b['scenery'][key]:
                different.append({'view': a['label'], 'field': 'scenery.' + key,
                                  'before': a['scenery'][key], 'after': b['scenery'][key]})
        for key in ('primitives', 'nodes', 'near_patches', 'tiles', 'draw_calls', 'distance_rings_20_100_200_outer'):
            if a[key] != b[key]:
                different.append({'view': a['label'], 'field': key, 'before': a[key], 'after': b[key]})
        for version, sample in [('before', a), ('after', b)]:
            cost('settled campaign', renderer, version, a['label'], sample)
        label = a['label']
        pair('campaign/' + renderer + '/before/' + label + '.png',
             'campaign/' + renderer + '/after/' + label + '.png',
             'comparisons/' + renderer + '/campaign_' + label + '.png', renderer + ' | campaign ' + label)
    checks['campaign-' + renderer] = {'passed': True, 'exact_pair_fields': common,
        'geometry': before['geometry'], 'views': 16, 'workload_differences': different,
        'workload_identical': not different,
        'unique_origins': len({json.dumps(s['origin']) for s in before['samples']})}

for renderer in ('gl', 'forward'):
    name, target = 'motion-' + renderer, 'motion/' + renderer
    data = load(name)
    copy_job(name, target, archive_pngs=True)
    assert len(data['frames']) == 128
    for index in range(64):
        assert data['frames'][index]['camera_transform'] == data['frames'][index + 64]['camera_transform']
    checks[name] = {'passed': True, 'frames': 128, 'scope': data['scope'],
                    'shader_sha256': data['shader_sha256']}
    with tempfile.TemporaryDirectory(prefix='int30-paired-motion-') as temporary:
        directory = Path(temporary)
        for index in range(64):
            a = Image.open(root / name / ('before_%03d.png' % index)).convert('RGB')
            b = Image.open(root / name / ('after_%03d.png' % index)).convert('RGB')
            canvas = Image.new('RGB', (1920, 576), '#17212b')
            canvas.paste(a, (0, 36)); canvas.paste(b, (960, 36))
            draw = ImageDraw.Draw(canvas)
            distance = data['frames'][index]['distance_m']
            draw.text((12, 9), 'VORHER | %s | %.1f m' % (renderer, distance), font=font, fill='white')
            draw.text((972, 9), 'NACHHER | gleiche Pose | Materialprobe', font=font, fill='white')
            canvas.save(directory / ('pair_%03d.png' % index))
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-framerate', '8',
                        '-i', str(directory / 'pair_%03d.png'), '-c:v', 'libx264', '-crf', '16',
                        '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(out / target / 'comparison.mp4')], check=True)
        strip = Image.new('RGB', (1440, 4 * 432), '#17212b')
        for row, index in enumerate((0, 9, 31, 63)):
            frame = Image.open(directory / ('pair_%03d.png' % index))
            frame.thumbnail((1440, 432));strip.paste(frame, (0, row * 432))
        strip.save(out / target / 'comparison-strip.png')

with (out / 'render-costs.csv').open('w', newline='') as file:
    writer = csv.DictWriter(file, fieldnames=list(rows[0]), lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
(out / 'pair-checks.json').write_text(json.dumps(checks, indent=2) + '\n')

summary = []
for renderer in ('gl', 'forward'):
    for category in ('forest', 'stone', 'ground'):
        subset = [r for r in rows if r['scope'] == 'material fixture' and r['renderer'] == renderer
                  and r['view'].startswith(category)]
        a = [r for r in subset if r['version'] == 'before']
        b = [r for r in subset if r['version'] == 'after']
        ratios = [y['render_gpu_ms_p50'] / x['render_gpu_ms_p50'] for x, y in zip(a, b)]
        summary.append({'renderer': renderer, 'category': category,
            'before_median_view_gpu_p50_ms': statistics.median(r['render_gpu_ms_p50'] for r in a),
            'after_median_view_gpu_p50_ms': statistics.median(r['render_gpu_ms_p50'] for r in b),
            'median_paired_gpu_p50_ratio': statistics.median(ratios), 'min_ratio': min(ratios), 'max_ratio': max(ratios)})
(out / 'cost-summary.json').write_text(json.dumps(summary, indent=2) + '\n')

items = ''.join('<section><h2>' + html.escape(label) + '</h2><div class="pair"><figure><figcaption>Vorher</figcaption><img loading="lazy" src="' + left +
                '"></figure><figure><figcaption>Nachher</figcaption><img loading="lazy" src="' + right + '"></figure></div><p><a href="' + left + '">Original vorher</a> · <a href="' +
                right + '">Original nachher</a></p></section>' for label, target, left, right in gallery)
(out / 'gallery.html').write_text('''<!doctype html><html lang="de"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>V30-03 Materialvergleich</title>
<style>body{font:16px system-ui;background:#111923;color:#e7edf4;margin:24px;max-width:1920px}img{max-width:100%;height:auto}.pair{display:grid;grid-template-columns:1fr 1fr;gap:8px}figure{margin:0}a{color:#9ad5ff}section{margin:35px 0}h2{font-size:18px}</style>
<h1>V30-03: gleicher Seed, gleiche Kamera, gleiche Sonne</h1>
<p>Seed 15838 · 960×540 · Tag 0 s / Nacht 720 s · Godot 4.6.3 · Software-Mesa.
Materialfixture 12 / 45 / 110 m; echte Kampagne an festen Hin-/Rückwegpunkten.
Keine Ziel-PC-FPS- oder vollständige bewegte LOD-Abnahme.</p>''' + items + '</html>')

# Compact contact sheet: each thumbnail keeps both sides of the same exact pair.
sheet = Image.new('RGB', (1440, 6 * 234 + 40), '#17212b')
draw = ImageDraw.Draw(sheet)
draw.text((12, 10), 'V30-03 | links vorher, rechts nachher je Paar | GL und Forward+', font=font, fill='white')
for row, label in enumerate(selected):
    for column, renderer in enumerate(('gl', 'forward')):
        tile = Image.open(out / 'comparisons' / renderer / (label + '.png')).convert('RGB')
        tile.thumbnail((720, 216))
        sheet.paste(tile, (column * 720, 40 + row * 234))
        draw.text((column * 720 + 8, 40 + row * 234 + 216), renderer + ' | ' + label, font=font, fill='white')
sheet.save(out / 'comparison-overview.png')

# Lossless originals stay available without making hundreds of motion frames
# dominate the code-review diff. Paired still originals remain individual PNGs.
copy_job('campaign-forward-before-first-failure', 'campaign/forward/before-first-failure', archive_pngs=True)
for path in (out / 'comparisons').rglob('*.png'):
    if path.stem not in selected:
        path.unlink()

print(json.dumps({'exact_pairs': len(gallery), 'render_cost_rows': len(rows), 'cost_summary': summary}, indent=2))
