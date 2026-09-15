"""CPU review of exported Godot body meshes; not a game screenshot or FPS test.

Usage: python tools/render_part_articulation.py bodies.json output.png
"""
import argparse
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
import numpy as np


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    models = json.loads(args.source.read_text())
    fig = plt.figure(figsize=(16, 10), facecolor="#102831")
    fig.suptitle("Voxelverse · Bewegliche Kiefer & Krebsscheren", color="#eff4e7", fontsize=24, y=0.96)
    light = np.array([0.3, -0.5, 0.8])
    light /= np.linalg.norm(light)
    bounds = np.concatenate([np.asarray(mesh["vertices"])[:, [0, 2, 1]]
                             for model in models for mesh in model["meshes"]])
    center = (bounds.min(axis=0) + bounds.max(axis=0)) / 2
    size = (bounds.max(axis=0) - bounds.min(axis=0)) * 1.12
    for index, model in enumerate(models):
        ax = fig.add_subplot(2, 3, index + 1, projection="3d", computed_zorder=True)
        ax.set_facecolor("#102831")
        faces, colors = [], []
        for mesh in model["meshes"]:
            vertices = np.asarray(mesh["vertices"], dtype=float)[:, [0, 2, 1]]
            indices = np.asarray(mesh["indices"], dtype=int).reshape(-1, 3)
            triangles = vertices[indices]
            normals = np.cross(triangles[:, 1] - triangles[:, 0], triangles[:, 2] - triangles[:, 0])
            normals /= np.maximum(np.linalg.norm(normals, axis=1)[:, None], 1e-12)
            shading = (0.65 + 0.35 * np.abs(normals @ light))[:, None]
            faces.append(triangles)
            colors.append(np.clip(np.asarray(mesh["colors"])[indices[:, 0]] * shading, 0, 1))
        ax.add_collection3d(Poly3DCollection(np.concatenate(faces), facecolors=np.concatenate(colors),
                                           edgecolors="none", linewidths=0, zsort="average"))
        ax.set(xlim=(center[0] - size[0]/2, center[0] + size[0]/2),
               ylim=(center[1] - size[1]/2, center[1] + size[1]/2),
               zlim=(center[2] - size[2]/2, center[2] + size[2]/2))
        ax.set_box_aspect(size.copy())
        ax.set_proj_type("ortho")
        ax.view_init(elev=14, azim=-48)
        ax.set_axis_off()
        ax.set_title(model["name"] + " · " + model["pose"], color="#eff4e7", fontsize=14)
    fig.subplots_adjust(left=0.01, right=0.99, bottom=0.07, top=0.89, wspace=0, hspace=0)
    fig.text(0.5, 0.035, "Vollständige Körper aus Godot-Meshdaten · CPU-Geometrieprüfung, keine Spielaufnahme",
             color="#a5b9b7", ha="center", fontsize=12)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(args.output, dpi=100, facecolor=fig.get_facecolor())
    plt.close(fig)


if __name__ == "__main__":
    main()
