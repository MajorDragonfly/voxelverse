"""Render actual Godot wing meshes for visual review (CPU, not game capture)."""
import json
import sys
from pathlib import Path
from render_tail_review import render
source, output = Path(sys.argv[1]), Path(sys.argv[2])
output.mkdir(parents=True, exist_ok=True)
data = json.loads(source.read_text())
render(data["models"], [(65, -65, "Schrägansicht"), (90, -90, "Draufsicht")], "Voxelverse · Vier neue Flügelformen", output / "wings-models.png")
render(data["bodies"], [(25, -65, "Am Körper")], "Voxelverse · Flügel am Kreaturenkörper", output / "wings-bodies.png")
render(data["stretched"], [(15, -65, "Gestreckt")], "Voxelverse · Streckbewegung aus dem Schultergelenk", output / "wings-stretched.png")
