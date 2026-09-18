import bpy, json
from mathutils import Vector
from collections import defaultdict
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath='/Users/doji/Documents/eva-recreate/TripoModels/mecha_3d_model/mecha_3d_model.fbx')
report=[]
for obj in list(bpy.context.scene.objects):
 if obj.type!='MESH': continue
 mesh=obj.data
 parent=list(range(len(mesh.vertices)))
 def find(x):
  while parent[x]!=x:
   parent[x]=parent[parent[x]]; x=parent[x]
  return x
 def union(a,b):
  a,b=find(a),find(b)
  if a!=b: parent[b]=a
 # UV seam vertices at the same location count as connected.
 positions={}
 for v in mesh.vertices:
  k=tuple(round(x,5) for x in v.co)
  if k in positions: union(v.index,positions[k])
  else: positions[k]=v.index
 for e in mesh.edges: union(*e.vertices)
 groups=defaultdict(list)
 for p in mesh.polygons: groups[find(p.vertices[0])].append(p.index)
 parts=[]
 for indices in groups.values():
  vs=set(v for i in indices for v in mesh.polygons[i].vertices)
  coords=[obj.matrix_world @ mesh.vertices[v].co for v in vs]
  lo=[min(v[i] for v in coords) for i in range(3)]
  hi=[max(v[i] for v in coords) for i in range(3)]
  parts.append(dict(faces=len(indices),vertices=len(vs),min=lo,max=hi,polygons=indices))
 parts.sort(key=lambda x:-x['faces'])
 report.append(dict(name=obj.name,faces=len(mesh.polygons),vertices=len(mesh.vertices),uv_layers=len(mesh.uv_layers),materials=[m.name for m in mesh.materials],components=parts))
with open('/Users/doji/Documents/eva-recreate/tools/asset_analysis/components.json','w') as f:json.dump(report,f,indent=2)
for obj in report:
 print('OBJECT',obj['name'],'faces',obj['faces'],'UV',obj['uv_layers'],'components',len(obj['components']))
 for i,c in enumerate(obj['components'][:45]): print(i,c['faces'],'min',[round(x,3) for x in c['min']],'max',[round(x,3) for x in c['max']])
import bmesh, os
out='/Users/doji/Documents/eva-recreate/TripoModels/hangar_separated'
os.makedirs(out,exist_ok=True)
texture='/Users/doji/Documents/eva-recreate/TripoModels/mecha_3d_model/mecha+3d+model.fbm/mecha+3d+model_basecolor.jpg'
for image in bpy.data.images:
 if image.source=='FILE':
  image.filepath=texture
  image.reload()
for item in report:
 original=bpy.data.objects[item['name']]
 for idx,part in enumerate(item['components']):
  data=original.data.copy()
  bm=bmesh.new();bm.from_mesh(data);bm.faces.ensure_lookup_table()
  keep=set(part['polygons'])
  bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.index not in keep],context='FACES')
  bm.to_mesh(data);bm.free()
  obj=bpy.data.objects.new('Part_%03d_%dfaces'%(idx,part['faces']),data)
  bpy.context.collection.objects.link(obj)
  obj.matrix_world=original.matrix_world.copy()
 bpy.data.objects.remove(original,do_unlink=True)
bpy.ops.export_scene.gltf(filepath=out+'/hangar_loose_parts.glb',export_format='GLB',export_yup=True)
bpy.ops.wm.save_as_mainfile(filepath=out+'/source/hangar_loose_parts.blend')
