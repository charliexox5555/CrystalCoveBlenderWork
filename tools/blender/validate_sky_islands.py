"""Validate saved source and FBX round trips. Run with Blender --factory-startup.

blender --background --factory-startup --python tools/blender/validate_sky_islands.py
"""
import bpy
import json
import os
import runpy
from pathlib import Path
from mathutils import Vector
from mathutils.kdtree import KDTree

ROOT = Path(os.environ.get('GLASSCLASH_REPO', 'C:/Users/charl/Documents/CrystalCoveBlenderWork'))
OUT = ROOT / 'assets/blender/map/sky'
builder = runpy.run_path(str(ROOT / 'tools/blender/build_sky_islands.py'), run_name='sky_validation')


def validate():
    with bpy.data.libraries.load(str(OUT / 'sky_islands.blend'), link=False) as (source, target):
        target.scenes = source.scenes
    manifest = json.loads((OUT / 'manifest.json').read_text(encoding='utf-8'))
    results = []
    for entry in manifest['islands']:
        expected = {m['name']: bpy.data.objects[m['name']] for m in entry['meshes']}
        source_report = [builder['inspect'](ob) for ob in expected.values()]
        scene = bpy.data.scenes.new(entry['name'] + '_Roundtrip')
        bpy.context.window.scene = scene
        before = set(bpy.data.objects)
        bpy.ops.import_scene.fbx(filepath=str(OUT / entry['fbx']))
        bpy.context.view_layer.update()
        imported = list(set(bpy.data.objects) - before)
        assert len(imported) == 3 and all(ob.type == 'MESH' for ob in imported)
        checks = []
        for ob in imported:
            name = ob.name.rsplit('.', 1)[0] if ob.name.rsplit('.', 1)[-1].isdigit() else ob.name
            original = expected[name]
            a = [v.co.copy() for v in original.data.vertices]
            b = [ob.matrix_world @ v.co for v in ob.data.vertices]
            bounds_error = max(abs(f(p[i] for p in a) - f(p[i] for p in b)) for i in range(3) for f in (min, max))
            # Symmetric nearest-vertex error permits FBX vertex splitting at seams.
            def deviation(first, second):
                kd = KDTree(len(second))
                for i, point in enumerate(second):
                    kd.insert(point, i)
                kd.balance()
                return max(kd.find(point)[2] for point in first)
            vertex_error = max(deviation(a, b), deviation(b, a))
            triangle_count = sum(len(p.vertices) - 2 for p in ob.data.polygons)
            pivot_error = ob.matrix_world.translation.length
            assert bounds_error < .0001 and vertex_error < .0001 and pivot_error < .0001
            assert triangle_count == len(original.data.polygons)
            checks.append({'name': name, 'triangle_count': triangle_count,
                           'max_bounds_error_studs': bounds_error,
                           'max_vertex_error_studs': vertex_error,
                           'pivot_error_studs': pivot_error})
        grass = expected[entry['name'] + '_Grass']
        top = [p for p in grass.data.polygons if p.normal.z > .99]
        assert len(top) == builder['N']
        assert all(grass.data.vertices[i].co.z == 0 for p in top for i in p.vertices)
        assert all(not p.use_smooth for ob in expected.values() for p in ob.data.polygons)
        results.append({'island': entry['name'], 'source': source_report,
                        'grass_top_exactly_zero': True, 'fbx_roundtrip': sorted(checks, key=lambda x: x['name'])})
    report = {'status': 'passed', 'blender_version': bpy.app.version_string,
              'mesh_count': 15, 'triangles_total': sum(m['triangle_count'] for e in results for m in e['source']),
              'max_triangles_per_mesh': max(m['triangle_count'] for e in results for m in e['source']),
              'max_roundtrip_vertex_error_studs': max(m['max_vertex_error_studs'] for e in results for m in e['fbx_roundtrip']),
              'studio_import_tested': False, 'islands': results}
    (OUT / 'validation.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    return {k: v for k, v in report.items() if k != 'islands'}


if __name__ == '__main__':
    print(json.dumps(validate(), indent=2))
