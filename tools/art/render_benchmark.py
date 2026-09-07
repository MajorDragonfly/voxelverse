#!/usr/bin/env python3
"""Render exact exported GLB geometry with a small CPU z-buffer for art review.

This is geometry/LOD/palette QA, not a screenshot of Godot lighting or gameplay.
Requires numpy and Pillow. No external models, textures or generated imagery.
"""
import argparse
import json
import math
from pathlib import Path
import struct
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0,str(Path(__file__).parent))
from build_benchmark import ROOT, RUNTIME, FAMILIES, COLORS


def read_glb(path):
    data=path.read_bytes(); n=struct.unpack_from('<I',data,12)[0]; doc=json.loads(data[20:20+n]); binary=data[28+n:]
    def arr(index):
        a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']];count={'SCALAR':1,'VEC2':2,'VEC3':3}[a['type']]
        return np.frombuffer(binary,dtype='<f4' if a['componentType']==5126 else '<u4',count=a['count']*count,offset=v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,count)
    primitive=doc['meshes'][0]['primitives'][0]; attrs=primitive['attributes']
    return arr(attrs['POSITION']),arr(attrs['NORMAL']),arr(attrs['TEXCOORD_0']),arr(primitive['indices']).reshape(-1,3)


def render(path,size=(650,650),palette=None,azimuth=35):
    vertices,normals,uv,indices=read_glb(path)
    rgb=np.array([tuple(bytes.fromhex(c)) for c in COLORS]+[(255,0,255)]*(32-len(COLORS)),float)
    if palette:
        for slot,c in palette.items(): rgb[int(slot)]=np.array(c[:3])*255
    width,height=size
    yaw=math.radians(azimuth); elevation=.36
    forward=np.array([math.sin(yaw)*math.cos(elevation),math.sin(elevation),math.cos(yaw)*math.cos(elevation)])
    right=np.cross([0,1,0],forward);right/=np.linalg.norm(right);up=np.cross(forward,right)
    projected=np.column_stack([vertices@right,vertices@up,vertices@forward])
    low=projected[:,:2].min(axis=0);high=projected[:,:2].max(axis=0)
    scale=min((width-80)/(high[0]-low[0]),(height-85)/(high[1]-low[1]))
    projected[:,0]=(projected[:,0]-(low[0]+high[0])/2)*scale+width/2
    projected[:,1]=height-50-(projected[:,1]-low[1])*scale
    pixels=np.full((height,width,3),(233,235,228),dtype=np.uint8);depth=np.full((height,width),-np.inf)
    light=np.array([-.55,.82,.5]);light/=np.linalg.norm(light)
    for triangle in indices:
        if normals[triangle[0]]@forward <=0: continue
        p=projected[triangle]; lo=np.maximum(np.floor(p[:,:2].min(axis=0)).astype(int),[0,0]);hi=np.minimum(np.ceil(p[:,:2].max(axis=0)).astype(int),[width-1,height-1])
        if np.any(hi<lo):continue
        xa,ya=p[0,:2];xb,yb=p[1,:2];xc,yc=p[2,:2];den=(yb-yc)*(xa-xc)+(xc-xb)*(ya-yc)
        if abs(den)<1e-7:continue
        xx,yy=np.meshgrid(np.arange(lo[0],hi[0]+1)+.5,np.arange(lo[1],hi[1]+1)+.5)
        w0=((yb-yc)*(xx-xc)+(xc-xb)*(yy-yc))/den;w1=((yc-ya)*(xx-xc)+(xa-xc)*(yy-yc))/den;w2=1-w0-w1
        zz=w0*p[0,2]+w1*p[1,2]+w2*p[2,2]
        target=depth[lo[1]:hi[1]+1,lo[0]:hi[0]+1];mask=(w0>=-1e-5)&(w1>=-1e-5)&(w2>=-1e-5)&(zz>target)
        slot=min(31,int(uv[triangle[0],0]*32));shade=.58+.42*max(0,float(normals[triangle[0]]@light))
        pixels[lo[1]:hi[1]+1,lo[0]:hi[0]+1][mask]=np.clip(rgb[slot]*shade,0,255).astype(np.uint8);target[mask]=zz[mask]
    return Image.fromarray(pixels)


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,default=ROOT/'art/review/benchmark_v2');args=parser.parse_args();args.output.mkdir(parents=True,exist_ok=True)
    fontpath='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';font=ImageFont.truetype(fontpath,20)
    small=ImageFont.truetype(fontpath,15)
    sheet=Image.new('RGB',(650*3,700*len(FAMILIES)),(233,235,228));draw=ImageDraw.Draw(sheet)
    for row,family in enumerate(FAMILIES):
        for col,lod in enumerate(['near','mid','far']):
            picture=render(RUNTIME/(family+'_'+lod+'.glb'))
            picture.save(args.output/(family+'_'+lod+'.png'))
            sheet.paste(picture,(col*650,row*700+42))
            draw.text((col*650+24,row*700+12),family+' / '+lod.upper(),fill=(35,45,39),font=font)
            print(f'Rendered {family} {lod}',flush=True)
    sheet.save(args.output/'lod_comparison.png')
    natural=Image.new('RGB',(1950,1500),(233,235,228));d=ImageDraw.Draw(natural)
    for i,family in enumerate(FAMILIES[:6]):
        pic=Image.open(args.output/(family+'_near.png'))
        natural.paste(pic,((i%3)*650,(i//3)*730+50));d.text(((i%3)*650+22,(i//3)*730+15),family,fill=(35,45,39),font=font)
    d.text((24,1470),'Exact GLB geometry / CPU preview / lighting and shadows require an in-game review',fill=(65,74,68),font=small)
    natural.save(args.output/'benchmark_lineup.png')


if __name__=='__main__':main()
