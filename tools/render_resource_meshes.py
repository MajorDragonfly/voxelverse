"""CPU inspection of exported native mesh arrays; not a game screenshot."""
import argparse
import json
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from mpl_toolkits.mplot3d.art3d import Poly3DCollection

def draw(ax, model, nest=False):
    faces, colors = [], []
    light = np.array([0.3,-0.5,0.8])
    for mesh in model['meshes']:
        vertices = np.asarray(mesh['vertices'])[:,[0,2,1]]
        indices = np.asarray(mesh['indices']).reshape(-1,3)
        triangles = vertices[indices]
        normals = np.cross(triangles[:,1]-triangles[:,0],triangles[:,2]-triangles[:,0])
        normals /= np.maximum(np.linalg.norm(normals,axis=1)[:,None],1e-12)
        shade = 0.70+0.30*np.abs(normals@light)
        colors.append(np.clip(np.asarray(mesh['colors'])[indices[:,0]]*shade[:,None],0,1))
        faces.append(triangles)
    ax.add_collection3d(Poly3DCollection(np.concatenate(faces),facecolors=np.concatenate(colors),
        edgecolors='none',linewidths=0,zsort='average'))
    span = 1.6 if nest else 1.0
    height = 0.65 if nest else 1.5
    ax.set(xlim=(-span,span),ylim=(-span,span),zlim=(-0.05,height))
    ax.set_box_aspect((span*2,span*2,height),zoom=1.3)
    ax.view_init(elev=42 if nest else 22,azim=-58)
    ax.set_proj_type('ortho')
    ax.set_axis_off()
    ax.set_facecolor('#0b1c23')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory',type=Path)
    args = parser.parse_args()
    labels = ['Verzweigter Strauch','Aufrechter Strauch','Etagenkrone','Fächerform','Bogenform','Flaches Polster']
    for kind,rows,columns,title in [('forage',2,3,'Voxelverse · Sechs Pflanzenformen'),('nest',1,2,'Voxelverse · Prozedurales Nest')]:
        models = json.loads((args.directory/f'{kind}_meshes.json').read_text())
        fig = plt.figure(figsize=(15,10 if rows==2 else 6),facecolor='#0b1c23')
        fig.suptitle(title,color='#f1eddc',fontsize=24,y=0.97)
        for i,model in enumerate(models):
            ax=fig.add_subplot(rows,columns,i+1,projection='3d')
            draw(ax,model,kind=='nest')
            ax.set_title(labels[i] if kind=='forage' else f'Variante {i+1}',color='#cbded6',fontsize=15,pad=5)
        fig.text(0.5,0.025,'Echte Godot-Meshdaten · CPU-Ansicht · keine Spielaufnahme',ha='center',color='#9ab6b8',fontsize=11)
        fig.subplots_adjust(left=0.01,right=0.99,bottom=0.06,top=0.88,wspace=0.01,hspace=0.12)
        fig.savefig(args.directory/f'{kind}_mesh_review.png',dpi=125)
        plt.close(fig)

if __name__ == '__main__':
    main()
