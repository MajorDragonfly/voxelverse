from pathlib import Path
import json,zipfile,hashlib,sys
from PIL import Image
import io
root=Path(__file__).resolve().parents[1];repo=root.parent/'gfx-ref-03/voxelverse';sys.path.insert(0,str(repo/'tools'))
from validate_godot import ERROR
records=json.loads((root/'work/ci-downloaded-index.json').read_text());verified=[]
for a in records:
 if not a['name'].startswith(('environment-review-','spherical-campaign-review-','planet-lab-review-','resource-review-')):continue
 data=Path(a['local_path']).read_bytes();assert len(data)==a['size_in_bytes'] and hashlib.sha256(data).hexdigest()==a['digest'].removeprefix('sha256:')
 reports=[];images=[];logs=[]
 with zipfile.ZipFile(a['local_path']) as z:
  assert z.testzip() is None
  for n in z.namelist():
   if n.endswith('.json'):
    j=json.loads(z.read(n))
    if isinstance(j,dict) and isinstance(j.get('passed'),bool):
     assert j['passed'],(a['name'],n,j.get('failures'))
     reports.append({'path':n,'passed':True,'failures':j.get('failures')})
   elif n.endswith('.log'):
    raw=z.read(n);assert not ERROR.search(raw.decode(errors='replace')),(a['name'],n)
    logs.append({'path':n,'sha256':hashlib.sha256(raw).hexdigest()})
   elif n.endswith('.png'):
    raw=z.read(n)
    with Image.open(io.BytesIO(raw)) as im:size=im.size;im.verify()
    images.append({'path':n,'size':size,'sha256':hashlib.sha256(raw).hexdigest()})
 assert images and logs,(a['name'],len(images),len(logs))
 verified.append({'artifact_id':a['id'],'name':a['name'],'reports':reports,'images':images,'logs':logs})
assert len(verified)==8,len(verified)
result={'passed':True,'artifacts':8,'images':sum(len(a['images']) for a in verified),'logs':sum(len(a['logs']) for a in verified),'source_tree':'062f512579ac40e852ed617006edde879f5fea35','verified':verified,'note':'All original artifact digests/ZIP CRCs, boolean reports, strict error/leak-free raw logs and image decodes checked; source tree bound by current official runs/import reports. Non-JSON render cases retain original images/logs and successful job status. No target-PC/FPS claim.'}
(root/'work/environment-verification.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='verified'}))
