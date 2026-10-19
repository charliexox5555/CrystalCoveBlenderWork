"""Glassy revamp v3 (workstream C). Run inside Blender through the Blender MCP:

    R = "<repo>"
    exec(open(R + "/tools/blender/glassclash_blender.py").read()); set_repo(R)
    exec(open(R + "/docs/art/glassy_revamp/tools/build_glassy_v3.py").read())
    build_v3("glass_dragon")          # builds, exports, renders, writes manifest
    validate_v3("glass_dragon")       # FBX round-trip into a scratch scene

Writes only assets/blender/glassies/<id>/v3/ (refuses to overwrite unless force=True).
Every animated detail gets a `Pivot_<Detail>` empty (local Z = motion axis) in the .blend
and the same pivot/axis/motion in manifest.json. FBX files carry meshes only.
"""
import hashlib
import json
import math
import os
import random
import shutil

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector

exec(open(repo_path("tools", "blender", "build_combat_release.py"), encoding="utf-8").read())

V3 = "v3"
RARITY = {
    "pop": "Starter", "jam": "Starter", "prism": "Starter",
    "milk_bottle": "Common", "pickle_jar": "Common", "ketchup_bottle": "Common",
    "glass_cup": "Common", "water_jug": "Common", "lemonade_bottle": "Common",
    "mason_jar": "Uncommon", "hot_sauce": "Uncommon", "crystal_tumbler": "Uncommon", "chime": "Uncommon",
    "crescent_axe": "Rare", "briar_flask": "Rare", "arc_coil": "Rare", "hourglass": "Rare", "frostglobe": "Rare",
    "rocket_pop": "Epic", "prism_blade": "Epic", "glass_duck": "Epic",
    "comet": "Legendary", "glass_dragon": "Mythic", "galaxy_orb": "Mythic",
}
SHARD_COUNT = {"Epic": 18, "Legendary": 20, "Mythic": 20}
BUDGET = {"Legendary": 3000, "Mythic": 3000}
BUILDERS = {}


def builder(gid):
    def wrap(fn):
        BUILDERS[gid] = fn
        return fn
    return wrap


def v3_folder(gid):
    return repo_path("assets", "blender", "glassies", gid, V3)


def v2_manifest(gid):
    return json.load(open(repo_path("assets", "blender", "glassies", gid, "release_v2", "manifest.json")))


def v2_body_bounds(gid):
    body = next(e for e in v2_manifest(gid)["meshes"] if e["role"] == "Body")
    return [Vector(body["bounds_blender"][0]), Vector(body["bounds_blender"][1])]


def to_roblox(v):
    return [round(v[0], 6), round(v[2], 6), round(-v[1], 6)]


# ------------------------------------------------------------------------------------------
# Materials (previews only; Studio sets the real Color/Material from the manifest)
# ------------------------------------------------------------------------------------------

def neon_material(color):
    mat = bpy.data.materials.get("V3Neon_" + color) or bpy.data.materials.new("V3Neon_" + color)
    mat.use_nodes = True
    node = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    rgb = hex_to_rgb(color)
    _set_input(node, "Base Color", (*rgb, 1))
    _set_input(node, ["Emission Color", "Emission"], (*rgb, 1))
    _set_input(node, "Emission Strength", 1.6)
    _set_input(node, "Roughness", 0.3)
    return mat


def paint(obj, color, material="Glass", role="Detail", alpha=None, transmission=None):
    """Tags Studio color/material and assigns a preview material."""
    if material == "Neon":
        obj["studio_color"], obj["studio_material"], obj["asset_role"] = color, "Neon", role
        obj["studio_transparency"] = 0
        assign_material([obj], neon_material(color))
        return obj
    rmaterial(obj, color, material, role)
    if material == "Glass" and (alpha is not None or transmission is not None):
        mat = obj.data.materials[0].copy()
        mat.name = "V3_%s_%s" % (color, obj.name)
        obj.data.materials[0] = mat
        node = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        if alpha is not None:
            _set_input(node, "Alpha", alpha)
        if transmission is not None:
            _set_input(node, "Transmission Weight", transmission)
    return obj


# ------------------------------------------------------------------------------------------
# Geometry primitives (all build in hang space: origin = hang point, body hangs down -Z)
# ------------------------------------------------------------------------------------------

def _obj(name, bm, smooth=True, sharp_deg=None):
    obj = _mesh_object(name, bm)
    set_shading(obj, smooth)
    if smooth and sharp_deg:
        obj.data.set_sharp_from_angle(angle=math.radians(sharp_deg))
    obj["source_name"] = name
    return obj


def chaikin(points, fixed=(), iterations=1):
    """Rounds a (r, z) profile; keeps the end points and indices in `fixed` as hard corners."""
    pts = [(tuple(p), i in fixed or i in (0, len(points) - 1)) for i, p in enumerate(points)]
    for _ in range(iterations):
        out = [pts[0]]
        for i in range(1, len(pts) - 1):
            p, keep = pts[i]
            if keep:
                out.append(pts[i])
                continue
            a, b = pts[i - 1][0], pts[i + 1][0]
            out.append(((p[0] * 0.75 + a[0] * 0.25, p[1] * 0.75 + a[1] * 0.25), False))
            out.append(((p[0] * 0.75 + b[0] * 0.25, p[1] * 0.75 + b[1] * 0.25), False))
        out.append(pts[-1])
        pts = out
    return [p for p, _ in pts]


def lathe3(name, profile, h, segments=24, sharp_deg=38, flat=False):
    obj = lathe(name, profile, segments=segments, flat=flat, hang_z=h)
    if not flat and sharp_deg:
        obj.data.set_sharp_from_angle(angle=math.radians(sharp_deg))
    obj["source_name"] = name
    return obj


def ellipsoid_bm(bm, at, radii, segments=16, rings=10, rot=None):
    tmp = bmesh.new()
    bmesh.ops.create_uvsphere(tmp, u_segments=segments, v_segments=rings, radius=1)
    m = Matrix.Diagonal((*radii, 1))
    if rot is not None:
        m = rot.to_matrix().to_4x4() @ m
    bmesh.ops.transform(tmp, matrix=Matrix.Translation(Vector(at)) @ m, verts=tmp.verts)
    _merge_bm(bm, tmp)
    return bm


def _merge_bm(dst, src):
    mesh = bpy.data.meshes.new("_tmp_merge")
    src.to_mesh(mesh)
    src.free()
    dst.from_mesh(mesh)
    bpy.data.meshes.remove(mesh)


def blob(name, at, radii, segments=16, rings=10, rot=None):
    bm = bmesh.new()
    ellipsoid_bm(bm, at, radii, segments, rings, rot)
    return _obj(name, bm)


def blobs(name, items, segments=12, rings=8):
    """Several ellipsoids in one mesh: items = [(at, radii), ...]."""
    bm = bmesh.new()
    for at, radii in items:
        ellipsoid_bm(bm, at, radii, segments, rings)
    return _obj(name, bm)


def tube_bm(bm, points, radii, sides=10, cap=True):
    """Closed tube along a polyline with per-point radii (parallel-transport frames)."""
    pts = [Vector(p) for p in points]
    n = len(pts)
    if not isinstance(radii, (list, tuple)):
        radii = [radii] * n
    tangents = []
    for i in range(n):
        a, b = pts[max(i - 1, 0)], pts[min(i + 1, n - 1)]
        tangents.append((b - a).normalized())
    ref = Vector((0, 0, 1)) if abs(tangents[0].z) < 0.9 else Vector((1, 0, 0))
    normal = tangents[0].cross(ref).normalized()
    rings = []
    for i in range(n):
        t = tangents[i]
        if i:
            axis = tangents[i - 1].cross(t)
            if axis.length > 1e-6:
                ang = tangents[i - 1].angle(t)
                normal = (Matrix.Rotation(ang, 3, axis.normalized()) @ normal).normalized()
        binormal = t.cross(normal)
        ring = []
        for j in range(sides):
            a = j * math.tau / sides
            ring.append(bm.verts.new(pts[i] + (normal * math.cos(a) + binormal * math.sin(a)) * radii[i]))
        rings.append(ring)
    for i in range(n - 1):
        for j in range(sides):
            k = (j + 1) % sides
            bm.faces.new((rings[i][j], rings[i][k], rings[i + 1][k], rings[i + 1][j]))
    if cap:
        for ring, p in ((rings[0], pts[0] - tangents[0] * radii[0] * 0.15), (rings[-1], pts[-1] + tangents[-1] * radii[-1] * 0.15)):
            c = bm.verts.new(p)
            for j in range(sides):
                bm.faces.new((ring[j], ring[(j + 1) % sides], c))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def tube(name, points, radii, sides=10):
    bm = bmesh.new()
    tube_bm(bm, points, radii, sides)
    return _obj(name, bm, sharp_deg=None)


def spline(ctrl, samples=16):
    """Catmull-Rom through control points (3D), returns sampled points."""
    c = [Vector(p) for p in ctrl]
    c = [c[0] + (c[0] - c[1])] + c + [c[-1] + (c[-1] - c[-2])]
    out = []
    for i in range(1, len(c) - 2):
        p0, p1, p2, p3 = c[i - 1], c[i], c[i + 1], c[i + 2]
        steps = max(2, samples // (len(c) - 3))
        for s in range(steps):
            t = s / steps
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(c[-2])
    return out


def slab_bm(bm, points, depth, bevel=0.03, segments=2, matrix=None, clamp=False):
    """Extruded 2D outline (u, v) in the local XZ plane, depth along local Y, bevelled."""
    tmp = bmesh.new()
    n = len(points)
    vs = [tmp.verts.new((u, d, v)) for d in (-depth / 2, depth / 2) for u, v in points]
    tmp.faces.new(list(reversed(vs[:n])))
    tmp.faces.new(vs[n:])
    for i in range(n):
        j = (i + 1) % n
        tmp.faces.new((vs[i], vs[j], vs[j + n], vs[i + n]))
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    if bevel:
        bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=bevel, segments=segments, affect="EDGES", profile=0.5, clamp_overlap=clamp)
    bmesh.ops.triangulate(tmp, faces=[f for f in tmp.faces if len(f.verts) > 4])
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    if matrix is not None:
        bmesh.ops.transform(tmp, matrix=matrix, verts=tmp.verts)
    _merge_bm(bm, tmp)
    return bm


def slab(name, points, depth, matrix=None, bevel=0.03, segments=2, sharp_deg=50, clamp=False):
    bm = bmesh.new()
    slab_bm(bm, points, depth, bevel, segments, matrix, clamp)
    return _obj(name, bm, sharp_deg=sharp_deg)


def star_points(points=5, outer=1.0, inner=0.45, rot=0.0):
    return [((outer if i % 2 == 0 else inner) * math.sin(rot + i * math.pi / points),
             (outer if i % 2 == 0 else inner) * math.cos(rot + i * math.pi / points)) for i in range(points * 2)]


def gem_bm(bm, at, radius, height, sides=6, matrix=None):
    """Double pyramid (bipyramid) gem."""
    tmp = bmesh.new()
    ring = [tmp.verts.new((radius * math.cos(i * math.tau / sides), radius * math.sin(i * math.tau / sides), 0)) for i in range(sides)]
    top, bot = tmp.verts.new((0, 0, height / 2)), tmp.verts.new((0, 0, -height / 2))
    for i in range(sides):
        j = (i + 1) % sides
        tmp.faces.new((ring[i], ring[j], top))
        tmp.faces.new((ring[j], ring[i], bot))
    m = Matrix.Translation(Vector(at)) @ (matrix if matrix is not None else Matrix.Identity(4))
    bmesh.ops.transform(tmp, matrix=m, verts=tmp.verts)
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    _merge_bm(bm, tmp)
    return bm


def torus_bm(bm, centre, radius, tube_r, steps=24, sides=6, matrix=None):
    tmp = bmesh.new()
    rings = []
    for i in range(steps):
        a = i * math.tau / steps
        ring = []
        for j in range(sides):
            b = j * math.tau / sides
            ring.append(tmp.verts.new(((radius + tube_r * math.cos(b)) * math.cos(a), (radius + tube_r * math.cos(b)) * math.sin(a), tube_r * math.sin(b))))
        rings.append(ring)
    for i in range(steps):
        for j in range(sides):
            tmp.faces.new((rings[i][j], rings[(i + 1) % steps][j], rings[(i + 1) % steps][(j + 1) % sides], rings[i][(j + 1) % sides]))
    m = Matrix.Translation(Vector(centre)) @ (matrix if matrix is not None else Matrix.Identity(4))
    bmesh.ops.transform(tmp, matrix=m, verts=tmp.verts)
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    _merge_bm(bm, tmp)
    return bm


def remesh_union(name, build, voxel=0.03, target_tris=1100, smooth_iters=4, fit=None):
    """Union of overlapping volumes -> voxel remesh -> smooth -> decimate -> one closed mesh.
    `fit` = (lo, hi) bounds to scale-fit exactly (keeps collision dimensions)."""
    bm = bmesh.new()
    build(bm)
    tmp = _obj("_union_src", bm)
    rm = tmp.modifiers.new("Remesh", "REMESH")
    rm.mode, rm.voxel_size, rm.use_smooth_shade = "VOXEL", voxel, True
    sm = tmp.modifiers.new("Smooth", "SMOOTH")
    sm.factor, sm.iterations = 0.6, smooth_iters
    dg = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bpy.data.objects.remove(tmp, do_unlink=True)
    tri = sum(len(p.vertices) - 2 for p in mesh.polygons)
    obj = bpy.data.objects.new(name, mesh)
    _link(obj)
    dec = obj.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = min(1.0, target_tris / max(tri, 1))
    dg = bpy.context.evaluated_depsgraph_get()
    final = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
    obj.modifiers.clear()
    old = obj.data
    obj.data = final
    bpy.data.meshes.remove(old)
    final.name = name
    bm = _bm_from_object(obj)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if fit:
        lo, hi = Vector(fit[0]), Vector(fit[1])
        xs = [v.co for v in bm.verts]
        a = Vector((min(p.x for p in xs), min(p.y for p in xs), min(p.z for p in xs)))
        b = Vector((max(p.x for p in xs), max(p.y for p in xs), max(p.z for p in xs)))
        for v in bm.verts:
            v.co = Vector(tuple(lo[k] + (v.co[k] - a[k]) * (hi[k] - lo[k]) / (b[k] - a[k]) for k in range(3)))
    bm.to_mesh(obj.data)
    bm.free()
    set_shading(obj, True)
    obj["source_name"] = name
    return obj


# ------------------------------------------------------------------------------------------
# Motion tags
# ------------------------------------------------------------------------------------------

def sway(amp, period, phase=0.0):
    return {"type": "sway", "amp_deg": amp, "period_s": period, "phase": phase}


def spin(speed):
    return {"type": "spin", "deg_per_s": speed}


def bob(amp, period, phase=0.0):
    return {"type": "bob", "amp_studs": amp, "period_s": period, "phase": phase}


def pulse(amp, period, phase=0.0):
    return {"type": "pulse", "amp": amp, "period_s": period, "phase": phase}


def slosh(max_deg=14, gain=0.35, freq=1.6, damping=0.35):
    return {"type": "slosh", "max_deg": max_deg, "gain": gain, "freq_hz": freq, "damping": damping}


def flicker(amp, rate):
    return {"type": "flicker", "amp": amp, "rate_hz": rate}


def blink(interval=3.5, dur=0.12):
    return {"type": "blink", "interval_s": interval, "dur_s": dur}


def kick(deg, freq=3.0, damping=0.3):
    return {"type": "kick", "deg": deg, "freq_hz": freq, "damping": damping}


def flare(deg, freq=2.5, damping=0.35):
    return {"type": "flare", "deg": deg, "freq_hz": freq, "damping": damping}


def hop(studs, freq=4.0, damping=0.3):
    return {"type": "hop", "studs": studs, "freq_hz": freq, "damping": damping}


def squash(factor, freq=5.0, damping=0.35):
    return {"type": "squash", "factor": factor, "freq_hz": freq, "damping": damping}


def flash(dur=0.18):
    return {"type": "flash", "dur_s": dur}


def spin_boost(speed, dur=0.8):
    return {"type": "spin_boost", "deg_per_s": speed, "dur_s": dur}


def anim(obj, pivot, axis=(0, 0, 1), idle=None, hit=None, lod_keep=False, extra_idle=None, note=None):
    """Attach a pivot empty + motion tags to a detail."""
    pivot, axis = Vector(pivot), Vector(axis).normalized()
    obj["animation_pivot"] = [round(c, 6) for c in pivot]
    motion = {"pivot_blender": [round(c, 6) for c in pivot], "axis_blender": [round(c, 6) for c in axis],
              "pivot_roblox": to_roblox(pivot), "axis_roblox": to_roblox(axis),
              "idle": idle or {"type": "static"}, "hit": hit or {"type": "none"}, "lod_keep": lod_keep}
    if extra_idle:
        motion["idle_layers"] = extra_idle
    if note:
        motion["note"] = note
    obj["motion_json"] = json.dumps(motion)
    emp = bpy.data.objects.new("Pivot_" + obj["source_name"], None)
    emp.empty_display_type, emp.empty_display_size = "ARROWS", 0.15
    emp.location = pivot
    emp.rotation_euler = axis.to_track_quat("Z", "Y").to_euler()
    emp["pivot_for"] = obj["source_name"]
    _link(emp)
    return obj


# ------------------------------------------------------------------------------------------
# Batch 1 builders. Each returns (hang_z_unused, body, details).
# ------------------------------------------------------------------------------------------

@builder("glass_dragon")
def b_glass_dragon(gid):
    tint, pale, wing_c = "#7CF0C4", "#C8F8D9", "#5FD6A8"
    lo, hi = v2_body_bounds(gid)

    def shape(bm):
        ellipsoid_bm(bm, (0, -0.04, -0.58), (0.62, 0.58, 0.56), 24, 14)        # head
        ellipsoid_bm(bm, (0, 0.03, -1.18), (0.34, 0.32, 0.34), 16, 10)         # neck
        ellipsoid_bm(bm, (0, 0.0, -1.58), (0.5, 0.48, 0.42), 20, 12)           # chest
        ellipsoid_bm(bm, (0, 0.02, -2.12), (0.69, 0.66, 0.74), 24, 14)         # belly
        for x in (-0.33, 0.33):
            ellipsoid_bm(bm, (x, -0.2, -2.8), (0.21, 0.25, 0.2), 12, 8)        # feet
    body = remesh_union("Body", shape, voxel=0.028, target_tris=1000, fit=(lo, hi))
    paint(body, tint, role="Body")
    ds = []
    muzzle = paint(blob("Muzzle", (0, -0.5, -0.78), (0.38, 0.3, 0.23), 14, 8), "#93ECC6")
    nostrils = paint(blobs("Nostrils", [((-0.12, -0.775, -0.7), (0.045, 0.03, 0.035)), ((0.12, -0.775, -0.7), (0.045, 0.03, 0.035))], 6, 4), "#2F5A4C", "SmoothPlastic")
    jaw = paint(blob("Jaw", (0, -0.47, -0.97), (0.32, 0.27, 0.1), 12, 6), pale)
    anim(jaw, (0, -0.24, -0.9), (1, 0, 0), sway(4, 2.6), kick(18, 4, 0.35))
    eyes = paint(blobs("Eyes", [((-0.25, -0.5, -0.46), (0.1, 0.07, 0.125)), ((0.25, -0.5, -0.46), (0.1, 0.07, 0.125))], 10, 6), "#22323F", "SmoothPlastic")
    anim(eyes, (0, -0.5, -0.46), (0, 0, 1), blink(3.8, 0.12))
    shine = paint(blobs("EyeShine", [((-0.22, -0.56, -0.41), (0.035, 0.02, 0.035)), ((0.28, -0.56, -0.41), (0.035, 0.02, 0.035))], 6, 4), "#FFFFFF", "SmoothPlastic")
    anim(shine, (0, -0.5, -0.46), (0, 0, 1), blink(3.8, 0.12), note="blinks with Eyes")
    horns = bmesh.new()
    for s in (-1, 1):
        tube_bm(horns, spline([(s * 0.26, 0.05, -0.2), (s * 0.36, 0.25, -0.12), (s * 0.44, 0.48, -0.1), (s * 0.5, 0.64, -0.2)], 8), [0.1, 0.085, 0.06, 0.04, 0.03, 0.022, 0.016, 0.01, 0.006], 6)
    horns = paint(_obj("Horns", horns), pale)
    belly = paint(blob("BellyPlate", (0, -0.585, -2.0), (0.36, 0.08, 0.48), 14, 7), "#DDFBEA", alpha=0.55)
    spines = bmesh.new()
    for i, z in enumerate((-0.98, -1.42, -1.86)):
        r = 0.16 - i * 0.02
        y = {0: 0.3, 1: 0.44, 2: 0.6}[i]
        slab_bm(spines, [(-0.0, -r * 0.6), (r * 1.6, 0.0), (0, r * 0.9)], 0.07, 0.02, 1,
                Matrix.Translation((0, y, z)) @ Matrix.Rotation(math.pi / 2, 4, "Z"))
    spines = paint(_obj("Spines", spines, sharp_deg=50), wing_c)
    wing_pts = [(0.0, -0.05), (0.18, 0.22), (0.45, 0.58), (0.82, 0.86), (0.98, 0.9), (0.9, 0.62),
                (0.78, 0.52), (0.74, 0.34), (0.58, 0.3), (0.52, 0.12), (0.34, 0.08), (0.2, -0.08)]
    for side, label in ((-1, "L"), (1, "R")):
        pts = [(side * u * 1.05, v) for u, v in wing_pts]
        if side < 0:
            pts = list(reversed(pts))
        rot = Matrix.Rotation(side * -0.42, 4, "Z")
        m = Matrix.Translation((side * 0.3, 0.42, -1.62)) @ rot
        w = paint(slab("Wing_" + label, pts, 0.07, m, bevel=0.028, segments=1), wing_c)
        anim(w, (side * 0.3, 0.42, -1.62), rot.to_3x3() @ Vector((0, side, 0)), sway(14, 1.4), flare(28), lod_keep=True)
        ds.append(w)
    tail_path = spline([(0, 0.42, -2.42), (0, 0.8, -2.62), (0.12, 1.08, -2.42), (0.22, 1.16, -2.1), (0.14, 1.02, -1.92)], 14)
    tb = bmesh.new()
    rads = [0.24 - 0.17 * i / (len(tail_path) - 1) for i in range(len(tail_path))]
    tube_bm(tb, tail_path, rads, 8)
    end, prev = tail_path[-1], tail_path[-2]
    d = (end - prev).normalized()
    m = Matrix.Translation(end + d * 0.08) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4() @ Matrix.Rotation(math.pi / 2, 4, "X")
    slab_bm(tb, [(0, -0.05), (0.16, 0.08), (0.0, 0.26), (-0.16, 0.08)], 0.06, 0.02, 1, m)
    tail = paint(_obj("Tail", tb, sharp_deg=60), "#6CE2B4")
    anim(tail, (0, 0.42, -2.42), (0, 0, 1), sway(12, 1.9), kick(20))
    core = paint(blob("BreathCore", (0, -0.12, -1.55), (0.2, 0.2, 0.2), 10, 6), "#FFF2B3", "Neon")
    anim(core, (0, -0.12, -1.55), (0, 0, 1), pulse(0.08, 1.6), flash(0.2))
    ds += [muzzle, nostrils, jaw, eyes, shine, horns, belly, spines, tail, core]
    return body, ds


# ------------------------------------------------------------------------------------------
# Package: shards, cracks, FBX, icon, preview, .blend, manifest
# ------------------------------------------------------------------------------------------

def _rel(path):
    return os.path.relpath(path, REPO).replace(os.sep, "/")


def _sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def _tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def _gpu(scene):
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        scene.cycles.device = "GPU"
    except Exception:
        scene.cycles.device = "CPU"
    scene.render.threads_mode = "AUTO"


def render_views(scene, objs, icon_path, preview_path, samples=64):
    """Icon: the shared release rig (front, ortho, key/rim/fill). Preview: same rig from 3/4."""
    release_rig(scene, objs)
    scene.cycles.samples = samples
    _gpu(scene)
    scene.render.filepath = icon_path
    bpy.ops.render.render(write_still=True)
    cam = scene.camera
    lo, hi = _world_bounds(objs)
    centre = (lo + hi) / 2
    direction = Vector((1.0, -1.35, 0.75)).normalized()
    cam.location = centre + direction * 12
    cam.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
    cam.data.ortho_scale = max((hi - lo).length * 0.86, 1)
    scene.render.filepath = preview_path
    bpy.ops.render.render(write_still=True)


def build_v3(gid, force=False, render=True):
    global COLLECTION
    folder = v3_folder(gid)
    manifest_path = os.path.join(folder, "manifest.json")
    if os.path.exists(manifest_path) and not force:
        return {"id": gid, "status": "existing v3 preserved (force=True to rebuild)"}
    os.makedirs(folder, exist_ok=True)
    rarity = RARITY[gid]
    previous, old_col = bpy.context.window.scene, COLLECTION
    scene = bpy.data.scenes.new("V3_" + gid)
    scene.unit_settings.system, scene.unit_settings.scale_length = "NONE", 1
    bpy.context.window.scene = scene
    COLLECTION = scene.name
    try:
        with bpy.context.temp_override(scene=scene, view_layer=scene.view_layers[0]):
            body, details = BUILDERS[gid](gid)
            body["glassy_id"], body["asset_role"], body["source_name"] = gid, "Body", "Body"
            for d in details:
                d["glassy_id"] = gid
            for o in [body, *details]:
                assert o.name == o["source_name"], ("name clash", o.name, o["source_name"])
            tris = sum(_tris(o) for o in [body, *details])
            budget = BUDGET.get(rarity, 1500)
            assert tris <= budget, (gid, "intact budget", tris, budget)
            count = SHARD_COUNT.get(rarity, 16)
            for attempt in range(12):
                shards = make_shards(body, count, seed=3030 + sum(map(ord, gid)) + attempt * 7919, cut=rcut, min_volume_ratio=0.3 / count)
                if len(shards) == count and all(rclosed(s)["nonmanifold_edges"] == 0 and rclosed(s)["volume"] > 1e-7 for s in shards):
                    break
                for s in shards:
                    bpy.data.objects.remove(s, do_unlink=True)
            else:
                raise AssertionError((gid, "no valid fracture seed"))
            checks = {o.name: rclosed(o) for o in [body, *shards]}
            assert all(c["nonmanifold_edges"] == 0 and c["boundary_edges"] == 0 for c in checks.values()), checks
            ratio = sum(rclosed(s)["volume"] for s in shards) / rclosed(body)["volume"]
            assert abs(ratio - 1) < 0.001, (gid, "volume ratio", ratio)
            for i, s in enumerate(shards):
                s["source_name"], s["asset_role"], s["glassy_id"] = f"Shard_{i + 1:02d}", "Shard", gid
                assert s.name == s["source_name"]
                paint(s, body["studio_color"], role="Shard")
            cracks = rcracks(body)
            assert len(cracks) > 20, (gid, "cracks", len(cracks))
            files = {}
            for role, objs in (("body", [body]), ("details", details), ("shards", shards), ("bundle", [body, *details, *shards])):
                files[role] = export_fbx(objs, os.path.join(folder, f"{gid}_{role}.fbx"))
            for s in shards:
                s.hide_render = True
            icon = os.path.join(folder, f"{gid}_icon.png")
            preview = repo_path("docs", "art", "glassy_revamp", "previews", f"{gid}_v3_34.png")
            os.makedirs(os.path.dirname(preview), exist_ok=True)
            if render:
                render_views(scene, [body, *details], icon, preview)
                files["icon"] = icon
            for s in shards:
                s.hide_set(True)
            files["blend"] = save_blend_copy(os.path.join(folder, f"{gid}.blend"))
            crack_path = os.path.join(folder, "cracks.json")
            with open(crack_path, "w", newline="\n") as fh:
                json.dump(cracks, fh, indent=2)
            files["cracks"] = crack_path
            meshes = []
            for o in [body, *details, *shards]:
                lo, hi = _world_bounds([o])
                entry = {"name": o.name, "source_name": o["source_name"], "role": o["asset_role"], "triangles": _tris(o),
                         "bounds_blender": [list(lo), list(hi)], "origin": [0, 0, 0], "color": o["studio_color"],
                         "material": o["studio_material"], "transparency": o.get("studio_transparency", 0),
                         "animation_pivot": list(o.get("animation_pivot", [0, 0, 0])), "effect_only": bool(o.get("effect_only", False))}
                if "motion_json" in o:
                    entry["motion"] = json.loads(o["motion_json"])
                    entry["pivot_empty"] = "Pivot_" + o["source_name"]
                meshes.append(entry)
            blo, bhi = _world_bounds([body])
            vlo, vhi = v2_body_bounds(gid)
            dims, v2dims = bhi - blo, vhi - vlo
            v2 = v2_manifest(gid)
            v2_blend = repo_path("assets", "blender", "glassies", gid, "release_v2", gid + ".blend")
            report = {
                "id": gid, "version": V3, "rarity": rarity, "base_version": "release_v2",
                "status": {"exported": True, "blender_validated": True, "studio_imported": False, "uploaded": False, "playtested": False},
                "units": "1 Blender unit = 1 stud", "axis_conversion": "Blender (x,y,z) -> Roblox (x,z,-y)", "hang_origin": [0, 0, 0],
                "intact_triangles": tris, "triangle_budget": budget, "shard_count": len(shards), "fracture_volume_ratio": ratio,
                "checks": checks, "crack_segments": len(cracks), "meshes": meshes,
                "files": {k: _rel(v) for k, v in files.items()}, "hashes": {k: _sha(v) for k, v in files.items()},
                "before": {"source": _rel(v2_blend), "sha256": _sha(v2_blend), "icon": "assets/icons/release_v2/%s.png" % gid,
                           "intact_triangles": v2["intact_triangles"]},
                "collision": {"config_radius_unchanged": True,
                              "body_dimensions_roblox_v2": [v2dims.x, v2dims.z, v2dims.y], "body_dimensions_roblox_v3": [dims.x, dims.z, dims.y],
                              "max_dimension_change_pct": round(max(abs(dims[k] / v2dims[k] - 1) for k in range(3)) * 100, 2)},
                "measured_body_dimensions_roblox": [dims.x, dims.z, dims.y],
                "preview": _rel(preview) if render else None,
                "remaining_checks": ["Roblox FBX import scale/orientation/pivot", "Glass/Neon material against live sky",
                                     "idle motion implementation in Studio", "phone performance with all details animated"],
            }
            with open(manifest_path, "w") as fh:
                json.dump(report, fh, indent=2)
            return {"id": gid, "tris": tris, "budget": budget, "shards": len(shards), "ratio": round(ratio, 8),
                    "dims_v3": [round(x, 3) for x in dims], "dims_v2": [round(x, 3) for x in v2dims],
                    "change_pct": report["collision"]["max_dimension_change_pct"], "details": len(details)}
    finally:
        bpy.context.window.scene = previous
        COLLECTION = old_col
        _drop_scene(scene)


def _drop_scene(scene):
    for o in list(scene.objects):
        data = o.data
        bpy.data.objects.remove(o, do_unlink=True)
        if isinstance(data, bpy.types.Mesh) and data.users == 0:
            bpy.data.meshes.remove(data)
        elif isinstance(data, bpy.types.Camera) and data.users == 0:
            bpy.data.cameras.remove(data)
        elif isinstance(data, bpy.types.Light) and data.users == 0:
            bpy.data.lights.remove(data)
    for c in list(scene.collection.children):
        bpy.data.collections.remove(c)
    bpy.data.scenes.remove(scene)
    for m in list(bpy.data.meshes):
        if m.users == 0:
            bpy.data.meshes.remove(m)


def validate_v3(gid):
    folder = v3_folder(gid)
    path = os.path.join(folder, "manifest.json")
    report = json.load(open(path))
    previous = bpy.context.window.scene
    scene = bpy.data.scenes.new("V3Check_" + gid)
    bpy.context.window.scene = scene
    try:
        with bpy.context.temp_override(scene=scene, view_layer=scene.view_layers[0]):
            bpy.ops.import_scene.fbx(filepath=repo_path(report["files"]["bundle"]), use_custom_props=True)
            meshes = [o for o in scene.objects if o.type == "MESH"]
            assert len(meshes) == len(report["meshes"]), (gid, "mesh count", len(meshes), len(report["meshes"]))
            rows = []
            for entry in report["meshes"]:
                obj = next(o for o in meshes if o.get("source_name") == entry["source_name"])
                lo, hi = _world_bounds([obj])
                delta = max((lo - Vector(entry["bounds_blender"][0])).length, (hi - Vector(entry["bounds_blender"][1])).length)
                assert delta < 1e-4, (gid, entry["source_name"], "bounds", delta)
                assert obj.location.length < 1e-5, (gid, "origin", list(obj.location))
                check = rclosed(obj)
                if entry["role"] in ("Body", "Shard"):
                    assert check["nonmanifold_edges"] == 0, (entry["source_name"], check)
                rows.append({"name": entry["source_name"], "bounds_error": delta, "nonmanifold_edges": check["nonmanifold_edges"]})
            for key, rel in report["files"].items():
                assert _sha(repo_path(rel)) == report["hashes"][key], (gid, key, "hash changed")
            assert _sha(repo_path(report["before"]["source"])) == report["before"]["sha256"], (gid, "release_v2 source changed")
            body = next(o for o in meshes if o.get("asset_role") == "Body")
            shards = [o for o in meshes if o.get("asset_role") == "Shard"]
            a, b = _world_bounds([body])
            c, d = _world_bounds(shards)
            assert max((a - c).length, (b - d).length) < 1e-4, (gid, "shards do not recombine to body bounds")
            report["fbx_roundtrip"] = {"passed": True, "application": "Blender " + bpy.app.version_string, "format": "FBX bundle round-trip",
                                       "mesh_count": len(meshes), "shard_count": len(shards), "checks": rows, "roblox_import": False}
            with open(path, "w") as fh:
                json.dump(report, fh, indent=2)
            return {"id": gid, "passed": True, "meshes": len(meshes), "shards": len(shards)}
    finally:
        bpy.context.window.scene = previous
        _drop_scene(scene)


def preview_v3(gid, out_dir, samples=24):
    """Quick look while iterating: builds in a throwaway scene, renders front + 3/4, exports nothing."""
    global COLLECTION
    previous, old_col = bpy.context.window.scene, COLLECTION
    scene = bpy.data.scenes.new("V3Preview_" + gid)
    bpy.context.window.scene = scene
    COLLECTION = scene.name
    try:
        with bpy.context.temp_override(scene=scene, view_layer=scene.view_layers[0]):
            body, details = BUILDERS[gid](gid)
            tris = {o.name: _tris(o) for o in [body, *details]}
            blo, bhi = _world_bounds([body])
            os.makedirs(out_dir, exist_ok=True)
            render_views(scene, [body, *details], os.path.join(out_dir, gid + "_front.png"), os.path.join(out_dir, gid + "_34.png"), samples)
            return {"tris_total": sum(tris.values()), "tris": tris, "body_dims": [round(x, 3) for x in (bhi - blo)],
                    "v2_dims": [round(x, 3) for x in (v2_body_bounds(gid)[1] - v2_body_bounds(gid)[0])],
                    "body_closed": rclosed(body)}
    finally:
        bpy.context.window.scene = previous
        COLLECTION = old_col
        _drop_scene(scene)


# ------------------------------------------------------------------------------------------
# Batch 1 (continued)
# ------------------------------------------------------------------------------------------

def circle_profile(radius, z0, start_deg=-90, end_deg=90, steps=12):
    return [(radius * math.cos(math.radians(start_deg + (end_deg - start_deg) * i / steps)),
             z0 + radius * math.sin(math.radians(start_deg + (end_deg - start_deg) * i / steps))) for i in range(steps + 1)]


def loft(name, sections, sharp_deg=None, smooth=False):
    """Closed loft through 2D cross-sections [(z, [(x, y), ...]), ...]; a section with one point is a tip."""
    bm = bmesh.new()
    rings = [[bm.verts.new((x, y, z)) for x, y in pts] for z, pts in sections]
    for a, b in zip(rings, rings[1:]):
        if len(a) == 1:
            for j in range(len(b)):
                bm.faces.new((a[0], b[(j + 1) % len(b)], b[j]))
        elif len(b) == 1:
            for j in range(len(a)):
                bm.faces.new((a[j], a[(j + 1) % len(a)], b[0]))
        else:
            for j in range(len(a)):
                k = (j + 1) % len(a)
                bm.faces.new((a[j], a[k], b[k], b[j]))
    for ring in (rings[0], rings[-1]):
        if len(ring) > 2:
            bm.faces.new(ring)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj(name, bm, smooth=smooth, sharp_deg=sharp_deg)


@builder("galaxy_orb")
def b_galaxy_orb(gid):
    h, r = 2.40, 0.96
    prof = circle_profile(r, r, -90, 74, 14) + [(0.3, 2.06), (0.27, 2.16), (0.31, 2.2), (0.31, 2.27), (0, 2.27)]
    prof[0] = (0, 0)
    body = paint(lathe3("Body", prof, h, 28, sharp_deg=50), "#7A5CFF", role="Body")
    c = Vector((0, 0, r - h))
    ds = []
    crown = paint(lathe3("HangCrown", [(0, -0.02 + 2.24), (0.2, 2.24), (0.23, 2.29), (0.16, 2.36), (0.1, 2.36), (0.12, 2.4), (0, 2.4)], h, 12), "#D8C8FF", "Metal")
    anim(crown, (0, 0, 0), (1, 0, 0), None, kick(10))
    shell = paint(blob("Nebula", c, (0.66, 0.66, 0.66), 14, 9), "#B05CFF", alpha=0.45)
    sw = bmesh.new()
    tilt = Matrix.Translation(c) @ Matrix.Rotation(0.42, 4, "X")
    for arm in range(2):
        pts = []
        for i in range(12):
            t = i / 11
            a = arm * math.pi + t * 3.4
            rr = 0.08 + 0.5 * t
            pts.append(tilt @ Vector((rr * math.cos(a), rr * math.sin(a), 0)))
        tube_bm(sw, pts, [0.075 * (1 - 0.8 * i / 11) + 0.01 for i in range(12)], 6)
    swirl = paint(_obj("GalaxySwirl", sw), "#F2A8FF", "Neon")
    anim(swirl, c, tilt.to_3x3() @ Vector((0, 0, 1)), spin(25), flash(0.2), lod_keep=True)
    core = paint(blob("StarCore", c, (0.15, 0.15, 0.15), 10, 7), "#FFF1B8", "Neon")
    anim(core, c, (0, 0, 1), pulse(0.12, 1.2), flash(0.25))
    rng = random.Random(7)
    dust = bmesh.new()
    for i in range(12):
        while True:
            p = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)))
            if 0.35 < p.length < 0.95:
                break
        gem_bm(dust, c + p * 0.72, 0.035, 0.09, 4)
    dust = paint(_obj("Stardust", dust, smooth=False), "#FFFFFF", "Neon")
    anim(dust, c, (0, 0, 1), spin(-12))
    for i, (angle, speed) in enumerate(((0.5, 40), (-0.6, -55))):
        rot = Matrix.Rotation(angle, 4, "X") @ Matrix.Rotation(i * 0.9, 4, "Z")
        rb = bmesh.new()
        torus_bm(rb, c, 1.16, 0.045, 28, 5, rot)
        band = paint(_obj(f"OrbitBand_{i + 1}", rb), "#D8C8FF")
        axis = rot.to_3x3() @ Vector((0, 0, 1))
        anim(band, c, axis, spin(speed), spin_boost(240), lod_keep=(i == 0))
        mb = bmesh.new()
        for s in (-1, 1):
            ellipsoid_bm(mb, c + rot.to_3x3() @ Vector((s * 1.16, 0, 0)), (0.1, 0.1, 0.1), 10, 6)
        moons = paint(_obj(f"OrbitBand_{i + 1}_Moons", mb), ("#FFD27A", "#8FE3FF")[i], "SmoothPlastic")
        anim(moons, c, axis, spin(speed), spin_boost(240), note=f"rides OrbitBand_{i + 1}")
        ds += [band, moons]
    ds += [crown, shell, swirl, core, dust]
    return body, ds


@builder("comet")
def b_comet(gid):
    h = 2.45
    prof = chaikin([(0, 0.10), (0.48, 0.12), (0.74, 0.32), (0.84, 0.66), (0.82, 1.04), (0.66, 1.38), (0.44, 1.64), (0.27, 1.86), (0.15, 2.1), (0.06, 2.34), (0, 2.45)], fixed=(), iterations=1)
    body = paint(lathe3("Body", prof, h, 28, sharp_deg=None), "#B8F1FF", role="Body")
    head = Vector((0, 0, 0.72 - h))
    ds = []
    star = paint(slab("StarCore", star_points(5, 0.36, 0.17), 0.16, Matrix.Translation(head + Vector((0, -0.22, 0))), bevel=0.05, segments=2), "#FFD57D", "Neon")
    anim(star, head + Vector((0, -0.22, 0)), (0, 1, 0), pulse(0.08, 1.3), flash(0.25), lod_keep=True)
    fin_shape = [(-0.2, 0.0), (-0.3, 0.28), (-0.27, 0.58), (-0.14, 0.88), (0.04, 1.16), (0.08, 0.86), (0.13, 0.56), (0.19, 0.26), (0.18, 0.0)]
    root = Vector((0, 0.32, 1.45 - h))
    for i, (yaw, size, tint) in enumerate(((-1.38, 1.5, "#B9EBFF"), (-1.02, 1.22, "#D3C6FF"), (-0.68, 0.95, "#FFE9A8"))):
        pts = [(u * size, v * size) for u, v in fin_shape]
        rot = Matrix.Rotation(yaw, 4, "Y") @ Matrix.Rotation(-0.3, 4, "X")
        fin = paint(slab(f"TailFin_{i + 1}", pts, 0.1 - i * 0.015, Matrix.Translation(root + Vector((0, i * 0.06, 0))) @ rot, bevel=0.035, segments=2), tint)
        anim(fin, root, rot.to_3x3() @ Vector((0, 1, 0)), sway(8, 1.1, i * 0.9), kick(16))
        ds.append(fin)
    for i, (ang, z, r) in enumerate(((0.6, -1.25, 1.02), (2.6, -1.85, 0.98), (4.4, -0.85, 0.82))):
        p = Vector((r * math.cos(ang), r * math.sin(ang), z))
        m = Matrix.Translation(p) @ Matrix.Rotation(ang + math.pi / 2, 4, "Z")
        sp = paint(slab(f"Sparkle_{i + 1}", star_points(4, 0.13, 0.04), 0.04, m, bevel=0.012, segments=1), "#FFFFFF", "Neon")
        anim(sp, (0, 0, z), (0, 0, 1), spin(60 + i * 15), spin_boost(300))
        ds.append(sp)
    ds.insert(0, star)
    return body, ds


@builder("prism_blade")
def b_prism_blade(gid):
    def hexs(w, t, k=0.5):
        return [(w, 0), (w * k, t), (-w * k, t), (-w, 0), (-w * k, -t), (w * k, -t)]
    secs = [(-0.48, hexs(0.1, 0.07)), (-0.56, hexs(0.3, 0.13)), (-0.7, hexs(0.36, 0.15)), (-1.6, hexs(0.33, 0.145)),
            (-2.3, hexs(0.3, 0.13)), (-2.62, hexs(0.22, 0.1)), (-2.86, hexs(0.1, 0.05)), (-2.99, [(0, 0)])]
    body = paint(loft("Body", secs), "#9BE7FF", role="Body")
    ds = []
    core = paint(loft("RainbowCore", [(-0.8, hexs(0.03, 0.02)), (-0.95, hexs(0.09, 0.04)), (-2.35, hexs(0.07, 0.035)), (-2.6, [(0, 0)])]), "#E6B8FF", "Neon")
    anim(core, (0, 0, -1.7), (0, 0, 1), pulse(0.04, 2.0), flash(0.15))
    guard_pts = [(-0.66, 0.12), (-0.52, 0.08), (-0.36, 0.0), (-0.14, 0.07), (0.14, 0.07), (0.36, 0.0), (0.52, 0.08), (0.66, 0.12),
                 (0.6, -0.06), (0.44, -0.16), (0.22, -0.18), (0.0, -0.28), (-0.22, -0.18), (-0.44, -0.16), (-0.6, -0.06)]
    guard = paint(slab("Crossguard", guard_pts, 0.22, Matrix.Translation((0, 0, -0.33)), bevel=0.04, segments=2), "#A7DAF6")
    anim(guard, (0, 0, -0.4), (0, 1, 0), None, kick(4))
    gb = bmesh.new()
    gem_bm(gb, (0, -0.12, -0.42), 0.085, 0.1, 6, Matrix.Rotation(math.pi / 2, 4, "X"))
    ggem = paint(_obj("GuardGem", gb, smooth=False), "#FF8FD8", "Neon")
    anim(ggem, (0, -0.12, -0.42), (0, 1, 0), pulse(0.1, 1.4), flash(0.25), lod_keep=True)
    hprof = [(0, 0.0), (0.075, 0.0), (0.09, 0.03), (0.075, 0.06), (0.09, 0.09), (0.075, 0.12), (0.09, 0.15), (0.075, 0.18), (0.11, 0.2),
             (0.15, 0.24), (0.16, 0.3), (0.13, 0.35), (0.06, 0.37), (0, 0.37)]
    hilt = paint(lathe3("Hilt", [(r, z - 0.37) for r, z in hprof], 0.0, 12, sharp_deg=40), "#A7DAF6")
    pb = bmesh.new()
    gem_bm(pb, (0, -0.15, -0.07), 0.055, 0.07, 6, Matrix.Rotation(math.pi / 2, 4, "X"))
    pgem = paint(_obj("PommelGem", pb, smooth=False), "#8FE3FF", "Neon")
    anim(pgem, (0, -0.15, -0.07), (0, 1, 0), None, flash(0.2))
    for i, (ang, z) in enumerate(((0.3, -1.35), (math.pi + 0.3, -2.15))):
        sb = bmesh.new()
        p = Vector((0.55 * math.cos(ang), 0.55 * math.sin(ang), z))
        gem_bm(sb, p, 0.1, 0.42, 5, Matrix.Rotation(0.3, 4, "Y"))
        shard = paint(_obj(f"PrismShard_{i + 1}", sb, smooth=False), ("#C9A8FF", "#9BE7FF")[i])
        anim(shard, (0, 0, -1.75), (0, 0, 1), spin(70), spin_boost(300), extra_idle=[bob(0.06, 1.6, i * math.pi)])
        ds.append(shard)
    ds = [guard, ggem, hilt, pgem, core] + ds
    return body, ds


@builder("rocket_pop")
def b_rocket_pop(gid):
    h = 2.70
    prof = chaikin([(0, 0), (0.4, 0), (0.55, 0.1), (0.61, 0.3), (0.61, 1.3), (0.56, 1.56), (0.4, 1.84), (0.27, 2.04), (0.24, 2.16), (0.3, 2.22), (0.3, 2.3), (0.25, 2.34), (0.25, 2.49), (0, 2.49)], fixed=(1, 8, 9, 10, 11, 12), iterations=1)
    body = paint(lathe3("Body", prof, h, 18), "#8FE3FF", role="Body")
    ds = []
    cap = lathe3("Cap", [(0, 2.49), (0.3, 2.49), (0.34, 2.53), (0.34, 2.62), (0.29, 2.68), (0.2, 2.70), (0, 2.70)], h, 16)
    for v in cap.data.vertices:
        rr = math.hypot(v.co.x, v.co.y)
        if rr > 0.32 and v.co.z < -0.06:
            a = math.atan2(v.co.y, v.co.x)
            k = 1 + 0.06 * math.cos(8 * a)
            v.co.x *= k
            v.co.y *= k
    paint(cap, "#ED5367", "SmoothPlastic")
    anim(cap, (0, 0, -0.2), (0, 0, 1), None, hop(0.08), lod_keep=False)
    fin_pts = [(0.0, 0.0), (0.0, 0.82), (0.12, 0.7), (0.42, 0.18), (0.5, -0.16), (0.36, -0.12), (0.18, -0.02)]
    for i in range(3):
        rot = Matrix.Rotation(i * math.tau / 3, 4, "Z")
        m = rot @ Matrix.Translation((0.5, 0, -2.42))
        fin = paint(slab(f"RocketFin_{i + 1}", fin_pts, 0.12, m, bevel=0.04, segments=1), "#ED5367", "SmoothPlastic")
        anim(fin, rot.to_3x3() @ Vector((0.55, 0, -2.0)), rot.to_3x3() @ Vector((0, 1, 0)), None, kick(6))
        ds.append(fin)
    nozzle = paint(lathe3("BoosterNozzle", [(0, -0.08), (0.36, -0.08), (0.42, -0.02), (0.36, 0.06), (0.3, 0.16), (0.32, 0.22), (0, 0.22)], h, 10), "#C0D9EF", "Metal")
    flame = paint(lathe3("BoosterFlame", chaikin([(0, -0.72), (0.12, -0.52), (0.26, -0.3), (0.32, -0.16), (0, -0.06)], iterations=1), h, 10), "#FF8A2A", "Neon")
    anim(flame, (0, 0, -0.04 - h), (0, 0, 1), flicker(0.12, 14), squash(1.5), lod_keep=True)
    pr = bmesh.new()
    torus_bm(pr, (0, -0.6, 1.0 - h), 0.2, 0.05, 12, 4, Matrix.Rotation(math.pi / 2, 4, "X"))
    port = paint(_obj("Porthole", pr), "#C0D9EF", "Metal")
    fizz = []
    for i, (x, z, r) in enumerate(((-0.2, 0.62, 0.11), (0.22, 0.95, 0.09), (-0.05, 1.3, 0.075))):
        f = paint(blob(f"Fizz_{i + 1}", (x, -0.15, z - h), (r, r, r), 6, 4), "#EAFBFF")
        anim(f, (x, 0.18, z - h), (0, 0, 1), bob(0.06, 0.9 + i * 0.2, i))
        fizz.append(f)
    ds = [cap] + ds + [nozzle, flame, port] + fizz
    return body, ds


@builder("glass_duck")
def b_glass_duck(gid):
    lo, hi = v2_body_bounds(gid)

    def shape(bm):
        ellipsoid_bm(bm, (0, -0.12, -0.5), (0.5, 0.48, 0.5), 20, 12)      # head
        ellipsoid_bm(bm, (0, -0.06, -0.98), (0.34, 0.32, 0.3), 14, 8)     # neck
        ellipsoid_bm(bm, (0, 0.1, -1.62), (0.86, 0.9, 0.68), 24, 14)      # body
        ellipsoid_bm(bm, (0, -0.38, -1.46), (0.6, 0.5, 0.56), 18, 10)     # breast
        ellipsoid_bm(bm, (0, 0.72, -1.3), (0.34, 0.3, 0.3), 12, 8,
                     Quaternion((1, 0, 0), -0.6))                          # tail nub
    body = remesh_union("Body", shape, voxel=0.026, target_tris=550, fit=(lo, hi))
    paint(body, "#FFE45C", role="Body", alpha=0.85, transmission=0.45)
    ds = []
    beak = bmesh.new()
    ellipsoid_bm(beak, (0, -0.6, -0.6), (0.3, 0.26, 0.09), 12, 6)
    ellipsoid_bm(beak, (0, -0.55, -0.7), (0.24, 0.2, 0.06), 8, 5)
    beak = paint(_obj("Beak", beak), "#FF9E3D", "SmoothPlastic")
    anim(beak, (0, -0.4, -0.64), (1, 0, 0), None, kick(10))
    eyes = paint(blobs("Eyes", [((-0.2, -0.53, -0.38), (0.075, 0.05, 0.1)), ((0.2, -0.53, -0.38), (0.075, 0.05, 0.1))], 8, 5), "#22323F", "SmoothPlastic")
    anim(eyes, (0, -0.53, -0.38), (0, 0, 1), blink(4.2, 0.12))
    shine = paint(blobs("EyeShine", [((-0.18, -0.58, -0.34), (0.026, 0.016, 0.026)), ((0.22, -0.58, -0.34), (0.026, 0.016, 0.026))], 6, 4), "#FFFFFF", "SmoothPlastic")
    anim(shine, (0, -0.53, -0.38), (0, 0, 1), blink(4.2, 0.12), note="blinks with Eyes")
    for side, label in ((-1, "L"), (1, "R")):
        w = paint(blob("Wing_" + label, (side * 0.84, 0.14, -1.55), (0.12, 0.5, 0.33), 8, 6, Quaternion((1, 0, 0), 0.35)), "#FFD23C")
        anim(w, (side * 0.78, -0.22, -1.38), (0, side, 0), sway(6, 1.8), flare(30), lod_keep=True)
        ds.append(w)
    tail = paint(blob("TailFeather", (0, 0.94, -1.12), (0.2, 0.26, 0.1), 10, 5, Quaternion((1, 0, 0), -0.75)), "#FFD23C")
    anim(tail, (0, 0.74, -1.3), (0, 0, 1), sway(10, 1.2), kick(14))
    tb = bmesh.new()
    tube_bm(tb, spline([(0, -0.16, -0.06), (0, -0.2, 0.06), (0, -0.32, 0.12), (0, -0.4, 0.06), (0, -0.34, 0.0)], 10), [0.07, 0.06, 0.05, 0.04, 0.03, 0.025, 0.02, 0.016, 0.012, 0.01, 0.008], 6)
    tuft = paint(_obj("HeadTuft", tb), "#FFD23C")
    anim(tuft, (0, -0.16, -0.06), (1, 0, 0), sway(3, 2.2), kick(25))
    bubble = paint(blob("CrownBubble", (0, 0.04, 0.0), (0.13, 0.13, 0.13), 8, 6), "#EAFBFF")
    anim(bubble, (0, 0.04, 0.0), (0, 0, 1), bob(0.05, 1.5), hop(0.08))
    heart = [(0.0, -0.22), (0.2, -0.02), (0.22, 0.1), (0.14, 0.18), (0.05, 0.16), (0.0, 0.1), (-0.05, 0.16), (-0.14, 0.18), (-0.22, 0.1), (-0.2, -0.02)]
    hc = paint(slab("HeartCore", heart, 0.12, Matrix.Translation((0, -0.32, -1.5)), bevel=0.035, segments=1), "#FF7A9C", "Neon")
    anim(hc, (0, -0.32, -1.5), (0, 1, 0), pulse(0.1, 1.1), flash(0.2))
    ds = [beak, eyes, shine] + ds + [tail, tuft, bubble, hc]
    return body, ds


def montage(paths, out, cols=4, cell=384, bg=(0.09, 0.13, 0.22)):
    """Quick contact sheet with numpy (no labels)."""
    import numpy as np
    rows = math.ceil(len(paths) / cols)
    W, H = cols * cell, rows * cell
    canvas = np.zeros((H, W, 4), dtype=np.float32)
    canvas[:, :] = (*bg, 1)
    for i, p in enumerate(paths):
        img = bpy.data.images.load(p, check_existing=False)
        img.scale(cell, cell)
        px = np.array(img.pixels[:], dtype=np.float32).reshape(cell, cell, 4)
        bpy.data.images.remove(img)
        r, c = divmod(i, cols)
        y0 = H - (r + 1) * cell
        x0 = c * cell
        a = px[:, :, 3:4]
        canvas[y0:y0 + cell, x0:x0 + cell, :3] = px[:, :, :3] * a + canvas[y0:y0 + cell, x0:x0 + cell, :3] * (1 - a)
    img = bpy.data.images.new("_montage", W, H, alpha=True)
    img.pixels = canvas.ravel()
    img.filepath_raw = out
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    return out


def labeled_sheet(entries, out, title, cols=2, cell=300):
    """Before/after sheet. entries = [(label, [png, png, ...]), ...]; each entry is one group of images
    side by side with its label underneath. Rendered with EEVEE in a throwaway scene."""
    global COLLECTION
    per = len(entries[0][1])
    rows = math.ceil(len(entries) / cols)
    gw, gh = per * 1.0 + 0.25, 1.0 + 0.35
    W, H = cols * gw + 0.25, rows * gh + 0.45
    previous, old_col = bpy.context.window.scene, COLLECTION
    scene = bpy.data.scenes.new("V3Sheet")
    bpy.context.window.scene = scene
    COLLECTION = scene.name
    images = []
    try:
        with bpy.context.temp_override(scene=scene, view_layer=scene.view_layers[0]):
            def emit(name, color=None, image=None):
                mat = bpy.data.materials.new(name)
                mat.use_nodes = True
                nt = mat.node_tree
                nt.nodes.clear()
                out_n = nt.nodes.new("ShaderNodeOutputMaterial")
                em = nt.nodes.new("ShaderNodeEmission")
                if image is not None:
                    tex = nt.nodes.new("ShaderNodeTexImage")
                    tex.image = image
                    mix = nt.nodes.new("ShaderNodeMixShader")
                    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
                    nt.links.new(tex.outputs["Color"], em.inputs["Color"])
                    nt.links.new(tex.outputs["Alpha"], mix.inputs[0])
                    nt.links.new(tr.outputs[0], mix.inputs[1])
                    nt.links.new(em.outputs[0], mix.inputs[2])
                    nt.links.new(mix.outputs[0], out_n.inputs["Surface"])
                    try:
                        mat.surface_render_method = "BLENDED"
                    except Exception:
                        mat.blend_method = "BLEND"
                else:
                    em.inputs["Color"].default_value = (*color, 1)
                    nt.links.new(em.outputs[0], out_n.inputs["Surface"])
                return mat

            def text(body, x, y, size, color=(0.85, 0.9, 1.0)):
                cu = bpy.data.curves.new("T", "FONT")
                cu.body, cu.size, cu.align_x = body, size, "CENTER"
                ob = bpy.data.objects.new("T", cu)
                ob.location = (x, y, 0.01)
                ob.data.materials.append(emit("TM", color))
                scene.collection.objects.link(ob)

            for i, (label, paths) in enumerate(entries):
                r, c = divmod(i, cols)
                gx = 0.25 + c * gw
                gy = H - 0.45 - r * gh
                for j, p in enumerate(paths):
                    img = bpy.data.images.load(p, check_existing=False)
                    images.append(img)
                    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(gx + j * 1.0 + 0.5, gy - 0.5, 0))
                    plane = bpy.context.active_object
                    plane.data.materials.append(emit("IM", image=img))
                text(label, gx + per * 0.5, gy - 1.17, 0.1)
            text(title, W / 2, H - 0.3, 0.13, (1, 1, 1))
            cam = bpy.data.objects.new("SheetCam", bpy.data.cameras.new("SheetCam"))
            cam.data.type, cam.data.ortho_scale = "ORTHO", max(W, H)
            cam.location = (W / 2, H / 2, 5)
            scene.collection.objects.link(cam)
            scene.camera = cam
            world = bpy.data.worlds.new("SheetWorld")
            world.use_nodes = True
            world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.012, 0.02, 0.045, 1)
            scene.world = world
            scene.render.engine = "BLENDER_EEVEE"
            scene.render.resolution_x = int(W * cell)
            scene.render.resolution_y = int(H * cell)
            scene.render.film_transparent = False
            scene.view_settings.view_transform = "Standard"
            scene.render.image_settings.file_format = "PNG"
            scene.render.filepath = out
            bpy.ops.render.render(write_still=True)
            return out
    finally:
        bpy.context.window.scene = previous
        COLLECTION = old_col
        for o in list(scene.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.scenes.remove(scene)
        for img in images:
            bpy.data.images.remove(img)


def before_after(gids, out, title):
    entries = []
    for g in gids:
        name = next(r["name"] for r in ROWS.values() if r["id"] == g)
        entries.append((f"{name}  ({RARITY[g]})  release_v2  |  v3  |  v3 3/4", [
            repo_path("assets", "icons", "release_v2", g + ".png"),
            os.path.join(v3_folder(g), g + "_icon.png"),
            repo_path("docs", "art", "glassy_revamp", "previews", g + "_v3_34.png")]))
    return labeled_sheet(entries, out, title)


# ------------------------------------------------------------------------------------------
# Batch 2: starters and first Rares
# ------------------------------------------------------------------------------------------

def inset(profile, d, z_lo, z_hi):
    """Liquid/fill profile: the body profile pulled in by d, clipped to [z_lo, z_hi], closed on the axis."""
    pts = [(max(r - d, 0.02), z) for r, z in profile if z_lo <= z <= z_hi and r > d]
    if not pts:
        raise ValueError("empty inset")
    return [(0, pts[0][1])] + pts + [(0, pts[-1][1])]


def crimp(obj, lobes, amount, below_z):
    for v in obj.data.vertices:
        if v.co.z < below_z and math.hypot(v.co.x, v.co.y) > 0.05:
            k = 1 + amount * math.cos(lobes * math.atan2(v.co.y, v.co.x))
            v.co.x *= k
            v.co.y *= k
    return obj


@builder("pop")
def b_pop(gid):
    h = 2.55
    ctrl = [(0, 0), (0.44, 0), (0.58, 0.06), (0.65, 0.2), (0.65, 0.4), (0.58, 0.56), (0.56, 0.68), (0.61, 0.8), (0.62, 1.3),
            (0.57, 1.5), (0.44, 1.7), (0.3, 1.88), (0.245, 2.02), (0.245, 2.22), (0.3, 2.26), (0.3, 2.35), (0, 2.35)]
    prof = chaikin(ctrl, fixed=(1, 12, 13, 14, 15), iterations=1)
    body = paint(lathe3("Body", prof, h, 18), "#8FE3FF", role="Body")
    cap = lathe3("Cap", [(0, 2.35), (0.3, 2.35), (0.34, 2.39), (0.34, 2.47), (0.3, 2.53), (0.2, 2.55), (0, 2.55)], h, 12)
    paint(crimp(cap, 6, 0.06, -0.06), "#ED5367", "SmoothPlastic")
    anim(cap, (0, 0, -0.2), (0, 0, 1), None, hop(0.08), lod_keep=True)
    fill = paint(lathe3("SodaFill", inset(prof, 0.07, 0.06, 1.42), h, 10, sharp_deg=None), "#45C3F5", alpha=0.55)
    anim(fill, (0, 0, 1.42 - h), (1, 0, 0), slosh(12))
    ds = [cap, fill]
    for i, (x, z, r) in enumerate(((-0.22, 0.66, 0.17), (0.2, 1.02, 0.2), (-0.1, 1.36, 0.16))):
        b = paint(blob(f"ChargeBubble_{i + 1}", (x, -0.42, z - h), (r, 0.12, r), 8, 5), "#EAFBFF")
        ds.append(b)
    return body, ds


@builder("jam")
def b_jam(gid):
    h = 2.05
    ctrl = [(0, 0), (0.67, 0), (0.85, 0.08), (0.94, 0.24), (0.95, 0.42), (0.95, 1.26), (0.91, 1.46), (0.79, 1.6), (0.79, 1.69), (0.9, 1.72), (0.9, 1.8), (0, 1.8)]
    prof = chaikin(ctrl, fixed=(1, 7, 8, 9, 10), iterations=1)
    body = paint(lathe3("Body", prof, h, 20), "#FF6B8B", role="Body")
    cap = paint(lathe3("Cap", [(0, 1.8), (0.93, 1.8), (0.98, 1.84), (0.98, 1.98), (0.92, 2.05), (0, 2.05)], h, 20), "#F5C860", "Metal")
    cloth = lathe3("ClothCover", [(0, 2.08), (0.7, 2.08), (0.96, 2.04), (1.04, 1.96), (1.07, 1.8), (1.06, 1.68), (1.0, 1.68), (1.0, 1.8), (0.97, 1.92), (0.9, 2.0), (0.6, 2.03), (0, 2.03)], h, 16, sharp_deg=None)
    for v in cloth.data.vertices:
        a = math.atan2(v.co.y, v.co.x)
        if v.co.z < -0.18:
            v.co.z += 0.06 * (1 + math.cos(8 * a))
            k = 1 + 0.03 * math.cos(8 * a)
            v.co.x *= k
            v.co.y *= k
    paint(cloth, "#FF9DB8", "SmoothPlastic")
    anim(cloth, (0, 0, 0), (1, 0, 0), sway(3, 2.4), hop(0.06), lod_keep=True)
    tb = bmesh.new()
    torus_bm(tb, (0, 0, 1.79 - h), 1.035, 0.035, 16, 4)
    tie = paint(_obj("TieBand", tb), "#FFFFFF", "SmoothPlastic")
    anim(tie, (0, 0, 0), (1, 0, 0), sway(3, 2.4), hop(0.06), note="moves with ClothCover")
    jam = paint(lathe3("JamInsert", inset(prof, 0.08, 0.06, 1.18), h, 12, sharp_deg=None), "#E0325A", alpha=0.7)
    anim(jam, (0, 0, 1.18 - h), (1, 0, 0), slosh(10, 0.25))
    berries = paint(blobs("Berries", [((0.32, -0.45, 0.62 - h), (0.17, 0.15, 0.2)), ((-0.36, -0.38, 0.42 - h), (0.15, 0.13, 0.17))], 6, 4), "#FF4D6D", "SmoothPlastic")
    anim(berries, (0, 0, 1.18 - h), (1, 0, 0), slosh(10, 0.25), note="moves with JamInsert")
    return body, [cap, cloth, tie, jam, berries]


@builder("prism")
def b_prism(gid):
    h = 2.60
    prof = [(0, 0), (0.48, 0), (0.62, 0.06), (0.74, 0.2), (0.81, 0.42), (0.81, 1.16), (0.74, 1.3), (0.44, 1.56), (0.26, 1.72), (0.24, 1.9), (0.31, 1.93), (0.31, 1.96), (0, 1.96)]
    body = paint(lathe3("Body", prof, h, 8, flat=True), "#C9A8FF", role="Body")
    stopper = lathe3("GemStopper", [(0, 1.94), (0.18, 1.94), (0.4, 2.12), (0.44, 2.22), (0.3, 2.42), (0.1, 2.56), (0, 2.6)], h, 8, flat=True)
    paint(stopper, "#E2CCFF")
    anim(stopper, (0, 0, 1.95 - h), (1, 0, 0), sway(3, 2.2), kick(12), lod_keep=True)
    lens = paint(blob("RayLens", (0, -0.79, 0.86 - h), (0.27, 0.06, 0.29), 12, 6), "#B9F4FF")
    sp = paint(slab("Sparkle", star_points(4, 0.13, 0.035), 0.04, Matrix.Translation((0.5, -0.2, 2.25 - h)), bevel=0.012, segments=1), "#FFFFFF", "Neon")
    anim(sp, (0, 0, 2.25 - h), (0, 0, 1), spin(70), spin_boost(300))
    core = paint(lathe3("FacetCore", [(0, 0.3), (0.32, 0.42), (0.4, 0.8), (0.32, 1.18), (0, 1.3)], h, 8, flat=True), "#F3E6FF", alpha=0.5)
    return body, [stopper, lens, sp, core]


@builder("crescent_axe")
def b_crescent_axe(gid):
    h = 2.40
    ctrl = [(0, 0), (0.52, 0), (0.77, 0.13), (0.89, 0.43), (0.85, 1.08), (0.65, 1.39), (0.3, 1.61), (0.27, 1.9), (0.36, 1.93), (0.36, 1.96), (0, 1.96)]
    prof = chaikin(ctrl, fixed=(1, 6, 7, 8, 9), iterations=1)
    body = paint(lathe3("Body", prof, h, 22), "#B69BFF", role="Body")

    def crescent(R, w, n=7, tip_deg=60):
        """Simple crescent outline opening to +x: outer arc of radius R, inner arc through both tips."""
        t = math.radians(tip_deg)
        p1 = (R * math.cos(t), R * math.sin(t))
        a = -R + w
        k = a - p1[0]
        rho = -(k * k + p1[1] ** 2) / (2 * k)
        cx = a + rho
        outer = [(R * math.cos(t + (math.tau - 2 * t) * i / n), R * math.sin(t + (math.tau - 2 * t) * i / n)) for i in range(n + 1)]
        f1 = math.atan2(p1[1], p1[0] - cx)
        inner = [(cx + rho * math.cos(-f1 - (math.tau - 2 * f1) * i / n), rho * math.sin(-f1 - (math.tau - 2 * f1) * i / n)) for i in range(1, n)]
        return outer + inner
    sb = bmesh.new()
    lathe_tmp = lathe3("_plug", [(0, 1.84), (0.24, 1.84), (0.26, 2.02), (0.2, 2.06), (0, 2.06)], h, 12)
    sb.from_mesh(lathe_tmp.data)
    bpy.data.objects.remove(lathe_tmp, do_unlink=True)
    pts = crescent(0.28, 0.12, 7, 70)
    slab_bm(sb, pts, 0.14, 0.03, 1, Matrix.Translation((-0.06, 0, 2.27 - h)), clamp=True)
    stopper = paint(_obj("CrescentStopper", sb, sharp_deg=50), "#E2DBFF")
    anim(stopper, (0, 0, 1.9 - h), (0, 1, 0), sway(5, 2.0), kick(15), lod_keep=True)
    tb = bmesh.new()
    torus_bm(tb, (0, 0, 1.45 - h), 0.62, 0.06, 20, 4)
    band = paint(_obj("ShoulderBand", tb), "#C9DDF2", "Metal")
    em_pts = [(u * 1.0, v) for u, v in crescent(0.24, 0.09, 6, 70)]
    emblem = paint(slab("CrescentEmblem", em_pts, 0.05, Matrix.Translation((0, -0.83, 0.82 - h)) @ Matrix.Rotation(-0.3, 4, "Y"), bevel=0.015, segments=1, clamp=True), "#F1E8FF", "Neon")
    anim(emblem, (0, -0.83, 0.82 - h), (0, 1, 0), pulse(0.06, 1.8), flash(0.2))
    handle = paint(tube("AxeHandle", [(0.96, 0, -1.9), (0.97, 0, -1.3), (0.96, 0, -0.62)], [0.07, 0.065, 0.06], 8), "#9BCDEB")
    head_pts = [(-u, v) for u, v in crescent(0.44, 0.17, 8, 62)]
    head = paint(slab("AxeHead", head_pts, 0.14, Matrix.Translation((1.27, 0, -0.84)), bevel=0.04, segments=1, clamp=True), "#D2CBFF")
    for o in (handle, head):
        o["effect_only"] = True
        anim(o, (0.96, 0, -1.7), (0, 1, 0), None, None, note="effect-only; the Crescent Sweep kit swings it about this pivot")
    return body, [stopper, band, emblem, handle, head]


@builder("briar_flask")
def b_briar_flask(gid):
    h = 2.65
    ctrl = [(0, 0), (0.35, 0.03), (0.6, 0.21), (0.79, 0.56), (0.8, 0.82), (0.69, 1.2), (0.48, 1.56), (0.24, 1.91), (0.21, 2.12), (0.28, 2.16), (0.28, 2.23), (0, 2.23)]
    prof = chaikin(ctrl, fixed=(8, 9, 10), iterations=1)
    body = paint(lathe3("Body", prof, h, 18), "#35CB97", role="Body")
    ds = []
    plug = bmesh.new()
    tmp = lathe3("_plug", [(0, 2.1), (0.2, 2.1), (0.22, 2.28), (0, 2.3)], h, 10)
    plug.from_mesh(tmp.data)
    bpy.data.objects.remove(tmp, do_unlink=True)
    leaf = [(0.0, 0.0), (-0.16, 0.12), (-0.2, 0.3), (-0.08, 0.46), (0.06, 0.5), (0.14, 0.34), (0.12, 0.14)]
    slab_bm(plug, leaf, 0.07, 0.025, 1, Matrix.Translation((0, 0, 2.24 - h)) @ Matrix.Rotation(-0.35, 4, "Y"))
    stopper = paint(_obj("LeafStopper", plug, sharp_deg=55), "#8EEDB2")
    anim(stopper, (0, 0, 2.2 - h), (0, 1, 0), sway(4, 2.2), kick(12))
    for i in range(3):
        rot = Matrix.Rotation(i * math.tau / 3, 3, "Z")
        path = [rot @ Vector(p) for p in spline([(0.66, 0, -1.6), (0.9, 0, -1.5), (1.05, 0, -1.36), (1.12, 0, -1.2)], 6)]
        tb = bmesh.new()
        tube_bm(tb, path, [0.13 * (1 - k / (len(path) - 1)) + 0.012 for k in range(len(path))], 7)
        thorn = paint(_obj(f"Thorn_{i + 1}", tb), "#A0F7CC")
        anim(thorn, rot @ Vector((0.64, 0, -1.5)), rot @ Vector((0, 1, 0)), None, kick(10), note="client grows it from AnimationPivot by charge")
        ds.append(thorn)
    vine = []
    for k in range(18):
        t = k / 17
        z = 0.35 + t * 1.25
        r = max(rr for rr, zz in prof if abs(zz - z) < 0.12) + 0.035 if any(abs(zz - z) < 0.12 for rr, zz in prof) else 0.6
        a = t * math.tau * 1.15 + 0.4
        vine.append((r * math.cos(a), r * math.sin(a), z - h))
    vb = bmesh.new()
    tube_bm(vb, vine, 0.04, 4)
    vine_o = paint(_obj("Vine", vb), "#2FA86A", "SmoothPlastic")
    leaf_pts = [(0.0, 0.0), (0.1, 0.07), (0.2, 0.06), (0.28, 0.0), (0.2, -0.06), (0.1, -0.07)]
    for i, k in enumerate((6, 13)):
        p = Vector(vine[k])
        a = math.atan2(p.y, p.x)
        m = Matrix.Translation(p) @ Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(0.5 if i else -0.4, 4, "Y")
        lf = paint(slab(f"Leaf_{i + 1}", leaf_pts, 0.035, m, bevel=0.012, segments=1), "#5FD38E")
        anim(lf, p, Matrix.Rotation(a, 3, "Z") @ Vector((0, 1, 0)), sway(6, 1.7, i * 1.3), kick(14))
        ds.append(lf)
    bud = bmesh.new()
    for j in range(4):
        a = j * math.tau / 4 + 0.4
        ellipsoid_bm(bud, (0.09 * math.cos(a), -0.1 + 0.09 * math.sin(a), 0.72 - h), (0.12, 0.1, 0.16), 6, 4)
    ellipsoid_bm(bud, (0, -0.1, 0.78 - h), (0.1, 0.1, 0.14), 6, 4)
    rose = paint(_obj("RoseSeed", bud), "#FF7AB6", "Neon")
    anim(rose, (0, -0.1, 0.72 - h), (0, 0, 1), pulse(0.07, 1.6), flash(0.2), lod_keep=True)
    return body, [stopper] + ds[:3] + [vine_o] + ds[3:] + [rose]


@builder("arc_coil")
def b_arc_coil(gid):
    h = 2.30
    ctrl = [(0, 0), (0.49, 0), (0.7, 0.13), (0.87, 0.43), (0.91, 0.78), (0.83, 1.12), (0.61, 1.41), (0.33, 1.57), (0.3, 1.88), (0, 1.88)]
    prof = chaikin(ctrl, fixed=(1, 7, 8), iterations=1)
    body = paint(lathe3("Body", prof, h, 20), "#6BE9FF", role="Body")
    cap = paint(lathe3("Cap", [(0, 1.84), (0.36, 1.84), (0.39, 1.9), (0.39, 2.06), (0.3, 2.12), (0.12, 2.14), (0.1, 2.2), (0, 2.2)], h, 12), "#D99561", "Metal")
    term = paint(blob("Terminal", (0, 0, 2.24 - h), (0.16, 0.16, 0.15), 10, 7), "#EAFBFF")
    anim(term, (0, 0, 2.24 - h), (0, 0, 1), pulse(0.06, 0.8), flash(0.15))
    ds = [cap, term]
    for i in range(3):
        z0, r = 0.72 + i * 0.27, 0.95 - i * 0.07
        pts = []
        for k in range(17):
            a = k / 16 * 5.4
            pts.append((r * math.cos(a), r * math.sin(a), z0 - h + 0.1 * k / 16))
        cb = bmesh.new()
        tube_bm(cb, pts, 0.06, 4)
        ds.append(paint(_obj(f"CoilSegment_{i + 1}", cb), "#BBFAFF"))
    for i in range(2):
        a0 = i * math.pi + 0.5
        zig = []
        for k in range(5):
            rr = 0.22 + k * 0.11
            zig.append((rr * math.cos(a0), rr * math.sin(a0), 2.18 - h + (0.06 if k % 2 else -0.06) - k * 0.04))
        sb = bmesh.new()
        tube_bm(sb, zig, [0.035, 0.03, 0.025, 0.02, 0.012], 5)
        spark = paint(_obj(f"Spark_{i + 1}", sb, smooth=False), "#9FF3FF", "Neon")
        anim(spark, (0, 0, 2.24 - h), (0, 0, 1), spin(140 if i == 0 else -110), flash(0.12), extra_idle=[flicker(0.25, 12)], lod_keep=(i == 0))
        ds.append(spark)
    return body, ds


# ------------------------------------------------------------------------------------------
# Batch 3: remaining Rares and Uncommons
# ------------------------------------------------------------------------------------------

def rounded_box(name, size, at, bevel=0.06, segments=2, rot=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=segments, affect="EDGES", profile=0.5)
    m = Matrix.Translation(Vector(at)) @ (rot.to_matrix().to_4x4() if rot is not None else Matrix.Identity(4))
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj(name, bm, sharp_deg=None)


def lathe_bm(bm, profile, h, segments):
    tmp = lathe3("_tmp_lathe", profile, h, segments, sharp_deg=None)
    bm.from_mesh(tmp.data)
    mesh = tmp.data
    bpy.data.objects.remove(tmp, do_unlink=True)
    bpy.data.meshes.remove(mesh)
    return bm


@builder("hourglass")
def b_hourglass(gid):
    h = 2.65
    ctrl = [(0, 0.15), (0.68, 0.15), (0.75, 0.29), (0.66, 0.62), (0.43, 0.92), (0.19, 1.22), (0.17, 1.36), (0.39, 1.68), (0.66, 2.05), (0.75, 2.34), (0.68, 2.49), (0, 2.49)]
    prof = chaikin(ctrl, fixed=(1, 2, 9, 10), iterations=1)
    body = paint(lathe3("Body", prof, h, 16), "#F8C16B", role="Body")
    frame = "#AD91DC"
    caps = []
    for label, z, flip in (("Bottom", 0.02, False), ("Top", 2.49, True)):
        p = [(0, 0), (0.7, 0), (0.8, 0.03), (0.84, 0.08), (0.8, 0.13), (0.72, 0.16), (0, 0.16)]
        p = [(r, z + (0.16 - dz if flip else dz)) for r, dz in p]
        if flip:
            p = list(reversed(p))
        cb = bmesh.new()
        lathe_bm(cb, p, h, 12)
        for k in range(3):
            a = k * math.tau / 3 + math.pi / 6
            ellipsoid_bm(cb, (0.6 * math.cos(a), 0.6 * math.sin(a), (z - 0.04 if not flip else z + 0.2) - h), (0.08, 0.08, 0.06), 6, 3)
        cap = paint(_obj("FrameCap_" + label, cb), frame)
        anim(cap, (0, 0, 1.33 - h), (0, 1, 0), None, kick(4), note="client flips the whole frame about the body centre (Hourglass kit)")
        caps.append(cap)
    posts = []
    for i, x in enumerate((-0.76, 0.76)):
        zs = [0.16 + k * (2.33 / 10) for k in range(11)]
        rs = [0.07 + 0.03 * math.sin(k / 10 * math.pi * 3) ** 2 for k in range(11)]
        pb = bmesh.new()
        tube_bm(pb, [(x, 0.0, z - h) for z in zs], rs, 5)
        post = paint(_obj(f"FramePost_{i + 1}", pb), frame)
        anim(post, (0, 0, 1.33 - h), (0, 1, 0), None, kick(4), note="flips with the frame")
        posts.append(post)
    sand = paint(lathe3("SandInsert", chaikin([(0, 0.24), (0.6, 0.24), (0.62, 0.36), (0.42, 0.56), (0.12, 0.72), (0, 0.74)], iterations=1), h, 10, sharp_deg=None), "#F6D36E", "SmoothPlastic")
    anim(sand, (0, 0, 0.24 - h), (0, 0, 1), None, squash(0.92), note="client scales it by charge")
    top = paint(lathe3("SandTop", [(0, 1.5), (0.3, 1.74), (0.5, 1.92), (0.52, 1.98), (0, 1.98)], h, 12, sharp_deg=None), "#F6D36E", "SmoothPlastic")
    anim(top, (0, 0, 1.4 - h), (0, 0, 1), pulse(0.02, 2.0))
    stream = paint(tube("SandStream", [(0, 0, 1.5 - h), (0, 0, 0.72 - h)], 0.03, 6), "#F6D36E", "SmoothPlastic")
    anim(stream, (0, 0, 1.5 - h), (0, 0, 1), flicker(0.15, 10), lod_keep=True)
    return body, caps + posts + [sand, top, stream]


@builder("frostglobe")
def b_frostglobe(gid):
    h = 2.40
    ctrl = [(0, 0.25), (0.48, 0.25), (0.73, 0.42), (0.91, 0.75), (0.95, 1.1), (0.88, 1.49), (0.66, 1.82), (0.34, 2.05), (0, 2.13)]
    prof = chaikin(ctrl, fixed=(1,), iterations=1)
    body = paint(lathe3("Body", prof, h, 22), "#9ECFFF", role="Body")
    collar = paint(lathe3("SnowCollar", chaikin([(0, 0), (0.72, 0), (0.82, 0.08), (0.84, 0.18), (0.76, 0.28), (0.6, 0.32), (0, 0.32)], fixed=(1,), iterations=1), h, 18, sharp_deg=None), "#EAFBFF", "SmoothPlastic")
    drift = paint(blob("SnowDrift", (0, 0, 0.36 - h), (0.66, 0.66, 0.16), 12, 6), "#FFFFFF", "SmoothPlastic")
    cb = bmesh.new()
    for x, y, z, r, ht, tilt in ((0, 0, 0.98, 0.15, 0.95, 0.0), (-0.24, 0.05, 0.74, 0.1, 0.55, 0.35), (0.25, -0.04, 0.7, 0.09, 0.48, -0.4)):
        gem_bm(cb, (x, y, z - h), r, ht, 6, Matrix.Rotation(tilt, 4, "Y"))
    sprout = paint(_obj("CrystalSprout", cb, smooth=False), "#C8F7FF", "Neon")
    anim(sprout, (0, 0, 0.5 - h), (0, 0, 1), pulse(0.05, 2.2), flash(0.2))
    rng = random.Random(11)
    fb = bmesh.new()
    for k in range(9):
        a = k * math.tau / 9 + rng.uniform(-0.2, 0.2)
        rr = rng.uniform(0.42, 0.72)
        z = rng.uniform(0.7, 1.75)
        m = Matrix.Translation((rr * math.cos(a), rr * math.sin(a), z - h)) @ Matrix.Rotation(a, 4, "Z")
        slab_bm(fb, star_points(3, 0.07, 0.025), 0.02, 0, 1, m)
    flakes = paint(_obj("SnowSwirl", fb, smooth=False), "#FFFFFF", "SmoothPlastic")
    anim(flakes, (0, 0, 1.2 - h), (0, 0, 1), spin(30), spin_boost(220), lod_keep=True)
    pearl = paint(blob("HangPearl", (0, 0, -0.12), (0.13, 0.13, 0.12), 10, 6), "#EAFBFF")
    anim(pearl, (0, 0, 0), (1, 0, 0), None, kick(10))
    return body, [collar, drift, sprout, flakes, pearl]


@builder("mason_jar")
def b_mason_jar(gid):
    h = 2.25
    ctrl = [(0, 0), (0.62, 0), (0.83, 0.08), (0.91, 0.24), (0.88, 0.39), (0.85, 0.46), (0.85, 1.36), (0.89, 1.44), (0.85, 1.54), (0.76, 1.75), (0.76, 1.96), (0, 1.96)]
    prof = chaikin(ctrl, fixed=(1, 5, 6, 9, 10), iterations=1)
    body = paint(lathe3("Body", prof, h, 20), "#BFEFFF", role="Body")
    cap = paint(lathe3("Cap", [(0, 1.96), (0.86, 1.96), (0.9, 2.0), (0.9, 2.18), (0.84, 2.25), (0, 2.25)], h, 18), "#F5C860", "Metal")
    anim(cap, (0, 0, 0), (0, 0, 1), None, kick(8), note="hit = a little quarter-turn twist")
    tpts = [(0.785 * math.cos(k / 24 * math.tau * 1.6), 0.785 * math.sin(k / 24 * math.tau * 1.6), 1.78 + 0.14 * k / 24 - h) for k in range(25)]
    th = bmesh.new()
    tube_bm(th, tpts, 0.03, 4)
    threads = paint(_obj("Threads", th), "#D8F6FF")
    ds = [cap, threads]
    for i, z in enumerate((0.57, 1.19)):
        sb = bmesh.new()
        torus_bm(sb, (0, 0, z - h), 0.86, 0.035, 18, 4)
        ds.append(paint(_obj(f"StressBand_{i + 1}", sb), "#C3F9ED"))
    for i, (a, z) in enumerate(((0.8, 0.9), (3.6, 1.3))):
        p = (0.42 * math.cos(a), 0.42 * math.sin(a), z - h)
        fb = bmesh.new()
        ellipsoid_bm(fb, p, (0.095, 0.095, 0.095), 8, 5)
        ff = paint(_obj(f"Firefly_{i + 1}", fb), "#FFF07A", "Neon")
        anim(ff, (0, 0, z - h), (0, 0, 1), spin(35 if i == 0 else -28), flash(0.2), extra_idle=[bob(0.08, 1.7, i * 2.0), pulse(0.25, 0.9, i)], lod_keep=(i == 0))
        ds.append(ff)
    return body, ds


@builder("hot_sauce")
def b_hot_sauce(gid):
    h = 2.66
    ctrl = [(0, 0), (0.33, 0), (0.47, 0.09), (0.53, 0.25), (0.51, 1.17), (0.45, 1.4), (0.28, 1.65), (0.19, 1.86), (0.19, 2.34), (0, 2.34)]
    prof = chaikin(ctrl, fixed=(1, 7, 8), iterations=1)
    body = paint(lathe3("Body", prof, h, 18), "#FF5A4E", role="Body")
    cap = lathe3("Cap", [(0, 2.34), (0.22, 2.34), (0.25, 2.38), (0.25, 2.54), (0.2, 2.58), (0.12, 2.6), (0.1, 2.66), (0, 2.66)], h, 12)
    paint(crimp(cap, 6, 0.05, -0.12), "#354865", "SmoothPlastic")
    anim(cap, (0, 0, -0.32), (0, 0, 1), None, hop(0.06))
    band = lathe3("FlameBand", [(0.535, 0.62), (0.545, 0.62), (0.545, 1.0), (0.535, 1.0)], h, 18, sharp_deg=None)
    bm = _bm_from_object(band)
    for v in bm.verts:
        if v.co.z > 0.8 - h:
            a = math.atan2(v.co.y, v.co.x)
            v.co.z += 0.1 * max(0.0, math.cos(3 * a)) ** 2
    bm2 = bmesh.new()
    lathe_bm(bm2, [(0, 0.62), (0.535, 0.62), (0.555, 0.64), (0.555, 0.98), (0.535, 1.0), (0, 1.0)], h, 18)
    bm.free()
    bpy.data.objects.remove(band, do_unlink=True)
    for v in bm2.verts:
        if v.co.z > 0.9 - h and math.hypot(v.co.x, v.co.y) > 0.1:
            a = math.atan2(v.co.y, v.co.x)
            v.co.z += 0.14 * max(0.0, math.cos(3 * a + math.pi / 2)) ** 3
    band = paint(_obj("FlameBand", bm2, sharp_deg=None), "#FFD36E", "SmoothPlastic")
    ds = [cap, band]
    for i, x in enumerate((-0.2, 0.0, 0.2)):
        eb = bmesh.new()
        slab_bm(eb, [(0, -0.09), (0.06, -0.03), (0.05, 0.04), (0.0, 0.11), (-0.05, 0.04), (-0.06, -0.03)], 0.04, 0.012, 1,
                Matrix.Translation((x, -0.53, 1.42 - h + (0.04 if i == 1 else 0))))
        ds.append(paint(_obj(f"Ember_{i + 1}", eb), "#FFBD62", "SmoothPlastic"))
    ch = bmesh.new()
    path = spline([(0.2, -0.12, 1.84 - h), (0.27, -0.2, 1.62 - h), (0.32, -0.26, 1.42 - h), (0.27, -0.27, 1.27 - h)], 8)
    tube_bm(ch, path, [0.06, 0.085, 0.09, 0.085, 0.075, 0.06, 0.045, 0.03, 0.015], 7)
    chili = paint(_obj("ChiliCharm", ch), "#E8242E", "SmoothPlastic")
    anim(chili, (0.2, -0.12, 1.86 - h), (0, 1, 0), sway(10, 1.5), kick(25), lod_keep=True)
    st = bmesh.new()
    tube_bm(st, [(0.19, -0.11, 1.95 - h), (0.2, -0.12, 1.84 - h), (0.23, -0.15, 1.8 - h)], [0.03, 0.035, 0.025], 5)
    stem = paint(_obj("ChiliStem", st), "#3FAE4C", "SmoothPlastic")
    anim(stem, (0.2, -0.12, 1.86 - h), (0, 1, 0), sway(10, 1.5), kick(25), note="moves with ChiliCharm")
    ds += [chili, stem]
    return body, ds


@builder("crystal_tumbler")
def b_crystal_tumbler(gid):
    h = 2.05
    prof = [(0, 0), (0.56, 0), (0.74, 0.13), (0.77, 0.29), (0.69, 0.43), (0.7, 1.58), (0.79, 1.9), (0.79, 2.05), (0.66, 2.05), (0.6, 1.65), (0.56, 0.39), (0.48, 0.25), (0, 0.25)]
    body = paint(lathe3("Body", prof, h, 12, flat=True), "#D7E9FF", role="Body")
    rb = bmesh.new()
    torus_bm(rb, (0, 0, -0.05), 0.72, 0.055, 24, 5)
    rim = paint(_obj("ThickRim", rb), "#EAFBFF")
    mirror = paint(slab("MirrorFacet", [(-0.27, -1.54), (0.27, -1.54), (0.32, -0.45), (-0.32, -0.45)], 0.04, Matrix.Translation((0, -0.665, 0)), bevel=0.015, segments=1), "#C4E9FF")
    ice = paint(rounded_box("IceCube", (0.48, 0.48, 0.46), (0.06, -0.04, 1.1 - h), 0.09, 2, Quaternion((0.3, 0.2, 1), 0.5)), "#BFE6FF", transmission=0.35)
    anim(ice, (0.06, 0.02, 1.08 - h), (0, 0, 1), spin(18), hop(0.1), extra_idle=[bob(0.05, 1.9)], lod_keep=True)
    return body, [rim, mirror, ice]


@builder("chime")
def b_chime(gid):
    h = 2.50
    ctrl = [(0, 0), (0.91, 0), (0.99, 0.11), (0.94, 0.26), (0.73, 0.55), (0.61, 1.2), (0.49, 1.61), (0.29, 1.91), (0.25, 2.3), (0, 2.3)]
    prof = chaikin(ctrl, fixed=(1, 8), iterations=1)
    body = paint(lathe3("Body", prof, h, 22), "#80E7DE", role="Body")
    clap = bmesh.new()
    tube_bm(clap, [(0, -0.3, 0.62 - h), (0, -0.3, 0.3 - h)], 0.04, 5)
    ellipsoid_bm(clap, (0, -0.3, 0.22 - h), (0.2, 0.2, 0.2), 10, 6)
    clapper = paint(_obj("Clapper", clap), "#F8E6B0")
    clapper["animation_pivot"] = [0, -0.3, 0.62 - h]
    anim(clapper, (0, -0.3, 0.62 - h), (1, 0, 0), sway(6, 1.3), kick(30), lod_keep=True)
    rb = bmesh.new()
    torus_bm(rb, (0, 0, 0.12 - h), 0.95, 0.07, 24, 5)
    rim = paint(_obj("BellRim", rb), "#C5FFF5")
    cb = bmesh.new()
    torus_bm(cb, (0, 0, 2.38 - h), 0.11, 0.045, 12, 5, Matrix.Rotation(math.pi / 2, 4, "X"))
    lathe_bm(cb, [(0, 2.28), (0.24, 2.28), (0.27, 2.32), (0.18, 2.36), (0, 2.36)], h, 12)
    crown = paint(_obj("Crown", cb), "#C5FFF5")
    bow = bmesh.new()
    for s in (-1, 1):
        slab_bm(bow, [(0, 0), (s * 0.12, 0.1), (s * 0.24, 0.08), (s * 0.26, -0.04), (s * 0.14, -0.08)][::s], 0.05, 0.02, 1, Matrix.Translation((0, -0.27, 2.12 - h)))
        slab_bm(bow, [(0, 0), (s * 0.08, -0.08), (s * 0.13, -0.3), (s * 0.05, -0.26), (s * 0.02, -0.08)][::s], 0.04, 0.015, 1, Matrix.Translation((0, -0.27, 2.12 - h)))
    ellipsoid_bm(bow, (0, -0.28, 2.12 - h), (0.06, 0.04, 0.06), 6, 4)
    centre = Vector((0, -0.27, 2.12 - h))
    for v in bow.verts:
        v.co = centre + (v.co - centre) * 1.7 + Vector((0, -0.05, 0))
    ribbon = paint(_obj("Ribbon", bow), "#FF8FB0", "SmoothPlastic")
    anim(ribbon, (0, -0.27, 2.12 - h), (0, 1, 0), sway(5, 1.6), kick(12))
    return body, [clapper, rim, crown, ribbon]
