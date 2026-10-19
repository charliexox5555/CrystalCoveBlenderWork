"""Finishers v3: original meshes and particle textures for the five standard finishers (docs/vfx/FINISHERS_V2.md).

Headless:  /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/blender/build_finishers_v3.py
Writes assets/blender/round_cosmetics/finishers_v3/{finishers_v3.fbx, finishers_v3.blend, manifest.json,
preview.png, textures/*.png}. Refuses to overwrite an existing FBX (make a new revision instead).

Coordinates: 1 BU = 1 stud. Shapes are authored in Roblox space and converted (Roblox (x, y, z) = Blender
(x, -z, y)). Flat pieces face Roblox -Z (the part's Front), so CFrame.lookAt(position, camera) shows their front.
Each mesh is centred on its bounding box, which is where Roblox puts a MeshPart's pivot.
"""
import json
import math
import os
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
GLASSCLASH_REPO = REPO
exec(open(os.path.join(HERE, "glassclash_blender.py")).read())
set_repo(REPO)

OUT = os.path.join(REPO, "assets", "blender", "round_cosmetics", "finishers_v3")
PREFIX = "FV3_"


def to_blender(p):
    x, y, z = p
    return (x, -z, y)


def mesh_from(name, verts, faces, smooth=False, bevel=0.0, solidify=0.0):
    """verts in Roblox space; faces wound counter-clockwise seen from outside (normals recalculated anyway)."""
    bm = bmesh.new()
    bv = [bm.verts.new(to_blender(v)) for v in verts]
    for f in faces:
        try:
            bm.faces.new([bv[i] for i in f])
        except ValueError:
            pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    if not solidify:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(PREFIX + name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(PREFIX + name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for poly in mesh.polygons:
        poly.use_smooth = smooth
    if solidify:
        mod = obj.modifiers.new("Solidify", "SOLIDIFY")
        mod.thickness, mod.offset = solidify, 0
    if bevel:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width, mod.segments, mod.limit_method, mod.angle_limit = bevel, 1, "ANGLE", math.radians(40)
    obj.modifiers.new("Triangulate", "TRIANGULATE")
    return obj


def polygon(n, radius, phase=math.pi / 2, jitter=None):
    pts = []
    for i in range(n):
        r = radius * (jitter[i % len(jitter)] if jitter else 1)
        a = phase + i / n * math.pi * 2
        pts.append((math.cos(a) * r, math.sin(a) * r))
    return pts


def slab(name, outline, depth, front_apex=0.0, back_apex=0.0, bevel=0.0):
    """Extrudes a 2D outline (Roblox XY) through Z = ±depth/2; optional gem apexes on the front (-Z) and back."""
    n = len(outline)
    verts = [(x, y, -depth / 2) for x, y in outline] + [(x, y, depth / 2) for x, y in outline]
    faces = [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
    if front_apex:
        verts.append((0, 0, -depth / 2 - front_apex))
        c = len(verts) - 1
        faces += [[i, c, (i + 1) % n] for i in range(n)]
    else:
        faces.append(list(range(n)))
    if back_apex:
        verts.append((0, 0, depth / 2 + back_apex))
        c = len(verts) - 1
        faces += [[n + (i + 1) % n, c, n + i] for i in range(n)]
    else:
        faces.append(list(range(2 * n - 1, n - 1, -1)))
    return mesh_from(name, verts, faces, bevel=bevel)


def ring_loft(rings, closed_ends=True):
    """rings: list of point lists with equal counts; returns verts, faces of the lofted tube."""
    verts, faces = [], []
    m = len(rings[0])
    for ring in rings:
        verts += ring
    for r in range(len(rings) - 1):
        for i in range(m):
            a, b = r * m + i, r * m + (i + 1) % m
            faces.append([a, b, b + m, a + m])
    return verts, faces


# ---------------------------------------------------------------------------------------------- meshes
def prism_facet():
    # One pentagonal gem plate of a dodecahedron shell; 12 copies form the Prism Pop shell.
    return slab("PrismFacet", polygon(5, 1.0), 0.14, front_apex=0.0, back_apex=0.3)


def prism_sliver():
    verts, faces = [], []
    sides = 6
    for x, r in ((-0.55, 0.12), (0.55, 0.12)):
        for i in range(sides):
            a = i / sides * math.pi * 2
            verts.append((x, math.cos(a) * r, math.sin(a) * r))
    faces += [[i, (i + 1) % sides, sides + (i + 1) % sides, sides + i] for i in range(sides)]
    verts += [(-1.0, 0, 0), (1.0, 0, 0)]
    faces += [[(i + 1) % sides, i, 2 * sides] for i in range(sides)]
    faces += [[sides + i, sides + (i + 1) % sides, 2 * sides + 1] for i in range(sides)]
    return mesh_from("PrismSliver", verts, faces)


def pinata_point():
    # One arm of the piñata star, base at y = 0 pointing +Y, faceted diamond section.
    base = [(-0.5, 0, 0), (0, 0, -0.34), (0.5, 0, 0), (0, 0, 0.34)]
    mid = [(-0.36, 0.5, 0), (0, 0.5, -0.27), (0.36, 0.5, 0), (0, 0.5, 0.27)]
    verts = base + mid + [(0, 1.25, 0)]
    faces = [[i, (i + 1) % 4, 4 + (i + 1) % 4, 4 + i] for i in range(4)]
    faces += [[4 + i, 4 + (i + 1) % 4, 8] for i in range(4)]
    faces.append([3, 2, 1, 0])
    return mesh_from("PinataPoint", verts, faces, bevel=0.03)


def pinata_core():
    return slab("PinataCore", polygon(5, 0.78), 0.62, front_apex=0.28, back_apex=0.28, bevel=0.03)


def candy_gem():
    verts, faces = [], []
    # Faceted centre: an 8-sided bicone along X.
    sides = 8
    for x, r in ((-0.32, 0.36), (0.32, 0.36)):
        for i in range(sides):
            a = i / sides * math.pi * 2
            verts.append((x, math.cos(a) * r, math.sin(a) * r))
    faces += [[i, (i + 1) % sides, sides + (i + 1) % sides, sides + i] for i in range(sides)]
    verts += [(-0.5, 0, 0), (0.5, 0, 0)]
    faces += [[(i + 1) % sides, i, 2 * sides] for i in range(sides)]
    faces += [[sides + i, sides + (i + 1) % sides, 2 * sides + 1] for i in range(sides)]
    # Two zig-zag wrapper fans.
    for s in (-1, 1):
        start = len(verts)
        verts.append((s * 0.42, 0, -0.06))
        verts.append((s * 0.42, 0, 0.06))
        tips = [(-0.36, s * 0.98), (-0.12, s * 0.86), (0.0, s * 1.0), (0.12, s * 0.86), (0.36, s * 0.98)]
        for y, x in tips:
            verts.append((x, y, -0.05))
            verts.append((x, y, 0.05))
        k = len(tips)
        for i in range(k - 1):
            a, b = start + 2 + 2 * i, start + 2 + 2 * (i + 1)
            faces.append([start, a, b])
            faces.append([start + 1, b + 1, a + 1])
            faces.append([a, a + 1, b + 1, b])
        first, last = start + 2, start + 2 + 2 * (k - 1)
        faces.append([start, start + 1, first + 1, first])
        faces.append([start, last, last + 1, start + 1])
    return mesh_from("CandyGem", verts, faces)


def fizz_crown():
    n = 14
    base, top, tips = [], [], []
    for i in range(n * 2):
        a = i / (n * 2) * math.pi * 2
        base.append((math.cos(a) * 0.62, 0.0, math.sin(a) * 0.62))
        top.append((math.cos(a) * 0.95, 0.5, math.sin(a) * 0.95))
        spike = i % 2 == 0
        r, y = (1.12, 1.0) if spike else (1.0, 0.62)
        tips.append((math.cos(a) * r, y, math.sin(a) * r))
    verts, faces = ring_loft([base, top, tips])
    obj = mesh_from("FizzCrown", verts, faces, smooth=True, solidify=0.07)
    return obj


def fizz_drops():
    # Droplet beads that sit on the crown's spike tips (separate so they can be tinted brighter).
    bm = bmesh.new()
    n = 14
    for i in range(0, n * 2, 2):
        a = i / (n * 2) * math.pi * 2
        center = to_blender((math.cos(a) * 1.16, 1.12, math.sin(a) * 1.16))
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.09, matrix=__import__("mathutils").Matrix.Translation(center))
    mesh = bpy.data.meshes.new(PREFIX + "FizzDrops")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(PREFIX + "FizzDrops", mesh)
    bpy.context.scene.collection.objects.link(obj)
    for poly in mesh.polygons:
        poly.use_smooth = True
    return obj


def toy_block():
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    faces = list(bm.faces)
    result = bmesh.ops.inset_individual(bm, faces=faces, thickness=0.12, depth=-0.035)
    mesh = bpy.data.meshes.new(PREFIX + "ToyBlock")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(PREFIX + "ToyBlock", mesh)
    bpy.context.scene.collection.objects.link(obj)
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width, mod.segments, mod.limit_method, mod.angle_limit = 0.07, 2, "ANGLE", math.radians(60)
    obj.modifiers.new("Triangulate", "TRIANGULATE")
    return obj


def letter(char):
    curve = bpy.data.curves.new(PREFIX + "Letter" + char, "FONT")
    curve.body = char
    curve.size = 0.82
    curve.extrude = 0.06
    curve.bevel_depth = 0.012
    curve.resolution_u = 3
    curve.align_x, curve.align_y = "CENTER", "CENTER"
    text = bpy.data.objects.new(PREFIX + "LetterText" + char, curve)
    bpy.context.scene.collection.objects.link(text)
    # Text lies in Blender XY facing +Z; stand it up facing Blender +Y (Roblox -Z), reading left to right.
    text.rotation_euler = (math.radians(90), 0, math.radians(180))
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(text.evaluated_get(depsgraph))
    obj = bpy.data.objects.new(PREFIX + "BlockLetter" + char, mesh)
    obj.matrix_world = text.matrix_world.copy()
    bpy.context.scene.collection.objects.link(obj)
    bpy.data.objects.remove(text)
    # Centre on the bounding box.
    bpy.context.view_layer.update()
    pts = [obj.matrix_world @ v.co for v in mesh.vertices]
    centre = sum(pts, Vector()) / max(1, len(pts))
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    centre = (lo + hi) / 2
    obj.location -= centre
    for poly in mesh.polygons:
        poly.use_smooth = False
    obj.modifiers.new("Triangulate", "TRIANGULATE")
    return obj


def burst_sign():
    jitter = [1.0, 0.72, 0.93, 0.7, 1.06, 0.74, 0.9, 0.69, 1.02, 0.73, 0.95, 0.7, 1.04, 0.72, 0.92, 0.71]
    return slab("BurstSign", polygon(16, 1.0, jitter=jitter), 0.14, bevel=0.03)


def star_core():
    verts, faces = [], []
    # Octahedron heart.
    r = 0.36
    oct_v = [(r, 0, 0), (-r, 0, 0), (0, r, 0), (0, -r, 0), (0, 0, r), (0, 0, -r)]
    verts += oct_v
    for a in (0, 1):
        for b in (2, 3):
            for c in (4, 5):
                faces.append([a, b, c])
    # Six pyramid spikes.
    for axis in range(3):
        for sign in (-1, 1):
            u = [0, 0, 0]
            u[axis] = sign
            p = [i for i in range(3) if i != axis]
            start = len(verts)
            for du, dv in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                v = [0.0, 0.0, 0.0]
                v[axis] = sign * 0.18
                v[p[0]] = du * 0.17
                v[p[1]] = dv * 0.17
                verts.append(tuple(v))
            tip = [0.0, 0.0, 0.0]
            tip[axis] = sign * (1.0 if axis != 2 else 0.7)
            verts.append(tuple(tip))
            faces += [[start + i, start + (i + 1) % 4, start + 4] for i in range(4)]
    return mesh_from("StarCore", verts, faces)


def star_halo_band():
    seg = 48
    outer = [(math.cos(a) * 1.0, math.sin(a) * 1.0) for a in (i / seg * math.pi * 2 for i in range(seg))]
    inner = [(math.cos(a) * 0.86, math.sin(a) * 0.86) for a in (i / seg * math.pi * 2 for i in range(seg))]
    verts, faces = [], []
    for z in (-0.04, 0.04):
        verts += [(x, y, z) for x, y in outer]
        verts += [(x, y, z) for x, y in inner]
    o0, i0, o1, i1 = 0, seg, 2 * seg, 3 * seg
    for k in range(seg):
        n = (k + 1) % seg
        faces.append([o0 + k, o0 + n, i0 + n, i0 + k])
        faces.append([o1 + k, i1 + k, i1 + n, o1 + n])
        faces.append([o0 + k, o1 + k, o1 + n, o0 + n])
        faces.append([i0 + k, i0 + n, i1 + n, i1 + k])
    return mesh_from("StarHaloBand", verts, faces, smooth=True)


def star_halo_gems():
    verts, faces = [], []
    for g in range(8):
        a = g / 8 * math.pi * 2
        cx, cy = math.cos(a) * 0.93, math.sin(a) * 0.93
        start = len(verts)
        # Four-point star plate, front apex.
        pts = []
        for i in range(8):
            b = a + i / 8 * math.pi * 2
            r = 0.2 if i % 2 == 0 else 0.07
            pts.append((cx + math.cos(b) * r, cy + math.sin(b) * r))
        verts += [(x, y, 0.05) for x, y in pts]
        verts.append((cx, cy, -0.1))
        c = start + 8
        faces += [[start + i, c, start + (i + 1) % 8] for i in range(8)]
        faces.append([start + i for i in range(7, -1, -1)])
    return mesh_from("StarHaloGems", verts, faces)


def nova_ray():
    verts = [(0, 0, 0), (0.45, 0.16, 0), (0.45, -0.16, 0), (0.45, 0, -0.04), (0.45, 0, 0.04), (2.0, 0, 0)]
    faces = [[0, 1, 3], [0, 3, 2], [0, 2, 4], [0, 4, 1], [5, 3, 1], [5, 2, 3], [5, 4, 2], [5, 1, 4]]
    return mesh_from("NovaRay", verts, faces)


# ---------------------------------------------------------------------------------------------- textures
def save_png(name, rgba):
    h, w, _ = rgba.shape
    img = bpy.data.images.new(name, w, h, alpha=True)
    img.pixels.foreach_set(np.flipud(rgba).astype(np.float32).ravel())
    path = os.path.join(OUT, "textures", name + ".png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    return path


def white(alpha):
    rgba = np.ones(alpha.shape + (4,))
    rgba[..., 3] = np.clip(alpha, 0, 1)
    return rgba


def grid(size):
    c = (np.arange(size) + 0.5) / size * 2 - 1
    x, y = np.meshgrid(c, -c)
    return x, y


def tex_star_glint():
    x, y = grid(256)
    r = np.sqrt(x * x + y * y)
    core = np.exp(-((r / 0.12) ** 2))
    glow = 0.35 * np.exp(-((r / 0.35) ** 2))
    spikes = np.exp(-np.abs(x) / 0.025) * np.exp(-np.abs(y) / 0.42) + np.exp(-np.abs(y) / 0.025) * np.exp(-np.abs(x) / 0.42)
    u, v = (x + y) / math.sqrt(2), (x - y) / math.sqrt(2)
    diag = 0.45 * (np.exp(-np.abs(u) / 0.02) * np.exp(-np.abs(v) / 0.2) + np.exp(-np.abs(v) / 0.02) * np.exp(-np.abs(u) / 0.2))
    fade = np.clip(1 - r, 0, 1)
    return save_png("StarGlint", white((core + glow + spikes + diag) * fade))


def tex_soft_glow():
    x, y = grid(256)
    r = np.sqrt(x * x + y * y)
    return save_png("SoftGlow", white(np.exp(-((r / 0.45) ** 2)) * np.clip(1 - r, 0, 1) * 1.15))


def tex_streak():
    x, y = grid(256)
    a = np.exp(-((x / 0.07) ** 2)) * np.clip(1 - np.abs(y), 0, 1) ** 1.5
    a += 0.6 * np.exp(-((x / 0.025) ** 2)) * np.clip(1 - np.abs(y) * 1.1, 0, 1)
    return save_png("Streak", white(a))


def tex_bubble():
    x, y = grid(256)
    r = np.sqrt(x * x + y * y)
    rim = np.exp(-(((r - 0.82) / 0.07) ** 2)) * 0.95
    inner = 0.1 * (r < 0.82)
    hx, hy = x + 0.32, y - 0.36
    highlight = np.exp(-((hx / 0.16) ** 2 + (hy / 0.09) ** 2)) * 0.95
    small = np.exp(-(((x - 0.3) / 0.05) ** 2 + ((y + 0.42) / 0.05) ** 2)) * 0.6
    return save_png("Bubble", white(rim + inner + highlight + small))


def tex_confetti():
    """4x4 flipbook of a paper strip tumbling through one turn (white; tinted by the emitter)."""
    cells, size = 4, 128
    sheet = np.zeros((cells * size, cells * size, 4))
    c = (np.arange(size) + 0.5) / size * 2 - 1
    x, y = np.meshgrid(c, -c)
    for k in range(cells * cells):
        turn = k / (cells * cells) * math.pi * 2
        spin = 0.35 + k / (cells * cells) * math.pi
        width = 0.62 * max(0.12, abs(math.cos(turn)))
        u = x * math.cos(spin) + y * math.sin(spin)
        v = -x * math.sin(spin) + y * math.cos(spin)
        edge = 0.04
        a = np.clip((width - np.abs(u)) / edge, 0, 1) * np.clip((0.3 - np.abs(v)) / edge, 0, 1)
        shade = 0.72 + 0.28 * abs(math.cos(turn))
        cell = np.zeros((size, size, 4))
        cell[..., 0:3] = shade
        cell[..., 3] = a
        row, col = k // cells, k % cells
        sheet[row * size:(row + 1) * size, col * size:(col + 1) * size] = cell
    return save_png("Confetti4x4", sheet)


# ---------------------------------------------------------------------------------------------- build
def main():
    fbx = os.path.join(OUT, "finishers_v3.fbx")
    if os.path.exists(fbx):
        raise RuntimeError("finishers_v3 export exists; make a new revision instead of overwriting")
    os.makedirs(OUT, exist_ok=True)
    scene = bpy.context.scene
    for obj in list(scene.objects):
        bpy.data.objects.remove(obj)
    scene.unit_settings.system = "METRIC"

    builders = [prism_facet, prism_sliver, pinata_point, pinata_core, candy_gem, fizz_crown, fizz_drops, toy_block,
                lambda: letter("B"), lambda: letter("O"), lambda: letter("M"), burst_sign, star_core, star_halo_band,
                star_halo_gems, nova_ray]
    objects = [build() for build in builders]
    tints = {
        "PrismFacet": "#BDEFFF", "PrismSliver": "#FFFFFF", "PinataPoint": "#F9ADDA", "PinataCore": "#FFE790",
        "CandyGem": "#FF9FCF", "FizzCrown": "#80E8DA", "FizzDrops": "#D9FFF8", "ToyBlock": "#8FD3FF",
        "BlockLetterB": "#FFAE62", "BlockLetterO": "#FFAE62", "BlockLetterM": "#FFAE62", "BurstSign": "#FFF2A0",
        "StarCore": "#FFE9A8", "StarHaloBand": "#A995FF", "StarHaloGems": "#FFAFE9", "NovaRay": "#FFFFFF",
    }
    for obj in objects:
        short = obj.name[len(PREFIX):]
        assign_material([obj], glossy_preview_material("GC_Preview_" + short, tints.get(short, "#FFFFFF")))

    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    manifest = {"Version": 3, "Meshes": {}}
    total = 0
    for obj in objects:
        evaluated = obj.evaluated_get(depsgraph)
        m = evaluated.to_mesh()
        tris = sum(len(p.vertices) - 2 for p in m.polygons)
        pts = [obj.matrix_world @ v.co for v in m.vertices]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        size = hi - lo
        centre = (lo + hi) / 2
        evaluated.to_mesh_clear()
        total += tris
        # Roblox size/centre (x, y, z) = Blender (x, z, y) magnitudes.
        manifest["Meshes"][obj.name] = {
            "Tris": tris,
            "RobloxSize": [round(size.x, 4), round(size.z, 4), round(size.y, 4)],
            "RobloxCentre": [round(centre.x, 4), round(centre.z, 4), round(-centre.y, 4)],
        }
    manifest["TotalTris"] = total

    export_fbx(objects, fbx)
    textures = [tex_star_glint(), tex_soft_glow(), tex_streak(), tex_bubble(), tex_confetti()]
    manifest["Textures"] = [os.path.relpath(p, OUT) for p in textures]

    # Review sheet: lay the pieces out in a row and render with the shared icon camera.
    x, shifts = 0.0, []
    for obj in objects:
        obj.location.x += x
        shifts.append(x)
        x += 2.6
    bpy.context.view_layer.update()
    try:
        render_icon(objects, os.path.join(OUT, "preview.png"), size=1024, samples=24)
    except Exception as err:  # the preview is a convenience; the export already succeeded
        manifest["PreviewError"] = str(err)
    for obj, shift in zip(objects, shifts):
        obj.location.x -= shift
    bpy.data.libraries.write(os.path.join(OUT, "finishers_v3.blend"), {scene}, fake_user=True, compress=True)
    with open(os.path.join(OUT, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=2)
    print("FINISHERS_V3", json.dumps({"total_tris": total, "meshes": len(objects)}))


main()
