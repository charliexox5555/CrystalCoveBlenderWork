"""Flyers v3: premium rebuild of the four standard flyers (docs/art/FLYERS_V3.md).

Headless:
    /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/blender/build_flyers_v3.py -- [ids] [--render] [--samples N]

Writes assets/blender/round_cosmetics/flyers_v3/<id>/{<id>.fbx, <id>.blend, manifest.json, <id>_preview.png}
and flyers_v3/manifest.json (all four). Refuses nothing: v3 is the working revision; Studio installs read
the manifest, so rebuild before re-uploading.

Axes: 1 BU = 1 stud, Z up, nose +Y (Roblox -Z). Origin = rider contact point (deck top under the feet,
or seat top under the hips). Roblox coords = (x, z, -y). Every moving part is its own mesh; pivots,
materials and motion attributes go to manifest.json in Roblox coords, relative to the part's bounds
centre (MeshPart CFrame) where noted.
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

REPO = os.environ.get("GLASSCLASH_REPO") or os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(REPO, "assets", "blender", "round_cosmetics", "flyers_v3")
TAU = math.pi * 2

# ---------------------------------------------------------------------------------------------
# Palette (Studio values; previews approximate them)
# ---------------------------------------------------------------------------------------------
PEARL, GOLD, NAVY, WHITE = "#F4F1EA", "#F2C46B", "#2A3554", "#FFFFFF"


def hex_rgb(h):
    h = h.lstrip("#")
    srgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb)


def to_roblox(v):
    return [round(v[0], 5), round(v[2], 5), round(-v[1], 5)]


# ---------------------------------------------------------------------------------------------
# Geometry
# ---------------------------------------------------------------------------------------------

def catmull(points, u):
    """Piecewise Catmull-Rom through (u, value) control points, u in [0, 1]."""
    u = min(max(u, points[0][0]), points[-1][0])
    for i in range(len(points) - 1):
        if u <= points[i + 1][0]:
            break
    p0 = points[max(i - 1, 0)][1]
    p1, p2 = points[i][1], points[i + 1][1]
    p3 = points[min(i + 2, len(points) - 1)][1]
    span = points[i + 1][0] - points[i][0]
    t = 0 if span == 0 else (u - points[i][0]) / span
    t2, t3 = t * t, t * t * t
    return 0.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)


def spaced(n, ease=0.5):
    """n+1 parameters in [0, 1], denser at both ends (ease 0 = uniform, 1 = full cosine)."""
    return [(1 - ease) * (i / n) + ease * (0.5 - 0.5 * math.cos(math.pi * i / n)) for i in range(n + 1)]


def superellipse(phi, e):
    c, s = math.cos(phi), math.sin(phi)
    return (math.copysign(abs(c) ** (2 / e), c), math.copysign(abs(s) ** (2 / e), s))


def loft(frames, n=16, exp=2.0, cap=True, closed=False, phase=0.0):
    """frames: [(centre, U, V, a, b_top, b_bottom[, exp])]. Superellipse rings -> closed tube bmesh."""
    bm = bmesh.new()
    rings = []
    for f in frames:
        c, U, V, a, bt, bb = f[:6]
        e = f[6] if len(f) > 6 else exp
        ring = []
        for j in range(n):
            x, y = superellipse(TAU * j / n + phase, e)
            ring.append(bm.verts.new(c + U * (a * x) + V * ((bt if y >= 0 else bb) * y)))
        rings.append(ring)
    pairs = list(zip(rings, rings[1:]))
    if closed:
        pairs.append((rings[-1], rings[0]))
    for r0, r1 in pairs:
        for j in range(n):
            bm.faces.new((r0[j], r0[(j + 1) % n], r1[(j + 1) % n], r1[j]))
    if cap and not closed:
        for ring, f, flip in ((rings[0], frames[0], True), (rings[-1], frames[-1], False)):
            tip = bm.verts.new(f[0])
            for j in range(n):
                face = (ring[j], ring[(j + 1) % n], tip)
                bm.faces.new(face[::-1] if flip else face)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def frames_along(points, sizes, up_hint=Vector((0, 0, 1))):
    """Parallel-transport frames along a polyline. sizes: [(a, b_top, b_bottom)] per point."""
    out = []
    prev_u = None
    for i, p in enumerate(points):
        t = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        if prev_u is None:
            u = up_hint.cross(t)
            if u.length < 1e-4:
                u = Vector((1, 0, 0)).cross(t)
            u.normalize()
        else:
            u = (prev_u - t * prev_u.dot(t)).normalized()
        v = t.cross(u).normalized()
        prev_u = u
        a, bt, bb = sizes[i]
        out.append((p, u, v, a, bt, bb))
    return out


def tube(points, radius, n=8, cap=True, closed=False, flat=1.0, exp=2.0, up_hint=Vector((0, 0, 1))):
    radii = radius if isinstance(radius, (list, tuple)) else [radius] * len(points)
    sizes = [(r, r * flat, r * flat) for r in radii]
    return loft(frames_along(points, sizes, up_hint), n=n, exp=exp, cap=cap, closed=closed)


def lathe(profile, origin, axis, segs=24, exp=2.0, phase=0.0):
    """profile: [(r, h)] along axis from origin; ends with r ~ 0 are closed by the loft caps."""
    axis = Vector(axis).normalized()
    ref = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    U = ref.cross(axis).normalized()
    V = axis.cross(U).normalized()
    frames = [(Vector(origin) + axis * h, U, V, max(r, 1e-4), max(r, 1e-4), max(r, 1e-4)) for r, h in profile]
    return loft(frames, n=segs, exp=exp, phase=phase)


def sphere(centre, radius, segs=16, rings=10, scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=radius)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(centre), verts=bm.verts)
    return bm


def merge(*bms):
    out = bmesh.new()
    for bm in bms:
        tmp = bpy.data.meshes.new("_merge")
        bm.to_mesh(tmp)
        out.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
        bm.free()
    return out


def rrect(u, power=6.0):
    """Half-width factor of a rounded rectangle along u in [0, 1] (1 in the middle, 0 at the ends)."""
    return max(1 - abs(2 * u - 1) ** power, 0.0) ** (1 / power)


def bevel_bm(bm, offset=0.03, min_deg=20, segments=1):
    edges = [e for e in bm.edges if len(e.link_faces) == 2 and math.degrees(e.calc_face_angle(0)) > min_deg]
    if edges:
        bmesh.ops.bevel(bm, geom=edges, offset=offset, segments=segments, affect="EDGES", profile=0.5, clamp_overlap=True)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


# ---------------------------------------------------------------------------------------------
# Scene objects
# ---------------------------------------------------------------------------------------------
PARTS = []  # (obj, spec)
SCALE = [1.0]  # uniform build scale about the origin (contact point), applied to meshes, pivots and attachments


def material(name, color, kind):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    p = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    rgb = hex_rgb(color)

    def put(key, value):
        for k in key if isinstance(key, (list, tuple)) else [key]:
            if k in p.inputs:
                p.inputs[k].default_value = value
                return

    put("Base Color", (*rgb, 1))
    if kind == "Glass":
        put("Transmission Weight", 0.85)
        put("Roughness", 0.04)
        put("IOR", 1.3)
        put(["Coat Weight", "Clearcoat"], 1.0)
        put(["Coat Roughness"], 0.03)
    elif kind == "Core":
        put("Transmission Weight", 0.35)
        put("Roughness", 0.18)
        put(["Subsurface Weight"], 0.2)
    elif kind == "Neon":
        put(["Emission Color", "Emission"], (*rgb, 1))
        put("Emission Strength", 4.0)
    elif kind == "Gold":
        put("Metallic", 0.9)
        put("Roughness", 0.22)
    elif kind == "Frost":
        put("Transmission Weight", 0.35)
        put("Roughness", 0.32)
        put(["Coat Weight", "Clearcoat"], 0.6)
        put(["Subsurface Weight"], 0.35)
    else:  # Pearl / Matte
        put("Roughness", 0.28 if kind == "Pearl" else 0.6)
        put(["Coat Weight", "Clearcoat"], 0.5 if kind == "Pearl" else 0.0)
    return mat


STUDIO = {
    # kind -> (Roblox Material, Transparency, Reflectance)
    "Glass": ("Glass", 0.3, 0.1),
    "Core": ("Glass", 0.08, 0.05),
    "Frost": ("Glass", 0.12, 0.05),
    "Neon": ("Neon", 0.0, 0.0),
    "Gold": ("SmoothPlastic", 0.0, 0.18),
    "Pearl": ("SmoothPlastic", 0.0, 0.08),
    "Matte": ("SmoothPlastic", 0.0, 0.0),
}


def add(name, bm, color, kind, smooth=True, sharp_deg=None, motion=None, studio=None):
    """motion: dict of attributes; pivot points (Blender coords) under keys ending in 'PivotWorld'."""
    if SCALE[0] != 1.0:
        bmesh.ops.scale(bm, vec=Vector((SCALE[0],) * 3), verts=bm.verts)
        motion = {k: (Vector(v) * SCALE[0] if k.endswith("PivotWorld") else v) for k, v in (motion or {}).items()}
    mesh = bpy.data.meshes.new(name)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3], quad_method="BEAUTY")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for poly in mesh.polygons:
        poly.use_smooth = True
    if sharp_deg:
        mesh.set_sharp_from_angle(angle=math.radians(sharp_deg))
    mod = obj.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
    mod.mode, mod.weight, mod.keep_sharp = "FACE_AREA", 50, True
    if not smooth:
        mesh.set_sharp_from_angle(angle=math.radians(1))
    obj.data.materials.append(material("M_%s_%s" % (kind, color), color, kind))
    mat, tr, refl = STUDIO[kind]
    spec = {"Color": color, "Material": mat, "Transparency": tr, "Reflectance": refl, "Kind": kind}
    spec.update(studio or {})
    spec["Motion"] = motion or {}
    PARTS.append((obj, spec))
    return obj


def bounds(obj):
    vs = [obj.matrix_world @ v.co for v in obj.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return lo, hi


def bvh_of(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    return tree


def surface_z(obj, x, y, top=True):
    tree = bvh_of(obj)
    origin = Vector((x, y, 20 if top else -20))
    hit = tree.ray_cast(origin, Vector((0, 0, -1 if top else 1)))
    return hit[0].z if hit[0] else None


# ---------------------------------------------------------------------------------------------
# Skyboard (Common)
# ---------------------------------------------------------------------------------------------
SKY = {"aqua": "#61D4DF", "deep": "#2C9DB5", "gold": "#F5D99A", "glow": "#9BF6F2"}


def build_skyboard():
    Y0, Y1 = -3.6, 4.0
    L = Y1 - Y0
    hw_ctrl = [(0, 0.28), (0.01, 0.55), (0.035, 0.8), (0.09, 1.0), (0.2, 1.2), (0.42, 1.34), (0.55, 1.33),
               (0.7, 1.18), (0.82, 0.92), (0.91, 0.6), (0.965, 0.3), (1.0, 0.05)]
    th_ctrl = [(0, 0.16), (0.08, 0.26), (0.3, 0.34), (0.6, 0.33), (0.85, 0.22), (1.0, 0.1)]

    def ytop(u):  # rocker: nose and tail kick up
        return 0.55 * max(0.0, (u - 0.62) / 0.38) ** 2.2 + 0.24 * max(0.0, (0.3 - u) / 0.3) ** 2

    def station(u, w=1.0, t=1.0, inset=0.0):
        y = Y0 + L * u
        hw, th = catmull(hw_ctrl, u) * w - inset, catmull(th_ctrl, u) * t
        top = ytop(u) - 0.06
        bt, bb = th * 0.36, th * 0.64
        return y, max(hw, 0.02), top - bt, bt, bb

    X, Yv, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
    us = spaced(26, 0.55)
    frames = []
    for u in us:
        y, hw, zc, bt, bb = station(u)
        frames.append((Vector((0, y, zc)), X, Z, hw, bt, bb, 2.6))
    deck = add("Deck", loft(frames, n=24), SKY["aqua"], "Glass")

    core = []
    for u in spaced(14, 0.5)[1:-1]:
        u = 0.04 + 0.92 * u
        y, hw, zc, bt, bb = station(u, 0.8, 0.5)
        core.append((Vector((0, y, zc - 0.01)), X, Z, hw, bt, bb, 2.4))
    add("DeckCore", loft(core, n=12), SKY["deep"], "Core")

    # Pearl rail around the widest line of the deck.
    pts = []
    for u in spaced(30, 0.6)[:-1]:
        y, hw, zc, bt, bb = station(u)
        pts.append(Vector((hw + 0.01, y, zc)))
    loop = pts + [Vector((0, Y1 + 0.02, station(1.0)[2]))] + [Vector((-p.x, p.y, p.z)) for p in reversed(pts)]
    loop += [Vector((0, Y0 - 0.02, station(0.0)[2]))]
    add("Rail", tube(loop, 0.085, n=6, cap=False, closed=True, flat=0.85), PEARL, "Pearl")

    # Grip pad: rounded rectangle on the flat middle of the deck.
    grip = []
    for u in spaced(12, 0.8):
        g = 0.22 + 0.5 * u
        y, hw, zc, bt, bb = station(g)
        k = rrect(u, 5)
        grip.append((Vector((0, y, ytop(g) - 0.03)), X, Z, max(min(hw * 0.72, 0.98) * k, 0.03), 0.03, 0.035, 5.0))
    add("Grip", loft(grip, n=16), NAVY, "Matte")
    treads = []
    for i in range(6):
        g = 0.27 + 0.4 * i / 5
        y, hw, zc, bt, bb = station(g)
        w = min(hw * 0.72, 0.98) * 0.62
        pts = [Vector((-w, y - 0.16, ytop(g) + 0.004)), Vector((0, y + 0.1, ytop(g) + 0.004)), Vector((w, y - 0.16, ytop(g) + 0.004))]
        treads.append(tube(pts, 0.045, n=5, flat=0.45))
    add("Treads", merge(*treads), PEARL, "Pearl")
    # Neon chevrons inside the glass at nose and tail (seen through the deck).
    chev = []
    for g, d in ((0.8, 1), (0.74, 1), (0.13, -1)):
        y, hw, zc, bt, bb = station(g)
        w = hw * 0.55
        pts = [Vector((-w, y - 0.32 * d, zc + 0.02)), Vector((0, y, zc + 0.02)), Vector((w, y - 0.32 * d, zc + 0.02))]
        chev.append(tube(pts, 0.045, n=5, flat=0.6))
    add("Chevrons", merge(*chev), SKY["glow"], "Neon")

    # Gold stringer along the centre line, nose to tail.
    s = []
    for u in spaced(20, 0.3):
        g = 0.06 + 0.86 * u
        y, hw, zc, bt, bb = station(g)
        taper = math.sin(math.pi * u) ** 0.3
        s.append((Vector((0, y, ytop(g) - 0.06 + 0.004)), X, Z, 0.075 * taper + 0.01, 0.018, 0.02, 3.0))
    add("Stringer", loft(s, n=6), SKY["gold"], "Gold")

    # Nose gem.
    ny = Y0 + L * 0.88
    nz = ytop(0.88) - 0.06
    add("NoseGem", lathe([(0.001, 0.0), (0.17, 0.05), (0.13, 0.13), (0.001, 0.2)], (0, ny, nz - 0.03), (0, 0, 1), segs=8),
        SKY["glow"], "Neon", sharp_deg=30)

    # Lift glow strips under both rails.
    for side, tag in ((1, "R"), (-1, "L")):
        pts = []
        for u in spaced(20, 0.2):
            g = 0.12 + 0.72 * u
            y, hw, zc, bt, bb = station(g)
            pts.append(Vector((side * (hw - 0.2), y, zc - bb * 0.82)))
        r = [0.012 + 0.04 * math.sin(math.pi * i / (len(pts) - 1)) ** 0.4 for i in range(len(pts))]
        add("LiftGlow_" + tag, tube(pts, r, n=6), SKY["glow"], "Neon")

    # Hover pods (static glass lens) and spinning dashed neon rings.
    bottom = lambda y: station((y - Y0) / L)[2] - station((y - Y0) / L)[4]
    for tag, py, direction in (("F", 1.45, 1), ("B", -1.75, -1)):
        bz = bottom(py)
        add("HoverPod_" + tag,
            lathe([(0.001, 0.08), (0.5, 0.06), (0.64, -0.04), (0.56, -0.16), (0.3, -0.24), (0.001, -0.26)], (0, py, bz), (0, 0, 1), segs=24),
            SKY["aqua"], "Glass")
        dashes = []
        for k in range(6):
            a0 = TAU * k / 6
            arc = [Vector((0.56 * math.cos(a0 + t * 0.62), py + 0.56 * math.sin(a0 + t * 0.62), bz - 0.2)) for t in [i / 4 for i in range(5)]]
            dashes.append(tube(arc, [0.025, 0.06, 0.065, 0.06, 0.025], n=6))
        add("HoverRing_" + tag, merge(*dashes), SKY["glow"], "Neon",
            motion={"RideMotion": "Spin", "SpinAxis": "Y", "SpinSpeed": 2.6 * direction})

    # Three glass tail fins, the side pair canted out.
    for tag, fx, fy, h, cant in (("C", 0.0, -2.95, 0.55, 0.0), ("L", -0.72, -2.55, 0.38, -0.3), ("R", 0.72, -2.55, 0.38, 0.3)):
        root = Vector((fx, fy, bottom(fy) + 0.05))
        fr = []
        for i in range(7):
            t = i / 6
            c = root + Vector((math.sin(cant) * h * t, -0.42 * t ** 1.3, -h * t))
            chord = 0.42 * (1 - t) + 0.12
            fr.append((c, Yv, Vector((math.cos(cant), 0, math.sin(cant))), chord, 0.045 * (1 - 0.6 * t), 0.045 * (1 - 0.6 * t), 2.0))
        add("TailFin_" + tag, loft(fr, n=10), SKY["aqua"], "Glass")

    return {
        "Id": "skyboard", "Name": "Skyboard", "Contact": "Feet",
        "Attachments": {
            "RiderFeet": ("Grip", (0, 0, 0)),
            "TrailR0": ("Rail", (1.0, Y0 + 0.5, station(0.07)[2] + 0.02)),
            "TrailR1": ("Rail", (1.0, Y0 + 0.5, station(0.07)[2] - 0.12)),
            "TrailL0": ("Rail", (-1.0, Y0 + 0.5, station(0.07)[2] + 0.02)),
            "TrailL1": ("Rail", (-1.0, Y0 + 0.5, station(0.07)[2] - 0.12)),
            "PodF": ("HoverPod_F", (0, 1.45, bottom(1.45) - 0.25)),
            "PodB": ("HoverPod_B", (0, -1.75, bottom(-1.75) - 0.25)),
            "Wake": ("Deck", (0, Y1 - 0.4, 0.1)),
            "Launch": ("Deck", (0, 0, bottom(0) - 0.2)),
        },
    }


# ---------------------------------------------------------------------------------------------
# Cloud Cushion (Uncommon)
# ---------------------------------------------------------------------------------------------
CLOUD = {"cloud": "#EEF3FF", "shade": "#D6DBFF", "cushion": "#A9A0EA", "pink": "#F7A8D2", "butter": "#FFE08A", "aqua": "#7FE6EA"}


def voxel_union(name, balls, voxel=0.055, smooth_iter=6, target_tris=2400):
    bm = merge(*[sphere(c, r, segs=20, rings=12, scale=s) for c, r, s in balls])
    mesh = bpy.data.meshes.new("_src")
    bm.to_mesh(mesh)
    bm.free()
    tmp = bpy.data.objects.new("_src", mesh)
    bpy.context.scene.collection.objects.link(tmp)
    rm = tmp.modifiers.new("Remesh", "REMESH")
    rm.mode, rm.voxel_size, rm.use_smooth_shade = "VOXEL", voxel, True
    sm = tmp.modifiers.new("Smooth", "SMOOTH")
    sm.factor, sm.iterations = 0.6, smooth_iter
    dg = bpy.context.evaluated_depsgraph_get()
    m1 = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    tmp.modifiers.clear()
    tmp.data = m1
    tris = sum(len(p.vertices) - 2 for p in m1.polygons)
    dec = tmp.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = min(1.0, target_tris / max(tris, 1))
    dec.use_collapse_triangulate = True
    dg = bpy.context.evaluated_depsgraph_get()
    m2 = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bpy.data.objects.remove(tmp, do_unlink=True)
    out = bmesh.new()
    out.from_mesh(m2)
    bpy.data.meshes.remove(m2)
    bmesh.ops.recalc_face_normals(out, faces=out.faces)
    return out


def build_cloud_cushion():
    one = (1, 1, 1)
    flat = (1, 1, 0.82)
    balls = [
        # base under the seat (top stays below the cushion)
        ((0, -0.1, -0.98), 0.92, flat), ((0.85, -0.2, -0.88), 0.74, flat), ((-0.85, -0.2, -0.88), 0.74, flat),
        ((0, -0.9, -0.86), 0.86, flat), ((0.9, -0.95, -0.72), 0.6, one), ((-0.9, -0.95, -0.72), 0.6, one),
        ((0, 0.55, -1.05), 0.7, flat), ((0.72, 0.5, -0.98), 0.56, one), ((-0.72, 0.5, -0.98), 0.56, one),
        # back puff
        ((0, -1.42, 0.12), 0.74, one), ((0.66, -1.3, 0.02), 0.58, one), ((-0.66, -1.3, 0.02), 0.58, one),
        ((0, -1.48, 0.78), 0.55, one), ((0.46, -1.4, 0.56), 0.44, one), ((-0.46, -1.4, 0.56), 0.44, one),
        # arm puffs
        ((1.32, -0.3, -0.18), 0.5, one), ((-1.32, -0.3, -0.18), 0.5, one),
        ((1.38, 0.24, -0.3), 0.42, one), ((-1.38, 0.24, -0.3), 0.42, one),
        # footrest
        ((0, 1.62, -0.98), 0.46, one), ((0.42, 1.5, -1.02), 0.38, one), ((-0.42, 1.5, -1.02), 0.38, one),
    ]
    add("CloudBody", voxel_union("CloudBody", balls, target_tris=2300), CLOUD["cloud"], "Frost")

    puffs = [("Puff_C", (0, -0.25, -1.82), 0.46, 0.0), ("Puff_L", (-0.82, -0.45, -1.6), 0.38, 1.3),
             ("Puff_R", (0.82, -0.45, -1.6), 0.38, 2.5), ("Puff_B", (0, -1.12, -1.62), 0.4, 3.6),
             ("Puff_F", (0, 0.62, -1.66), 0.36, 4.7)]
    for name, c, r, ph in puffs:
        add(name, sphere(c, r, segs=14, rings=9, scale=(1, 1, 0.86)), CLOUD["shade"], "Frost",
            motion={"RideMotion": "Puff", "PuffPhase": ph})

    X, Z = Vector((1, 0, 0)), Vector((0, 0, 1))
    cush = []
    for u in spaced(12, 0.8):
        y = -0.88 + 1.8 * u
        k = rrect(u, 3.5)
        cush.append((Vector((0, y, -0.12)), X, Z, max(0.88 * k, 0.04), 0.13 * k + 0.01, 0.1 * k + 0.01, 3.4))
    add("Cushion", loft(cush, n=20), CLOUD["cushion"], "Pearl")
    buttons = [lathe([(0.001, 0.02), (0.07, 0.0), (0.055, -0.03), (0.001, -0.035)], (bx, by, 0.005), (0, 0, 1), segs=10)
               for bx in (-0.38, 0.38) for by in (-0.42, 0.38)]
    add("Buttons", merge(*buttons), GOLD, "Gold")

    # Rainbow ribbon tail swooping back from under the back puff.
    pivot = Vector((0, -1.75, -0.8))
    for name, dx, dz, col in (("RainbowPink", -0.29, 0.0, CLOUD["pink"]), ("RainbowButter", 0.0, 0.02, CLOUD["butter"]),
                              ("RainbowAqua", 0.29, 0.0, CLOUD["aqua"])):
        pts = []
        for i in range(17):
            t = i / 16
            y = -1.45 - 3.1 * t
            z = -0.95 + dz - 0.35 * math.sin(math.pi * t * 0.9) + 1.15 * t ** 2.2
            x = dx * (1 - 0.35 * t) + 0.3 * math.sin(math.pi * t * 1.3)
            pts.append(Vector((x, y, z)))
        r = [0.16 * (1 - 0.4 * (i / 16) ** 1.5) for i in range(17)]
        sizes = [(rr * 0.25, rr * 0.25, rr * 0.25) for rr in r]
        # wide flat ribbon: width along X, thin along Z
        fr = []
        for (p, u, v, a, bt, bb), rr in zip(frames_along(pts, [(1, 1, 1)] * 17, Vector((0, 0, 1))), r):
            fr.append((p, u, v, rr, 0.055, 0.055, 2.6))
        add(name, loft(fr, n=10), col, "Glass" if name != "RainbowAqua" else "Glass",
            studio={"Transparency": 0.15},
            motion={"RideMotion": "Tail", "MotionPivotWorld": pivot, "TailAngle": 0.16, "TailLag": 0.9})

    return {
        "Id": "cloud_cushion", "Name": "Cloud Cushion", "Contact": "Seat",
        "Attachments": {
            "RiderSeat": ("Cushion", (0, 0, 0)),
            "Trail0": ("RainbowButter", (0, -4.45, 0.2 + 0.2)),
            "Trail1": ("RainbowButter", (0, -4.45, 0.2 - 0.2)),
            "Wisps": ("CloudBody", (0, -0.3, -1.6)),
            "Wake": ("CloudBody", (0, 1.8, -0.6)),
            "Launch": ("CloudBody", (0, -0.2, -1.9)),
        },
    }


# ---------------------------------------------------------------------------------------------
# Rocket Skiff (Rare)
# ---------------------------------------------------------------------------------------------
ROCKET = {"coral": "#EF8268", "deep": "#B6493A", "cream": "#FFE39A", "glow": "#FFC46B", "flame": "#FFF1B8"}


def build_rocket_skiff():
    Y0, Y1 = -3.5, 4.7
    L = Y1 - Y0
    hw_ctrl = [(0, 0.5), (0.02, 0.78), (0.08, 1.0), (0.3, 1.16), (0.55, 1.16), (0.75, 0.96), (0.88, 0.66), (0.96, 0.32), (1.0, 0.04)]
    bt_ctrl = [(0, 0.36), (0.1, 0.46), (0.6, 0.47), (0.82, 0.36), (0.95, 0.16), (1.0, 0.04)]
    bb_ctrl = [(0, 0.4), (0.1, 0.56), (0.6, 0.58), (0.85, 0.42), (0.96, 0.18), (1.0, 0.04)]
    X, Yv, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))

    def zc(u):
        return -0.56 + 0.22 * max(0.0, (u - 0.7) / 0.3) ** 1.5

    def st(u, w=1.0, t=1.0):
        return Vector((0, Y0 + L * u, zc(u))), catmull(hw_ctrl, u) * w, catmull(bt_ctrl, u) * t, catmull(bb_ctrl, u) * t

    hull = []
    for u in spaced(28, 0.55):
        c, hw, bt, bb = st(u)
        hull.append((c, X, Z, max(hw, 0.02), max(bt, 0.02), max(bb, 0.02), 2.3))
    add("Hull", loft(hull, n=24), ROCKET["coral"], "Glass")
    core = []
    for u in spaced(14, 0.5)[1:-1]:
        u = 0.04 + 0.9 * u
        c, hw, bt, bb = st(u, 0.78, 0.6)
        core.append((c + Vector((0, 0, -0.05)), X, Z, hw, bt, bb, 2.2))
    add("HullCore", loft(core, n=14), ROCKET["deep"], "Core")

    # Racing stripe over the top, tail to nose.
    s = []
    for u in spaced(22, 0.3):
        g = 0.02 + 0.95 * u
        c, hw, bt, bb = st(g)
        taper = math.sin(math.pi * u) ** 0.25
        s.append((Vector((0, c.y, c.z + bt + 0.003)), X, Z, 0.2 * taper + 0.02, 0.022, 0.03, 3.0))
    add("Stripe", loft(s, n=10), WHITE, "Pearl")

    deck = []
    for u in spaced(12, 0.8):
        y = -2.2 + 3.7 * u
        k = rrect(u, 4)
        deck.append((Vector((0, y, -0.05)), X, Z, max(0.84 * k, 0.03), 0.05, 0.06, 4.5))
    add("DeckPlate", loft(deck, n=16), NAVY, "Matte")

    # Steering column, T handlebar, grips and dashboard gem.
    col_pts = [Vector((0, 2.15, -0.15)), Vector((0, 2.0, 0.6)), Vector((0, 1.72, 1.4)), Vector((0, 1.47, 2.05))]
    col = tube(col_pts, [0.16, 0.12, 0.1, 0.1], n=12)
    fair = lathe([(0.001, -0.05), (0.42, 0.0), (0.3, 0.22), (0.14, 0.42), (0.001, 0.5)], (0, 2.15, -0.18), (0, 0, 1), segs=16)
    add("Column", merge(col, fair), PEARL, "Pearl")
    bar = [Vector((x, 1.4 - 0.18 * (x / 0.95) ** 2, 2.12 + 0.06 * (x / 0.95) ** 2)) for x in [-0.95 + 1.9 * i / 14 for i in range(15)]]
    add("Handlebar", tube(bar, 0.07, n=10), ROCKET["cream"], "Gold")
    grips = [tube([Vector((sx * 0.62, 1.35, 2.135)), Vector((sx * 1.02, 1.22, 2.19))], [0.105, 0.105], n=12) for sx in (-1, 1)]
    add("Grips", merge(*grips), NAVY, "Matte")
    add("DashGem", lathe([(0.001, -0.1), (0.13, 0.0), (0.001, 0.12)], (0, 1.42, 2.2), (0, -0.4, 1), segs=8),
        "#7CE7D5", "Neon", sharp_deg=30)

    # Twin nacelles on pylons.
    nac_profile = [(0.001, -3.55), (0.3, -3.5), (0.44, -3.3), (0.54, -2.9), (0.58, -1.6), (0.58, 0.4), (0.53, 1.1), (0.47, 1.4), (0.38, 1.47)]
    for side, tag in ((-1, "L"), (1, "R")):
        cx, cz = side * 1.98, -0.52
        shell = lathe([(r, h) for r, h in nac_profile] + [(0.3, 1.38), (0.001, 1.28)], (cx, 0, cz), (0, 1, 0), segs=20)
        add("Nacelle_" + tag, shell, ROCKET["coral"], "Glass")
        add("NacelleCore_" + tag, lathe([(0.001, -2.9), (0.3, -2.8), (0.32, 0.6), (0.24, 0.95), (0.001, 1.0)], (cx, 0, cz), (0, 1, 0), segs=12),
            ROCKET["glow"], "Neon")
        ring = [Vector((cx + 0.46 * math.cos(a), 1.42, cz + 0.46 * math.sin(a))) for a in [TAU * i / 20 for i in range(20)]]
        add("IntakeRing_" + tag, tube(ring, 0.07, n=8, cap=False, closed=True), ROCKET["cream"], "Gold")
        blades = [lathe([(0.001, 1.24), (0.09, 1.26), (0.11, 1.34), (0.001, 1.38)], (cx, 0, cz), (0, 1, 0), segs=10)]
        for k in range(5):
            a = TAU * k / 5
            d = Vector((math.cos(a), 0, math.sin(a)))
            perp = Vector((-math.sin(a), 0, math.cos(a)))
            fr = []
            for i in range(4):
                t = i / 3
                c = Vector((cx, 1.31, cz)) + d * (0.08 + 0.3 * t)
                twist = (perp * math.cos(0.7) + Vector((0, 1, 0)) * math.sin(0.7)).normalized()
                fr.append((c, twist, d.cross(twist).normalized(), 0.1 - 0.03 * t, 0.016, 0.016, 2.0))
            blades.append(loft(fr, n=6))
        add("Fan_" + tag, merge(*blades), PEARL, "Pearl",
            motion={"RideMotion": "Spin", "SpinAxis": "Z", "SpinSpeed": 9.0 * side})
        add("Nozzle_" + tag, lathe([(0.3, -3.42), (0.4, -3.5), (0.36, -3.86), (0.27, -3.86), (0.24, -3.6), (0.001, -3.55)], (cx, 0, cz), (0, 1, 0), segs=16),
            NAVY, "Matte")
        add("Flame_" + tag, lathe([(0.24, -3.78), (0.25, -4.0), (0.17, -4.4), (0.07, -4.75), (0.001, -4.9)], (cx, 0, cz), (0, 1, 0), segs=12),
            ROCKET["flame"], "Neon", studio={"Transparency": 0.15},
            motion={"RideMotion": "Flame", "FlamePhase": 0.0 if side < 0 else 1.7})
        # pylon: swept stub wing from hull side to nacelle
        fr = []
        for i in range(5):
            t = i / 4
            x = side * (0.95 + 0.85 * t)
            fr.append((Vector((x, -0.6 - 0.2 * t, -0.48 - 0.04 * t)), Yv, Z, 0.8 - 0.15 * t, 0.07, 0.07, 2.2))
        add("Pylon_" + tag, loft(fr, n=10, cap=True), ROCKET["coral"], "Glass")

    # Swept tail fins (canted out) with gold tips; they trim gently with the bank.
    for side, tag in ((-1, "L"), (1, "R")):
        cant = math.radians(22) * side
        root = Vector((side * 0.6, -2.55, -0.18))
        out = Vector((math.sin(cant), 0, math.cos(cant)))
        fr = []
        for i in range(7):
            t = i / 6
            c = root + out * (1.3 * t) + Vector((0, -0.95 * t ** 1.2, 0))
            fr.append((c, Yv, Vector((math.cos(cant), 0, -math.sin(cant))), 0.78 * (1 - t) + 0.2, 0.07 * (1 - 0.5 * t), 0.07 * (1 - 0.5 * t), 2.0))
        add("TailFin_" + tag, loft(fr, n=10), ROCKET["coral"], "Glass",
            motion={"RideMotion": "Fin", "MotionPivotWorld": root, "FinAxis": "Z", "FinAngle": 0.05, "FinBank": 0.5})
        tip = root + out * 1.38 + Vector((0, -1.0, 0))
        add("FinTip_" + tag, sphere(tip, 0.12, segs=10, rings=6, scale=(0.7, 1.9, 0.7)), ROCKET["cream"], "Gold",
            motion={"RideMotion": "Fin", "MotionPivotWorld": root, "FinAxis": "Z", "FinAngle": 0.05, "FinBank": 0.5})

    return {
        "Id": "rocket_skiff", "Name": "Rocket Skiff", "Contact": "Feet",
        "Attachments": {
            "RiderFeet": ("DeckPlate", (0, 0, 0)),
            "HandL": ("Handlebar", (-0.8, 1.3, 2.15)),
            "HandR": ("Handlebar", (0.8, 1.3, 2.15)),
            "Exhaust_L": ("Nozzle_L", (-1.98, -3.9, -0.52)),
            "Exhaust_R": ("Nozzle_R", (1.98, -3.9, -0.52)),
            "FinTrailL0": ("TailFin_L", (-1.12, -3.55, 1.08)), "FinTrailL1": ("TailFin_L", (-1.0, -3.4, 0.8)),
            "FinTrailR0": ("TailFin_R", (1.12, -3.55, 1.08)), "FinTrailR1": ("TailFin_R", (1.0, -3.4, 0.8)),
            "Wake": ("Hull", (0, 4.4, -0.4)),
            "Launch": ("Hull", (0, -0.5, -1.2)),
        },
    }


# ---------------------------------------------------------------------------------------------
# Prism Ray (Epic)
# ---------------------------------------------------------------------------------------------
RAY = {"lilac": "#B8A4F4", "violet": "#7B5BD6", "mint": "#7CE7D5", "eye": "#1B2440", "blush": "#FF9FC4"}


def build_prism_ray():
    X, Yv, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
    Y0, Y1 = -2.3, 2.8
    L = Y1 - Y0
    hw_ctrl = [(0, 0.22), (0.12, 0.8), (0.4, 1.45), (0.62, 1.5), (0.82, 1.25), (0.94, 0.86), (1.0, 0.42)]
    bt_ctrl = [(0, 0.1), (0.2, 0.26), (0.5, 0.36), (0.8, 0.3), (1.0, 0.12)]
    bb_ctrl = [(0, 0.12), (0.2, 0.32), (0.5, 0.42), (0.8, 0.34), (1.0, 0.14)]

    def st(u):
        bt = catmull(bt_ctrl, u)
        return Vector((0, Y0 + L * u, -0.1 - bt)), catmull(hw_ctrl, u), bt, catmull(bb_ctrl, u)

    body = []
    for u in spaced(12, 0.45):
        c, hw, bt, bb = st(u)
        body.append((c, X, Z, hw, bt, bb, 1.7))
    bm = loft(body, n=10, phase=math.pi / 10)
    add("Body", bevel_bm(bm, 0.04, 24), RAY["lilac"], "Glass", sharp_deg=22)
    core = []
    for u in spaced(8, 0.5)[1:-1]:
        c, hw, bt, bb = st(0.06 + 0.88 * u)
        core.append((c + Vector((0, 0, -0.04)), X, Z, hw * 0.72, bt * 0.6, bb * 0.6, 2.0))
    add("BodyCore", loft(core, n=12), RAY["violet"], "Core")

    # Faceted wings from shoulder hinges, pointed swept tips that curl up.
    def wing_frames(side):
        fr = []
        for i in range(15):
            s = i / 14
            x = side * (0.7 + 4.6 * s)
            le = 1.9 - 3.0 * s ** 1.35
            te = -1.55 + 0.25 * s ** 1.6
            th = 0.3 * (1 - s) ** 0.8 + 0.04
            z = -0.42 + 0.18 * s + 0.75 * s ** 3.5
            fr.append((Vector((x, (le + te) / 2, z)), Yv, Z, (le - te) / 2, th * 0.45, th * 0.55, 2.0))
        return fr

    for side, tag in ((-1, "L"), (1, "R")):
        hinge = Vector((side * 1.0, 0.15, -0.4))
        wing = loft(wing_frames(side), n=10)
        add("Wing_" + tag, bevel_bm(wing, 0.02, 25), RAY["lilac"], "Glass", sharp_deg=35,
            motion={"RideMotion": "Wing", "WingSide": side, "MotionPivotWorld": hinge, "WingAngle": 0.3})
        fr = wing_frames(side)
        lead, mid = [], []
        for i in range(1, 14):
            c, U, V, a, bt, bb = fr[i][:6]
            lead.append(c + Vector((0, a * 0.72, bt * 0.75)))
            if 3 <= i <= 11:
                mid.append(c + Vector((0, -a * 0.05, bt * 0.95)))
        r1 = [0.05 * (1 - 0.6 * k / (len(lead) - 1)) for k in range(len(lead))]
        r2 = [0.04 * (1 - 0.6 * k / (len(mid) - 1)) for k in range(len(mid))]
        add("WingVein_" + tag, merge(tube(lead, r1, n=6), tube(mid, r2, n=6)), RAY["mint"], "Neon",
            motion={"RideMotion": "Wing", "WingSide": side, "MotionPivotWorld": hinge, "WingAngle": 0.3})

    # Cephalic fins: two little curled lobes at the front corners.
    for side, tag in ((-1, "L"), (1, "R")):
        pts = [Vector((side * (1.0 - 0.42 * t ** 1.4), 2.45 + 0.62 * t, -0.36 - 0.26 * t ** 2)) for t in [i / 7 for i in range(8)]]
        r = [0.24 * (1 - 0.6 * i / 7) for i in range(8)]
        fr = [(p, u, v, a, bt * 0.4, bb * 0.4, 2.0) for (p, u, v, a, bt, bb) in frames_along(pts, [(x, x, x) for x in r], Vector((0, 0, 1)))]
        add("HeadFin_" + tag, loft(fr, n=8), RAY["lilac"], "Glass",
            motion={"RideMotion": "Fin", "MotionPivotWorld": pts[0], "FinAxis": "X", "FinAngle": 0.22, "FinHz": 1.6, "FinPhase": 0 if side < 0 else 0.5})

    # Whip tail with a spinning prism.
    tpivot = Vector((0, -2.1, -0.42))
    tail_pts = [Vector((0.0, -2.0 - 4.0 * t, -0.42 + 0.35 * t ** 1.5 + 0.12 * math.sin(math.pi * t))) for t in [i / 14 for i in range(15)]]
    add("Tail", tube(tail_pts, [0.27 * (1 - 0.82 * i / 14) + 0.025 for i in range(15)], n=8), RAY["lilac"], "Glass",
        motion={"RideMotion": "Tail", "MotionPivotWorld": tpivot, "TailAngle": 0.22, "TailLag": 0.8})
    tip = tail_pts[-1] + Vector((0, -0.42, 0.04))
    prism = lathe([(0.001, -0.55), (0.32, -0.1), (0.32, 0.1), (0.001, 0.5)], tip, (0, 1, 0), segs=6)
    add("TailPrism", bevel_bm(prism, 0.025, 20), RAY["mint"], "Neon", sharp_deg=30,
        motion={"RideMotion": "Tail", "MotionPivotWorld": tpivot, "TailAngle": 0.22, "TailLag": 0.8, "SpinAxis": "Z", "SpinSpeed": 2.2})

    # Saddle with a gold rim.
    sad = []
    for u in spaced(10, 0.7):
        y = -0.95 + 2.0 * u
        k = math.sin(math.pi * u) ** 0.35
        sad.append((Vector((0, y, -0.07)), X, Z, max(0.82 * k, 0.03), 0.07, 0.06, 3.0))
    add("Saddle", loft(sad, n=18), PEARL, "Pearl")
    rim = []
    for i in range(28):
        a = TAU * i / 28
        rim.append(Vector((0.86 * math.cos(a), 0.05 + 1.04 * math.sin(a), -0.09)))
    add("SaddleRim", tube(rim, 0.045, n=6, cap=False, closed=True), GOLD, "Gold")

    # Face: eyes with shines, blush, brow gem; placed on the body's top surface.
    body_obj = next(o for o, _ in PARTS if o.name == "Body")
    eyes, shines, blush = [], [], []
    for side in (-1, 1):
        ex, ey = side * 0.62, 2.18
        ez = surface_z(body_obj, ex, ey) or -0.2
        eyes.append(sphere((ex, ey, ez - 0.02), 0.2, segs=14, rings=9, scale=(1, 0.8, 0.85)))
        shines.append(sphere((ex - 0.06 * side + 0.04, ey + 0.06, ez + 0.13), 0.06, segs=8, rings=5))
        bz = surface_z(body_obj, side * 0.98, 1.92) or -0.3
        blush.append(sphere((side * 0.98, 1.92, bz - 0.01), 0.16, segs=10, rings=6, scale=(1, 0.7, 0.25)))
    add("Eyes", merge(*eyes), RAY["eye"], "Pearl")
    add("EyeShine", merge(*shines), WHITE, "Neon")
    add("Blush", merge(*blush), RAY["blush"], "Matte")
    gz = surface_z(body_obj, 0, 2.38) or -0.2
    add("BrowGem", bevel_bm(lathe([(0.001, -0.04), (0.17, 0.02), (0.11, 0.12), (0.001, 0.16)], (0, 2.38, gz - 0.03), (0, 0.25, 1), segs=6), 0.015, 20),
        RAY["mint"], "Neon", sharp_deg=30)

    return {
        "Id": "prism_ray", "Name": "Prism Ray", "Contact": "Feet",
        "Attachments": {
            "RiderFeet": ("Saddle", (0, 0, 0)),
            "WingTipL0": ("Wing_L", (-5.25, -1.05, 0.55)), "WingTipL1": ("Wing_L", (-5.0, -1.25, 0.45)),
            "WingTipR0": ("Wing_R", (5.25, -1.05, 0.55)), "WingTipR1": ("Wing_R", (5.0, -1.25, 0.45)),
            "Glints": ("Body", (0, 0.0, -0.6)),
            "PrismGlow": ("TailPrism", (tip.x, tip.y, tip.z)),
            "Wake": ("Body", (0, 2.9, -0.3)),
            "Launch": ("Body", (0, 0, -0.9)),
        },
    }


BUILDERS = {
    "skyboard": build_skyboard,
    "cloud_cushion": build_cloud_cushion,
    "rocket_skiff": build_rocket_skiff,
    "prism_ray": build_prism_ray,
}
BUDGET = {"skyboard": 5000, "cloud_cushion": 5000, "rocket_skiff": 7500, "prism_ray": 7500}
BUILD_SCALE = {"rocket_skiff": 1.2}


# ---------------------------------------------------------------------------------------------
# Export, manifest, validation, preview
# ---------------------------------------------------------------------------------------------

def tris_of(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def check_mesh(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    loose = sum(1 for v in bm.verts if not v.link_faces)
    degenerate = sum(1 for f in bm.faces if f.calc_area() < 1e-9)
    bm.free()
    return {"loose_verts": loose, "degenerate_faces": degenerate}


def export_fbx(objects, path):
    """Same settings as glassclash_blender.export_fbx (Roblox -Z forward, Y up, studs)."""
    for o in list(bpy.context.view_layer.objects):
        if o is not None:
            o.select_set(False)
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, object_types={"MESH"}, apply_unit_scale=True, axis_forward="-Z", axis_up="Y",
        bake_space_transform=True, use_mesh_modifiers=True, mesh_smooth_type="FACE", use_triangles=True,
        use_custom_props=True, add_leaf_bones=False, path_mode="COPY", embed_textures=True)
    for o in objects:
        o.select_set(False)


def manifest_for(meta):
    parts = {}
    total = 0
    for obj, spec in PARTS:
        lo, hi = bounds(obj)
        centre = (lo + hi) / 2
        rlo, rhi = Vector(to_roblox(lo)), Vector(to_roblox(hi))
        size = [round(abs(rhi[k] - rlo[k]), 5) for k in range(3)]
        motion = {}
        for k, v in spec["Motion"].items():
            if k.endswith("PivotWorld"):
                # offset from the part's bounds centre, Roblox axes (parts import unrotated)
                motion["MotionPivot"] = to_roblox(Vector(v) - centre)
            else:
                motion[k] = v
        t = tris_of(obj)
        total += t
        parts[obj.name] = {
            "Tris": t, "Centre": to_roblox(centre), "Size": size,
            "Color": spec["Color"], "Material": spec["Material"], "Transparency": spec["Transparency"],
            "Reflectance": spec["Reflectance"], "Kind": spec["Kind"], "Motion": motion, **check_mesh(obj),
        }
    atts = {}
    for name, (part, pos) in meta["Attachments"].items():
        obj = bpy.data.objects[part]
        lo, hi = bounds(obj)
        pos = Vector(pos) * SCALE[0]
        atts[name] = {"Part": part, "World": to_roblox(pos), "Offset": to_roblox(pos - (lo + hi) / 2)}
    all_lo = Vector((min(bounds(o)[0][k] for o, _ in PARTS) for k in range(3)))
    all_hi = Vector((max(bounds(o)[1][k] for o, _ in PARTS) for k in range(3)))
    return {
        "Id": meta["Id"], "Name": meta["Name"], "Contact": meta["Contact"], "Tris": total,
        "Budget": BUDGET[meta["Id"]], "Extents": [abs(c) for c in to_roblox(all_hi - all_lo)], "Parts": parts, "Attachments": atts,
        "Axes": "Roblox (x, y, z) = Blender (x, z, -y); model pivot = origin = rider contact point",
    }


def validate_fbx(path, manifest):
    """Re-import the FBX in a scratch scene: same names, triangle counts and Roblox-space bounds."""
    scene = bpy.data.scenes.new("_validate")
    win_scene = bpy.context.window.scene if bpy.context.window else None
    before = set(bpy.data.objects)
    with bpy.context.temp_override(scene=scene):
        bpy.ops.import_scene.fbx(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    report = {"objects": len(new), "missing": [], "tri_mismatch": [], "max_bounds_error": 0.0}
    names = {o.name.split(".")[0]: o for o in new if o.type == "MESH"}
    for name, part in manifest["Parts"].items():
        o = names.get(name)
        if not o:
            report["missing"].append(name)
            continue
        dg = bpy.context.evaluated_depsgraph_get()
        vs = [o.matrix_world @ v.co for v in o.data.vertices]
        # Imported FBX is converted back to Blender axes (Z up, +Y forward).
        lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
        hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
        centre = to_roblox((lo + hi) / 2)
        err = max(abs(centre[k] - part["Centre"][k]) for k in range(3))
        report["max_bounds_error"] = max(report["max_bounds_error"], err)
        if tris_of(o) != part["Tris"]:
            report["tri_mismatch"].append((name, tris_of(o), part["Tris"]))
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.scenes.remove(scene)
    report["ok"] = not report["missing"] and not report["tri_mismatch"] and report["max_bounds_error"] < 1e-3
    return report


def preview(path, samples=32, size=(1100, 820), mannequin=None):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        scene.cycles.device = "GPU"
    except Exception:
        pass
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces, scene.cycles.transmission_bounces, scene.cycles.transparent_max_bounces = 8, 8, 8
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX" if "AgX" in [i.identifier for i in scene.view_settings.bl_rna.properties["view_transform"].enum_items] else "Filmic"
    world = bpy.data.worlds.new("FlyerWorld")
    world.use_nodes = True
    nt = world.node_tree
    bg = nt.nodes["Background"]
    tc, sep, ramp = nt.nodes.new("ShaderNodeTexCoord"), nt.nodes.new("ShaderNodeSeparateXYZ"), nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], ramp.inputs[0])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    ramp.color_ramp.elements[0].position, ramp.color_ramp.elements[0].color = 0.4, (0.32, 0.42, 0.62, 1)
    ramp.color_ramp.elements[1].position, ramp.color_ramp.elements[1].color = 0.75, (0.72, 0.84, 1.0, 1)
    bg.inputs["Strength"].default_value = 0.9
    scene.world = world
    objs = [o for o, _ in PARTS]
    lo = Vector((min(bounds(o)[0][k] for o in objs) for k in range(3)))
    hi = Vector((max(bounds(o)[1][k] for o in objs) for k in range(3)))
    centre, extent = (lo + hi) / 2, (hi - lo).length
    if mannequin:
        centre.z += 1.2
        extent = max(extent, 7.5)
    # ground
    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, lo.z - 1.6))
    ground = bpy.context.active_object
    gm = bpy.data.materials.new("Ground")
    gm.use_nodes = True
    gp = next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    gp.inputs["Base Color"].default_value = (*hex_rgb("#BFD8B0"), 1)
    gp.inputs["Roughness"].default_value = 0.9
    ground.data.materials.append(gm)
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy, sun.data.angle = 3.2, math.radians(8)
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
    scene.collection.objects.link(sun)
    for name, off, energy, sz in (("Key", (-4, -5, 6), 900, 4), ("Rim", (5, 6, 4), 700, 3)):
        lt = bpy.data.objects.new(name, bpy.data.lights.new(name, "AREA"))
        lt.data.energy, lt.data.size = energy, sz
        lt.location = centre + Vector(off)
        lt.rotation_euler = (centre - lt.location).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(lt)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 50
    direction = Vector((1.25, 1.15, 0.55)).normalized()
    cam.location = centre + direction * extent * 1.9
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def add_mannequin(contact, pose="stand"):
    """Grey blocky R15-sized stand-in for scale checks in previews only (never exported)."""
    m = bpy.data.materials.new("Mannequin")
    m.use_nodes = True
    next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.5, 0.5, 0.55, 1)
    parts = []

    def box(c, s, rot=(0, 0, 0)):
        bpy.ops.mesh.primitive_cube_add(size=1, location=c, rotation=rot)
        o = bpy.context.active_object
        o.scale = s
        o.data.materials.append(m)
        parts.append(o)

    if pose == "seat":
        box((0, 0, 1.0), (2.0, 1.0, 2.0))
        box((0, 0, 2.6), (1.2, 1.2, 1.2))
        for sx in (-0.5, 0.5):
            box((sx, 0.55, 0.25), (0.9, 1.6, 0.5))
            box((sx, 1.2, -0.4), (0.9, 0.5, 1.3), (math.radians(40), 0, 0))
    else:
        box((0, 0, 3.0), (2.0, 1.0, 2.0))
        box((0, 0, 4.6), (1.2, 1.2, 1.2))
        for sx in (-0.5, 0.5):
            box((sx, 0, 1.0), (0.95, 1.0, 2.0))
            box((sx * 3.0, 0.2, 3.3), (0.9, 0.9, 2.0), (0, math.radians(-50 * (1 if sx > 0 else -1)), 0))
    return parts


def build(gid, render=False, samples=32):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    PARTS.clear()
    SCALE[0] = BUILD_SCALE.get(gid, 1.0)
    meta = BUILDERS[gid]()
    folder = os.path.join(OUT, gid)
    os.makedirs(folder, exist_ok=True)
    objs = [o for o, _ in PARTS]
    for o in objs:
        o["roblox_name"] = o.name
    manifest = manifest_for(meta)
    fbx = os.path.join(folder, gid + ".fbx")
    export_fbx(objs, fbx)
    manifest["FbxRoundTrip"] = validate_fbx(fbx, manifest)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(folder, gid + ".blend"), compress=True)
    with open(os.path.join(folder, "manifest.json"), "w") as fh:
        json.dump(manifest, fh, indent=1)
    if render:
        preview(os.path.join(folder, gid + "_preview.png"), samples)
        add_mannequin(meta["Contact"], "seat" if meta["Contact"] == "Seat" else "stand")
        preview(os.path.join(folder, gid + "_rider_scale.png"), max(16, samples // 2), (800, 640), mannequin=True)
    return manifest


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    render = "--render" in argv
    samples = 32
    if "--samples" in argv:
        samples = int(argv[argv.index("--samples") + 1])
    ids = [a for a in argv if a in BUILDERS] or list(BUILDERS)
    summary = {}
    for gid in ids:
        m = build(gid, render, samples)
        summary[gid] = {"Tris": m["Tris"], "Budget": m["Budget"], "Extents": m["Extents"], "Parts": len(m["Parts"]),
                        "RoundTrip": m["FbxRoundTrip"],
                        "Problems": {k: v for k, v in ((n, (p["loose_verts"], p["degenerate_faces"])) for n, p in m["Parts"].items()) if v != (0, 0)}}
    path = os.path.join(OUT, "build_summary.json")
    old = json.load(open(path)) if os.path.exists(path) else {}
    old.update(summary)
    with open(path, "w") as fh:
        json.dump(old, fh, indent=1)
    print("FLYERS_V3", json.dumps(summary))


if __name__ == "__main__":
    main()
