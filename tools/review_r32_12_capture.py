#!/usr/bin/env python3
"""Native R32-12 evidence; all outputs outside Git source, isolated user data."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import time
from validation_support import isolated_env
from validation_provenance import SourceRun


def run(args):
    project = args.project.resolve()
    output = args.output.resolve()
    if output.is_relative_to(project) or output.exists():
        raise ValueError('Use a new output directory outside the source')
    output.mkdir(parents=True)
    source = SourceRun(project)
    source.begin_report(output)
    command = [str(args.godot.resolve()), '--path', str(project), '--rendering-method', args.renderer,
               '--audio-driver', 'Dummy', '--fixed-fps', '30', '--script',
               'res://tools/review_r32_12_animation.gd', '--', str(output)]
    command += ['--group'] if args.group else ['--capture-video']
    if args.baseline:
        command.append('--allow-face-drift')
    if args.closeup:
        command.append('--closeup')
    if args.group_flee:
        assert args.group
        command.append('--group-flee')
    env = isolated_env(output / 'userdata')
    env['LIBGL_ALWAYS_SOFTWARE'] = '1'
    start = time.monotonic()
    with (output / 'render.log').open('wb') as stream:
        result = subprocess.run(command, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=900)
    source.observe('native_end', force=True)
    provenance = source.write_report(output)
    (output / 'source-provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
    metrics = json.loads((output / 'metrics.json').read_text())
    expected = ['Live foot penetrated loaded shore floor'] if args.baseline and not args.group else []
    assert metrics['failures'] == expected, metrics['failures']
    assert result.returncode == (1 if expected else 0), result.returncode
    text = (output / 'render.log').read_text()
    assert 'SCRIPT ERROR' not in text and 'Parse Error' not in text and 'leaked at exit' not in text
    warnings = [line for line in text.splitlines() if line.startswith('WARNING:')]
    # Xvfb/llvmpipe cannot change VSync; retain this exact host capability warning.
    known_display_warning = 'WARNING: Could not set V-Sync mode, as changing V-Sync mode is not supported by the graphics driver.'
    assert all(line == known_display_warning for line in warnings), warnings
    if not expected:
        assert 'ERROR:' not in text, text[-2000:]
    assert not source.blocked, provenance
    if not args.group:
        assert metrics['frames'] > 1000
        for shape in [row for row in metrics['samples'] if 'seen' in row]:
            assert all(shape['seen'].get(key) for key in ['rest', 'forage', 'eat', 'drink', 'seek_water',
                                                        'play_greet', 'play_play', 'play_rest', 'flee', 'alert'])
        assert len([row for row in metrics['samples'] if 'seen' in row]) == 3
        subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-framerate', '30', '-i',
                        str(output / 'frame_%05d.png'), '-c:v', 'libx264', '-crf', '23',
                        '-pix_fmt', 'yuv420p', str(output / 'encounters.mp4')], check=True, timeout=180)
        keep = set()
        for shape in range(3):
            for state in ['rest', 'forage', 'eat', 'drink', 'play_greet', 'play_play', 'play_rest', 'flee', 'alert']:
                matching = [row['frame'] for row in metrics['samples'] if row.get('shape') == shape and row.get('ai') == state]
                if matching:
                    keep.add(matching[len(matching) // 2])
        for frame in output.glob('frame_*.png'):
            if int(frame.stem.split('_')[1]) not in keep:
                frame.unlink()
    summary = {'command': command, 'returncode': result.returncode, 'seconds': time.monotonic() - start,
               'baseline_expected_negative': bool(expected), 'group': args.group,
               'environment_warnings': warnings, 'view': metrics['view'], 'group_states': metrics['group_states'],
               'system': platform.platform(), 'cpu': platform.processor(),
               'source': provenance['end'], 'scope': 'Software-rendered animation evidence, no target-PC acceptance'}
    if args.group:
        values = sorted(metrics['animation_cpu_us'])
        assert len(values) == 180
        summary['group_animation_ms'] = {'actors': 12, 'samples': len(values),
                                        'p50': statistics.median(values) / 1000,
                                        'p95': values[int((len(values) - 1) * .95)] / 1000,
                                        'p99': values[int((len(values) - 1) * .99)] / 1000,
                                        'max': max(values) / 1000}
        summary['render_wait_ms'] = {'p50': statistics.median(metrics['draw_wait_ms']),
                                     'max': max(metrics['draw_wait_ms'])}
    files = []
    for path in sorted(output.iterdir()):
        if path.is_file():
            files.append({'path': path.name, 'bytes': path.stat().st_size,
                          'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    summary['files'] = files
    (output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps({key: value for key, value in summary.items() if key != 'files'}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--project', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--renderer', choices=['gl_compatibility', 'forward_plus'], required=True)
    parser.add_argument('--baseline', action='store_true')
    parser.add_argument('--group', action='store_true')
    parser.add_argument('--group-flee', action='store_true')
    parser.add_argument('--closeup', action='store_true')
    run(parser.parse_args())
