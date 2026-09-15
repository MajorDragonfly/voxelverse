"""Render exported Godot tail meshes and complete bodies for visual QA.

CPU mesh views; this is not a game screenshot or native renderer acceptance.
Usage: python tools/render_tail_review.py meshes.json output_directory
"""
import argparse
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from mpl_toolkits.mplot3d.art3d import Poly3DCollection


def render(models, views, title, target):
    background, ink, muted = "#081820", "#edf1df", "#a5b9b7"
    fig = plt.figure(figsize=(18, 8.8 if len(views) > 1 else 6), facecolor=background)
    fig.suptitle(title, fontsize=24, color=ink, y=0.96)
    fig.text(0.5, 0.90 if len(views) > 1 else 0.85, "Gemeinsame Godot-Geometrie · gleicher Maßstab in jeder Spalte", ha="center", color=muted, fontsize=12)
    points = np.concatenate([np.asarray(mesh["vertices"])[:, [0, 2, 1]]
                             for model in models for mesh in model["meshes"]])
    low, high = points.min(axis=0) - 0.05, points.max(axis=0) + 0.05
    light = np.array([0.3, 0.8, 0.5])
    light /= np.linalg.norm(light)
    for column, model in enumerate(models):
        faces, colors = [], []
        for mesh in model["meshes"]:
            vertices = np.asarray(mesh["vertices"])[:, [0, 2, 1]]
            indices = np.asarray(mesh["indices"]).reshape((-1, 3))
            triangles = vertices[indices]
            tint = np.asarray(mesh["colors"])[indices[:, 0]]
            normals = np.cross(triangles[:, 1] - triangles[:, 0], triangles[:, 2] - triangles[:, 0])
            normals /= np.maximum(np.linalg.norm(normals, axis=1)[:, None], 1e-12)
            faces.append(triangles)
            colors.append(np.clip(tint * (0.65 + 0.35 * np.abs(normals @ light))[:, None], 0, 1))
        for row, (elevation, azimuth, label) in enumerate(views):
            ax = fig.add_subplot(len(views), len(models), row * len(models) + column + 1, projection="3d")
            ax.set_facecolor(background)
            ax.add_collection3d(Poly3DCollection(np.concatenate(faces), facecolors=np.concatenate(colors), edgecolors="none", linewidths=0, zsort="average"))
            ax.set(xlim=(low[0], high[0]), ylim=(low[1], high[1]), zlim=(low[2], high[2]))
            ax.set_box_aspect(high - low)
            ax.set_proj_type("ortho")
            ax.view_init(elev=elevation, azim=azimuth)
            ax.set_axis_off()
            ax.set_title(model["name"] if row == 0 else label, color=ink if row == 0 else muted, fontsize=14 if row == 0 else 11, pad=0)
    fig.subplots_adjust(left=0.01, right=0.99, bottom=0.06, top=0.84 if len(views) > 1 else 0.78, wspace=0, hspace=0.04)
    fig.text(0.5, 0.025, "Meshprüfung aus Godot-Daten · CPU-Ansicht, keine Spielaufnahme", ha="center", color=muted, fontsize=10)
    fig.savefig(target, dpi=115, facecolor=background)
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    data = json.loads(args.source.read_text())
    args.output.mkdir(parents=True, exist_ok=True)
    render(data["models"], [(25, -45, "Schrägansicht"), (90, -90, "Draufsicht")],
           "Voxelverse · Vier neue Schwanzformen", args.output / "tails-models.png")
    render(data["bodies"], [(12, -12, "Körperansicht")],
           "Voxelverse · Schwanzformen am Kreaturenkörper", args.output / "tails-bodies.png")


if __name__ == "__main__":
    main()
