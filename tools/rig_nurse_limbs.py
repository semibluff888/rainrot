"""Give each of the six original lower appendages its own two-joint chain.

The author's upper-body rig and all geometry/UVs are retained. Lower weights
blend into the six chains under the skirt. Re-run prepare_enemy_models first.
"""
import json
from pathlib import Path
import numpy as np

dest = Path(__file__).resolve().parents[1] / 'assets/models/enemies/nurse'
d = json.loads((dest/'model.gltf').read_text('utf-8'))
b = bytearray((dest/'model.bin').read_bytes())

def read(i):
    a=d['accessors'][i]; v=d['bufferViews'][a['bufferView']]
    dt={5126:'<f4',5123:'<u2',5125:'<u4',5121:'u1'}[a['componentType']]
    n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
    return np.ndarray((a['count'],n),dtype=dt,buffer=b,offset=v.get('byteOffset',0)+a.get('byteOffset',0),
                      strides=(v.get('byteStride',n*np.dtype(dt).itemsize),np.dtype(dt).itemsize)).copy()

def append(arr,typ,component):
    while len(b)%4:b.append(0)
    view=len(d['bufferViews']); raw=arr.tobytes()
    d['bufferViews'].append({'buffer':0,'byteOffset':len(b),'byteLength':len(raw)})
    b.extend(raw)
    idx=len(d['accessors'])
    d['accessors'].append({'bufferView':view,'componentType':component,'count':len(arr),'type':typ})
    return idx

if any('Tendril' in n.get('name','') for n in d['nodes']):
    raise SystemExit('Already adapted. Run prepare_enemy_models.py to reset first.')
skin=d['skins'][0]; binds=read(skin['inverseBindMatrices']); first=len(skin['joints'])
centers=np.array([[-1.30,-1.00],[.30,-1.40],[1.45,-.75],[-1.10,1.55],[-.27,1.30],[1.38,1.72]])
for i,(x,z) in enumerate(centers):
    base=np.array([x*.34,1.15,z*.25]); knee=np.array([x*.78,-.35,z*.73])
    parent=len(d['nodes']); child=parent+1
    d['nodes'].append({'name':f'Tendril_{i}_base','translation':base.tolist(),'children':[child]})
    d['nodes'].append({'name':f'Tendril_{i}_tip','translation':(knee-base).tolist()})
    d['nodes'][skin['skeleton']].setdefault('children',[]).append(parent)
    skin['joints'] += [parent,child]
    for pivot in [base,knee]:
        inv=np.eye(4,dtype='<f4');inv[:3,3]=-pivot
        binds=np.vstack([binds,inv.T.reshape(1,16)])
p=d['meshes'][2]['primitives'][0]['attributes']
v=read(p['POSITION']);j=read(p['JOINTS_0']);w=read(p['WEIGHTS_0'])
for i in np.where(v[:,1]<1.35)[0]:
    blend=np.clip((1.35-v[i,1])/.85,0,1)
    # Branches are well separated below the skirt. Project toward their tips.
    q=v[i,[0,2]]
    directions=centers/np.linalg.norm(centers,axis=1)[:,None]
    branch=int(np.argmax(directions@(q-np.array([.1,0]))))
    bend=np.clip((-.12-v[i,1])/.75,0,1)
    weights={int(k):float(t)*(1-blend) for k,t in zip(j[i],w[i]) if t>0}
    weights[first+branch*2]=blend*(1-bend)
    weights[first+branch*2+1]=blend*bend
    top=sorted(weights.items(),key=lambda p:p[1],reverse=True)[:4]
    j[i]=0;w[i]=0
    total=sum(t for k,t in top)
    for n,(k,t) in enumerate(top):j[i,n]=k;w[i,n]=t/total
p['JOINTS_0']=append(j.astype('<u2'),'VEC4',5123)
p['WEIGHTS_0']=append(w.astype('<f4'),'VEC4',5126)
skin['inverseBindMatrices']=append(binds.astype('<f4'),'MAT4',5126)
d['buffers'][0]['byteLength']=len(b)
(dest/'model.bin').write_bytes(b)
(dest/'model.gltf').write_text(json.dumps(d,indent=2),encoding='utf-8')
print('Nurse: six original appendages rigged with twelve added joints;',len(v),'body vertices.')
