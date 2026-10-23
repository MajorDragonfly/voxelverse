from pathlib import Path
import json, hashlib
root=Path(__file__).resolve().parents[1]
directories=[root/'evidence/accepted-native-gl',root/'evidence/accepted-native-forward']
reports=[json.loads((p/'atmosphere-comparison.json').read_text()) for p in directories]
runs=[json.loads((p/'results.json').read_text()) for p in directories]
recipes=[json.loads((p/'recipe.json').read_text()) for p in directories]
assert all(j['passed'] and j['provenance']['status']=='stable' and j['source']['complete'] and not j['source']['tracked_worktree_dirty'] for j in runs)
assert runs[0]['source']['tree']==runs[1]['source']['tree']=='062f512579ac40e852ed617006edde879f5fea35'
assert runs[0]['source']['source_sha256']==runs[1]['source']['source_sha256']
assert runs[0]['external_inputs']==runs[1]['external_inputs']
for field in ['initial_save_text','initial_save','region_blobs','views','baseline_code','baseline_sha256','baseline_commit']:
 assert recipes[0][field]==recipes[1][field],field
assert reports[0]['body']==reports[1]['body']
comparisons=[]
for a,b in zip(reports[0]['captures'],reports[1]['captures']):
 assert a['id']==b['id']
 fields=['clock','camera','camera_address','fov','size','palette','material_slots','debug_draw','tonemap','haze','foliage_pigment_strength']
 mismatch=[key for key in fields if a[key]!=b[key]]
 for field in ['sun_direction','sun_color','sample','ambient','ambient_color','exposure','white','fog','preset','graphics']:
  if a['lighting'][field]!=b['lighting'][field]:mismatch.append('lighting/'+field)
 assert not mismatch,(a['id'],mismatch)
 comparisons.append({'id':a['id'],'all_canonical_fields_exact':True,'gl_counts':[a['draw_calls'],a['primitives']],'forward_counts':[b['draw_calls'],b['primitives']]})
for directory,report,run in zip(directories,reports,runs):
 for name,digest in run['images'].items():assert hashlib.sha256((directory/name).read_bytes()).hexdigest()==digest
 assert len(run['images'])==16
 for pair in report['pairs']:
  selected=[next(c for c in report['captures'] if c['id']==name) for name in pair['captures']]
  if pair['id'].endswith('-night'):
   assert selected[0]['lighting']==selected[1]['lighting']==selected[2]['lighting']
   assert selected[0]['haze']==selected[1]['haze']==selected[2]['haze']
manifests=[(d/name).read_bytes() for d in directories for name in ['source-files-start.jsonl','source-files-end.jsonl']]
assert all(m==manifests[0] for m in manifests)
result={'passed':True,'canonical_inputs_exact':True,'original_replay_bytes_regions_views_exact':True,'complete_body_exact':True,'all_four_source_manifests_byte_equal':True,'source':runs[0]['source'],'external_inputs':runs[0]['external_inputs'],'captures':comparisons,'renderers':[{'renderer':j['renderer'],'seconds':j['seconds'],'pixels':j['pixels']} for j in runs],'note':'Counts/timings are renderer observations, not cross-renderer equality requirements or hardware FPS. Full-body, actual cameras/clock/weather/palette/haze/material strength are compared without tolerances. Report save wrappers have independent saved_unix_time; input save bytes/regions are exact.'}
(root/'work/accepted-cross-renderer.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'passed':True,'captures':len(comparisons),'images':32,'source':runs[0]['source']['source_sha256']}))
