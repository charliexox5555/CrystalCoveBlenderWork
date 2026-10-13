"""Crystal Isles / Part A. Run in Blender; preserves existing scenes.

Load with exec(compile(open(path).read(), path, 'exec')); then build_sky_islands().
Each asset scene contains three meshes at identity transforms. The preview scene
instances these collections at the concept positions; its camera/lights never export.
"""

import bpy
import bmesh
import json
import math
import os
import random
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree


ROOT = Path(os.environ.get('GLASSCLASH_REPO', 'C:/Users/charl/Documents/CrystalCoveBlenderWork'))
OUT = ROOT / 'assets/blender/map/sky'
N = 40
SPECS = [
    ('Isle_Lobby', 96, 56, 4.0, 11, 33, (0, 0, 0), 3),
    ('Isle_Arena1', 92, 46, 4.0, 23, 30, (0, 56, 2), 2),
    ('Isle_Arena2', 92, 46, 4.0, 47, 34, (0, 107, 4), 4),
    ('Isle_Arena3', 92, 46, 4.0, 71, 31, (0, 158, 6), 3),
    ('Isle_Featured', 72, 48, 3.0, 97, 32, (0, 210, 9), 3),
]
PALETTE = {'Grass': '#7CCB5B', 'GrassSide': '#5DA845', 'Dirt': '#9A6B43', 'Rock': '#9787A0'}


def material(label, hex_color):
    rgb = [int(hex_color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    rgba = tuple(c / 12.92 if c <= 0.04045 else ((c + .055) / 1.055) ** 2.4 for c in rgb) + (1,)
    mat = bpy.data.materials.new('SkyPreview_' + label)
    mat.use_nodes = True
    mat.diffuse_color = rgba
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = rgba
    shader.inputs['Roughness'].default_value = 1
    shader.inputs['Specular IOR Level'].default_value = .15
    return mat


def outline(width, length, exponent, seed):
    """Equal-distance samples avoid long edges at superellipse axis crossings."""
    rng = random.Random(seed)
    phase = rng.uniform(0, math.tau)
    dense = []
    for i in range(2000):
        t = math.tau * i / 2000
        c, s = math.cos(t), math.sin(t)
        k = 1 + .024 * math.sin(5 * t + phase) + .012 * math.sin(9 * t - phase)
        dense.append(Vector((width / 2 * math.copysign(abs(c) ** (2 / exponent), c) * k,
                             length / 2 * math.copysign(abs(s) ** (2 / exponent), s) * k, 0)))
    distances = [0.0]
    for i in range(len(dense)):
        distances.append(distances[-1] + (dense[(i + 1) % len(dense)] - dense[i]).length)
    pts, j = [], 0
    for i in range(N):
        target = distances[-1] * i / N
        while distances[j + 1] < target:
            j += 1
        p = dense[j].lerp(dense[(j + 1) % len(dense)], (target - distances[j]) / (distances[j + 1] - distances[j]))
        pts.append(p)
    # Exact requested overall dimensions; bounding-box centre is the origin.
    for axis, size in ((0, width), (1, length)):
        low, high = min(p[axis] for p in pts), max(p[axis] for p in pts)
        for p in pts:
            p[axis] = (p[axis] - (low + high) / 2) * size / (high - low)
    return pts


def make_mesh(name, vertices, faces, collection, materials, indices=None):
    mesh = bpy.data.meshes.new(name + '_Geometry')
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    for mat in materials:
        mesh.materials.append(mat)
    if indices:
        for p, index in zip(mesh.polygons, indices):
            p.material_index = index
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.triangulate(bm, faces=list(bm.faces), quad_method='BEAUTY', ngon_method='BEAUTY')
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    for p in mesh.polygons:
        p.use_smooth = False
    ob = bpy.data.objects.new(name, mesh)
    collection.objects.link(ob)
    ob['origin_contract'] = 'Grass surface centre: local (0, 0, 0)'
    ob['studio_color'] = PALETTE[name.rsplit('_', 1)[-1]]
    ob['studio_material'] = 'SmoothPlastic'
    return ob


def slab(name, top, bottom, collection, materials):
    verts = [tuple(p) for p in top + bottom]
    # Explicit triangle fans are planar, hole-free and preserve the full usable top.
    verts.extend([tuple(sum(top, Vector()) / N), tuple(sum(bottom, Vector()) / N)])
    faces, indices = [], []
    for i in range(N):
        j = (i + 1) % N
        faces.extend([(2 * N, i, j), (2 * N + 1, N + j, N + i), (i, N + i, N + j, j)])
        indices.extend([0, len(materials) - 1, len(materials) - 1])
    return make_mesh(name, verts, faces, collection, materials, indices)


def rock(name, top, depth, seed, chunks, collection, mat):
    rng = random.Random(seed + 101)
    rings = [top]
    # Paired rings form broad bevelled ledges, separated by tall angular faces.
    shoulder = rng.uniform(.91, .97)
    waist = rng.uniform(.58, .72)
    levels = [(shoulder, -.24 * depth), (.80, -.30 * depth),
              (waist, -.56 * depth), (waist - .12, -.61 * depth), (.23, -.85 * depth)]
    drift = Vector((rng.uniform(-5, 5), rng.uniform(-3, 3), 0))
    for level, (scale, z) in enumerate(levels):
        ring = []
        for i, p in enumerate(top):
            t = math.tau * i / N
            k = scale * (1 + .045 * math.sin(3 * t + seed + level * .7) + rng.uniform(-.025, .025))
            q = Vector((p.x * k, p.y * k, z + rng.uniform(-.65, .65))) + drift * ((level + 1) / 5)
            ring.append(q)
        rings.append(ring)
    verts = [tuple(p) for ring in rings for p in ring]
    top_center = len(verts)
    verts.append(tuple(sum(top, Vector()) / N))
    faces = [(top_center, (i + 1) % N, i) for i in range(N)]
    branch_indices = {(int(N * i / chunks) + seed % 8 + 3) % N for i in range(chunks)}
    for layer in range(len(rings) - 1):
        for i in range(N):
            j = (i + 1) % N
            if layer == 0 and (i - 1) % N in branch_indices:
                continue
            face = (layer * N + i, (layer + 1) * N + i, (layer + 1) * N + j, layer * N + j)
            if layer != 0 or i not in branch_indices:
                faces.append(face)
                continue
            # Branch a hanging chunk from an open shoulder face. No buried solids,
            # overlapping caps, Boolean debris or disconnected pieces in the rock.
            j2 = (i + 2) % N
            face = (i, N + i, N + j, N + j2, j2, j)
            centre = sum((Vector(verts[k]) for k in face), Vector()) / 6
            out = Vector((centre.x, centre.y, 0)).normalized()
            normal = (Vector(verts[face[1]]) - Vector(verts[face[0]])).cross(Vector(verts[face[2]]) - Vector(verts[face[0]])).normalized()
            direction = (out * .6 + Vector((0, 0, -.8))).normalized()
            rotation = normal.rotation_difference(direction)
            middle = centre + out * 4 + Vector((0, 0, -4))
            start = len(verts)
            for k in face:
                delta = Vector(verts[k]) - centre
                delta -= normal * delta.dot(normal)
                verts.append(tuple(middle + (rotation @ delta) * .78))
            tip = len(verts)
            verts.append(tuple(middle + direction * rng.uniform(6, 9)))
            for k in range(6):
                nxt = (k + 1) % 6
                faces.extend([(face[k], start + k, start + nxt, face[nxt]),
                              (start + k, tip, start + nxt)])
    tip = len(verts)
    verts.append((drift.x + rng.uniform(-3, 3), drift.y + rng.uniform(-2, 2), -depth))
    last = (len(rings) - 1) * N
    faces.extend([(last + i, tip, last + (i + 1) % N) for i in range(N)])
    ob = make_mesh(name, verts, faces, collection, [mat])
    ob['hanging_chunks'] = chunks
    return ob


def inspect(ob):
    mesh = ob.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.normal_update()
    nonmanifold = sum(not e.is_manifold for e in bm.edges)
    inconsistent = sum(not e.is_contiguous for e in bm.edges)
    volume = bm.calc_volume(signed=True)
    bm.free()
    verts = [v.co.copy() for v in mesh.vertices]
    faces = [tuple(p.vertices) for p in mesh.polygons]
    tree = BVHTree.FromPolygons(verts, faces, all_triangles=True, epsilon=0.000001)
    intersections = [(a, b) for a, b in tree.overlap(tree) if a < b and not set(faces[a]).intersection(faces[b])]
    assert nonmanifold == 0 and inconsistent == 0 and volume > 0, (ob.name, nonmanifold, inconsistent, volume)
    assert not intersections, (ob.name, 'self intersections', intersections[:8])
    assert len(faces) <= 5000 and all(len(f) == 3 for f in faces)
    assert all(p.area > .000001 for p in mesh.polygons), ob.name
    assert tuple(ob.location) == (0, 0, 0) and tuple(ob.scale) == (1, 1, 1)
    bounds = {'min': [round(min(v[i] for v in verts), 6) for i in range(3)],
              'max': [round(max(v[i] for v in verts), 6) for i in range(3)]}
    return {'name': ob.name, 'triangle_count': len(faces), 'local_bounds_blender_xyz_studs': bounds,
            'origin_blender_xyz': [0, 0, 0], 'preview_color': ob['studio_color'],
            'closed_manifold': True, 'self_intersections': 0, 'volume_studs3': round(volume, 4)}


def point_at(ob, target):
    ob.rotation_euler = (Vector(target) - ob.location).to_track_quat('-Z', 'Y').to_euler()


def build_sky_islands():
    OUT.mkdir(parents=True, exist_ok=True)
    helper = {'GLASSCLASH_REPO': str(ROOT), '__name__': 'sky_export_helper'}
    exec(compile((ROOT / 'tools/blender/glassclash_blender.py').read_text(encoding='utf-8'), 'glassclash_blender.py', 'exec'), helper)
    mats = {key: material(key, value) for key, value in PALETTE.items()}
    assets, scenes, entries = [], [], []
    for name, width, length, exponent, seed, depth, pos, chunks in SPECS:
        assert bpy.data.objects.get(name + '_Grass') is None, 'Asset exists: use a fresh Blender process to rebuild.'
        scene = bpy.data.scenes.new(name + '_Asset')
        scene.unit_settings.system = 'NONE'
        scene.unit_settings.scale_length = 1
        bpy.context.window.scene = scene
        coll = bpy.data.collections.new(name)
        scene.collection.children.link(coll)
        rim = outline(width, length, exponent, seed)
        bottom = [Vector((p.x, p.y, -1.4)) for p in rim]
        dirt_top = [Vector((p.x * (1 - 1 / width), p.y * (1 - 1 / length), -1.4)) for p in rim]
        dirt_bottom = [Vector((p.x * .98, p.y * .98, -3.9)) for p in dirt_top]
        grass = slab(name + '_Grass', rim, bottom, coll, [mats['Grass'], mats['GrassSide']])
        dirt = slab(name + '_Dirt', dirt_top, dirt_bottom, coll, [mats['Dirt']])
        stone = rock(name + '_Rock', dirt_bottom, depth, seed, chunks, coll, mats['Rock'])
        objects = [grass, dirt, stone]
        measurements = [inspect(o) for o in objects]
        assert all(v.co.z <= 0 for v in grass.data.vertices)
        top_faces = [p for p in grass.data.polygons if p.normal.z > .99]
        assert len(top_faces) == N and all(grass.data.vertices[i].co.z == 0 for p in top_faces for i in p.vertices)
        helper['export_fbx'](objects, str(OUT / (name + '.fbx')))
        scenes.append(scene)
        assets.append((coll, pos))
        entries.append({'name': name, 'fbx': name + '.fbx', 'top_size_xy_studs': [width, length],
                        'superellipse_exponent': exponent, 'depth_studs': depth, 'hanging_chunks': chunks,
                        'intended_world_position_blender_xyz': list(pos),
                        'intended_world_position_roblox_xyz': [pos[0], pos[2], -pos[1]], 'meshes': measurements})
    preview = bpy.data.scenes.new('Sky_Islands_Preview')
    bpy.context.window.scene = preview
    for coll, pos in assets:
        instance = bpy.data.objects.new(coll.name + '_Layout', None)
        instance.instance_type = 'COLLECTION'
        instance.instance_collection = coll
        instance.location = pos
        preview.collection.objects.link(instance)
    camera_data = bpy.data.cameras.new('Sky_Preview_Camera')
    camera = bpy.data.objects.new('Sky_Preview_Camera', camera_data)
    preview.collection.objects.link(camera)
    camera.location = (440, -125, 180)
    point_at(camera, (0, 100, -8))
    camera_data.type = 'ORTHO'
    camera_data.ortho_scale = 295
    preview.camera = camera
    world = bpy.data.worlds.new('Sky_Preview_Background')
    world.use_nodes = True
    world.node_tree.nodes.get('Background').inputs[0].default_value = (.40, .57, .77, 1)
    world.node_tree.nodes.get('Background').inputs[1].default_value = .65
    preview.world = world
    for label, location, power, size in [('Key', (50, -160, 240), 450000, 170),
                                         ('Fill', (-150, 70, 70), 260000, 180),
                                         ('RockFill', (180, 50, 25), 180000, 110)]:
        data = bpy.data.lights.new('Sky_' + label, 'AREA')
        data.energy, data.shape, data.size = power, 'DISK', size
        light = bpy.data.objects.new(data.name, data)
        preview.collection.objects.link(light)
        light.location = location
        point_at(light, (0, 100, -10))
    preview.render.engine = 'CYCLES'
    preview.cycles.samples = 32
    preview.cycles.use_denoising = True
    preview.render.resolution_x, preview.render.resolution_y = 1800, 1050
    preview.render.resolution_percentage = 100
    preview.render.image_settings.file_format = 'JPEG'
    preview.render.image_settings.quality = 94
    preview.render.filepath = str(OUT / 'preview.jpg')
    preview.view_settings.view_transform = 'Standard'
    preview.view_settings.look = 'None'
    preview.view_settings.exposure = 0
    preview.view_settings.gamma = 1
    bpy.context.view_layer.update()
    bpy.data.libraries.write(str(OUT / 'sky_islands.blend'), set(scenes + [preview]), fake_user=True, compress=True)
    manifest = {'schema_version': 1, 'units': '1 Blender unit = 1 stud; choose Studs in Studio importer',
                'coordinate_mapping': 'Blender (x,y,z) -> Roblox (x,z,-y)',
                'origin_contract': 'All exported meshes have identity transforms and origin at grass top centre.',
                'export_helper': 'tools/blender/glassclash_blender.py:export_fbx',
                'fbx_axes': {'forward': '-Z', 'up': 'Y', 'bake_space_transform': True, 'apply_unit_scale': True},
                'islands': entries}
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    return {'output': str(OUT), 'meshes': 15, 'triangles': sum(m['triangle_count'] for e in entries for m in e['meshes']),
            'scenes': [s.name for s in scenes] + [preview.name], 'validation': 'passed'}


if __name__ == '__main__':
    print(build_sky_islands())
