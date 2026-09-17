"""Compare actual Godot meshes at a shared scale; CPU views, no native screenshots."""
import argparse,json
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
from render_tail_review import render

def compare(rows, labels, target):
    bg,ink,muted='#081820','#edf1df','#a5b9b7'
    fig=plt.figure(figsize=(20,12),facecolor=bg)
    fig.suptitle('Voxelverse · Mundformen überarbeitet',fontsize=24,color=ink,y=.97)
    fig.text(.5,.93,'Bisherige Form / neue Form / neuer Kiefer geöffnet · gleicher Maßstab',ha='center',color=muted,fontsize=12)
    points=np.concatenate([np.asarray(m['vertices'])[:,[0,2,1]] for row in rows for model in row for m in model['meshes']])
    low,high=points.min(axis=0)-.035,points.max(axis=0)+.035
    light=np.array([.3,.8,.5]);light/=np.linalg.norm(light)
    for row,models in enumerate(rows):
        for col,model in enumerate(models):
            faces,colors=[],[]
            for mesh in model['meshes']:
                v=np.asarray(mesh['vertices'])[:,[0,2,1]];indices=np.asarray(mesh['indices']).reshape((-1,3));tri=v[indices]
                n=np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]);n/=np.maximum(np.linalg.norm(n,axis=1)[:,None],1e-12)
                faces.append(tri);colors.append(np.clip(np.asarray(mesh['colors'])[indices[:,0]]*(.70+.30*np.abs(n@light))[:,None],0,1))
            ax=fig.add_subplot(len(rows),len(models),row*len(models)+col+1,projection='3d');ax.set_facecolor(bg)
            ax.add_collection3d(Poly3DCollection(np.concatenate(faces),facecolors=np.concatenate(colors),edgecolors='none',linewidths=0,zsort='average'))
            ax.set(xlim=(low[0],high[0]),ylim=(low[1],high[1]),zlim=(low[2],high[2]));ax.set_box_aspect(high-low);ax.set_proj_type('ortho');ax.view_init(elev=10,azim=-65);ax.set_axis_off()
            ax.set_title(model['name'] if row==0 else labels[row],color=ink if row==0 else muted,fontsize=13,pad=0)
    fig.subplots_adjust(left=.01,right=.99,bottom=.045,top=.87,wspace=0,hspace=.06)
    fig.text(.5,.015,'Tatsächliche gemeinsame Godot-Geometrie · CPU-Ansicht, keine Spielaufnahme',ha='center',color=muted,fontsize=10)
    fig.savefig(target,dpi=105,facecolor=bg);plt.close(fig)

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('source',type=Path);p.add_argument('output',type=Path);a=p.parse_args();data=json.loads(a.source.read_text());a.output.mkdir(parents=True,exist_ok=True)
    for i,(start,end) in enumerate([(0,4),(4,7),(7,10)]):
        compare([data[key][start:end] for key in ['before','after','open']],['Bisher','Neu','Geöffnet'],a.output/f'mouths-comparison-{i+1}.png')
        render(data['bodies'][start:end],[(18,-35,'Körperansicht')],'Voxelverse · Überarbeitete Mundformen am Körper',a.output/f'mouths-bodies-{i+1}.png')
    render(data['after'][:4],[(10,0,'Seitenansicht')],'Voxelverse · Neue Grundformen von der Seite',a.output/'mouths-side.png')

if __name__=='__main__':main()
