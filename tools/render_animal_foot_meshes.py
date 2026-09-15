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
    parser.add_argument("--mouths", action="store_true", help="Compare mouth models from front and side")
    parser.add_argument("--trunk", action="store_true", help="Review a head module and its complete runtime body")
    args = parser.parse_args()
    models = json.loads(args.source.read_text())
    fig = plt.figure(figsize=(15, 6 if args.hands else 8.5), facecolor="#081820")
    fig.suptitle("Voxelverse · Rüsselmodul" if args.trunk else ("Voxelverse · Tiermundformen" if args.mouths else ("Voxelverse · Krebsscheren" if args.hands else "Voxelverse · Neue Tierfußformen")), color="#edf1df", fontsize=24, y=0.96, va="top")
    subtitle = "Bisherige Scherenhand · Neues Modell · Gespiegeltes Modell" if args.hands else ("Godot-Voxelgeometrie · Vorder- und Seitenansicht" if args.mouths else "Godot-Voxelgeometrie · Standansicht und Sohle")
    if args.trunk:
        subtitle = "Gemeinsame Godot-Geometrie · eigener Anschluss oberhalb des Mundes"
    fig.text(0.5, 0.895 if args.trunk else (0.885 if args.hands else 0.900), subtitle, ha="center", color="#a5b9b7", fontsize=12)

    mouth_bounds = None
    if args.mouths:
        points = np.concatenate([np.asarray(mesh["vertices"])[:, [0, 2, 1]]
                                 for model in models for mesh in model["meshes"]])
        mouth_bounds = (points.min(axis=0) - 0.07, points.max(axis=0) + 0.07)
    light = np.array([0.3, 0.8, 0.5])
    light /= np.linalg.norm(light)
    for column, model in enumerate(models):
        for row, elevation in enumerate([5] if args.hands else ([8, 8] if args.mouths else [24, -35])):
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
            if args.trunk:
                points = np.concatenate(all_faces).reshape(-1, 3)
                low, high = points.min(axis=0), points.max(axis=0)
                margin = (high - low) * 0.10
                ax.set(xlim=(low[0] - margin[0], high[0] + margin[0]),
                       ylim=(low[1] - margin[1], high[1] + margin[1]),
                       zlim=(low[2] - margin[2], high[2] + margin[2]))
                ax.set_box_aspect(high - low, zoom=1.6 if model["id"] == "trunk_body" else 1.1)
            elif args.mouths:
                low, high = mouth_bounds
                ax.set(xlim=(low[0], high[0]), ylim=(low[1], high[1]), zlim=(low[2], high[2]))
                ax.set_box_aspect(high - low)
            elif args.hands:
                ax.set(xlim=(-0.38, 0.38), ylim=(-0.2, 0.2), zlim=(-0.68, 0.18))
                ax.set_box_aspect((0.76, 0.4, 0.86))
            else:
                ax.set(xlim=(-0.34, 0.34), ylim=(-0.53, 0.27), zlim=(-0.24, 0.25))
                ax.set_box_aspect((0.68, 0.8, 0.49))
            ax.set_proj_type("ortho")
            ax.view_init(elev=elevation, azim=(-90 if row == 0 else -20) if args.mouths else (-90 if args.hands else -65))
            if args.trunk:
                ax.view_init(elev=12 if row == 0 else 5, azim=-55 if row == 0 else -5)
            ax.set_axis_off()
            title = model["name"] + (" · gespiegelt" if model.get("side", 1) == -1 else "")
            ax.set_title(title if row == 0 else ("Seitenansicht" if args.mouths or args.trunk else "Sohlenansicht"), color="#edf1df" if row == 0 else "#a5b9b7", fontsize=18 if row == 0 else 12, pad=0)
    fig.subplots_adjust(left=0.02, right=0.98, bottom=0.045, top=0.82 if args.trunk else (0.80 if args.hands else 0.87), wspace=0, hspace=0)
    fig.text(0.5, 0.025, "Meshprüfung aus Godot-Daten · CPU-Ansicht, keine Spielaufnahme", color="#a5b9b7", ha="center", fontsize=10)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(args.output, dpi=110, facecolor=fig.get_facecolor())
    plt.close(fig)


if __name__ == "__main__":
    main()
