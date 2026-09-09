#!/usr/bin/env python3
"""Show identical GLB geometry in exported, real generator palettes."""
import json
from PIL import Image, ImageDraw, ImageFont
from render_benchmark import render, ROOT, RUNTIME


def main():
    output = ROOT / 'art/review/benchmark_v2'
    samples = json.loads((output / 'planet_samples.json').read_text())
    sheet = Image.new('RGB', (1950, 1120), (233, 235, 228))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 23)
    small = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 16)
    for column, sample in enumerate(samples):
        x = column * 650
        draw.text((x + 22, 20), f'{sample["family"].upper()} / seed {sample["seed"]}', fill='#26362c', font=font)
        sheet.paste(render(RUNTIME / 'ancient_oak_v2_near.glb', palette=sample['palette']), (x, 55))
        for i, family in enumerate(['dense_bush_v2', 'layered_rock_v2']):
            sheet.paste(render(RUNTIME / (family + '_near.glb'), (325, 325), sample['palette']), (x + i * 325, 700))
        for i, slot in enumerate(['1', '20', '5', '7', '13', '16', '17']):
            c = tuple(round(v * 255) for v in sample['palette'][slot][:3])
            draw.rectangle((x + 25 + i * 85, 1040, x + 99 + i * 85, 1066), fill=c)
    draw.text((22, 1087), 'Same exported meshes; real planet material slots. CPU geometry preview; Godot lighting requires in-game review.', fill='#455347', font=small)
    sheet.save(output / 'planet_palette_comparison.png')


if __name__ == '__main__':
    main()
