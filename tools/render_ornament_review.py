"""Render actual shared Godot ornament meshes. CPU views, not game screenshots."""
import argparse
import json
from pathlib import Path
from render_tail_review import render


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    data = json.loads(args.source.read_text())
    args.output.mkdir(parents=True, exist_ok=True)
    render(data['models'], [(14, -80, 'Vorderansicht'), (20, 0, 'Seitenansicht')],
           'Voxelverse · Geweihe, Kämme und Nackenschild', args.output / 'ornaments-models.png')
    render(data['bodies'], [(18, -35, 'Körperansicht')],
           'Voxelverse · Geweihe und Kämme am Körper', args.output / 'ornaments-bodies.png')


if __name__ == '__main__':
    main()
