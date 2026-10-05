#!/usr/bin/env python3
"""Compare native R32-06 capture artifacts; requires Pillow and NumPy.

These display-image and paused-draw comparisons are not target-PC acceptance.
No engine, source files, materials or renderer settings are changed.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pixels(path, box=(96, 270, 680, 410)):
    # Fixed screen ROI excludes the native bottom-right survival HUD. It is
    # still a mixed terrain/material region, never a radiometric albedo probe.
    rgb = np.asarray(Image.open(path).convert('RGB').crop(box), dtype=float) / 255
    lum = rgb @ np.array([.2126, .7152, .0722])
    return {'roi': list(box), 'median_srgb_luminance': float(np.median(lum)),
            'p95_srgb_luminance': float(np.quantile(lum, .95)),
            'white_fraction': float(np.mean(rgb.min(axis=2) > .98)),
            'black_fraction': float(np.mean(lum < .015)),
            'rgb_median': np.median(rgb, axis=(0, 1)).tolist()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--gl', type=Path, required=True)
    parser.add_argument('--forward', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    records, metadata, differences = {}, {}, []
    for renderer, directory in [('gl', args.gl), ('forward', args.forward)]:
        records[renderer], metadata[renderer] = {}, {}
        for phase in ['before', 'after']:
            root = directory / phase
            run = json.loads((root / 'results.json').read_text())
            data = json.loads((root / 'campaign-light.json').read_text())
            if not run['passed'] or not data['passed'] or run['provenance']['status'] != 'stable':
                raise ValueError(f'Unaccepted original capture: {root}')
            files = {item['path']: item for item in map(json.loads, (root / 'source-files-end.jsonl').read_text().splitlines())}
            for name, expected in run['images'].items():
                if digest(root / name) != expected:
                    raise ValueError(f'Changed native image: {root / name}')
            metadata[renderer][phase] = {'host': run['host'], 'seconds': run['seconds'],
                'source': run['source'], 'provenance': run['provenance'],
                'engine': data['engine'], 'adapter': data['adapter'], 'cpu': data['cpu'],
                'log_sha256': run['log_sha256'], 'images': run['images'],
                'production_files': {name: item for name, item in files.items() if name.startswith(('world/visuals/atmosphere/', 'world/visuals/terrain/'))},
                'capture_report_sha256': digest(root / 'campaign-light.json'),
                'observed_foreign_godot': [p for row in run['observed_godot_processes'] for p in row['processes'] if p['executable'] != run['command'][0]],
                'captures': data['captures'], 'views': data['views']}
            records[renderer][phase] = {item['id']: item for item in data['captures']}
        if records[renderer]['before'].keys() != records[renderer]['after'].keys():
            raise ValueError(f'Capture IDs differ: {renderer}')
        for name, before in records[renderer]['before'].items():
            after = records[renderer]['after'][name]
            fields = ['clock', 'camera', 'camera_address', 'fov', 'size', 'lighting', 'palette', 'material_slots', 'debug_draw', 'tonemap']
            mismatch = [key for key in fields if before[key] != after[key]]
            a = np.asarray(Image.open(directory / 'before' / (name + '.png')).convert('RGB'), dtype=np.int16)
            b = np.asarray(Image.open(directory / 'after' / (name + '.png')).convert('RGB'), dtype=np.int16)
            delta = np.abs(a - b)
            differences.append({'renderer': renderer, 'id': name, 'condition_mismatches': mismatch,
                'mean_abs_rgb8_difference': float(delta.mean()), 'max_rgb8_difference': int(delta.max()),
                'changed_pixel_fraction': float(np.mean(np.any(delta != 0, axis=2))),
                'before_roi': pixels(directory / 'before' / (name + '.png')),
                'after_roi': pixels(directory / 'after' / (name + '.png')),
                'before_sky_roi': pixels(directory / 'before' / (name + '.png'), (280, 70, 600, 130)),
                'after_sky_roi': pixels(directory / 'after' / (name + '.png'), (280, 70, 600, 130)),
                'draw_median_ms_before': before['draw_wall_ms']['median'],
                'draw_median_ms_after': after['draw_wall_ms']['median'],
                'draw_median_ratio': after['draw_wall_ms']['median'] / before['draw_wall_ms']['median']})
    across = []
    for name, gl in records['gl']['after'].items():
        forward = records['forward']['after'][name]
        fields = ['clock', 'camera', 'camera_address', 'fov', 'size', 'palette', 'material_slots', 'debug_draw', 'tonemap']
        across.append({'id': name, 'condition_mismatches': [key for key in fields if gl[key] != forward[key]],
                       'gl_lighting': gl['lighting'], 'forward_lighting': forward['lighting']})
    result = {'target_pc_acceptance': False, 'roi_note': 'Fixed HUD-free screen ROI; mixed display-referred pixels, no lux/raw albedo or additive attribution.',
              'runs': metadata, 'within_renderer': differences, 'across_renderers': across}
    (args.output / 'comparison.json').write_text(json.dumps(result, indent=2) + '\n')
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 22)
    for view in ['forest', 'snow', 'water', 'creature-horizon', 'creature-close']:
        sheet = Image.new('RGB', (1920, 1168), '#111820')
        draw = ImageDraw.Draw(sheet)
        for column, renderer in enumerate(['gl', 'forward']):
            for row, phase in enumerate(['day', 'night']):
                name = f'{view}-{phase}'
                y = row * 584
                draw.text((column * 960 + 12, y + 8), f'{view} | {renderer} | {phase} | native 960x540', font=font, fill='white')
                sheet.paste(Image.open((args.gl if renderer == 'gl' else args.forward) / 'after' / (name + '.png')), (column * 960, y + 44))
        sheet.save(args.output / (view + '-renderers.png'))
    for renderer, directory in [('gl', args.gl), ('forward', args.forward)]:
        sheet = Image.new('RGB', (1920, 584), '#111820')
        draw = ImageDraw.Draw(sheet)
        for column, phase in enumerate(['before', 'after']):
            draw.text((column * 960 + 12, 8), f'{renderer} | creature-horizon-night | {phase}', font=font, fill='white')
            sheet.paste(Image.open(directory / phase / 'creature-horizon-night.png'), (column * 960, 44))
        sheet.save(args.output / f'{renderer}-night-sky-before-after.png')
        for view in ['forest', 'snow']:
            names = [f'{view}-day', *[f'{view}-day-{mode}' for mode in ['no-sun', 'no-ambient', 'exposure-half', 'white-one', 'albedo']]]
            sheet = Image.new('RGB', (1920, 1752), '#111820')
            draw = ImageDraw.Draw(sheet)
            for i, name in enumerate(names):
                x, y = (i % 2) * 960, (i // 2) * 584
                draw.text((x + 12, y + 8), f'{renderer} | {name}', font=font, fill='white')
                sheet.paste(Image.open(directory / 'after' / (name + '.png')), (x, y + 44))
            sheet.save(args.output / f'{renderer}-{view}-components.png')
    print(json.dumps({'comparison': str(args.output / 'comparison.json'),
                      'captures_compared': len(differences),
                      'within_condition_mismatches': [x['id'] for x in differences if x['condition_mismatches']],
                      'across_condition_mismatches': [x['id'] for x in across if x['condition_mismatches']]}))


if __name__ == '__main__':
    main()
