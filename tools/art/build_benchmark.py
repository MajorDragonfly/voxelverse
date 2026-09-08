#!/usr/bin/env python3
"""Deterministic voxel family authoring and culled, greedy-meshed GLB export.

No external assets or Python packages. Godot units are metres; Blockbench uses
16 authoring units/metre. UV.x stores a semantic slot, never a baked planet hue.
Near/Mid/Far use different architectural detail and sampling, not scaled copies.
"""
import argparse
import base64
from collections import defaultdict
import json
import math
from pathlib import Path
import random
import re
import struct
import uuid
import zlib

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art/source/blockbench/environment/benchmark_v2'
PACK = ROOT / 'assets/packs/temperate_forest_v1'
RUNTIME = PACK / 'environment/benchmark_v2'
SLOT_TEXT = (ROOT / 'assets/catalog/planet_material_slots.gd').read_text()
SLOTS = re.findall(r'"([a-z_]+)"', SLOT_TEXT.split('const NAMES:')[1].split('= [',1)[1].split(']')[0])
SLOT = {name: i for i, name in enumerate(SLOTS)}
COLORS = ['8baf55','557e3c','36562e','233a29','8c6a42','61492f','3b3028',
          '66834c','415737','b0a267','e8a99d','f4d580','aca89a','777b72','454e50',
          'c3b490','5bada9','266774','879a58','76614e','46776b','70a28a','30594e']
FAMILIES = ['ancient_oak_v2', 'tall_pine_v2', 'dense_bush_v2', 'fern_cluster_v2',
            'flower_cluster_v2', 'layered_rock_v2', 'grass_tuft_v2']


def png_palette():
    pixels = b''.join(bytes.fromhex(c) + b'\xff' for c in COLORS)
    pixels += b'\xff\x00\xff\xff' * (32 - len(COLORS))
    def chunk(name, data):
        return struct.pack('>I', len(data)) + name + data + struct.pack('>I', zlib.crc32(name + data) & 0xffffffff)
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB',32,1,8,6,0,0,0)) + chunk(b'IDAT', zlib.compress(b'\0'+pixels)) + chunk(b'IEND',b'')


class Voxels:
    def __init__(self, step, seed):
        self.step = step
        self.seed = seed
        self.cells = {}

    def ellipsoid(self, center, radii, slot, rough=0.0, overwrite=True):
        step = self.step
        lo = [math.floor((center[i]-radii[i]*(1+rough))/step) for i in range(3)]
        hi = [math.ceil((center[i]+radii[i]*(1+rough))/step) for i in range(3)]
        for x in range(lo[0], hi[0]+1):
            for y in range(max(lo[1],0), hi[1]+1):
                for z in range(lo[2], hi[2]+1):
                    p = (x,y,z)
                    d = sum((((p[i]+.5)*step-center[i])/max(radii[i],step*.53))**2 for i in range(3))
                    # Smooth block-scale edge scalloping, not independent RGB noise.
                    n = math.sin(x*1.7+z*.8+self.seed)*math.cos(y*1.3-z*.9)
                    if d < 1 + rough*n and (overwrite or p not in self.cells):
                        self.cells[p] = SLOT[slot]

    def path(self, points, radii, slot, rough=.0):
        for a,b,ra,rb in zip(points, points[1:], radii, radii[1:]):
            dist = math.sqrt(sum((b[i]-a[i])**2 for i in range(3)))
            count = max(2,math.ceil(dist/(self.step*.55)))
            for j in range(count+1):
                t = j/count
                center = tuple(a[i]+(b[i]-a[i])*t for i in range(3))
                radius = ra+(rb-ra)*t
                self.ellipsoid(center,(radius,)*3,slot,rough)

    def leaf_lobe(self, rng, center, radii, family='foliage', detail=True):
        self.ellipsoid(center,radii,family+'_base',.19 if detail else .08,False)
        # Broad patches preserve form from distance. Interior faces are culled.
        high = (center[0]-.12*radii[0],center[1]+.40*radii[1],center[2]-.14*radii[2])
        self.ellipsoid(high,tuple(r*.78 for r in radii),family+'_highlight',.12 if detail else .0,False)
        for j in range(5):
            a = rng.random()*math.tau
            c = (center[0]+math.cos(a)*radii[0]*.83,center[1]+rng.uniform(-.2,.28)*radii[1],center[2]+math.sin(a)*radii[2]*.83)
            r = rng.uniform(.19,.32)
            if detail:
                self.ellipsoid(c,(r,r*.6,r*.8),family+'_highlight' if j%3==0 else family+'_shadow',.14,False)



def oak(vox, rng, tier, variant):
    if variant in (1,2):
        # Open umbrella crown versus young forked column: different branching
        # architectures, not scaled copies of the ancient broad oak.
        umbrella = variant == 1
        h = 4.5 if umbrella else 7.2
        trunk = [(0,.08,0),(-.14,1.1,.08),(.22,2.25,0),(.32,h*.60,.1)]
        vox.path(trunk,[.42,.32,.24,.13],'bark_base')
        for i in range(5):
            a=i*math.tau/5
            vox.path([(0,.3,0),(math.cos(a)*1.2,.04,math.sin(a)*1.2)],[.20,.04],'bark_shadow')
        count=7 if umbrella else 5
        for i in range(count):
            a=i*2.39996
            reach=rng.uniform(2.2,3.1) if umbrella else rng.uniform(.8,1.65)
            tip=(math.cos(a)*reach,h+rng.uniform(-.3,.4),math.sin(a)*reach)
            elbow=(tip[0]*.48,h*.76,tip[2]*.48)
            vox.path([trunk[-2],elbow,tip],[.20,.12,.035],'bark_base')
            radii=(1.4,.48,1.15) if umbrella else (.80,1.1,.72)
            vox.leaf_lobe(rng,tip,radii,detail=tier==0)
            if tier<2:
                split=(tip[0]+.45,tip[1]+.35,tip[2]-.28)
                vox.path([elbow,split],[.08,.028],'bark_highlight')
                vox.leaf_lobe(rng,split,tuple(v*.55 for v in radii),detail=tier==0)
        vox.leaf_lobe(rng,(.25,h+.1,.1),(1.2,.5,1.0) if umbrella else (.85,1.2,.8),detail=tier==0)
        return
    lean = .38 + variant*.14
    trunk=[(0,.08,0),(-.12,1.25,.04),(.12,2.5,-.06),(lean,3.5,.12),(lean+.14,4.7,.05),(.18,5.8,-.08)]
    vox.path(trunk,[.65,.49,.38,.29,.21,.08],'bark_base')
    for i in range(7):
        a=i*math.tau/7+.18
        reach=rng.uniform(1.35,2.1)
        vox.path([(0,.52,0),(math.cos(a)*.8,.18,math.sin(a)*.8),(math.cos(a)*reach,.06,math.sin(a)*reach)], [.32,.21,.07],'bark_shadow')
    lobes=[]
    for i in range(10):
        a=i*2.39996+variant*.31
        reach=rng.uniform(2.45,3.6)
        start=trunk[2+i%3]
        end=(math.cos(a)*reach,4.6+rng.uniform(.1,2.0)+i*.06,math.sin(a)*reach*.86)
        elbow=(end[0]*.56, start[1]+rng.uniform(.32,.8),end[2]*.55)
        vox.path([start,elbow,end],[.27-i*.009,.18,.06],'bark_base')
        lobes.append((end,(rng.uniform(.92,1.35),rng.uniform(.62,.92),rng.uniform(.87,1.35))))
        for j in range(2):
            split=(end[0]+math.cos(a+j*1.8)*.9,end[1]+rng.uniform(.18,.74),end[2]+math.sin(a+j*1.8)*.9)
            if tier<2:
                vox.path([elbow,split],[.13,.04],'bark_highlight')
            lobes.append((split,(rng.uniform(.64,1.0),rng.uniform(.42,.68),rng.uniform(.62,.94))))
    lobes += [((.2,6.7,.1),(1.7,.94,1.5)), ((-.8,6.05,-.5),(1.3,.8,1.2))]
    for c,r in lobes:
        vox.leaf_lobe(rng,c,r,detail=tier==0)
    if tier==0:
        # Bark buttress ridges add vertical rhythm and a visible trunk taper.
        for i in range(5):
            a=i*math.tau/5
            vox.path([(math.cos(a)*.52,.18,math.sin(a)*.52),(math.cos(a)*.4,1.6,math.sin(a)*.4),(.12+math.cos(a)*.25,2.7,math.sin(a)*.25)], [.11,.07,.04],'bark_highlight')


def pine(vox,rng,tier,variant):
    if variant == 2:
        # Wind-shaped highland conifer, with a strongly one-sided branch fan.
        trunk=[(0,.05,0),(.2,1.5,0),(.6,3.2,0),(1.0,5.0,.12),(1.35,6.8,.2)]
        vox.path(trunk,[.32,.25,.18,.12,.035],'bark_base')
        for i in range(7):
            y=2.1+i*.63
            tip=(1.3+rng.uniform(.45,1.6),y+.2,(-1 if i%2 else 1)*rng.uniform(.35,1.0))
            vox.path([(.4,y-.15,0),tip],[.12,.03],'bark_shadow')
            vox.leaf_lobe(rng,tip,(.85,.3,.65),detail=tier==0)
        vox.leaf_lobe(rng,trunk[-1],(.35,.6,.35),detail=tier==0)
        return
    height=10.6 if variant == 0 else 8.6
    vox.path([(0,.06,0),(.12,4,-.04),(-.12,height*.72,.12),(.0,height,0)],[.38,.23,.12,.04],'bark_base')
    for i in range(5):
        a=i*1.256+.2
        vox.path([(0,.3,0),(math.cos(a)*1.0,.04,math.sin(a)*1.0)],[.18,.035],'bark_shadow')
    for layer in range(8 if variant == 0 else 5):
        y=3.0+layer*(.91 if variant == 0 else 1.05)
        span=(height-y)*.30
        branches=5
        for b in range(branches):
            a=b*math.tau/branches+layer*1.34+variant*.2
            stretch=rng.uniform(.8,1.18)
            tip=(math.cos(a)*span*stretch,y+.08,math.sin(a)*span*stretch)
            if tier<2:
                vox.path([(0,y+.18,0),(tip[0]*.7,y-.12,tip[2]*.7),tip],[.10,.065,.025],'bark_base')
            center=(tip[0]*.70,y+.16,tip[2]*.70)
            vox.leaf_lobe(rng,center,(max(span*.44,.24),.28+span*.11,max(span*.44,.24)),detail=tier==0)
    vox.ellipsoid((0,height-.30,0),(.28,.58,.28),'foliage_highlight',.15)


def bush(vox,rng,tier,variant):
    for i in range(8 if variant != 1 else 5):
        a=i*2.4
        c=(math.cos(a)*rng.uniform(.3,.8),rng.uniform(.52,1.05),math.sin(a)*rng.uniform(.32,.76))
        if variant==1: c=(c[0]*.5,c[1]*1.8,c[2]*.5)
        if variant==2: c=(c[0]*1.55,c[1]*.65,c[2]*1.55)
        vox.path([(0,.03,0),(c[0]*.5,.35,c[2]*.5),c],[.10,.065,.03],'bark_shadow')
        vox.leaf_lobe(rng,c,(rng.uniform(.42,.65),rng.uniform(.34,.56),rng.uniform(.4,.63)),family='shrub',detail=tier==0)


def fern(vox,rng,tier,variant):
    # A radial fountain of separated feather-shaped fronds, plus two juveniles.
    for plant in range(3):
        ox,oz=[(0,0),(-.82,.40),(.7,.55)][plant]
        factor=1.0 if plant==0 else .5
        count=9 if plant==0 else 5
        for frond in range(count):
            a=frond*math.tau/count+plant*.76+variant*.12
            reach=rng.uniform(.86,1.26)*factor; height=rng.uniform(.64,1.04)*factor
            points=[]
            for j in range(11):
                t=j/10
                points.append((ox+math.cos(a)*reach*t,height*math.sin(t*1.92)+.02,oz+math.sin(a)*reach*t))
            vox.path(points,[.018]*len(points),'foliage_shadow')
            for j in range(2,10,1 if tier==0 else 2):
                t=j/10; c=points[j]; length=math.sin(t*math.pi)*.18*factor
                for side in [-1,1]:
                    tip=(c[0]+math.cos(a+side*1.28)*length,c[1]+.018,c[2]+math.sin(a+side*1.28)*length)
                    vox.path([c,tip],[.023,.011],'foliage_highlight' if frond%3==0 else 'foliage_base')


def flowers(vox,rng,tier,variant):
    for stem in range(9 if tier<2 else 6):
        a=stem*2.4; radius=math.sqrt(stem/9)*.66
        x,z=math.cos(a)*radius,math.sin(a)*radius
        height=rng.uniform(.48,1.08)
        tip=(x+.10*math.cos(a+.8),height,z+.08*math.sin(a))
        vox.path([(x,0,z),(x-.06,height*.56,z+.04),tip],[.034,.026,.019],'foliage_shadow')
        if tier<2:
            for j in [1,2]:
                c=(x,height*j*.24,z)
                vox.path([c,(x+math.cos(a+j*2)*.22,c[1]+.12,z+math.sin(a+j*2)*.22)],[.07,.02],'foliage_base')
        for petal in range(5):
            pa=petal*math.tau/5+stem*.2
            c=(tip[0]+math.cos(pa)*.095,tip[1]+.02*(petal%2),tip[2]+math.sin(pa)*.095)
            vox.ellipsoid(c,(.088,.045,.088),'flower_primary')
        vox.ellipsoid((tip[0],tip[1]+.04,tip[2]),(.058,.056,.058),'flower_accent')


def rock(vox,rng,tier,variant):
    # A fractured, offset geological mass with oblique cut planes, not boxes.
    if variant in (1,2):
        if variant==1:
            vox.ellipsoid((-.15,1.7,0),(.7,2.0,.66),'rock_base',.11)
            vox.ellipsoid((.38,.8,.22),(.58,1.1,.68),'rock_dark',.14)
            for key in list(vox.cells):
                x,y,z=[(v+.5)*vox.step for v in key]
                if x+y*.19>.66 or -z+y*.15>.88:
                    del vox.cells[key]
                elif int((y+x*.23)/.42)%4==0:
                    vox.cells[key]=SLOT['rock_light']
        else:
            for c,rad in [((-.5,.6,.1),(1.0,.85,.8)),((.65,.42,-.2),(.85,.55,.7)),((.3,.16,.8),(.4,.28,.4))]:
                vox.ellipsoid(c,rad,'rock_base',.17)
            for key in vox.cells:
                if (key[1]+1)*vox.step>1.1: vox.cells[key]=SLOT['rock_light']
        return
    step=vox.step
    for ix in range(-math.ceil(2.0/step),math.ceil(2.0/step)):
        for iy in range(math.ceil(2.0/step)):
            for iz in range(-math.ceil(1.35/step),math.ceil(1.35/step)):
                x,y,z=(ix+.5)*step,(iy+.5)*step,(iz+.5)*step
                d=((x+(.25-variant*.045)*y)/(1.8+variant*.045))**2+((y-.22)/(1.7+variant*.10))**2+((z-.18*math.sin(y*2+variant*.3))/(1.15-variant*.025))**2
                cuts=x+y*(.72+variant*.035) < 1.95 and -x+y*.28 < 1.88 and z-y*.32 < .98 and x-z*.8 < 1.72-variant*.12
                fissure=abs(x-.45*y+.17*math.sin(z*3))<(.06 if tier==0 else 0) and y>.75
                if d < 1+.065*math.sin(x*5+z*3) and cuts and not fissure:
                    band=math.floor((y+x*.15-z*.1)/.28)%5
                    slot='rock_light' if band==0 else ('rock_dark' if band==4 else 'rock_base')
                    vox.cells[(ix,iy,iz)]=SLOT[slot]
    for j in range(4 if tier<2 else 2):
        a=j*1.9
        vox.ellipsoid((math.cos(a)*1.5,.15,math.sin(a)*.95),(.35,.28,.36),'rock_dark',.24)


def grass(vox,rng,tier,variant):
    for blade in range(40 if tier==0 else (23 if tier==1 else 12)):
        a=blade*2.4; r=math.sqrt(blade/40)*.40
        x,z=math.cos(a)*r,math.sin(a)*r; h=rng.uniform(.24,.64)
        drift=rng.uniform(.07,.19)
        vox.path([(x,0,z),(x,h*.65,z),(x+math.cos(a)*drift,h,z+math.sin(a)*drift)],[.035,.028,.01],'ground_highlight' if blade%4==0 else 'ground_base')


BUILDERS=dict(zip(FAMILIES,[oak,pine,bush,fern,flowers,rock,grass]))


def greedy_faces(vox):
    # Merge coplanar exposed faces only when their semantic slot matches.
    faces=[]
    for axis in range(3):
        u,v=(axis+1)%3,(axis+2)%3
        for direction in [-1,1]:
            planes=defaultdict(dict)
            for p,slot in vox.cells.items():
                n=list(p); n[axis]+=direction
                if tuple(n) not in vox.cells:
                    planes[p[axis]+(1 if direction>0 else 0)][(p[u],p[v])]=slot
            for plane,mask in sorted(planes.items()):
                while mask:
                    a,b=min(mask); slot=mask[(a,b)]; width=1
                    while mask.get((a+width,b))==slot: width+=1
                    height=1
                    while all(mask.get((a+j,b+height))==slot for j in range(width)): height+=1
                    for j in range(width):
                        for k in range(height): del mask[(a+j,b+k)]
                    quad=[]
                    for du,dv in [(0,0),(width,0),(width,height),(0,height)]:
                        p=[0,0,0];p[axis]=plane;p[u]=a+du;p[v]=b+dv
                        quad.append([n*vox.step for n in p])
                    if direction<0: quad.reverse()
                    normal=[0,0,0];normal[axis]=direction
                    faces.append((quad,normal,slot))
    return faces


def write_glb(path,faces,name):
    positions=[];normals=[];uvs=[];indices=[]
    for quad,normal,slot in faces:
        offset=len(positions)//3
        for point in quad:
            positions.extend(point);normals.extend(normal);uvs.extend(((slot+.5)/32,.5))
        indices.extend(offset+i for i in [0,1,2,0,2,3])
    blob=bytearray();views=[];accessors=[]
    def view(data,target=None):
        while len(blob)%4: blob.append(0)
        entry={'buffer':0,'byteOffset':len(blob),'byteLength':len(data)}
        if target: entry['target']=target
        views.append(entry);blob.extend(data);return len(views)-1
    def accessor(values,fmt,kind,components,target):
        bv=view(struct.pack('<'+fmt*len(values),*values),target)
        entry={'bufferView':bv,'componentType':5126 if fmt=='f' else 5125,'count':len(values)//components,'type':kind}
        if kind=='VEC3' and not accessors:
            entry['min']=[min(values[i::3]) for i in range(3)];entry['max']=[max(values[i::3]) for i in range(3)]
        accessors.append(entry);return len(accessors)-1
    pa=accessor(positions,'f','VEC3',3,34962);na=accessor(normals,'f','VEC3',3,34962);ua=accessor(uvs,'f','VEC2',2,34962);ia=accessor(indices,'I','SCALAR',1,34963)
    img=view(png_palette())
    doc={'asset':{'version':'2.0','generator':'Voxelverse original benchmark authoring'},'scene':0,'scenes':[{'nodes':[0]}],
         'nodes':[{'name':name,'mesh':0}], 'meshes':[{'name':name,'primitives':[{'attributes':{'POSITION':pa,'NORMAL':na,'TEXCOORD_0':ua},'indices':ia,'material':0}]}],
         'materials':[{'name':'planet_semantic_slots','pbrMetallicRoughness':{'baseColorTexture':{'index':0},'metallicFactor':0,'roughnessFactor':.92}}],
         'textures':[{'sampler':0,'source':0}],'samplers':[{'magFilter':9728,'minFilter':9728,'wrapS':33071,'wrapT':33071}],
         'images':[{'bufferView':img,'mimeType':'image/png'}], 'buffers':[{'byteLength':len(blob)}],'bufferViews':views,'accessors':accessors,
         'extras':{'palette_encoding':'uv_slot_v1','metres_per_unit':1,'slot_names':SLOTS}}
    encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4);blob+=b'\0'*((-len(blob))%4)
    data=struct.pack('<4sII',b'glTF',2,12+8+len(encoded)+8+len(blob))+struct.pack('<I4s',len(encoded),b'JSON')+encoded+struct.pack('<I4s',len(blob),b'BIN\0')+blob
    path.write_bytes(data)
    return {'triangles':len(indices)//3,'vertices':len(positions)//3,'surfaces':1,'bytes':len(data),'bounds':accessors[0]}


def write_bbmodel(path,vox,name):
    # Greedy cuboids keep the source editable as normal Blockbench cubes.
    remaining=dict(vox.cells);elements=[];groups=defaultdict(list)
    while remaining:
        x,y,z=min(remaining);slot=remaining[(x,y,z)];dx=1
        while remaining.get((x+dx,y,z))==slot: dx+=1
        dz=1
        while all(remaining.get((x+i,y,z+dz))==slot for i in range(dx)): dz+=1
        dy=1
        while all(remaining.get((x+i,y+dy,z+j))==slot for i in range(dx) for j in range(dz)): dy+=1
        for i in range(dx):
            for j in range(dy):
                for k in range(dz): del remaining[(x+i,y+j,z+k)]
        uid=str(uuid.uuid5(uuid.NAMESPACE_URL,f'voxelverse/{name}/{x}/{y}/{z}'))
        scale=vox.step*16
        elements.append({'name':SLOTS[slot], 'type':'cube','uuid':uid, 'from':[x*scale,y*scale,z*scale], 'to':[(x+dx)*scale,(y+dy)*scale,(z+dz)*scale], 'autouv':0,'box_uv':False,
                         'faces':{face:{'uv':[slot+.1,.1,slot+.9,.9],'texture':0} for face in ['north','east','south','west','up','down']}})
        groups[SLOTS[slot]].append(uid)
    groupdata=[];outliner=[]
    for slot,children in sorted(groups.items()):
        uid=str(uuid.uuid5(uuid.NAMESPACE_URL,f'voxelverse/{name}/group/{slot}'))
        groupdata.append({'name':slot,'uuid':uid,'origin':[0,0,0],'rotation':[0,0,0]})
        outliner.append({'uuid':uid,'isOpen':False,'children':children})
    data={'meta':{'format_version':'5.0','model_format':'free','box_uv':False},'name':name,'model_identifier':name,
          'resolution':{'width':32,'height':1},'elements':elements,'groups':groupdata,'outliner':outliner,
          'textures':[{'name':'semantic_preview.png','id':'0','uuid':str(uuid.uuid5(uuid.NAMESPACE_URL,'voxelverse/palette')),'uv_width':32,'uv_height':1,'width':32,'height':1,'mode':'bitmap','source':'data:image/png;base64,'+base64.b64encode(png_palette()).decode()}],
          'voxelverse':{'metres_per_unit':.0625,'voxel_size_metres':vox.step,'palette_slots':SLOTS,'generator':'tools/art/build_benchmark.py'}}
    path.write_text(json.dumps(data,separators=(',',':'))+'\n')
    return len(elements)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--families',nargs='*',default=FAMILIES,choices=FAMILIES)
    parser.add_argument('--variants',type=int,default=3)
    args=parser.parse_args();SOURCE.mkdir(parents=True,exist_ok=True);RUNTIME.mkdir(parents=True,exist_ok=True)
    manifest=json.loads((PACK/'manifest.json').read_text());entries={a['asset_id']:a for a in manifest['assets']};metrics={}
    metrics_path=RUNTIME/'benchmark_metrics.json'
    if metrics_path.exists(): metrics=json.loads(metrics_path.read_text())
    for family in args.families:
        all_lods={};stats=[];sources={}
        small=family in ['fern_cluster_v2','flower_cluster_v2','grass_tuft_v2']
        for variant in range(args.variants):
            lods={}
            for tier,label in enumerate(['near','mid','far']):
                step=([.03125,.0625,.125] if small else ([.0625,.125,.25] if family=='dense_bush_v2' else [.125,.25,.50]))[tier]
                seed=7177+FAMILIES.index(family)*917+variant*7907
                vox=Voxels(step,seed);BUILDERS[family](vox,random.Random(seed),tier,variant)
                faces=greedy_faces(vox)
                suffix='' if variant==0 else f'_species{variant}'
                name=family+suffix+'_'+label
                path=RUNTIME/(name+'.glb'); info=write_glb(path,faces,name)
                if tier==0:
                    source_name=family+suffix
                    source_path=SOURCE/(source_name+'.bbmodel')
                    info['source_cuboids']=write_bbmodel(source_path,vox,source_name)
                    sources[str(variant)]=str(source_path.relative_to(ROOT))
                info.update(lod=label,variant=variant,voxel_size=step,filled_voxels=len(vox.cells));stats.append(info)
                lods[label]='res://'+str(path.relative_to(ROOT))
                print(f'{name}: {info["triangles"]} triangles, {len(vox.cells)} voxels',flush=True)
            all_lods[str(variant)]=lods
        kind='environment_tree' if family in FAMILIES[:2] else ('environment_rock' if family=='layered_rock_v2' else 'environment_plant')
        entries[family]={'asset_id':family,'kind':kind,'family':family.removesuffix('_v2'),'source':str((SOURCE/(family+'.bbmodel')).relative_to(ROOT)),
                         'lod':all_lods['0'],'geometry_variants':all_lods,'variant_sources':sources,'palette_encoding':'uv_slot_v1','palette_slots':SLOTS,
                         'tags':['benchmark','original','semantic_palette','instanced'], 'morphology':{'variants':args.variants,'height_range':[.8,1.3],'width_range':[.85,1.2]},
                         'collision':entries.get(family, {}).get('collision', 'none')}
        metrics[family]=stats
    manifest['assets']=[entries[k] for k in sorted(entries)]
    (PACK/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (RUNTIME/'benchmark_metrics.json').write_text(json.dumps(metrics,indent=2)+'\n')


if __name__=='__main__': main()
