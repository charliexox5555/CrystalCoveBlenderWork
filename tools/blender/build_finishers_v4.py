"""Finishers v4: hero meshes and particle textures for the seven launch finishers (docs/design/COSMETICS_V2.md §4.2).

Headless:  /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/blender/build_finishers_v4.py
Writes assets/blender/round_cosmetics/finishers_v4/{finishers_v4.fbx, finishers_v4.blend, manifest.json,
preview.png, textures/*.png}. Refuses to overwrite an existing FBX.

Reuses the v3 helpers (Roblox-space authoring, flat pieces facing Roblox -Z, bbox-centred meshes). Glassy heroes
(Glass Unicorn, Glass Phoenix, Potion Flask) are not rebuilt: the shows use the installed glassy models.
"""
import json
import math
import os

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
_v3 = open(os.path.join(HERE, "build_finishers_v3.py")).read()
_v3 = _v3[: _v3.rindex("main()")]  # helpers only
exec(_v3)

OUT = os.path.join(REPO, "assets", "blender", "round_cosmetics", "finishers_v4")
PREFIX = "FV4_"


def merge(name, parts, smooth=False, bevel=0.0):
    """parts: list of (verts, faces) in Roblox space; joined into one mesh object."""
    verts, faces = [], []
    for v, f in parts:
        base = len(verts)
        verts += v
        faces += [[base + i for i in face] for face in f]
    return mesh_from(name, verts, faces, smooth=smooth, bevel=bevel)


def box(cx, cy, cz, sx, sy, sz, rot=0.0):
    """Axis box in Roblox space, rotated by `rot` radians about Z (the view axis)."""
    c, s = math.cos(rot), math.sin(rot)
    verts = []
    for dx in (-sx / 2, sx / 2):
        for dy in (-sy / 2, sy / 2):
            for dz in (-sz / 2, sz / 2):
                x, y = dx * c - dy * s, dx * s + dy * c
                verts.append((cx + x, cy + y, cz + dz))
    faces = [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
    return verts, faces


def ellipsoid(cx, cy, cz, rx, ry, rz, seg=12, rings=8):
    verts, faces = [], []
    for r in range(rings + 1):
        phi = math.pi * r / rings
        for k in range(seg):
            th = 2 * math.pi * k / seg
            verts.append((cx + rx * math.sin(phi) * math.cos(th), cy + ry * math.cos(phi), cz + rz * math.sin(phi) * math.sin(th)))
    for r in range(rings):
        for k in range(seg):
            a, b = r * seg + k, r * seg + (k + 1) % seg
            faces.append([a, b, b + seg, a + seg])
    return verts, faces


def lathe_rings(profile, seg=24):
    """profile: list of (radius, y); returns verts/faces of a surface of revolution about Roblox Y."""
    rings = []
    for r, y in profile:
        rings.append([(r * math.cos(2 * math.pi * k / seg), y, r * math.sin(2 * math.pi * k / seg)) for k in range(seg)])
    v, f = ring_loft(rings)
    # Cap both ends.
    n = len(v)
    v.append((0, profile[0][1], 0))
    v.append((0, profile[-1][1], 0))
    for k in range(seg):
        f.append([(k + 1) % seg, k, n])
        last = (len(profile) - 1) * seg
        f.append([last + k, last + (k + 1) % seg, n + 1])
    return v, f


# ---------------------------------------------------------------------------------------------- meshes
def ice_slab():
    # A chunky ice slab with chipped corners and a low faceted face.
    outline = [(-0.5, -0.42), (-0.42, -0.5), (0.42, -0.5), (0.5, -0.4), (0.5, 0.42), (0.4, 0.5), (-0.44, 0.5), (-0.5, 0.44)]
    return slab("IceSlab", outline, 0.2, front_apex=0.06, back_apex=0.03, bevel=0.02)


def glass_snowflake():
    parts = [ellipsoid(0, 0, 0, 0.16, 0.16, 0.05, seg=6, rings=2)]
    for k in range(6):
        a = k * math.pi / 3
        cx, cy = math.cos(a) * 0.5, math.sin(a) * 0.5
        parts.append(box(cx, cy, 0, 1.0, 0.1, 0.07, a))
        for side in (-1, 1):
            b = a + side * math.pi / 3
            bx, by = math.cos(a) * 0.62 + math.cos(b) * 0.13, math.sin(a) * 0.62 + math.sin(b) * 0.13
            parts.append(box(bx, by, 0, 0.28, 0.07, 0.06, b))
        parts.append(ellipsoid(math.cos(a) * 1.0, math.sin(a) * 1.0, 0, 0.07, 0.07, 0.05, seg=6, rings=2))
    return merge("GlassSnowflake", parts)


def gumball_base():
    profile = [(0.0, 0.0), (0.62, 0.0), (0.66, 0.06), (0.6, 0.42), (0.5, 0.5), (0.36, 0.56), (0.42, 0.62), (0.42, 0.7), (0.0, 0.7)]
    v, f = lathe_rings(profile[1:-1], seg=24)
    parts = [(v, f), box(0, 0.24, -0.6, 0.34, 0.26, 0.1)]  # coin plate on the front (-Z)
    return merge("GumballBase", parts, smooth=True)


def gumball_lid():
    # The coin-slot lid that pops at the peak (front plate with a slot groove).
    return merge("GumballLid", [box(0, 0, 0, 0.26, 0.18, 0.06), box(0, 0, -0.04, 0.16, 0.035, 0.03)])


def gumball_crank():
    parts = [ellipsoid(0, 0, 0, 0.16, 0.16, 0.05, seg=12, rings=4), box(0.16, 0, -0.04, 0.32, 0.06, 0.05), ellipsoid(0.32, 0, -0.1, 0.06, 0.06, 0.1, seg=8, rings=4)]
    return merge("GumballCrank", parts, smooth=True)


def honey_hex():
    outer = polygon(6, 0.5, phase=0)
    n = len(outer)
    inner = polygon(6, 0.36, phase=0)
    verts, faces = [], []
    # back face (+Z), side walls, front rim and a recessed honey floor.
    verts += [(x, y, 0.2) for x, y in outer]  # 0..5 back
    verts += [(x, y, -0.2) for x, y in outer]  # 6..11 front outer
    verts += [(x, y, -0.2) for x, y in inner]  # 12..17 front inner rim
    verts += [(x, y, -0.05) for x, y in inner]  # 18..23 recess floor
    faces.append(list(range(5, -1, -1)))
    for i in range(n):
        j = (i + 1) % n
        faces.append([i, j, 6 + j, 6 + i])
        faces.append([6 + i, 6 + j, 12 + j, 12 + i])
        faces.append([12 + i, 12 + j, 18 + j, 18 + i])
    faces.append([18 + i for i in range(n)])
    return mesh_from("HoneyHex", verts, faces, bevel=0.015)


def bee_body():
    return merge("BeeBody", [ellipsoid(0, 0, 0, 0.42, 0.3, 0.3, seg=14, rings=8), ellipsoid(0.42, 0.04, 0, 0.18, 0.18, 0.18, seg=10, rings=6)], smooth=True)


def bee_stripes():
    parts = []
    for x in (-0.18, 0.06):
        ring = []
        seg = 16
        for k in range(seg):
            th = 2 * math.pi * k / seg
            ring.append((x - 0.05, 0.305 * math.cos(th), 0.305 * math.sin(th)))
        ring2 = [(p[0] + 0.1, p[1], p[2]) for p in ring]
        v, f = ring_loft([ring, ring2])
        parts.append((v, f))
    return merge("BeeStripes", parts, smooth=True)


def bee_wings():
    parts = []
    for side in (-1, 1):
        pts = polygon(10, 1.0)
        v = [(0.05 + px * 0.16, 0.32 + py * 0.26 + 0.2, side * 0.18) for px, py in pts]
        f = [list(range(len(v)))]
        parts.append((v, f))
    return mesh_from("BeeWings", sum([p[0] for p in parts], []), [parts[0][1][0], [i + 10 for i in parts[1][1][0]]])


def frog_body():
    parts = [
        ellipsoid(0, 0, 0, 0.55, 0.38, 0.45, seg=16, rings=10),
        ellipsoid(-0.24, 0.36, -0.14, 0.16, 0.16, 0.16, seg=10, rings=6),
        ellipsoid(0.24, 0.36, -0.14, 0.16, 0.16, 0.16, seg=10, rings=6),
        ellipsoid(-0.42, -0.28, -0.2, 0.18, 0.1, 0.22, seg=10, rings=6),
        ellipsoid(0.42, -0.28, -0.2, 0.18, 0.1, 0.22, seg=10, rings=6),
        ellipsoid(-0.5, -0.3, 0.22, 0.24, 0.12, 0.28, seg=10, rings=6),
        ellipsoid(0.5, -0.3, 0.22, 0.24, 0.12, 0.28, seg=10, rings=6),
    ]
    return merge("FrogBody", parts, smooth=True)


def frog_crown():
    seg = 5 * 2
    base = [(0.2 * math.cos(2 * math.pi * k / seg), 0.0, 0.2 * math.sin(2 * math.pi * k / seg)) for k in range(seg)]
    mid = [(0.21 * math.cos(2 * math.pi * k / seg), 0.1, 0.21 * math.sin(2 * math.pi * k / seg)) for k in range(seg)]
    top = [(0.23 * math.cos(2 * math.pi * k / seg), 0.26 if k % 2 == 0 else 0.14, 0.23 * math.sin(2 * math.pi * k / seg)) for k in range(seg)]
    v, f = ring_loft([base, mid, top])
    parts = [(v, f)]
    for k in range(0, seg, 2):
        a = 2 * math.pi * k / seg
        parts.append(ellipsoid(0.23 * math.cos(a), 0.28, 0.23 * math.sin(a), 0.03, 0.03, 0.03, seg=6, rings=3))
    obj = merge("FrogCrown", parts, smooth=True)
    mod = obj.modifiers.new("Solidify", "SOLIDIFY")
    mod.thickness = 0.03
    obj.modifiers.move(len(obj.modifiers) - 1, 0)
    return obj


def flower_stem():
    # A gently curved tube (along +Y) with one leaf.
    rings = []
    seg = 8
    for i in range(9):
        y = i / 8 * 1.6
        cx = 0.12 * math.sin(i / 8 * math.pi)
        r = 0.05
        rings.append([(cx + r * math.cos(2 * math.pi * k / seg), y, r * math.sin(2 * math.pi * k / seg)) for k in range(seg)])
    v, f = ring_loft(rings)
    leaf = [(0.05 + 0.32 * u, 0.55 + 0.18 * u + 0.12 * math.sin(u * math.pi), 0.0) for u in (0, 0.25, 0.5, 0.75, 1.0)]
    leaf_low = [(0.05 + 0.32 * u, 0.55 + 0.18 * u - 0.12 * math.sin(u * math.pi), 0.0) for u in (0.25, 0.5, 0.75)]
    lv = leaf + list(reversed(leaf_low))
    base = len(v)
    v += lv
    f.append([base + i for i in range(len(lv))])
    return mesh_from("FlowerStem", v, f, smooth=True)


def flower_bud():
    profile = [(0.0, 0.0), (0.16, 0.08), (0.22, 0.24), (0.18, 0.4), (0.08, 0.52), (0.0, 0.58)]
    v, f = lathe_rings(profile[1:-1], seg=12)
    return mesh_from("FlowerBud", v, f, smooth=True)


def flower_bloom():
    # Six cupped petals around a centre dome, facing Roblox -Z (toward the camera).
    parts = [ellipsoid(0, 0, -0.04, 0.16, 0.16, 0.08, seg=12, rings=6)]
    for k in range(6):
        a = k * math.pi / 3
        verts, faces = [], []
        rows = 4
        cols = 5
        for r in range(rows + 1):
            u = r / rows
            width = 0.2 * math.sin(math.pi * min(1, u * 1.15)) + 0.02
            for c in range(cols + 1):
                w = (c / cols - 0.5) * 2
                along = 0.12 + u * 0.48
                lat = w * width
                cup = 0.12 * u * u - 0.05 * (1 - w * w) * u
                x = math.cos(a) * along - math.sin(a) * lat
                y = math.sin(a) * along + math.cos(a) * lat
                verts.append((x, y, -cup))
        for r in range(rows):
            for c in range(cols):
                i = r * (cols + 1) + c
                faces.append([i, i + 1, i + cols + 2, i + cols + 1])
        parts.append((verts, faces))
    obj = merge("FlowerBloom", parts, smooth=True)
    mod = obj.modifiers.new("Solidify", "SOLIDIFY")
    mod.thickness = 0.03
    obj.modifiers.move(len(obj.modifiers) - 1, 0)
    return obj


def rainbow_arc():
    seg = 32
    outer = [(math.cos(math.pi * k / seg), math.sin(math.pi * k / seg)) for k in range(seg + 1)]
    inner = [(0.86 * x, 0.86 * y) for x, y in reversed(outer)]
    return slab("RainbowArc", outer + inner, 0.08)


def sun_feather():
    pts = []
    n = 12
    for k in range(n + 1):
        u = k / n
        pts.append((0.22 * math.sin(math.pi * u) * (1 - 0.3 * u), u * 1.2 - 0.6))
    outline = pts + [(-x, y) for x, y in reversed(pts[1:-1])]
    feather = slab("SunFeatherPlate", outline, 0.04, front_apex=0.03)
    return feather


def rune_ring():
    seg = 48
    verts, faces = [], []
    for z in (-0.04, 0.04):
        verts += [(math.cos(2 * math.pi * k / seg), math.sin(2 * math.pi * k / seg), z) for k in range(seg)]
        verts += [(0.88 * math.cos(2 * math.pi * k / seg), 0.88 * math.sin(2 * math.pi * k / seg), z) for k in range(seg)]
    o0, i0, o1, i1 = 0, seg, 2 * seg, 3 * seg
    for k in range(seg):
        n = (k + 1) % seg
        faces += [[o0 + k, o0 + n, i0 + n, i0 + k], [o1 + k, i1 + k, i1 + n, o1 + n], [o0 + k, o1 + k, o1 + n, o0 + n], [i0 + k, i0 + n, i1 + n, i1 + k]]
    parts = [(verts, faces)]
    # Raised rune marks: alternating diamonds and bars around the band.
    for k in range(12):
        a = 2 * math.pi * k / 12
        cx, cy = math.cos(a) * 0.94, math.sin(a) * 0.94
        if k % 2 == 0:
            parts.append(box(cx, cy, -0.06, 0.07, 0.07, 0.05, a + math.pi / 4))
        else:
            parts.append(box(cx, cy, -0.06, 0.03, 0.1, 0.05, a))
    return merge("RuneRing", parts)


# ---------------------------------------------------------------------------------------------- textures
def tex_snow():
    x, y = grid(256)
    r = np.sqrt(x * x + y * y)
    th = np.arctan2(y, x)
    arms = np.exp(-((np.sin(3 * th) * r) / 0.05) ** 2) * np.clip(1 - r / 0.9, 0, 1)
    core = np.exp(-((r / 0.12) ** 2))
    glow = 0.25 * np.exp(-((r / 0.5) ** 2))
    return save_png("Snow", white(arms + core + glow))


def tex_petal():
    x, y = grid(256)
    u = (y + 0.9) / 1.8
    width = 0.55 * np.sin(np.pi * np.clip(u, 0, 1)) ** 0.8 * (1 - 0.25 * u)
    a = np.clip((width - np.abs(x)) / 0.05, 0, 1) * (u > 0) * (u < 1)
    shade = 0.75 + 0.25 * (1 - np.abs(x) / 0.6)
    rgba = np.ones(x.shape + (4,))
    rgba[..., 0:3] = np.clip(shade, 0, 1)[..., None]
    rgba[..., 3] = a
    return save_png("Petal", rgba)


def tex_ember():
    x, y = grid(256)
    r = np.sqrt(x * x + (y * 0.8) ** 2)
    return save_png("Ember", white(np.exp(-((r / 0.18) ** 2)) * 1.2 + 0.45 * np.exp(-((r / 0.5) ** 2))))


def tex_feather():
    x, y = grid(256)
    u = (y + 0.95) / 1.9
    width = 0.32 * np.sin(np.pi * np.clip(u, 0, 1)) * (1 - 0.3 * u)
    vane = np.clip((width - np.abs(x)) / 0.04, 0, 1) * (u > 0) * (u < 1)
    barbs = 0.75 + 0.25 * np.cos(60 * (y + np.abs(x) * 0.8))
    rib = np.exp(-((x / 0.02) ** 2)) * (u > -0.05) * (u < 1.05)
    return save_png("Feather", white(vane * barbs + rib))


def tex_heart():
    x, y = grid(256)
    x, y = x * 1.25, y * 1.25 + 0.15
    f = (x * x + y * y - 0.5) ** 3 - x * x * y ** 3
    a = np.clip(-f / 0.01, 0, 1)
    return save_png("Heart", white(a))


def tex_hex():
    x, y = grid(256)
    ax = np.abs(x)
    d = np.maximum(ax * 0.866 + np.abs(y) * 0.5, np.abs(y))
    rim = np.exp(-(((d - 0.7) / 0.06) ** 2))
    core = 0.25 * (d < 0.7)
    glint = np.exp(-(((x + 0.25) / 0.12) ** 2 + ((y - 0.3) / 0.06) ** 2))
    return save_png("Hex", white(rim + core + glint))


def main():
    fbx = os.path.join(OUT, "finishers_v4.fbx")
    if os.path.exists(fbx):
        raise RuntimeError("finishers_v4 export exists; make a new revision instead of overwriting")
    os.makedirs(OUT, exist_ok=True)
    scene = bpy.context.scene
    for obj in list(scene.objects):
        bpy.data.objects.remove(obj)
    builders = [ice_slab, glass_snowflake, gumball_base, gumball_lid, gumball_crank, honey_hex, bee_body, bee_stripes,
                bee_wings, frog_body, frog_crown, flower_stem, flower_bud, flower_bloom, rainbow_arc, sun_feather, rune_ring]
    objects = [build() for build in builders]
    tints = {
        "IceSlab": "#BFEFFF", "GlassSnowflake": "#FFFFFF", "GumballBase": "#FF5A4E", "GumballLid": "#FFD34E",
        "GumballCrank": "#FFD34E", "HoneyHex": "#FFB92E", "BeeBody": "#FFD34E", "BeeStripes": "#5A3A1A",
        "BeeWings": "#E8F8FF", "FrogBody": "#6CFF9A", "FrogCrown": "#FFD34E", "FlowerStem": "#7CD992",
        "FlowerBud": "#FF8FB8", "FlowerBloom": "#FF8FB8", "RainbowArc": "#FFD6F5", "SunFeatherPlate": "#FF7A2E",
        "RuneRing": "#FFD34E",
    }
    for obj in objects:
        short = obj.name[len(PREFIX):]
        assign_material([obj], glossy_preview_material("GC_Preview4_" + short, tints.get(short, "#FFFFFF")))
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    manifest = {"Version": 4, "Meshes": {}}
    total = 0
    for obj in objects:
        evaluated = obj.evaluated_get(depsgraph)
        m = evaluated.to_mesh()
        tris = sum(len(p.vertices) - 2 for p in m.polygons)
        pts = [obj.matrix_world @ v.co for v in m.vertices]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        size, centre = hi - lo, (lo + hi) / 2
        evaluated.to_mesh_clear()
        total += tris
        manifest["Meshes"][obj.name] = {
            "Tris": tris,
            "RobloxSize": [round(size.x, 4), round(size.z, 4), round(size.y, 4)],
            "RobloxCentre": [round(centre.x, 4), round(centre.z, 4), round(-centre.y, 4)],
        }
    manifest["TotalTris"] = total
    export_fbx(objects, fbx)
    textures = [tex_snow(), tex_petal(), tex_ember(), tex_feather(), tex_heart(), tex_hex()]
    manifest["Textures"] = [os.path.relpath(p, OUT) for p in textures]
    x, shifts = 0.0, []
    for obj in objects:
        obj.location.x += x
        shifts.append(x)
        x += 2.4
    bpy.context.view_layer.update()
    try:
        render_icon(objects, os.path.join(OUT, "preview.png"), size=1024, samples=24)
    except Exception as err:
        manifest["PreviewError"] = str(err)
    for obj, shift in zip(objects, shifts):
        obj.location.x -= shift
    bpy.data.libraries.write(os.path.join(OUT, "finishers_v4.blend"), {scene}, fake_user=True, compress=True)
    with open(os.path.join(OUT, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=2)
    print("FINISHERS_V4", json.dumps({"total_tris": total, "meshes": len(objects)}))


main()
