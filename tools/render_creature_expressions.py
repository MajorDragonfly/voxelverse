"""CPU review of six real Godot runtime poses. This is not a game screenshot."""
import argparse,json
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from mpl_toolkits.mplot3d.art3d import Poly3DCollection

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path)
    parser.add_argument('output',type=Path)
    args=parser.parse_args()
    models=json.loads(args.source.read_text())
    fig=plt.figure(figsize=(14,9),facecolor='#0e2028')
    fig.suptitle('VOXELVERSE  /  Tieremotionen',color='#edf1df',fontsize=25,y=.96)
    fig.text(.5,.91,'Gleiche Kreatur · sechs Reaktionen aus der Laufzeit',ha='center',color='#acc6c1',fontsize=13)
    light=np.array([.3,-.6,.8]);light/=np.linalg.norm(light)
    geometry=[]
    for model in models:
        faces=[];colors=[]
        for mesh in model['meshes']:
            vertices=np.asarray(mesh['vertices'])[:,[0,2,1]]
            indices=np.asarray(mesh['indices']).reshape(-1,3)
            triangles=vertices[indices]
            normals=np.cross(triangles[:,1]-triangles[:,0],triangles[:,2]-triangles[:,0])
            normals/=np.maximum(np.linalg.norm(normals,axis=1)[:,None],1e-12)
            shade=.68+.32*np.abs(normals@light)
            faces.append(triangles)
            colors.append(np.clip(np.asarray(mesh['colors'])[indices[:,0]]*shade[:,None],0,1))
        geometry.append((np.concatenate(faces),np.concatenate(colors)))
    points=np.concatenate([g[0].reshape(-1,3) for g in geometry]);low=points.min(axis=0);high=points.max(axis=0)
    for index,(faces,colors) in enumerate(geometry):
        ax=fig.add_subplot(2,3,index+1,projection='3d')
        ax.set_facecolor('#0e2028')
        ax.add_collection3d(Poly3DCollection(faces,facecolors=colors,edgecolors='none',linewidths=0,zsort='average'))
        ax.set(xlim=(low[0]-.05,high[0]+.05),ylim=(low[1]-.05,high[1]+.05),zlim=(low[2]-.05,high[2]+.05))
        ax.set_box_aspect(high-low,zoom=1.22)
        ax.view_init(elev=16,azim=-52)
        ax.set_proj_type('ortho');ax.set_axis_off()
        ax.set_title(models[index]['name'],color='#edf1df',fontsize=18,pad=0)
    fig.subplots_adjust(left=.02,right=.98,top=.85,bottom=.08,wspace=.03,hspace=.10)
    fig.text(.5,.03,'Echte Godot-Meshdaten · CPU-Ansicht · keine Spielaufnahme',ha='center',color='#acc6c1',fontsize=11)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    fig.savefig(args.output,dpi=115,facecolor=fig.get_facecolor());plt.close(fig)
if __name__=='__main__':main()
