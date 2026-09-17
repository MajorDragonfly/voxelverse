"""Render exported Godot fins/ears at consistent scale; CPU views, not gameplay."""
import json
import sys
from pathlib import Path
from render_tail_review import render
source, output, family = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
assert family in ('fins', 'ears')
output.mkdir(parents=True, exist_ok=True)
data = json.loads(source.read_text())
for group in range(2):
    chunk = slice(group * 3, (group + 1) * 3)
    views = [(18, -75, 'Vorderseite'), (18, -25, 'Schrägansicht')]
    title = 'Ohren'
    if family == 'fins':
        title = 'Seitenflossen' if group == 0 else 'Rückenflossen'
        views = [(60, -65, 'Schrägansicht'), (90, -90, 'Draufsicht')] if group == 0 else [(15, -10, 'Seitenansicht'), (35, -45, 'Schrägansicht')]
    render(data['models'][chunk], views, 'Voxelverse · ' + title, output / f'{family}-models-{group + 1}.png')
    render(data['bodies'][chunk], [(25, -65, 'Am Körper')], 'Voxelverse · ' + title + ' am Körper', output / f'{family}-bodies-{group + 1}.png')
