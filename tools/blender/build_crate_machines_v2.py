"""Crate Machines v2: original glass-and-light opening machines for Finishers and Flyers.

Run through Blender MCP after loading glassclash_blender.py and set_repo(). Everything is built in its own
scene so other work in the open file is untouched. Exports never overwrite: each run writes a new revision.

Axes: 1 BU = 1 stud, Z up, the machine FRONT faces +Y (Roblox -Z, toward the opening camera), origin = centre
of the base on the floor. Part names are the contract with Studio (see docs/testing/CRATE_MACHINES_V2.md):
  Body*        matte machine parts (SmoothPlastic)
  Trim*        currency-tinted parts (Coins gold / Marbles blue) -> CurrencyTint attribute
  Glass*       glass chamber shell (Glass material)
  RevealCore   neon heart of the machine; the reward cards launch from here
  RevealLid    the part that pops/opens at reveal
  Spin*        parts that idle-spin (tokens, rings, fans)
  Neon*        other glowing details
"""
import json
import math
import os
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

SCENE = "CrateMachines_v2_Concepts"
HEX = {
    "amethyst": "#8B4FE0", "amethystLight": "#CDAAFF", "amethystDark": "#57299F",
    "aqua": "#1FC2D3", "aquaLight": "#9BF3F8", "aquaDark": "#0F7C88",
    "sapphire": "#2E6BE6", "sapphireLight": "#93BCFF", "sapphireDark": "#1A409C",
    "amber": "#F5A524", "amberLight": "#FFD98A", "ruby": "#E23A55", "rubyLight": "#FF8EA0",
    "emerald": "#22B573", "emeraldLight": "#86EDB8", "milk": "#EEE7D9", "navy": "#1A1E4A",
}
TRIM = {"Coins": "#FFD98A", "Marbles": "#93BCFF"}
NEON_PREVIEW_SCALE = 0.3  # Standard view transform clips bright emission to white


# ------------------------------------------------------------------------------------------------
# Scene + materials
# ------------------------------------------------------------------------------------------------


def use_scene(name=SCENE, fresh=True):
    scene = bpy.data.scenes.get(name)
    if scene and fresh:
        for obj in list(scene.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
    if scene is None:
        scene = bpy.data.scenes.new(name)
    bpy.context.window.scene = scene
    return scene


def coll(name):
    scene = bpy.context.scene
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
    if c.name not in scene.collection.children:
        scene.collection.children.link(c)
    return c


def _principled(name):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    try:
        mat.use_nodes = True
    except Exception:
        pass
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    return mat, bsdf


def m_solid(hex_color, rough=0.75):
    mat, b = _principled("CM2_Solid_" + hex_color.lstrip("#") + f"_{int(rough * 100)}")
    _set_input(b, "Base Color", (*hex_to_rgb(hex_color), 1))
    _set_input(b, "Roughness", rough)
    return mat


def m_glass(hex_color="#DDEBFF"):
    mat, b = _principled("CM2_Glass_" + hex_color.lstrip("#"))
    _set_input(b, "Base Color", (*hex_to_rgb(hex_color), 1))
    _set_input(b, "Roughness", 0.03)
    _set_input(b, ["Transmission Weight", "Transmission"], 1.0)
    _set_input(b, "IOR", 1.2)
    _set_input(b, ["Coat Weight", "Clearcoat"], 0.6)
    _set_input(b, "Alpha", 1.0)
    return mat


def m_neon(hex_color, strength=6.0):
    mat, b = _principled("CM2_Neon_" + hex_color.lstrip("#") + f"_{int(strength)}")
    rgb = hex_to_rgb(hex_color)
    _set_input(b, "Base Color", (*rgb, 1))
    _set_input(b, ["Emission Color", "Emission"], (*rgb, 1))
    _set_input(b, "Emission Strength", strength * NEON_PREVIEW_SCALE)
    return mat


def m_beam(hex_color):
    """Soft additive-looking light cone for previews (Roblox uses a Beam/neon part at low opacity)."""
    name = "CM2_Beam_" + hex_color.lstrip("#")
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    mix = nt.nodes.new("ShaderNodeAddShader")
    em = nt.nodes.new("ShaderNodeEmission")
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    em.inputs["Color"].default_value = (*hex_to_rgb(hex_color), 1)
    em.inputs["Strength"].default_value = 0.12
    nt.links.new(em.outputs[0], mix.inputs[0])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(mix.outputs[0], out.inputs[0])
    return mat


def tag(obj, mat, color=None, material="SmoothPlastic", smooth=False, tint=False, transparency=None):
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    obj["studio_color"] = color or "#FFFFFF"
    obj["studio_material"] = material
    if tint:
        obj["currency_tint"] = True
    if transparency is not None:
        obj["studio_transparency"] = transparency
    set_shading(obj, smooth)
    return obj


# ------------------------------------------------------------------------------------------------
# Geometry helpers (all return objects linked to the active collection)
# ------------------------------------------------------------------------------------------------

_ACTIVE = {"coll": None}


def _new(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    (_ACTIVE["coll"] or bpy.context.scene.collection).objects.link(obj)
    return obj


def spin(name, profile, segments=16, loc=(0, 0, 0), rot=None):
    """Lathe of (radius, z) points around Z; profile ends on the axis to close the mesh."""
    bm = bmesh.new()
    verts = [bm.verts.new((r, 0.0, z)) for r, z in profile]
    edges = [bm.edges.new((verts[i], verts[i + 1])) for i in range(len(verts) - 1)]
    bmesh.ops.spin(bm, geom=verts + edges, cent=(0, 0, 0), axis=(0, 0, 1), angle=math.tau, steps=segments,
                   use_merge=True)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if rot is not None:
        bmesh.ops.transform(bm, matrix=rot, verts=bm.verts)
    bmesh.ops.translate(bm, vec=loc, verts=bm.verts)
    return _new(name, bm)


def tube(name, r_out, r_in, z0, z1, segments=24, loc=(0, 0, 0), rot=None):
    """Open-ended thick ring/tube (glass shells, rims)."""
    profile = [(r_in, z0), (r_out, z0), (r_out, z1), (r_in, z1), (r_in, z0 + 1e-4)]
    bm = bmesh.new()
    verts = [bm.verts.new((r, 0.0, z)) for r, z in profile[:-1]]
    edges = [bm.edges.new((verts[i], verts[(i + 1) % 4])) for i in range(4)]
    bmesh.ops.spin(bm, geom=verts + edges, cent=(0, 0, 0), axis=(0, 0, 1), angle=math.tau, steps=segments,
                   use_merge=True)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if rot is not None:
        bmesh.ops.transform(bm, matrix=rot, verts=bm.verts)
    bmesh.ops.translate(bm, vec=loc, verts=bm.verts)
    return _new(name, bm)


def shell_sphere(name, r_out, thickness, segments=24, rings=12, z_cut_low=None, z_cut_high=None, loc=(0, 0, 0)):
    """Hollow glass globe made from a lathe profile; optional flat openings at the bottom/top."""
    lo = -r_out if z_cut_low is None else z_cut_low
    hi = r_out if z_cut_high is None else z_cut_high
    outer, inner = [], []
    for i in range(rings + 1):
        z = lo + (hi - lo) * i / rings
        outer.append((math.sqrt(max(r_out * r_out - z * z, 0)), z))
        ri = r_out - thickness
        inner.append((math.sqrt(max(ri * ri - z * z, 0)), z))
    prof = outer + list(reversed(inner))
    bm = bmesh.new()
    verts = [bm.verts.new((r, 0.0, z)) for r, z in prof]
    edges = [bm.edges.new((verts[i], verts[(i + 1) % len(verts)])) for i in range(len(verts))]
    bmesh.ops.spin(bm, geom=verts + edges, cent=(0, 0, 0), axis=(0, 0, 1), angle=math.tau, steps=segments,
                   use_merge=True)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.translate(bm, vec=loc, verts=bm.verts)
    return _new(name, bm)


def block(name, size, loc=(0, 0, 0), bevel=0.0, rot=None, segments=1):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=segments, affect="EDGES")
    if rot is not None:
        bmesh.ops.transform(bm, matrix=rot, verts=bm.verts)
    bmesh.ops.translate(bm, vec=loc, verts=bm.verts)
    return _new(name, bm)


def ico(name, radius, loc=(0, 0, 0), subdiv=1, scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
    bmesh.ops.translate(bm, vec=loc, verts=bm.verts)
    return _new(name, bm)


def star(name, r_out, r_in, depth, points=5, loc=(0, 0, 0), rot=None):
    """Chunky extruded star in the XZ plane (faces +Y)."""
    bm = bmesh.new()
    front, back = [], []
    for i in range(points * 2):
        a = math.pi / 2 + i * math.pi / points
        r = r_out if i % 2 == 0 else r_in
        front.append(bm.verts.new((r * math.cos(a), depth / 2, r * math.sin(a))))
        back.append(bm.verts.new((r * math.cos(a), -depth / 2, r * math.sin(a))))
    cf = bm.verts.new((0, depth / 2 + depth * 0.35, 0))
    cb = bm.verts.new((0, -depth / 2 - depth * 0.35, 0))
    n = len(front)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], front[j], cf))
        bm.faces.new((back[j], back[i], cb))
        bm.faces.new((front[j], front[i], back[i], back[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if rot is not None:
        bmesh.ops.transform(bm, matrix=rot, verts=bm.verts)
    bmesh.ops.translate(bm, vec=loc, verts=bm.verts)
    return _new(name, bm)


def gem(name, radius, height, sides=6, loc=(0, 0, 0), rot=None):
    """Faceted gem/shard: crown + pointed pavilion."""
    prof = [(0, -height * 0.6), (radius, 0), (radius * 0.62, height * 0.32), (0, height * 0.32)]
    return spin(name, prof, segments=sides, loc=loc, rot=rot)


def wing_token(name, span, loc=(0, 0, 0), rot=None):
    """Little glider/paper-plane token for Flyer machines."""
    bm = bmesh.new()
    v = [bm.verts.new(p) for p in [
        (0, span * 0.55, 0.02), (-span / 2, -span * 0.3, 0.06), (0, -span * 0.12, -0.02),
        (span / 2, -span * 0.3, 0.06), (0, -span * 0.3, -span * 0.16),
    ]]
    bm.faces.new((v[0], v[1], v[2]))
    bm.faces.new((v[0], v[2], v[3]))
    bm.faces.new((v[0], v[4], v[2]))
    bmesh.ops.solidify(bm, geom=list(bm.faces), thickness=span * 0.05)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if rot is not None:
        bmesh.ops.transform(bm, matrix=rot, verts=bm.verts)
    bmesh.ops.translate(bm, vec=loc, verts=bm.verts)
    return _new(name, bm)


def cone_beam(name, r0, r1, length, loc, direction, segments=20):
    """Open light cone from loc along direction."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, segments=segments, radius1=r0, radius2=r1, depth=length)
    bmesh.ops.translate(bm, vec=(0, 0, length / 2), verts=bm.verts)
    q = Vector(direction).normalized().to_track_quat("Z", "Y")
    bmesh.ops.transform(bm, matrix=q.to_matrix().to_4x4(), verts=bm.verts)
    bmesh.ops.translate(bm, vec=loc, verts=bm.verts)
    return _new(name, bm)


def cloud(name, loc, scale=1.0, seed=3, subdiv=2, puffs_used=7):
    rnd = random.Random(seed)
    bm = bmesh.new()
    puffs = [(0, 0, 0, 0.62), (0.6, 0.05, -0.08, 0.5), (-0.6, 0.0, -0.1, 0.5), (0.25, 0.1, 0.32, 0.45),
             (-0.28, -0.05, 0.28, 0.42), (0.0, -0.35, -0.05, 0.48), (0.0, 0.38, -0.08, 0.46)]
    for x, y, z, r in puffs[:puffs_used]:
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=subdiv, radius=r * scale * (0.95 + rnd.random() * 0.1))
        bmesh.ops.translate(tmp, vec=(x * scale, y * scale, z * scale), verts=tmp.verts)
        mesh = bpy.data.meshes.new("tmp")
        tmp.to_mesh(mesh)
        tmp.free()
        bm.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
    bmesh.ops.translate(bm, vec=loc, verts=bm.verts)
    return _new(name, bm)


def rz(deg):
    return Matrix.Rotation(math.radians(deg), 4, "Z")


def rx(deg):
    return Matrix.Rotation(math.radians(deg), 4, "X")


def ry(deg):
    return Matrix.Rotation(math.radians(deg), 4, "Y")


def label(text, loc, size=0.55, color="#1A1E4A"):
    curve = bpy.data.curves.new("CM2_Label", "FONT")
    curve.body = text
    curve.align_x = "CENTER"
    curve.size = size
    curve.extrude = 0.02
    obj = bpy.data.objects.new("Label_" + text[:12], curve)
    (_ACTIVE["coll"] or bpy.context.scene.collection).objects.link(obj)
    obj.location = loc
    obj.rotation_euler = (math.radians(70), 0, math.radians(180))
    obj.data.materials.append(m_solid(color, 0.6))
    return obj


def fill_tokens(prefix, center, radius, count, makers, seed=7, floor_frac=0.62):
    """Packs prize tokens into the lower part of a globe so it reads as 'full of prizes'."""
    rnd = random.Random(seed)
    placed = []
    objs = []
    tries = 0
    while len(objs) < count and tries < 4000:
        tries += 1
        tr = 0.24 + rnd.random() * 0.12
        p = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * (radius - tr - 0.08)
        if p.length > radius - tr - 0.08 or p.z > radius * (floor_frac * 2 - 1):
            continue
        if any((p - q).length < tr + s * 0.92 for q, s in placed):
            continue
        placed.append((p, tr))
        maker = makers[len(objs) % len(makers)]
        objs.append(maker(f"{prefix}{len(objs) + 1:02d}", Vector(center) + p, tr, rnd))
    return objs


# ------------------------------------------------------------------------------------------------
# Concept blockouts (step 2). Each returns its collection; x offset lays them out for the sheet.
# ------------------------------------------------------------------------------------------------


def _start(name, x):
    c = coll(name)
    _ACTIVE["coll"] = c
    return c, Vector((x, 0, 0))


def concept_spark_forge(x=0.0, currency="Coins", base="amethystDark", body="amethyst", glow="amethystLight"):
    """F-A: chunky hex pedestal + tall glass capsule with a star core and orbiting shards; crown lid."""
    c, o = _start("F_A_SparkForge_" + currency, x)
    trim = TRIM[currency]
    tag(spin("BodyBase", [(0, 0), (1.9, 0), (1.9, 0.35), (1.6, 0.55), (1.45, 1.6), (1.65, 1.8), (1.65, 2.05),
                          (0, 2.05)], 6, o), m_solid(HEX[base]), HEX[base])
    tag(tube("TrimBaseRing", 1.72, 1.2, 2.05, 2.3, 6, o), m_solid(trim, 0.35), trim, tint=True)
    tag(tube("GlassChamber", 1.3, 1.2, 2.3, 5.0, 16, o), m_glass("#EBDDFF"), HEX["amethystLight"], "Glass",
        smooth=True, transparency=0.55)
    for i in range(6):
        a = math.radians(30 + i * 60)
        tag(block(f"BodyRib{i}", (0.18, 0.18, 2.7), o + Vector((1.36 * math.cos(a), 1.36 * math.sin(a), 3.65))),
            m_solid(HEX[body]), HEX[body])
    tag(star("RevealCore", 0.62, 0.27, 0.32, 5, o + Vector((0, 0, 3.6))), m_neon(HEX[glow], 8), HEX[glow], "Neon")
    for i in range(3):
        a = i * math.tau / 3
        tag(gem(f"SpinShard{i}", 0.2, 0.5, 4, o + Vector((0.8 * math.cos(a), 0.8 * math.sin(a), 3.2 + 0.5 * i)),
                rot=rx(25) @ rz(i * 40)), m_neon(["#FF8EA0", "#FFD98A", "#9BF3F8"][i], 4), "#FFFFFF", "Neon")
    lid = spin("RevealLid", [(0, 5.0), (1.5, 5.0), (1.5, 5.25), (1.1, 5.55), (0.55, 5.75), (0, 5.8)], 6, o)
    tag(lid, m_solid(trim, 0.35), trim, tint=True)
    for i in range(6):
        a = i * math.tau / 6
        tag(gem(f"TrimCrownPoint{i}", 0.16, 0.45, 4, o + Vector((1.05 * math.cos(a), 1.05 * math.sin(a), 5.8)),
                rot=rx(180)), m_solid(trim, 0.35), trim, tint=True)
    tag(gem("NeonTopGem", 0.32, 0.7, 6, o + Vector((0, 0, 6.15)), rot=rx(180)), m_neon(HEX[glow], 5), HEX[glow])
    tag(spin("TrimEmblem", [(0, 0), (0.48, 0), (0.48, 0.12), (0, 0.14)], 16, o + Vector((0, 1.62, 1.1)),
             rot=rx(-90 + 8)), m_solid(trim, 0.3), trim, tint=True)
    tag(block("BodyCrankArm", (0.2, 0.2, 1.0), o + Vector((1.75, 0, 1.4)), rot=ry(30)), m_solid(HEX["milk"]))
    tag(ico("TrimCrankKnob", 0.26, o + Vector((2.0, 0, 1.85))), m_solid(trim, 0.3), trim, tint=True)
    label("A  Spark Forge", o + Vector((0, 2.6, 0.05)))
    return c


def concept_burst_globe(x=0.0, currency="Coins"):
    """F-B: gumball-style glass globe brimming with burst tokens (stars, shards, gems); star topper."""
    c, o = _start("F_B_BurstGlobe_" + currency, x)
    trim = TRIM[currency]
    tag(spin("BodyFoot", [(0, 0), (1.7, 0), (1.7, 0.3), (1.35, 0.45), (0, 0.45)], 8, o), m_solid(HEX["amethystDark"]))
    tag(block("BodyCabinet", (2.4, 2.2, 2.2), o + Vector((0, 0, 1.55)), bevel=0.18), m_solid(HEX["amethyst"]),
        HEX["amethyst"])
    tag(block("BodyChute", (0.9, 0.3, 0.75), o + Vector((0, 1.15, 1.0)), bevel=0.08), m_solid(HEX["navy"]))
    tag(spin("TrimCrank", [(0, 0), (0.42, 0), (0.42, 0.16), (0, 0.18)], 12, o + Vector((0, 1.1, 2.05)), rot=rx(-90)),
        m_solid(trim, 0.3), trim, tint=True)
    tag(block("BodyCrankBar", (0.7, 0.14, 0.14), o + Vector((0, 1.3, 2.05))), m_solid(HEX["milk"]))
    tag(spin("TrimCollar", [(0, 2.65), (1.25, 2.65), (1.25, 2.9), (0, 2.9)], 16, o), m_solid(trim, 0.3), trim,
        tint=True)
    center = o + Vector((0, 0, 4.25))
    tag(shell_sphere("GlassChamber", 1.65, 0.08, 24, 12, -1.42, 1.42, center), m_glass("#F0E6FF"), "#F0E6FF",
        "Glass", smooth=True, transparency=0.6)

    def mk_star(n, p, r, rnd):
        return tag(star(n, r, r * 0.45, r * 0.6, 5, p, rot=rz(rnd.uniform(0, 360)) @ rx(rnd.uniform(-40, 40))),
                   m_neon(rnd.choice(["#FFD98A", "#FF8EA0", "#CDAAFF"]), 2.5), "#FFD98A")

    def mk_gem(n, p, r, rnd):
        return tag(gem(n, r * 0.9, r * 1.8, 6, p, rot=rx(rnd.uniform(0, 180)) @ rz(rnd.uniform(0, 360))),
                   m_glass(rnd.choice(["#8B4FE0", "#E23A55", "#1FC2D3", "#F5A524"])), "#8B4FE0", "Glass")

    def mk_ball(n, p, r, rnd):
        return tag(ico(n, r, p, 2), m_solid(rnd.choice(["#E23A55", "#2E6BE6", "#22B573", "#F5A524", "#CDAAFF"]), 0.25),
                   "#E23A55", smooth=True)

    fill_tokens("SpinToken", center, 1.55, 22, [mk_star, mk_gem, mk_ball], seed=11)
    tag(star("RevealCore", 0.45, 0.2, 0.25, 5, center + Vector((0, 0.2, 0.55))), m_neon("#FFFFFF", 8), "#FFFFFF",
        "Neon")
    tag(spin("RevealLid", [(0, 5.55), (0.95, 5.55), (0.95, 5.8), (0.6, 6.0), (0, 6.05)], 16, o), m_solid(trim, 0.3),
        trim, tint=True)
    tag(star("NeonTopStar", 0.62, 0.28, 0.3, 5, o + Vector((0, 0, 6.65))), m_neon(HEX["amethystLight"], 6),
        HEX["amethystLight"])
    label("B  Burst Globe - " + currency, o + Vector((0, 2.6, 0.05)))
    return c


def concept_kaleidoscope(x=0.0, currency="Coins"):
    """F-C: glass kaleidoscope cannon on a toy stand; a spinning stained-glass wheel and a light cone."""
    c, o = _start("F_C_Kaleidoscope_" + currency, x)
    trim = TRIM[currency]
    tag(spin("BodyFoot", [(0, 0), (1.8, 0), (1.8, 0.35), (1.4, 0.55), (0, 0.55)], 8, o), m_solid(HEX["navy"]))
    tag(spin("BodyPost", [(0, 0.5), (0.45, 0.5), (0.35, 2.2), (0, 2.2)], 8, o), m_solid(HEX["amethystDark"]))
    axis = Vector((-1.0, 0.15, 0.55)).normalized()  # lens points screen-right and up
    tilt = axis.to_track_quat("Z", "Y").to_matrix().to_4x4()
    pivot = o + Vector((0, 0, 2.85))
    tag(block("BodyYoke", (1.2, 0.7, 0.5), o + Vector((0, 0, 2.3)), bevel=0.1), m_solid(HEX["amethystDark"]))
    tag(tube("GlassChamber", 0.8, 0.72, -1.4, 1.5, 16, pivot, tilt), m_glass("#EEE0FF"), "#EEE0FF", "Glass",
        smooth=True, transparency=0.5)
    for i, t in enumerate((-1.3, 0.05, 1.4)):
        tag(tube(f"TrimBand{i}", 0.9, 0.79, t - 0.14, t + 0.14, 16, pivot, tilt), m_solid(trim, 0.3), trim,
            tint=True)
    tag(star("RevealCore", 0.45, 0.2, 0.25, 4, pivot + axis * 0.2), m_neon("#FFFFFF", 8), "#FFFFFF", "Neon")
    # Rose-window wheel stands upright facing the front, like a film reel on a toy projector.
    wheel_c = pivot - axis * 1.3 + Vector((0, 0.35, 0.55))
    face = rx(-90)
    colors = ["#E23A55", "#F5A524", "#22B573", "#1FC2D3", "#2E6BE6", "#8B4FE0", "#FF8EA0", "#FFD98A"]
    for i in range(8):
        a0 = i * math.tau / 8
        bm = bmesh.new()
        pts = [Vector((0, 0, 0))] + [Vector((1.2 * math.cos(a0 + k * math.tau / 32), 1.2 * math.sin(a0 + k * math.tau / 32), 0))
                                     for k in range(5)]
        vs = [bm.verts.new(p) for p in pts]
        top = [bm.verts.new(p + Vector((0, 0, 0.1))) for p in pts]
        for k in range(1, 5):
            bm.faces.new((vs[0], vs[k], vs[k + 1]))
            bm.faces.new((top[0], top[k + 1], top[k]))
            bm.faces.new((vs[k], top[k], top[k + 1], vs[k + 1]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bmesh.ops.transform(bm, matrix=face, verts=bm.verts)
        bmesh.ops.translate(bm, vec=wheel_c, verts=bm.verts)
        tag(_new(f"SpinWheelPane{i}", bm), m_neon(colors[i], 2.2), colors[i], "Neon")
    tag(tube("TrimWheelRim", 1.32, 1.18, -0.06, 0.16, 24, wheel_c, face), m_solid(trim, 0.3), trim, tint=True)
    tag(spin("TrimWheelHub", [(0, -0.1), (0.25, -0.1), (0.25, 0.25), (0, 0.3)], 12, wheel_c, face), m_solid(trim, 0.3),
        trim, tint=True)
    lens_c = pivot + axis * 1.5
    tag(spin("RevealLid", [(0, 0), (0.85, 0), (0.85, 0.15), (0, 0.2)], 16, lens_c + axis * 0.05, tilt),
        m_glass("#FFFFFF"), "#FFFFFF", "Glass", smooth=True)
    tag(cone_beam("NeonBeam", 0.7, 2.2, 3.6, lens_c + axis * 0.2, axis), m_beam(HEX["amethystLight"]),
        HEX["amethystLight"], "Neon", transparency=0.85)
    label("C  Kaleidoscope", o + Vector((0, 2.6, 0.05)))
    return c


def concept_sky_dome(x=0.0, currency="Coins"):
    """Y-A: little hangar with a glass dome; a glider circles inside on a ring; propeller lid on top."""
    c, o = _start("Y_A_SkyDome_" + currency, x)
    trim = TRIM[currency]
    tag(block("BodyHangar", (3.4, 3.0, 1.9), o + Vector((0, 0, 0.95)), bevel=0.25), m_solid(HEX["sapphire"]),
        HEX["sapphire"])
    tag(block("BodyDoor", (1.6, 0.2, 1.25), o + Vector((0, 1.5, 0.7)), bevel=0.08), m_solid(HEX["sapphireDark"]))
    for i in range(3):
        tag(block(f"TrimStripe{i}", (0.35, 0.08, 1.1), o + Vector((-0.45 + i * 0.45, 1.6, 0.7)), rot=rz(0)),
            m_solid(trim, 0.3), trim, tint=True)
    tag(spin("TrimRing", [(0, 1.9), (1.75, 1.9), (1.75, 2.15), (0, 2.15)], 20, o), m_solid(trim, 0.3), trim, tint=True)
    center = o + Vector((0, 0, 2.15))
    tag(shell_sphere("GlassChamber", 1.65, 0.08, 24, 10, 0.0, 1.5, center), m_glass("#E2F6FF"), "#E2F6FF", "Glass",
        smooth=True, transparency=0.6)
    tag(cloud("BodyCloudPuff", center + Vector((0, 0, 0.35)), 0.55), m_solid("#FFFFFF", 0.6), "#FFFFFF", smooth=True)
    tag(tube("NeonOrbitRing", 1.15, 1.1, -0.02, 0.02, 32, center + Vector((0, 0, 0.75)), rx(12)),
        m_neon(HEX["aquaLight"], 3), HEX["aquaLight"])
    tag(wing_token("RevealCore", 0.75, center + Vector((1.12, 0, 0.78)), rz(0) @ rx(-10)), m_neon("#FFFFFF", 4),
        "#FFFFFF")
    tag(spin("RevealLid", [(0, 3.62), (0.5, 3.62), (0.5, 3.85), (0, 3.9)], 12, o), m_solid(trim, 0.3), trim, tint=True)
    for i in range(3):
        tag(block(f"SpinProp{i}", (0.18, 1.0, 0.05), o + Vector((0, 0, 4.0)), rot=rz(i * 120) @ Matrix.Translation((0, 0.5, 0))),
            m_solid(HEX["ruby"], 0.4), HEX["ruby"])
    label("A  Sky Dome", o + Vector((0, 2.6, 0.05)))
    return c


def concept_cloud_globe(x=0.0, currency="Coins"):
    """Y-B: gumball globe on a cloud base, full of little gliders and clouds; propeller-cap topper."""
    c, o = _start("Y_B_CloudGlobe_" + currency, x)
    trim = TRIM[currency]
    tag(cloud("BodyCloudBase", o + Vector((0, 0, 0.7)), 1.9, seed=4), m_solid("#FFFFFF", 0.6), "#FFFFFF", smooth=True)
    tag(spin("BodyStem", [(0, 1.1), (1.05, 1.1), (0.9, 2.45), (0, 2.45)], 12, o), m_solid(HEX["sapphire"]),
        HEX["sapphire"])
    tag(spin("TrimCollar", [(0, 2.45), (1.2, 2.45), (1.2, 2.7), (0, 2.7)], 16, o), m_solid(trim, 0.3), trim, tint=True)
    tag(spin("TrimCrank", [(0, 0), (0.38, 0), (0.38, 0.14), (0, 0.16)], 12, o + Vector((0, 1.0, 1.95)), rot=rx(-90)),
        m_solid(trim, 0.3), trim, tint=True)
    center = o + Vector((0, 0, 4.05))
    tag(shell_sphere("GlassChamber", 1.65, 0.08, 24, 12, -1.42, 1.42, center), m_glass("#E2F6FF"), "#E2F6FF",
        "Glass", smooth=True, transparency=0.6)

    def mk_wing(n, p, r, rnd):
        return tag(wing_token(n, r * 2.2, p, rz(rnd.uniform(0, 360)) @ rx(rnd.uniform(-30, 30))),
                   m_solid(rnd.choice(["#FFFFFF", "#9BF3F8", "#FFD98A", "#FF8EA0"]), 0.4), "#FFFFFF")

    def mk_cloud(n, p, r, rnd):
        return tag(cloud(n, p, r * 0.75, seed=rnd.randint(0, 99)), m_solid("#FFFFFF", 0.5), "#FFFFFF", smooth=True)

    def mk_ball(n, p, r, rnd):
        return tag(ico(n, r, p, 2), m_solid(rnd.choice(["#1FC2D3", "#2E6BE6", "#93BCFF", "#86EDB8"]), 0.25), "#1FC2D3",
                   smooth=True)

    fill_tokens("SpinToken", center, 1.55, 20, [mk_wing, mk_cloud, mk_ball], seed=5)
    tag(wing_token("RevealCore", 0.8, center + Vector((0, 0.2, 0.6))), m_neon("#FFFFFF", 6), "#FFFFFF")
    tag(spin("RevealLid", [(0, 5.35), (1.0, 5.35), (0.95, 5.6), (0.55, 5.95), (0, 6.0)], 16, o),
        m_solid(HEX["sapphire"], 0.4), HEX["sapphire"])
    tag(spin("TrimLidBand", [(0, 5.42), (1.02, 5.42), (1.02, 5.55), (0, 5.55)], 16, o), m_solid(trim, 0.3), trim,
        tint=True)
    for i in range(3):
        tag(block(f"SpinProp{i}", (0.22, 1.1, 0.05), o + Vector((0, 0, 6.15)), rot=rz(i * 120) @ Matrix.Translation((0, 0.55, 0))),
            m_solid([HEX["ruby"], HEX["amber"], HEX["emerald"]][i], 0.4))
    label("B  Cloud Globe - " + currency, o + Vector((0, 2.6, 0.05)))
    return c


def concept_beacon_tower(x=0.0, currency="Coins"):
    """Y-C: toy lighthouse launch tower; glass lantern room with a glider core; sweeping beacon cone."""
    c, o = _start("Y_C_BeaconTower_" + currency, x)
    trim = TRIM[currency]
    tag(spin("BodyFoot", [(0, 0), (1.8, 0), (1.8, 0.35), (0, 0.35)], 8, o), m_solid(HEX["navy"]))
    for i in range(3):
        z0 = 0.35 + i * 0.95
        col = HEX["sapphire"] if i % 2 == 0 else "#FFFFFF"
        tag(spin(f"BodyTower{i}", [(0, z0), (1.4 - z0 * 0.12, z0), (1.4 - (z0 + 0.95) * 0.12, z0 + 0.95), (0, z0 + 0.95)],
                 8, o), m_solid(col), col)
    tag(spin("TrimBalcony", [(0, 3.2), (1.55, 3.2), (1.55, 3.45), (0, 3.45)], 8, o), m_solid(trim, 0.3), trim, tint=True)
    tag(tube("GlassChamber", 1.0, 0.92, 3.45, 5.0, 8, o), m_glass("#E2F6FF"), "#E2F6FF", "Glass", transparency=0.5)
    tag(wing_token("RevealCore", 0.9, o + Vector((0, 0, 4.2))), m_neon("#FFFFFF", 6), "#FFFFFF")
    tag(tube("NeonLampRing", 0.5, 0.42, 3.6, 3.75, 12, o), m_neon(HEX["aquaLight"], 5), HEX["aquaLight"])
    tag(spin("RevealLid", [(0, 5.0), (1.2, 5.0), (1.2, 5.15), (0.2, 6.1), (0, 6.15)], 8, o),
        m_solid(HEX["sapphireDark"]), HEX["sapphireDark"])
    tag(ico("TrimTopBall", 0.22, o + Vector((0, 0, 6.3))), m_solid(trim, 0.3), trim, tint=True)
    tag(cone_beam("NeonBeam", 0.35, 1.8, 4.5, o + Vector((-0.4, 0.3, 4.3)), (-1.0, 0.35, 0.15)), m_beam(HEX["aquaLight"]),
        HEX["aquaLight"], "Neon", transparency=0.85)
    tag(block("BodyDoor", (0.8, 0.2, 1.1), o + Vector((0, 1.3, 0.9)), bevel=0.08), m_solid(HEX["sapphireDark"]))
    tag(spin("TrimEmblem", [(0, 0), (0.38, 0), (0.38, 0.1), (0, 0.12)], 16, o + Vector((0, 1.18, 2.4)), rot=rx(-84)),
        m_solid(trim, 0.3), trim, tint=True)
    label("C  Beacon Tower", o + Vector((0, 2.6, 0.05)))
    return c


# ------------------------------------------------------------------------------------------------
# Review renders
# ------------------------------------------------------------------------------------------------


def _review_rig(name, target, distance, width=1800, height=900, lens=50, elevation=0.32):
    scene = bpy.context.scene
    cam = bpy.data.objects.get(name + "_Cam")
    if cam is None:
        cam = bpy.data.objects.new(name + "_Cam", bpy.data.cameras.new(name + "_Cam"))
        scene.collection.objects.link(cam)
    cam.data.lens = lens
    direction = Vector((0.0, 1.0, elevation)).normalized()
    cam.location = Vector(target) + direction * distance
    cam.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    for lname, kind, energy, loc, size in [
        ("Key", "AREA", 2600, (-8, 10, 12), 8), ("Rim", "AREA", 1800, (9, -8, 9), 6), ("Fill", "AREA", 900, (10, 10, 3), 10),
    ]:
        obj = bpy.data.objects.get(name + "_" + lname)
        if obj is None:
            obj = bpy.data.objects.new(name + "_" + lname, bpy.data.lights.new(name + "_" + lname, kind))
            scene.collection.objects.link(obj)
        obj.data.energy, obj.data.size = energy, size
        obj.location = Vector(target) + Vector(loc)
        obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()
    world = bpy.data.worlds.get("CM2_World") or bpy.data.worlds.new("CM2_World")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (*hex_to_rgb("#9CCBFF"), 1)
    bg.inputs["Strength"].default_value = 0.9
    scene.world = world
    floor = bpy.data.objects.get(name + "_Floor")
    if floor is None:
        _ACTIVE["coll"] = None
        floor = block(name + "_Floor", (60, 30, 0.2), (target[0], 0, -0.1))
        floor.name = name + "_Floor"
        floor.data.materials.append(m_solid("#5E8BD6", 0.9))
    r = scene.render
    r.engine = "CYCLES"
    scene.cycles.samples = 48
    try:
        scene.cycles.use_denoising = True
    except Exception:
        pass
    r.resolution_x, r.resolution_y, r.resolution_percentage = width, height, 100
    r.film_transparent = False
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGB"
    try:
        scene.view_settings.view_transform = "Standard"
    except Exception:
        pass
    return cam


def render_to(path):
    bpy.context.scene.render.filepath = os.path.abspath(path)
    bpy.ops.render.render(write_still=True)
    return os.path.abspath(path)


def build_concepts(out_dir):
    """Builds all six blockouts side by side (Finishers row at y=0, Flyers row offset in x) and renders two
    sheets: concepts_finishers.png and concepts_flyers.png."""
    use_scene()
    concept_spark_forge(6.5)
    concept_burst_globe(0.0)
    concept_kaleidoscope(-6.5)
    concept_sky_dome(46.5)
    concept_cloud_globe(40.0)
    concept_beacon_tower(33.5)
    concept_burst_globe(83.0, "Coins")
    concept_burst_globe(78.0, "Marbles")
    concept_cloud_globe(72.0, "Coins")
    concept_cloud_globe(67.0, "Marbles")
    os.makedirs(out_dir, exist_ok=True)
    out = []
    for name, cx in (("finishers", 0.0), ("flyers", 40.0), ("variants", 75.0)):
        _review_rig("CM2_Review_" + name, (cx, 0, 3.0), 28.0, 1600, 800)
        for o in bpy.context.scene.objects:
            if o.name.endswith("_Floor"):
                o.hide_render = not o.name.startswith("CM2_Review_" + name)
        out.append(render_to(os.path.join(out_dir, f"concepts_{name}.png")))
    return out


# ------------------------------------------------------------------------------------------------
# Final machines (creator picked Sky Dome -> purple Burst Dome for Finishers, Cloud Globe for Flyers)
# ------------------------------------------------------------------------------------------------

FINAL_SCENE = "CrateMachines_v2"
V = Vector


def to_roblox(v):
    return [round(v.x, 4), round(v.z, 4), round(-v.y, 4)]


def mark(obj, idle=None, lid=False, variant=None, axis=None, speed=None):
    """Animation metadata, copied to Studio attributes by the installer. Axes are Roblox world axes."""
    if idle:
        obj["idle"] = idle
    if lid:
        obj["lid"] = True
    if variant:
        obj["variant"] = variant
    if axis:
        obj["spin_axis"] = [float(a) for a in axis]
    if speed is not None:
        obj["spin_speed"] = speed
    return obj


def join(name, objs):
    objs = list(objs)
    with bpy.context.temp_override(active_object=objs[0], selected_editable_objects=objs, object=objs[0]):
        bpy.ops.object.join()
    objs[0].name = name
    objs[0].data.name = name
    return objs[0]


def emblem_coin(name, loc, r):
    disc = spin(name + "_Disc", [(0, 0), (r, 0), (r, 0.12), (r * 0.84, 0.17), (0, 0.17)], 16, loc, rx(-90))
    st = star(name + "_Star", r * 0.58, r * 0.26, 0.1, 5, V(loc) + V((0, 0.19, 0)))
    return join(name, [disc, st])


def emblem_marble(name, loc, r):
    ball = ico(name + "_Ball", r * 0.72, V(loc) + V((0, 0.18, 0)), 2)
    ring = tube(name + "_Ring", r, r * 0.8, -0.02, 0.14, 20, loc, rx(-90))
    return join(name, [ball, ring])


def helix_ribbon(name, center, r0, r1, z0, z1, turns, width, steps=40):
    bm = bmesh.new()
    rows = []
    for i in range(steps + 1):
        t = i / steps
        a = t * turns * math.tau
        r = r0 + (r1 - r0) * t
        z = z0 + (z1 - z0) * t
        w = width * math.sin(math.pi * min(1, t * 1.15 + 0.08))
        p = V((r * math.cos(a), r * math.sin(a), z))
        rows.append((bm.verts.new(p + V((0, 0, w / 2))), bm.verts.new(p - V((0, 0, w / 2)))))
    for i in range(steps):
        bm.faces.new((rows[i][0], rows[i][1], rows[i + 1][1], rows[i + 1][0]))
    bmesh.ops.solidify(bm, geom=list(bm.faces), thickness=0.05)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.translate(bm, vec=center, verts=bm.verts)
    return _new(name, bm)


def build_burst_dome(x=0.0):
    """Finishers: chunky amethyst hangar with a glass dome; a star core, swirl ribbon and orbiting shards
    churn inside; the gem-topped cap is the lid."""
    c, o = _start("BD_BurstDome", x)
    P, trim = "BD_", TRIM["Coins"]
    tag(block(P + "BodyFoot", (3.9, 3.5, 0.3), o + V((0, 0, 0.15)), bevel=0.1), m_solid(HEX["navy"]), HEX["navy"])
    tag(block(P + "BodyBase", (3.6, 3.2, 1.9), o + V((0, 0, 1.25)), bevel=0.3, segments=2), m_solid(HEX["amethyst"]),
        HEX["amethyst"])
    tag(block(P + "BodyDoor", (1.9, 0.2, 1.35), o + V((0, 1.6, 1.15)), bevel=0.1), m_solid(HEX["amethystDark"]),
        HEX["amethystDark"])
    mark(tag(emblem_coin(P + "TrimEmblemCoin", o + V((0, 1.68, 1.15)), 0.48), m_solid(trim, 0.3), trim, tint=True),
         variant="Coins")
    mark(tag(emblem_marble(P + "TrimEmblemMarble", o + V((0, 1.68, 1.15)), 0.48), m_solid(TRIM["Marbles"], 0.3),
             TRIM["Marbles"], tint=True, smooth=True), variant="Marbles")
    for sx, side in ((-1, "L"), (1, "R")):
        tag(block(P + "TrimStripe" + side, (0.24, 0.12, 1.05), o + V((sx * 1.25, 1.62, 1.15)), bevel=0.04),
            m_solid(trim, 0.3), trim, tint=True)
        mark(tag(ico(P + "NeonLamp" + side, 0.17, o + V((sx * 1.5, 1.45, 2.0)), 1), m_neon(HEX["amethystLight"], 5),
                 HEX["amethystLight"], "Neon"), idle="Blink")
    tag(spin(P + "TrimRing", [(0, 2.2), (1.95, 2.2), (1.95, 2.46), (1.8, 2.55), (0, 2.55)], 24, o), m_solid(trim, 0.3),
        trim, tint=True)
    tag(spin(P + "BodyDomeFloor", [(0, 2.55), (1.7, 2.55), (1.7, 2.6), (0, 2.62)], 24, o),
        m_solid(HEX["amethystDark"]), HEX["amethystDark"])
    center = o + V((0, 0, 2.55))
    tag(shell_sphere(P + "GlassChamber", 1.75, 0.08, 28, 10, 0.0, 1.62, center), m_glass("#F0E6FF"), "#E9DDFF",
        "Glass", smooth=True, transparency=0.55)
    tag(spin(P + "BodyPedestal", [(0, 2.6), (0.62, 2.6), (0.62, 2.74), (0.34, 2.9), (0.42, 3.05), (0, 3.05)], 10, o),
        m_solid(HEX["milk"]), HEX["milk"])
    core_c = o + V((0, 0, 3.62))
    mark(tag(star(P + "RevealCore", 0.55, 0.25, 0.3, 5, core_c), m_neon(HEX["amethystLight"], 8),
             HEX["amethystLight"], "Neon"), idle="Spin", axis=(0, 0, 1), speed=0.9)
    mark(tag(tube(P + "NeonOrbitRing", 1.02, 0.96, -0.03, 0.03, 32, core_c, rx(16)), m_neon(HEX["amethyst"], 4),
             HEX["amethyst"], "Neon"), idle="Spin", axis=(0, 1, 0), speed=1.4)
    mark(tag(helix_ribbon(P + "NeonSwirl", o, 1.3, 0.75, 2.75, 3.95, 1.25, 0.16), m_neon(HEX["amethystLight"], 3),
             "#E3CCFF", "Neon"), idle="Orbit", speed=-1.1)
    for i, col in enumerate(("#FF8EA0", "#FFD98A", "#9BF3F8")):
        a = i * math.tau / 3
        mark(tag(gem(P + f"SpinShard{i + 1}", 0.2, 0.5, 5,
                     core_c + V((1.0 * math.cos(a), 1.0 * math.sin(a), (i - 1) * 0.3)), rot=rx(20) @ rz(i * 50)),
                 m_neon(col, 4), col, "Neon"), idle="Orbit", speed=1.7)
    mark(tag(spin(P + "RevealLid", [(0, 4.12), (0.78, 4.12), (0.74, 4.34), (0.46, 4.55), (0, 4.6)], 12, o),
             m_solid(trim, 0.3), trim, tint=True), lid=True)
    mark(tag(gem(P + "NeonTopGem", 0.34, 0.75, 6, o + V((0, 0, 4.6 + 0.24)), rot=rx(180)),
             m_neon(HEX["amethystLight"], 5), HEX["amethystLight"], "Neon"), lid=True, idle="Spin", axis=(0, 1, 0),
         speed=0.8)
    return c


def build_cloud_globe(x=0.0):
    """Flyers: gumball globe on a puffy cloud, full of little gliders and clouds; propeller cap is the lid."""
    c, o = _start("CG_CloudGlobe", x)
    P, trim = "CG_", TRIM["Coins"]
    tag(cloud(P + "BodyCloudBase", o + V((0, 0, 1.15)), 1.9, seed=4, subdiv=2), m_solid("#FFFFFF", 0.6), "#FFFFFF",
        smooth=True)
    tag(spin(P + "BodyStem", [(0, 1.5), (1.1, 1.5), (0.95, 2.9), (0, 2.9)], 12, o), m_solid(HEX["sapphire"]),
        HEX["sapphire"])
    tag(spin(P + "TrimCollar", [(0, 2.9), (1.25, 2.9), (1.25, 3.18), (0, 3.18)], 20, o), m_solid(trim, 0.3), trim,
        tint=True)
    mark(tag(emblem_coin(P + "TrimEmblemCoin", o + V((0, 0.98, 2.35)), 0.42), m_solid(trim, 0.3), trim, tint=True),
         variant="Coins")
    mark(tag(emblem_marble(P + "TrimEmblemMarble", o + V((0, 0.98, 2.35)), 0.42), m_solid(TRIM["Marbles"], 0.3),
             TRIM["Marbles"], tint=True, smooth=True), variant="Marbles")
    tag(spin(P + "TrimCrankHub", [(0, 0), (0.34, 0), (0.34, 0.16), (0, 0.2)], 12, o + V((1.0, 0, 2.3)), ry(90)),
        m_solid(trim, 0.3), trim, tint=True)
    bar = block(P + "SpinCrank_Bar", (0.13, 0.95, 0.13), o + V((1.26, 0, 2.3)), bevel=0.03)
    knobs = [ico(P + f"SpinCrank_Knob{i}", 0.13, o + V((1.36, s * 0.45, 2.3)), 1) for i, s in enumerate((-1, 1))]
    mark(tag(join(P + "SpinCrank", [bar, *knobs]), m_solid(HEX["milk"]), HEX["milk"]), idle="Crank", axis=(1, 0, 0),
         speed=0.0)
    center = o + V((0, 0, 4.6))
    tag(shell_sphere(P + "GlassChamber", 1.7, 0.08, 28, 12, -1.45, 1.45, center), m_glass("#E2F6FF"), "#E2F6FF",
        "Glass", smooth=True, transparency=0.55)
    groups = {"White": [], "Aqua": [], "Gold": [], "Pink": [], "Sapphire": []}
    cols = {"White": "#FFFFFF", "Aqua": "#9BF3F8", "Gold": "#FFD98A", "Pink": "#FF8EA0", "Sapphire": "#2E6BE6"}

    def mk_wing(n, p, r, rnd):
        g = rnd.choice(["White", "White", "Aqua", "Gold", "Pink"])
        obj = wing_token(n, r * 2.3, p, rz(rnd.uniform(0, 360)) @ rx(rnd.uniform(-30, 30)))
        groups[g].append(obj)
        return obj

    def mk_cloud(n, p, r, rnd):
        obj = cloud(n, p, r * 0.75, seed=rnd.randint(0, 99), subdiv=1, puffs_used=5)
        groups["White"].append(obj)
        return obj

    def mk_ball(n, p, r, rnd):
        g = rnd.choice(["Aqua", "Sapphire", "Pink"])
        obj = ico(n, r * 0.95, p, 1)
        groups[g].append(obj)
        return obj

    fill_tokens(P + "Token", center, 1.6, 21, [mk_wing, mk_cloud, mk_ball], seed=5)
    for g, objs in groups.items():
        if objs:
            mark(tag(join(P + "SpinTokens" + g, objs), m_solid(cols[g], 0.35), cols[g], smooth=True),
                 idle="Swirl", speed=0.22)
    mark(tag(wing_token(P + "RevealCore", 0.9, center + V((0, 0.25, 0.8))), m_neon("#FFFFFF", 6), "#FFFFFF", "Neon"),
         idle="Bob")
    mark(tag(spin(P + "RevealLid", [(0, 6.0), (1.05, 6.0), (1.0, 6.3), (0.6, 6.65), (0, 6.7)], 16, o),
             m_solid(HEX["sapphire"], 0.4), HEX["sapphire"]), lid=True)
    mark(tag(spin(P + "TrimLidBand", [(0, 6.06), (1.08, 6.06), (1.08, 6.22), (0, 6.22)], 16, o), m_solid(trim, 0.3),
             trim, tint=True), lid=True)
    mark(tag(spin(P + "BodyPropHub", [(0, 6.65), (0.16, 6.65), (0.16, 6.95), (0.1, 7.0), (0, 7.0)], 8, o),
             m_solid(HEX["milk"]), HEX["milk"]), lid=True)
    for i, col in enumerate((HEX["ruby"], HEX["amber"])):
        mark(tag(block(P + f"SpinProp{i + 1}", (0.4, 2.2, 0.07), o + V((0, 0, 6.98 + i * 0.08)), bevel=0.035,
                       rot=rz(45 + i * 90) @ ry(12)), m_solid(col, 0.4), col), lid=True, idle="Spin", axis=(0, 1, 0),
             speed=2.4)
    return c


def build_final(out_dir, render=True):
    """Builds both machines, writes review renders, the FBX, a manifest and a .blend copy into out_dir.
    Refuses to overwrite an existing revision."""
    assert not os.path.exists(os.path.join(out_dir, "CRATE_MACHINES_V2.fbx")), "Revision exists; bump the folder"
    use_scene(FINAL_SCENE)
    build_burst_dome(2.6)
    build_cloud_globe(-2.6)
    scene = bpy.context.scene
    meshes = [o for o in scene.objects if o.type == "MESH"]
    bpy.context.view_layer.update()
    manifest = {"version": 2, "front": "-Z", "meshes": []}
    for obj in meshes:
        machine = "Finishers" if obj.name.startswith("BD_") else "Rideables"
        offset = V((2.6, 0, 0)) if machine == "Finishers" else V((-2.6, 0, 0))
        pts = [obj.matrix_world @ V(cn) for cn in obj.bound_box]
        lo = V((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = V((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        size = hi - lo
        manifest["meshes"].append({
            "name": obj.name,
            "machine": machine,
            "part": obj.name[3:],
            "center": to_roblox((lo + hi) / 2 - offset),
            "size": [round(size.x, 4), round(size.z, 4), round(size.y, 4)],
            "color": obj.get("studio_color", "#FFFFFF"),
            "material": obj.get("studio_material", "SmoothPlastic"),
            "transparency": obj.get("studio_transparency", 0),
            "tint": bool(obj.get("currency_tint", False)),
            "idle": obj.get("idle"),
            "lid": bool(obj.get("lid", False)),
            "variant": obj.get("variant"),
            "spinAxis": list(obj["spin_axis"]) if "spin_axis" in obj else None,
            "spinSpeed": obj.get("spin_speed"),
            "triangles": sum(len(p.vertices) - 2 for p in obj.data.polygons),
        })
    totals = {}
    for m in manifest["meshes"]:
        if m["variant"] != "Marbles":
            totals[m["machine"]] = totals.get(m["machine"], 0) + m["triangles"]
    manifest["triangles"] = totals
    os.makedirs(out_dir, exist_ok=True)
    out = {"totals": totals, "meshes": len(meshes)}
    if render:
        out["renders"] = render_final(out_dir)
    with open(os.path.join(out_dir, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")
    save_blend_copy(os.path.join(out_dir, "crate_machines_v2.blend"))
    export_fbx(meshes, os.path.join(out_dir, "CRATE_MACHINES_V2.fbx"))
    return out


def _set_trim(currency):
    for o in bpy.context.scene.objects:
        if o.type != "MESH":
            continue
        variant = o.get("variant")
        o.hide_render = variant is not None and variant != currency
        if o.get("currency_tint") and variant is None:
            o.data.materials[0] = m_solid(TRIM[currency], 0.3)


def render_final(out_dir):
    out = []
    for currency in ("Coins", "Marbles"):
        _set_trim(currency)
        _review_rig("CM2_Final", (0, 0, 3.2), 19.0, 1400, 900, elevation=0.28)
        cam = bpy.context.scene.camera
        d = V((0.45, 1.0, 0.32)).normalized()
        cam.location = V((0, 0, 3.2)) + d * 19.0
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        out.append(render_to(os.path.join(out_dir, f"review_{currency.lower()}.png")))
    _set_trim("Coins")
    return out
