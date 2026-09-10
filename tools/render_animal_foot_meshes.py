"""Render exported Godot triangles for geometry QA without a window server.

This is a CPU mesh review, not a screenshot or renderer/FPS acceptance.
Usage: python tools/render_animal_foot_meshes.py meshes.json output.png
"""
import argparse
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from mpl_toolkits.mplot3d.art3d import Poly3DCollection


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--hands", action="store_true", help="Compare hand models with a front view")
    args = parser.parse_args()
    models = json.loads(args.source.read_text())
    fig = plt.figure(figsize=(15, 6 if args.hands else 8.5), facecolor="#081820")
    fig.suptitle("Voxelverse · Krebsscheren" if args.hands else "Voxelverse · Neue Tierfußformen", color="#edf1df", fontsize=24, y=0.96, va="top")
    subtitle = "Bisherige Scherenhand · Neues Modell · Gespiegeltes Modell" if args.hands else "Godot-Voxelgeometrie · Standansicht und Sohle"
    fig.text(0.5, 0.885 if args.hands else 0.915, subtitle, ha="center", color="#a5b9b7", fontsize=12)
    light = np.array([0.3, 0.8, 0.5])
    light /= np.linalg.norm(light)
    for column, model in enumerate(models):
        for row, elevation in enumerate([5] if args.hands else [24, -35]):
            ax = fig.add_subplot(1 if args.hands else 2, len(models), row * len(models) + column + 1, projection="3d", computed_zorder=True)
            ax.set_facecolor("#081820")
            all_faces, all_colors = [], []
            for mesh in model["meshes"]:
                vertices = np.asarray(mesh["vertices"], dtype=float)
                indices = np.asarray(mesh["indices"], dtype=int).reshape((-1, 3))
                # Godot +Y is up; matplotlib +Z is up.
                vertices = vertices[:, [0, 2, 1]]
                faces = vertices[indices]
                colors = np.asarray(mesh["colors"], dtype=float)[indices[:, 0]]
                normals = np.cross(faces[:, 1] - faces[:, 0], faces[:, 2] - faces[:, 0])
                lengths = np.linalg.norm(normals, axis=1)
                normals /= np.maximum(lengths[:, None], 1e-12)
                colors = np.clip(colors * (0.65 + 0.35 * np.abs(normals @ light))[:, None], 0, 1)
                all_faces.append(faces)
                all_colors.append(colors)
            # Sort faces across components together so underside pads remain visible.
            ax.add_collection3d(Poly3DCollection(np.concatenate(all_faces), facecolors=np.concatenate(all_colors), edgecolors="none", linewidths=0, zsort="average"))
            if args.hands:
                ax.set(xlim=(-0.38, 0.38), ylim=(-0.2, 0.2), zlim=(-0.68, 0.18))
                ax.set_box_aspect((0.76, 0.4, 0.86))
            else:
                ax.set(xlim=(-0.34, 0.34), ylim=(-0.53, 0.27), zlim=(-0.24, 0.25))
                ax.set_box_aspect((0.68, 0.8, 0.49))
            ax.set_proj_type("ortho")
            ax.view_init(elev=elevation, azim=-90 if args.hands else -65)
            ax.set_axis_off()
            title = model["name"] + (" · gespiegelt" if model.get("side", 1) == -1 else "")
            ax.set_title(title if row == 0 else "Sohlenansicht", color="#edf1df" if row == 0 else "#a5b9b7", fontsize=18 if row == 0 else 12, pad=0)
    fig.subplots_adjust(left=0.02, right=0.98, bottom=0.045, top=0.80 if args.hands else 0.87, wspace=0, hspace=0)
    fig.text(0.5, 0.025, "Meshprüfung aus Godot-Daten · CPU-Ansicht, keine Spielaufnahme", color="#a5b9b7", ha="center", fontsize=10)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(args.output, dpi=110, facecolor=fig.get_facecolor())
    plt.close(fig)


if __name__ == "__main__":
    main()
