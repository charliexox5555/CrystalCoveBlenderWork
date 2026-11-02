"""Glass Buddies v5: six re-engineered hero glassies (docs/design/RELAUNCH_PLAN.md).

Run inside Blender (MCP):
    exec(open(r"<repo>/tools/blender/build_buddies_v5.py").read()); build_all()

Rules of the redesign:
- Clear glass shell + a saturated inner fill, so the hue reads on any background and at phone size.
- A big, low-set face: every glassy is a character. Faces are separate meshes (Idle/Blink/Hurt/Happy)
  with vertex colours, one visible at a time, so expressions swap instantly with no extra rig.
- Six hues spaced around the wheel and six different silhouettes: identify in one glance at 64 px.
- Origin at the hang point (top of the assembly). 1 Blender unit = 1 stud. Blender -Y is the front.
"""
import math
import os
import random

import bpy
import bmesh
from mathutils import Vector

_REPO = globals().get("GLASSCLASH_REPO") or os.environ.get("GLASSCLASH_REPO") or r"C:\Users\charl\Documents\CrystalCoveBlenderWork"
COLLECTION = "BuddiesV5"
OUT = os.path.join(_REPO, "assets", "blender", "glassies_v5")
SEGMENTS = 28
INK = (0.035, 0.03, 0.075, 1)
WHITE = (1, 1, 1, 1)
BLUSH = (1.0, 0.42, 0.52, 1)
MOUTH = (0.12, 0.05, 0.10, 1)
TONGUE = (1.0, 0.38, 0.45, 1)

# profile: (radius, z) from the top of the shell to its base; z is below the hang point.
# fill: the z range the liquid occupies. face: z of the eyes, eye size, spacing (radians).
# mood: browless | angry | sleepy | cool | eager | excited.
BUDDIES = {
    "pop": {
        "Name": "Pop", "Fill": "#1E7BFF", "Glass": "#BFE6FF", "Mood": "excited", "Top": "#FF3B4E",
        "Profile": [(0.34, 0.22), (0.34, 0.46), (0.42, 0.62), (0.80, 1.00), (0.98, 1.42), (1.02, 1.95), (0.98, 2.42), (0.78, 2.72), (0.0, 2.80)],
        "FillZ": (1.02, 2.70), "EyeZ": 1.78, "EyeR": 0.235, "EyeA": 0.46,
    },
    "jam": {
        "Name": "Jam", "Fill": "#FF8A1F", "Glass": "#FFE7C4", "Mood": "sleepy", "Top": "#FFC93C",
        "Profile": [(1.02, 0.26), (1.14, 0.42), (1.30, 0.70), (1.38, 1.15), (1.38, 1.70), (1.26, 2.12), (0.96, 2.32), (0.0, 2.38)],
        "FillZ": (0.60, 2.30), "EyeZ": 1.36, "EyeR": 0.26, "EyeA": 0.40,
    },
    "prism": {
        "Name": "Prism", "Fill": "#8B4DFF", "Glass": "#E4D6FF", "Mood": "cool", "Top": "#FFE36E",
        "Profile": [(0.26, 0.40), (0.30, 0.62), (0.98, 1.05), (1.20, 1.50), (0.98, 2.10), (0.42, 2.58), (0.0, 2.72)],
        "FillZ": (0.92, 2.62), "EyeZ": 1.48, "EyeR": 0.235, "EyeA": 0.42, "Sides": 8,
    },
    "glass_cup": {
        "Name": "Cup", "Fill": "#6FE01F", "Glass": "#E2FFC9", "Mood": "eager", "Top": None,
        "Profile": [(0.98, 0.10), (0.94, 0.40), (0.86, 1.10), (0.76, 1.70), (0.64, 1.92), (0.0, 1.98)],
        "FillZ": (0.58, 1.92), "EyeZ": 1.02, "EyeR": 0.235, "EyeA": 0.50,
    },
    "water_jug": {
        "Name": "Jug", "Fill": "#10CFC0", "Glass": "#C8FFF7", "Mood": "friendly", "Top": "#FFFFFF",
        "Profile": [(0.44, 0.22), (0.48, 0.56), (0.62, 0.84), (1.12, 1.30), (1.40, 1.90), (1.42, 2.46), (1.20, 2.86), (0.0, 2.96)],
        "FillZ": (1.02, 2.84), "EyeZ": 1.86, "EyeR": 0.27, "EyeA": 0.42,
    },
    "ketchup_bottle": {
        "Name": "Ketchup", "Fill": "#F2212F", "Glass": "#FFD2D2", "Mood": "angry", "Top": "#FFD23C",
        "Profile": [(0.20, 0.30), (0.24, 0.62), (0.50, 0.86), (0.80, 1.34), (0.94, 2.00), (0.96, 2.52), (0.76, 2.80), (0.0, 2.86)],
        "FillZ": (0.92, 2.76), "EyeZ": 1.84, "EyeR": 0.22, "EyeA": 0.50,
    },
}


def rgb(hex_color, a=1.0):
    h = hex_color.lstrip("#")
    srgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
    return (lin[0], lin[1], lin[2], a)


def collection():
    col = bpy.data.collections.get(COLLECTION)
    if not col:
        col = bpy.data.collections.new(COLLECTION)
        bpy.context.scene.collection.children.link(col)
    return col


def clear(prefix=None):
    col = collection()
    for ob in list(col.objects):
        if prefix is None or ob.name.startswith(prefix):
            bpy.data.objects.remove(ob, do_unlink=True)


def smooth_profile(points, subdivisions=3):
    """Catmull-Rom through the authored points; chunky toy curves from a handful of numbers."""
    out = []
    n = len(points)
    for i in range(n - 1):
        p0, p1, p2, p3 = points[max(i - 1, 0)], points[i], points[i + 1], points[min(i + 2, n - 1)]
        for s in range(subdivisions):
            t = s / subdivisions
            out.append(tuple(
                0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t * t
                       + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t ** 3)
                for k in (0, 1)
            ))
    out.append(tuple(points[-1]))
    return [(max(r, 0.0), z) for r, z in out]


def radius_at(profile, z):
    best = None
    for (r1, z1), (r2, z2) in zip(profile, profile[1:]):
        if z1 <= z <= z2 and z2 > z1:
            t = (z - z1) / (z2 - z1)
            r = r1 + (r2 - r1) * t
            best = r if best is None else max(best, r)
    return best if best is not None else 0.0


def obj_from_bm(name, bm, col_rgba=None, smooth=True):
    me = bpy.data.meshes.new(name)
    if col_rgba is not None:
        layer = bm.loops.layers.color.get("Col") or bm.loops.layers.color.new("Col")
        for f in bm.faces:
            for l in f.loops:
                l[layer] = col_rgba
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    collection().objects.link(ob)
    me.polygons.foreach_set("use_smooth", [smooth] * len(me.polygons))
    me.update()
    return ob


def lathe(name, profile, segments=SEGMENTS, sides=None, cap_top=True):
    """Revolves (radius, depth) around Z. Depth runs downward from the hang point at z=0."""
    bm = bmesh.new()
    seg = sides or segments
    rings = []
    for r, depth in profile:
        ring = []
        for i in range(seg):
            a = 2 * math.pi * i / seg + (math.pi / seg if sides else 0)
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), -depth)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap_top:
        bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def surface_point(profile, z, angle, lift=0.0):
    """Point on the shell front. angle 0 faces -Y, positive to the viewer's right (+X)."""
    r = radius_at(profile, z) + lift
    return Vector((r * math.sin(angle), -r * math.cos(angle), -z))


def surface_frame(profile, z, angle):
    eps = 0.02
    p = surface_point(profile, z, angle)
    du = surface_point(profile, z, angle + eps) - p
    dv = surface_point(profile, z + eps, angle) - p
    n = du.cross(dv).normalized()
    if n.dot(Vector((math.sin(angle), -math.cos(angle), 0))) < 0:
        n = -n
    return p, du.normalized(), dv.normalized(), n


def blob(bm_target, center, u, v, n, ru, rv, rn, color, layer, segs=14, rings=5):
    """A squashed dome hugging the surface; vertex-coloured into a shared face mesh."""
    vs = []
    if u.cross(v).dot(n) < 0:  # keep the dome's winding outward, or Roblox back-face culls it
        v = -v
    top = bm_target.verts.new(center + n * rn)
    prev = None
    first_ring = None
    for ri in range(1, rings + 1):
        phi = (math.pi / 2) * ri / rings
        ring = []
        for si in range(segs):
            th = 2 * math.pi * si / segs
            d = u * (ru * math.sin(phi) * math.cos(th)) + v * (rv * math.sin(phi) * math.sin(th)) + n * (rn * math.cos(phi))
            ring.append(bm_target.verts.new(center + d))
        if prev is None:
            for si in range(segs):
                f = bm_target.faces.new((top, ring[si], ring[(si + 1) % segs]))
                for l in f.loops:
                    l[layer] = color
        else:
            for si in range(segs):
                j = (si + 1) % segs
                f = bm_target.faces.new((prev[si], ring[si], ring[j], prev[j]))
                for l in f.loops:
                    l[layer] = color
        prev = ring
    return vs


def stroke(bm_target, profile, points, radius, color, layer, lift=0.03, segs=6, flat=0.55):
    """Sweeps a flattened tube along (z, angle) points on the shell: mouths, brows, closed eyes."""
    rings = []
    for idx, (z, ang) in enumerate(points):
        p, u, v, n = surface_frame(profile, z, ang)
        p = p + n * lift
        a = points[max(idx - 1, 0)]
        b = points[min(idx + 1, len(points) - 1)]
        pa = surface_point(profile, a[0], a[1])
        pb = surface_point(profile, b[0], b[1])
        tangent = (pb - pa).normalized()
        side = tangent.cross(n).normalized()
        taper = math.sin(math.pi * (idx + 0.5) / len(points)) ** 0.5
        r = radius * (0.45 + 0.55 * taper)
        ring = []
        for s in range(segs):
            th = 2 * math.pi * s / segs
            ring.append(bm_target.verts.new(p + side * (r * math.cos(th)) + n * (r * flat * math.sin(th))))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for s in range(segs):
            j = (s + 1) % segs
            f = bm_target.faces.new((a[s], a[j], b[j], b[s]))
            for l in f.loops:
                l[layer] = color
    for ring in (rings[0], rings[-1]):
        f = bm_target.faces.new(ring)
        for l in f.loops:
            l[layer] = color


def arc(cz, ca, wz, wa, curve, n=11):
    pts = []
    for i in range(n):
        t = i / (n - 1) * 2 - 1
        pts.append((cz + wz * t + curve * (1 - t * t), ca + wa * t))
    return pts


def eye(bm_target, profile, z, ang, r, layer, tall=1.22, iris=None):
    p, u, v, n = surface_frame(profile, z, ang)
    p = p + n * 0.018
    blob(bm_target, p, u, v, n, r, r * tall, 0.075, iris or INK, layer)
    # Two catchlights: reads as a living eye rather than a button.
    blob(bm_target, p - u * r * 0.30 - v * r * 0.42 + n * 0.066, u, v, n, r * 0.38, r * 0.42, 0.028, WHITE, layer, segs=12, rings=4)
    blob(bm_target, p + u * r * 0.34 + v * r * 0.42 + n * 0.066, u, v, n, r * 0.17, r * 0.19, 0.022, WHITE, layer, segs=10, rings=3)


def build_face(gid, d, profile, state):
    bm = bmesh.new()
    layer = bm.loops.layers.color.new("Col")
    ez, er, ea = d["EyeZ"], d["EyeR"], d["EyeA"]
    mood = d["Mood"]
    mouth_z = ez + er * 1.75
    for side in (-1, 1):
        a = ea * side
        if state == "Idle":
            if mood == "sleepy":
                eye(bm, profile, ez, a, er, layer, tall=0.92)
                stroke(bm, profile, arc(ez - er * 0.62, a, 0.0, er * 1.0 / max(radius_at(profile, ez), 0.1), 0.03), er * 0.26, rgb(d["Fill"]) if False else INK, layer, lift=0.09)
            else:
                eye(bm, profile, ez, a, er, layer)
        elif state == "Blink":
            stroke(bm, profile, arc(ez, a, 0.0, er * 1.05 / max(radius_at(profile, ez), 0.1), 0.05), er * 0.27, INK, layer)
        elif state == "Hurt":
            w = er * 0.95 / max(radius_at(profile, ez), 0.1)
            stroke(bm, profile, [(ez - er * 0.55 + 1.1 * er * i / 6, a + side * w * (1 - abs(i - 3) / 3) * -1 + side * w * 0.0) for i in range(7)], er * 0.26, INK, layer)
        elif state == "Happy":
            stroke(bm, profile, arc(ez + er * 0.15, a, 0.0, er * 1.10 / max(radius_at(profile, ez), 0.1), -er * 0.62), er * 0.30, INK, layer)
        # Blush sits outside the eye and below it: low, wide, soft.
        p, u, v, n = surface_frame(profile, ez + er * 1.25, a * 1.42)
        blob(bm, p + n * 0.012, u, v, n, er * 0.62, er * 0.34, 0.022, BLUSH, layer, segs=14, rings=3)
        # Brows carry the personality.
        if state in ("Idle", "Blink"):
            bw = er * 1.05 / max(radius_at(profile, ez), 0.1)
            if mood == "angry":
                stroke(bm, profile, [(ez - er * (1.62 - 0.62 * (i / 6)), a + side * bw * (1 - i / 3)) for i in range(7)], er * 0.26, INK, layer, lift=0.04)
            elif mood == "cool":
                stroke(bm, profile, [(ez - er * 1.34, a + side * bw * (1 - i / 3)) for i in range(7)], er * 0.2, INK, layer, lift=0.04)
            elif mood == "eager":
                stroke(bm, profile, arc(ez - er * 1.58, a, 0.0, bw * 0.8, -er * 0.22), er * 0.18, INK, layer, lift=0.04)

    mw = er * 1.05 / max(radius_at(profile, mouth_z), 0.1)
    if state == "Hurt":
        # Wobbly gritted line.
        stroke(bm, profile, [(mouth_z + 0.05 * math.sin(i * 1.9), mw * (i / 5 - 1)) for i in range(11)], er * 0.17, MOUTH, layer)
    elif state == "Happy" or mood in ("excited", "friendly", "eager"):
        # Open smile with tongue.
        p, u, v, n = surface_frame(profile, mouth_z + er * 0.18, 0)
        blob(bm, p + n * 0.016, u, v, n, er * 0.62, er * 0.52, 0.04, MOUTH, layer, segs=12, rings=4)
        blob(bm, p + v * er * 0.22 + n * 0.042, u, v, n, er * 0.36, er * 0.22, 0.022, TONGUE, layer, segs=12, rings=3)
    elif mood == "angry":
        stroke(bm, profile, arc(mouth_z + 0.08, 0, 0, mw * 0.72, -0.09), er * 0.17, MOUTH, layer)
    elif mood == "cool":
        stroke(bm, profile, [(mouth_z + 0.03 - 0.07 * (i / 8), mw * 0.72 * (i / 4 - 1)) for i in range(9)], er * 0.15, MOUTH, layer)
    else:
        stroke(bm, profile, arc(mouth_z, 0, 0, mw * 0.5, 0.07), er * 0.17, MOUTH, layer)
    return obj_from_bm(f"Face{state}", bm, None)


def inner_profile(profile, z_range, inset=0.07):
    z0, z1 = z_range
    pts = []
    steps = 22
    for i in range(steps + 1):
        z = z0 + (z1 - z0) * i / steps
        r = max(radius_at(profile, z) - inset, 0.02)
        # Rounded shoulder and base so it reads as a blob of liquid, not a slice of the shell.
        edge = min(i, steps - i) / 3
        if edge < 1:
            r *= math.sqrt(max(1 - (1 - edge) ** 2, 0.0)) * 0.98 + 0.02
        pts.append((r, z))
    return pts


def ring_mesh(name, major, minor, depth, segs=28, sides=10, scale_z=1.0):
    bm = bmesh.new()
    rings = []
    for i in range(segs):
        a = 2 * math.pi * i / segs
        c = Vector((major * math.cos(a), major * math.sin(a), -depth))
        ring = []
        for s in range(sides):
            th = 2 * math.pi * s / sides
            ring.append(bm.verts.new(c + Vector((minor * math.cos(th) * math.cos(a), minor * math.cos(th) * math.sin(a), minor * math.sin(th) * scale_z))))
        rings.append(ring)
    for i in range(segs):
        a, b = rings[i], rings[(i + 1) % segs]
        for s in range(sides):
            j = (s + 1) % sides
            bm.faces.new((a[s], a[j], b[j], b[s]))
    return obj_from_bm(name, bm)


def top_piece(gid, d, profile):
    """The accessory that gives each character its hat and silhouette."""
    parts = []
    z_top = profile[0][1]
    r_top = profile[0][0]
    if gid == "pop":
        # Crimped bottle cap worn like a little hat.
        cap = [(0.0, 0.02), (0.30, 0.03), (0.46, 0.10), (0.48, 0.26), (0.44, 0.34), (0.36, 0.36)]
        parts.append(("Cap", obj_from_bm("Cap", lathe("Cap", cap, segments=20))))
    elif gid == "jam":
        lid = [(0.0, 0.0), (0.92, 0.02), (1.14, 0.08), (1.20, 0.20), (1.20, 0.38), (1.08, 0.44)]
        parts.append(("Lid", obj_from_bm("Lid", lathe("Lid", lid))))
    elif gid == "prism":
        gem = [(0.0, 0.0), (0.26, 0.05), (0.44, 0.18), (0.26, 0.42), (0.06, 0.48)]
        parts.append(("Stopper", obj_from_bm("Stopper", lathe("Stopper", gem, sides=8), smooth=False)))
    elif gid == "water_jug":
        cap = [(0.0, 0.0), (0.44, 0.02), (0.54, 0.08), (0.54, 0.24), (0.46, 0.28)]
        parts.append(("Cap", obj_from_bm("Cap", lathe("Cap", cap, segments=20))))
    elif gid == "ketchup_bottle":
        nozzle = [(0.0, 0.0), (0.08, 0.02), (0.16, 0.14), (0.30, 0.22), (0.36, 0.40), (0.26, 0.46)]
        parts.append(("Cap", obj_from_bm("Cap", lathe("Cap", nozzle, segments=20))))
    elif gid == "glass_cup":
        parts.append(("Rim", ring_mesh("Rim", 0.96, 0.075, 0.10)))
    return parts


def jug_handle(profile):
    """A chunky glass handle on the viewer's right, part of the Jug's silhouette."""
    bm = bmesh.new()
    n, sides = 18, 10
    rings = []
    for i in range(n + 1):
        t = i / n
        z = 0.92 + 1.15 * t
        bulge = math.sin(math.pi * t)
        x = radius_at(profile, z) * 0.82 + 0.74 * bulge
        c = Vector((x, 0, -z))
        ring = []
        for s in range(sides):
            th = 2 * math.pi * s / sides
            ring.append(bm.verts.new(c + Vector((0.13 * math.cos(th), 0.17 * math.sin(th), 0.13 * math.cos(th) * 0.6))))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for s in range(sides):
            j = (s + 1) % sides
            bm.faces.new((a[s], a[j], b[j], b[s]))
    bm.faces.new(rings[0])
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return obj_from_bm("Handle", bm)


def details_for(gid, d, profile):
    """Small touches inside the fill: fizz, seeds, sparkle facets."""
    out = []
    rnd = random.Random(hash(gid) & 0xffff if False else sum(map(ord, gid)))
    if gid in ("pop", "water_jug", "glass_cup"):
        bm = bmesh.new()
        layer = bm.loops.layers.color.new("Col")
        for _ in range(9):
            z = rnd.uniform(d["FillZ"][0] + 0.15, d["FillZ"][1] - 0.2)
            a = rnd.uniform(0, math.tau)
            r = radius_at(profile, z) * rnd.uniform(0.5, 0.82)
            # Bubbles stay behind the face plane so they never read as extra eyes.
            c = Vector((r * math.cos(a), abs(r * math.sin(a)) * 0.9 + 0.1, -z))
            s = rnd.uniform(0.06, 0.13)
            bmesh.ops.create_icosphere(bm, subdivisions=1, radius=s, matrix=__import__("mathutils").Matrix.Translation(c))
        for f in bm.faces:
            for l in f.loops:
                l[layer] = (0.85, 0.97, 1.0, 1)
        out.append(("Fizz", obj_from_bm("Fizz", bm)))
    return out


def make_shards_for(shell, count, seed):
    """Random-plane fracture through the shared helper; falls back to fewer pieces on tiny bodies."""
    return make_shards(shell, pieces=count, seed=seed)


def preview_material(name, base, transmission=0.0, rough=0.25, emission=0.0, use_vertex=False, alpha=1.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    p = nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = base
    p.inputs["Roughness"].default_value = rough
    if "Transmission Weight" in p.inputs:
        p.inputs["Transmission Weight"].default_value = transmission
    if "IOR" in p.inputs:
        p.inputs["IOR"].default_value = 1.25
    if "Alpha" in p.inputs:
        p.inputs["Alpha"].default_value = alpha
    if use_vertex:
        attr = nodes.get("VCol") or nodes.new("ShaderNodeVertexColor")
        attr.name = "VCol"
        attr.layer_name = "Col"
        mat.node_tree.links.new(attr.outputs["Color"], p.inputs["Base Color"])
    mat.blend_method = "BLEND" if alpha < 1 else "OPAQUE"
    return mat


def set_material(ob, mat):
    ob.data.materials.clear()
    ob.data.materials.append(mat)


def build(gid):
    d = BUDDIES[gid]
    clear(gid + "/")
    profile = smooth_profile(d["Profile"])
    shell_bm = lathe("Body", profile, sides=d.get("Sides"))
    shell = obj_from_bm(f"{gid}/Body", shell_bm, smooth=not d.get("Sides"))
    fill = obj_from_bm(f"{gid}/Fill", lathe("Fill", inner_profile(profile, d["FillZ"]), segments=20, sides=d.get("Sides")), smooth=not d.get("Sides"))
    parts = {"Body": shell, "Fill": fill}
    for key, ob in top_piece(gid, d, profile):
        ob.name = f"{gid}/{key}"
        parts[key] = ob
    if gid == "water_jug":
        h = jug_handle(profile)
        h.name = f"{gid}/Handle"
        parts["Handle"] = h
    for key, ob in details_for(gid, d, profile):
        ob.name = f"{gid}/{key}"
        parts[key] = ob
    for state in ("Idle", "Blink", "Hurt", "Happy"):
        f = build_face(gid, d, profile, state)
        f.name = f"{gid}/Face{state}"
        parts[f"Face{state}"] = f
    # Preview materials only; final Glass/SmoothPlastic and colours are set in Studio (ART_BIBLE).
    set_material(shell, preview_material(f"BV5_{gid}_glass", rgb(d["Glass"]), rough=0.06, alpha=0.26))
    set_material(fill, preview_material(f"BV5_{gid}_fill", rgb(d["Fill"]), rough=0.18))
    for key, ob in parts.items():
        if key.startswith("Face"):
            set_material(ob, preview_material("BV5_face", (1, 1, 1, 1), rough=0.12, use_vertex=True))
        elif key in ("Cap", "Lid", "Stopper", "Rim", "Handle"):
            col = rgb(d["Top"]) if d["Top"] and key != "Handle" and key != "Rim" else rgb(d["Glass"])
            alpha = 0.45 if key in ("Rim", "Handle") else 1.0
            set_material(ob, preview_material(f"BV5_{gid}_{key}", col, rough=0.16, alpha=alpha))
        elif key == "Fizz":
            set_material(ob, preview_material("BV5_fizz", (0.9, 0.98, 1.0, 1), rough=0.1))
    for key in ("FaceBlink", "FaceHurt", "FaceHappy"):
        parts[key].hide_render = True
        parts[key].hide_viewport = True
    return parts


def stats(parts):
    out = {}
    for key, ob in parts.items():
        ob.data.calc_loop_triangles()
        out[key] = len(ob.data.loop_triangles)
    out["Total"] = sum(v for k, v in out.items() if k not in ("FaceBlink", "FaceHurt", "FaceHappy"))
    return out


def lay_out_row(all_parts, spacing=3.9, y=0.0):
    ids = list(all_parts)
    for i, gid in enumerate(ids):
        x = (i - (len(ids) - 1) / 2) * spacing
        for ob in all_parts[gid].values():
            ob.location = (x, y, 0)


def stage_for_preview(states="Idle"):
    scene = bpy.context.scene
    world = bpy.data.worlds.get("BV5_world") or bpy.data.worlds.new("BV5_world")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (0.012, 0.012, 0.035, 1)
    bg.inputs[1].default_value = 1.0
    scene.world = world
    cam_data = bpy.data.cameras.get("BV5_cam") or bpy.data.cameras.new("BV5_cam")
    cam = bpy.data.objects.get("BV5_cam") or bpy.data.objects.new("BV5_cam", cam_data)
    if cam.name not in collection().objects:
        collection().objects.link(cam)
    cam_data.lens = 70
    cam.location = (0, -48, -1.4)
    cam.rotation_euler = (math.pi / 2, 0, 0)
    scene.camera = cam
    for name, loc, energy, color, size in (
        ("BV5_key", (-7, -12, 8), 1250, (1, 0.97, 0.94), 10),
        ("BV5_rim", (9, 8, 6), 1500, (0.8, 0.88, 1), 8),
        ("BV5_fillLight", (6, -14, -6), 520, (1, 0.94, 1), 12),
    ):
        data = bpy.data.lights.get(name) or bpy.data.lights.new(name, "AREA")
        data.energy, data.color, data.size = energy, color, size
        lamp = bpy.data.objects.get(name) or bpy.data.objects.new(name, data)
        if lamp.name not in collection().objects:
            collection().objects.link(lamp)
        lamp.location = loc
        lamp.rotation_euler = (Vector((0, 0, -1.4)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in {i.identifier for i in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items} else "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x, scene.render.resolution_y = 1800, 520
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    try:
        scene.eevee.use_raytracing = True
    except Exception:
        pass


def show_state(all_parts, state):
    for parts in all_parts.values():
        for key, ob in parts.items():
            if key.startswith("Face"):
                visible = key == "Face" + state
                ob.hide_render = not visible
                ob.hide_viewport = not visible


def build_all(ids=None):
    default_cube = bpy.data.objects.get("Cube")
    if default_cube:  # keep the user's scene intact; just keep it out of the previews
        default_cube.hide_render = True
        default_cube.hide_viewport = True
    all_parts = {gid: build(gid) for gid in (ids or BUDDIES)}
    lay_out_row(all_parts)
    stage_for_preview()
    return all_parts, {gid: stats(p) for gid, p in all_parts.items()}


def crack_paths(gid, seed_offset=0):
    """Jagged surface cracks in Roblox model space (x, z, -y), stage 1-3, drawn on the shell front.
    Format matches Config CrackPaths rows: {ax, ay, az, bx, by, bz, stage}."""
    d = BUDDIES[gid]
    profile = smooth_profile(d["Profile"])
    z_min, z_max = d["FillZ"][0] + 0.05, d["FillZ"][1] - 0.1
    rnd = random.Random(sum(map(ord, gid)) + seed_offset)
    rows = []
    for stage, count, length in ((1, 2, 5), (2, 3, 6), (3, 4, 7)):
        for _ in range(count):
            # Keep cracks off the face so expressions stay readable: start beside it and run outward.
            side = rnd.choice((-1, 1))
            ang = side * rnd.uniform(0.75, 1.5)
            z = rnd.uniform(z_min, z_max)
            for _ in range(length):
                nz = min(max(z + rnd.uniform(-0.3, 0.3), z_min), z_max)
                na = ang + side * rnd.uniform(0.04, 0.24)
                a = surface_point(profile, z, ang, lift=0.02)
                b = surface_point(profile, nz, na, lift=0.02)
                rows.append([round(a.x, 3), round(a.z, 3), round(-a.y, 3), round(b.x, 3), round(b.z, 3), round(-b.y, 3), stage])
                z, ang = nz, na
    return rows


def export_all(ids=None, shard_count=14):
    """Bundles Body, Fill, accessories, faces and shards into one FBX per glassy; returns a manifest."""
    import json
    helper = {"__name__": "gc_helper", "GLASSCLASH_REPO": _REPO}
    exec(compile(open(os.path.join(_REPO, "tools", "blender", "glassclash_blender.py")).read(), "gc", "exec"), helper)
    manifest = {}
    os.makedirs(OUT, exist_ok=True)
    for gid in (ids or BUDDIES):
        parts = build(gid)
        for ob in parts.values():
            ob.hide_viewport = False
            ob.hide_render = False
            ob.location = (0, 0, 0)
        bpy.context.view_layer.update()
        shards = helper["make_shards"](parts["Body"], pieces=shard_count, seed=sum(map(ord, gid)))
        for s in shards:
            if s.name not in collection().objects:
                for c in list(s.users_collection):
                    c.objects.unlink(s)
                collection().objects.link(s)
            s.name = f"{gid}/{s.name}"
        objects = list(parts.values()) + shards
        # FBX object names become MeshPart names, so strip the "<id>/" namespace for the export only.
        originals = {ob: ob.name for ob in objects}
        for ob in objects:
            ob.name = ob.name.split("/", 1)[1]
        path = os.path.join(OUT, f"{gid}_bundle.fbx")
        try:
            helper["export_fbx"](objects, path)
        finally:
            for ob, name in originals.items():
                ob.name = name
        manifest[gid] = {
            "Name": BUDDIES[gid]["Name"], "Fill": BUDDIES[gid]["Fill"], "Glass": BUDDIES[gid]["Glass"],
            "Top": BUDDIES[gid]["Top"], "Stats": stats(parts), "Shards": len(shards),
            "Cracks": crack_paths(gid),
        }
        for s in shards:
            bpy.data.objects.remove(s, do_unlink=True)
    with open(os.path.join(OUT, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=1)
    return manifest


def render_icons(ids=None, size=512):
    """Transparent 512 px portraits with the shared camera, one per glassy (and one Happy face row)."""
    scene = bpy.context.scene
    stage_for_preview()
    scene.render.film_transparent = True
    scene.render.resolution_x, scene.render.resolution_y = size, size
    cam = scene.camera
    out = os.path.join(_REPO, "assets", "icons", "glassies_v5")
    os.makedirs(out, exist_ok=True)
    built = {}
    for gid in (ids or BUDDIES):
        built[gid] = build(gid)
    for gid, parts in built.items():
        for other, oparts in built.items():
            for key, ob in oparts.items():
                ob.location = (0, 0, 0)
                visible = other == gid and (not key.startswith("Face") or key == "FaceIdle")
                ob.hide_render = not visible
                ob.hide_viewport = not visible
        cz = -BUDDIES[gid]["Profile"][-1][1] / 2 + 0.08
        cam.location = (0, -8.8, cz)
        cam.rotation_euler = (math.pi / 2, 0, 0)
        scene.render.filepath = os.path.join(out, f"{gid}.png")
        bpy.ops.render.render(write_still=True)
    scene.render.film_transparent = False
    return out
