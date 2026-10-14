"""Glass Clash Blender helpers (Blender 4.2+ / 5.x).

Load inside Blender through the Blender MCP (or Blender's Python console):

    GLASSCLASH_REPO = r"C:/path/to/CrystalCoveBlenderWork"   # optional; defaults to a guess
    exec(open(GLASSCLASH_REPO + "/tools/blender/glassclash_blender.py").read())
    self_check()

Main functions
    self_check()                         sanity check, prints what works
    build_starter(gid)                   body mesh for "pop", "jam" or "prism" (origin = hang point)
    lathe(name, profile, segments, flat) build any round glassy from a profile of (radius, z)
    make_shards(body, pieces, seed)      pre-broken pieces with the same origin as the body
    render_icon(objects, path, tint)     512x512 transparent icon, shared camera + lighting
    export_fbx(objects, path)            FBX export of just those objects
    export_glassy(gid, body, shards)     body + shards FBX + icon + .blend copy into assets/
    build_clash_stand()                  low-poly Clash Stand + octagon pen (palette texture)
    export_clash_stand()                 builds it and exports to assets/blender/map/

Conventions (docs/art/ART_BIBLE.md): 1 Blender unit = 1 Roblox stud. Glassies are smooth and
glossy; the world is low-poly and flat-shaded. Materials here preview Studio colours;
in-game colours and materials are assigned in Studio, without baked colour textures.
Builders use a "GlassClash" collection; batch exports use isolated asset scenes and
collections, preserving your other objects and your original active scene.
"""

import math
import os
import random
import re

import bpy  # import bpy first: bmesh and mathutils need it when running as a Python module
import bmesh
from mathutils import Vector

# --------------------------------------------------------------------------------------------
# Paths
# --------------------------------------------------------------------------------------------


def _guess_repo():
    explicit = globals().get("GLASSCLASH_REPO")
    if explicit:
        return os.path.abspath(explicit)
    here = globals().get("__file__")
    if here:
        return os.path.abspath(os.path.join(os.path.dirname(here), "..", ".."))
    return os.path.abspath(os.getcwd())


REPO = _guess_repo()


def repo_path(*parts):
    return os.path.join(REPO, *parts)


def set_repo(path):
    """Point the helpers at the repo if the guess was wrong."""
    global REPO
    REPO = os.path.abspath(path)
    return REPO


# --------------------------------------------------------------------------------------------
# Scene helpers
# --------------------------------------------------------------------------------------------

COLLECTION = "GlassClash"


def gc_collection(name=None):
    name = name or COLLECTION
    # Collection datablock names are global, but builders must stay in the asset scene.
    col = next((c for c in bpy.context.scene.collection.children
                if c.name == name or c.get("gc_collection_key") == name), None)
    if col is None:
        col = bpy.data.collections.new(name)
        col["gc_collection_key"] = name
        bpy.context.scene.collection.children.link(col)
    return col


def clear_collection(name=COLLECTION):
    """Delete only the objects this script created."""
    col = bpy.data.collections.get(name)
    if col is None:
        return 0
    count = 0
    for obj in list(col.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
        count += 1
    return count


def _link(obj):
    gc_collection().objects.link(obj)
    return obj


def _mesh_object(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    return _link(obj)


def set_shading(obj, smooth):
    for poly in obj.data.polygons:
        poly.use_smooth = smooth
    return obj


def hex_to_rgb(hex_color):
    h = hex_color.lstrip("#")
    srgb = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    # sRGB -> linear for Blender colour inputs
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb)


def glassy_tint(gid, default="#8FE3FF"):
    """Reads the glassy's Tint from src/shared/Config/Glassies.luau."""
    path = repo_path("src", "shared", "Config", "Glassies.luau")
    try:
        text = open(path, encoding="utf-8").read()
    except OSError:
        return default
    match = re.search(r'Id = "' + re.escape(gid) + r'",.*?Tint = "(#[0-9A-Fa-f]{6})"', text, re.S)
    return match.group(1) if match else default


# --------------------------------------------------------------------------------------------
# Glassy shapes
# --------------------------------------------------------------------------------------------


def lathe(name, profile, segments=24, flat=False, hang_z=None):
    """Spins a profile of (radius, z) points around the Z axis into a closed mesh.

    The profile should start and end on the axis (radius 0) so the mesh is closed.
    The object's origin is put at the hang point: the top centre unless hang_z is given.
    """
    bm = bmesh.new()
    verts = [bm.verts.new((r, 0.0, z)) for r, z in profile]
    edges = [bm.edges.new((verts[i], verts[i + 1])) for i in range(len(verts) - 1)]
    bmesh.ops.spin(
        bm,
        geom=verts + edges,
        cent=(0, 0, 0),
        axis=(0, 0, 1),
        angle=math.tau,
        steps=segments,
        use_merge=True,
    )
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    top = max(z for _, z in profile) if hang_z is None else hang_z
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, -top))
    obj = _mesh_object(name, bm)
    return set_shading(obj, smooth=not flat)


# Profiles are (radius, z) in studs, bottom to top. Glassies are about 2-3 studs tall.
STARTER_PROFILES = {
    # Pop: rounded soda bottle, raised belt and a chunky cap ring.
    "pop": dict(
        segments=24,
        flat=False,
        profile=[
            (0.0, 0.0), (0.46, 0.0), (0.59, 0.05), (0.65, 0.16), (0.67, 0.28),
            (0.65, 0.40), (0.61, 0.51), (0.61, 0.64), (0.65, 0.69), (0.65, 0.76),
            (0.62, 0.81), (0.62, 1.24), (0.64, 1.29), (0.64, 1.36), (0.60, 1.42),
            (0.52, 1.59), (0.36, 1.79), (0.25, 1.94), (0.23, 2.06), (0.23, 2.20),
            (0.31, 2.23), (0.32, 2.38), (0.28, 2.46), (0.0, 2.46),
        ],
    ),
    # Jam: short, wide jar with a chunky screw lid
    "jam": dict(
        segments=24,
        flat=False,
        profile=[
            (0.0, 0.0), (0.65, 0.0), (0.79, 0.05), (0.88, 0.17), (0.91, 0.32),
            (0.91, 1.20), (0.88, 1.39), (0.80, 1.51), (0.75, 1.55), (0.75, 1.62),
            (0.87, 1.65), (0.91, 1.72), (0.91, 1.79), (0.87, 1.82),
            (0.91, 1.86), (0.91, 1.96), (0.83, 2.04), (0.0, 2.04),
        ],
    ),
    # Prism: eight broad polished crystal facets and a diamond stopper.
    "prism": dict(
        segments=8,
        flat=True,
        profile=[
            (0.0, 0.0), (0.47, 0.0), (0.63, 0.10), (0.80, 0.43), (0.80, 1.10),
            (0.61, 1.46), (0.24, 1.64), (0.20, 1.70), (0.20, 1.83),
            (0.28, 1.86), (0.28, 1.94), (0.21, 1.99), (0.43, 2.15),
            (0.43, 2.28), (0.25, 2.48), (0.0, 2.52),
        ],
    ),
}


def build_starter(gid):
    """Builds a chunky starter with its origin at the top-centre hang point."""
    spec = STARTER_PROFILES[gid]
    profile = spec["profile"]
    hang_z = max(z for _, z in profile)
    if gid in ("pop", "jam"):
        # Caps/lids are separate Studio-colourable meshes sharing the hang origin.
        cut_z = 2.20 if gid == "pop" else 1.65
        profile = [(r, z) for r, z in profile if z <= cut_z] + [(0.0, cut_z)]
    obj = lathe(f"{gid}_Body", profile, spec["segments"], spec["flat"], hang_z=hang_z)
    obj["glassy_id"] = gid
    return obj


def preview_solid_material(name, tint, metallic=0.0, roughness=0.3):
    """Untextured preview only; Studio assigns the final Color/Material."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    _set_input(bsdf, "Base Color", (*hex_to_rgb(tint), 1.0))
    _set_input(bsdf, "Metallic", metallic)
    _set_input(bsdf, "Roughness", roughness)
    return mat


def build_starter_details(gid):
    details = []
    if gid == "pop":
        cap = lathe("Cap", [(0, 2.20), (0.29, 2.20), (0.34, 2.23),
                             (0.34, 2.38), (0.30, 2.46), (0, 2.46)], hang_z=2.46)
        assign_material([cap], preview_solid_material("GC_PopCap", "#F33142", metallic=0.1))
        cap["studio_color"] = "#F33142"
        cap["studio_material"] = "SmoothPlastic"
        details.append(cap)
        # Five lightweight bubble meshes, all below the glass surface.
        for i, (x, y, z, radius) in enumerate([
            (-0.24, -0.27, -1.99, 0.085), (0.17, -0.30, -1.69, 0.070),
            (-0.15, -0.29, -1.34, 0.095), (0.20, -0.25, -1.03, 0.065),
            (-0.07, -0.17, -0.72, 0.055),
        ], 1):
            bm = bmesh.new()
            bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=4, radius=radius)
            bmesh.ops.translate(bm, verts=bm.verts, vec=(x, y, z))
            bubble = set_shading(_mesh_object(f"Bubble_{i:02d}", bm), smooth=True)
            assign_material([bubble], preview_solid_material("GC_PopBubbles", "#DEFAFF", roughness=0.08))
            bubble["studio_color"] = "#DEFAFF"
            bubble["studio_material"] = "Glass"
            details.append(bubble)
    elif gid == "jam":
        lid = lathe("Lid", [(0, 1.65), (0.87, 1.65), (0.91, 1.72), (0.91, 1.79),
                             (0.87, 1.82), (0.91, 1.86), (0.91, 1.96),
                             (0.83, 2.04), (0, 2.04)], hang_z=2.04)
        assign_material([lid], preview_solid_material("GC_JamLid", "#E8BB57", metallic=0.75, roughness=0.23))
        lid["studio_color"] = "#E8BB57"
        lid["studio_material"] = "Metal"
        details.append(lid)
    for obj in details:
        obj["glassy_id"] = gid
        obj["asset_role"] = "Detail"
    return details


# --------------------------------------------------------------------------------------------
# Shards (plane-cut fracture, no add-ons needed)
# --------------------------------------------------------------------------------------------


def _bm_from_object(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    return bm


def _cut(bm, co, no, keep_inner):
    piece = bm.copy()
    geom = piece.verts[:] + piece.edges[:] + piece.faces[:]
    bmesh.ops.bisect_plane(piece, geom=geom, plane_co=co, plane_no=no, clear_outer=keep_inner, clear_inner=not keep_inner)
    boundary = [e for e in piece.edges if e.is_boundary]
    if boundary:
        bmesh.ops.holes_fill(piece, edges=boundary, sides=0)
    bmesh.ops.recalc_face_normals(piece, faces=piece.faces)
    return piece


def _volume(bm):
    try:
        return abs(bm.calc_volume())
    except Exception:
        return 0.0


def make_shards(body, pieces=16, seed=1, min_volume_ratio=0.01, cut=None):
    """Cuts the body into `pieces` closed shards with random planes. Each shard keeps the body's
    origin (the hang point), so in Roblox the shards line up exactly where the body was."""
    rng = random.Random(seed)
    cutter = cut or _cut
    source = _bm_from_object(body)
    total = _volume(source) or 1.0
    parts = [source]
    attempts = 0
    while len(parts) < pieces and attempts < pieces * 20:
        attempts += 1
        parts.sort(key=_volume, reverse=True)
        target = parts[0]
        xs = [v.co.x for v in target.verts]
        ys = [v.co.y for v in target.verts]
        zs = [v.co.z for v in target.verts]
        centre = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, (min(zs) + max(zs)) / 2))
        size = Vector((max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)))
        co = centre + Vector(tuple(rng.uniform(-0.25, 0.25) * s for s in size))
        no = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)))
        if no.length < 1e-3:
            continue
        no.normalize()
        a, b = cutter(target, co, no, True), cutter(target, co, no, False)
        if len(a.faces) < 4 or len(b.faces) < 4 or min(_volume(a), _volume(b)) < total * min_volume_ratio:
            a.free()
            b.free()
            continue
        target.free()
        parts[0] = a
        parts.append(b)

    shards = []
    for i, bm in enumerate(parts, start=1):
        obj = _mesh_object(f"Shard_{i:02d}", bm)
        obj.matrix_world = body.matrix_world.copy()
        set_shading(obj, smooth=False)
        if "glassy_id" in body:
            obj["glassy_id"] = body["glassy_id"]
        shards.append(obj)
    return shards


# --------------------------------------------------------------------------------------------
# Materials
# --------------------------------------------------------------------------------------------


def _set_input(node, names, value):
    for name in names if isinstance(names, (list, tuple)) else [names]:
        if name in node.inputs:
            node.inputs[name].default_value = value
            return True
    return False


def glossy_preview_material(name, tint_hex):
    """Candy-glass look for icons and renders (Roblox uses its own Glass material in-game)."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    try:
        mat.use_nodes = True
    except Exception:
        pass
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        bsdf = mat.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
    rgb = hex_to_rgb(tint_hex)
    _set_input(bsdf, "Base Color", (*rgb, 1.0))
    _set_input(bsdf, "Roughness", 0.055)
    _set_input(bsdf, ["Coat Weight", "Clearcoat"], 0.5)
    _set_input(bsdf, ["Coat Roughness", "Clearcoat Roughness"], 0.03)
    _set_input(bsdf, ["Transmission Weight", "Transmission"], 0.9)
    _set_input(bsdf, "IOR", 1.45)
    _set_input(bsdf, ["Emission Color", "Emission"], (*rgb, 1.0))
    _set_input(bsdf, "Emission Strength", 0.015)
    return mat


def assign_material(objects, mat):
    for obj in objects:
        obj.data.materials.clear()
        obj.data.materials.append(mat)


# Shared low-poly palette: 16 x 16 grid of flat swatches in one 256 x 256 texture.
PALETTE = {
    # row 0: shared materials
    "wood_light": (0, 0, "#D99A58"), "wood": (0, 1, "#C98B4E"), "wood_dark": (0, 2, "#A86A33"),
    "metal": (0, 3, "#B8C2D6"), "rope": (0, 4, "#F4F1E8"), "grass": (0, 5, "#62CF9C"),
    "grass_dark": (0, 6, "#3FA874"), "path": (0, 7, "#E9D7B0"), "stone": (0, 8, "#9AA5B8"),
    "white": (0, 9, "#F5F7FF"), "navy": (0, 10, "#1A1E4A"), "red": (0, 11, "#E5263F"),
    "yellow": (0, 12, "#FFC93C"), "sand": (0, 13, "#F2DFA6"), "shadow": (0, 14, "#5A3414"),
    # row 1: Recycling Yard
    "bin_blue": (1, 0, "#3D7BF2"), "bin_green": (1, 1, "#3FB86B"), "bin_yellow": (1, 2, "#FFC93C"),
    "crate": (1, 3, "#D9A066"), "conveyor": (1, 4, "#4A4F6B"), "glass_bank": (1, 5, "#7FD8FF"),
}
PALETTE_CELLS = 16


def palette_image(save=True):
    """Creates (or rebuilds) the shared palette texture and saves it to assets/blender/map/palette.png."""
    size = 256
    cell = size // PALETTE_CELLS
    img = bpy.data.images.get("GC_Palette") or bpy.data.images.new("GC_Palette", size, size, alpha=False)
    if tuple(img.size) != (size, size):
        img.scale(size, size)
    pixels = [0.5] * (size * size * 4)
    for row, col, hex_color in PALETTE.values():
        h = hex_color.lstrip("#")
        srgb = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
        y0 = size - (row + 1) * cell  # row 0 at the top of the image
        for y in range(y0, y0 + cell):
            for x in range(col * cell, (col + 1) * cell):
                i = (y * size + x) * 4
                pixels[i : i + 4] = [*srgb, 1.0]
    img.pixels[:] = pixels
    if save:
        path = repo_path("assets", "blender", "map", "palette.png")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()
    return img


def palette_material():
    mat = bpy.data.materials.get("GC_Palette")
    if mat is None:
        mat = bpy.data.materials.new("GC_Palette")
        try:
            mat.use_nodes = True
        except Exception:
            pass
        nodes = mat.node_tree.nodes
        bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
        _set_input(bsdf, "Roughness", 0.85)
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = palette_image()
        tex.interpolation = "Closest"
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def paint(obj, swatch):
    """Preview swatch on a separate mesh; final colouring happens in Studio."""
    tint = PALETTE[swatch][2]
    obj["studio_color"] = tint
    obj["studio_material"] = "SmoothPlastic"
    assign_material([obj], preview_solid_material(f"GC_World_{swatch}", tint, roughness=0.85))
    set_shading(obj, smooth=False)
    return obj


# --------------------------------------------------------------------------------------------
# Low-poly primitives for the world kit
# --------------------------------------------------------------------------------------------


def box(name, size, location=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    bmesh.ops.translate(bm, vec=location, verts=bm.verts)
    return _mesh_object(name, bm)


def prism_column(name, radius, height, sides=8, location=(0, 0, 0), top_radius=None):
    """Low-poly faceted cylinder (posts, tree trunks, bins). Base at location."""
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=sides, radius1=radius,
        radius2=radius if top_radius is None else top_radius, depth=height,
    )
    bmesh.ops.translate(bm, vec=(location[0], location[1], location[2] + height / 2), verts=bm.verts)
    return _mesh_object(name, bm)


def chamfer_box(name, size, location=(0, 0, 0), bevel=0.06):
    obj = box(name, size, location)
    bm = _bm_from_object(obj)
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return obj


def hook_ring(name, location):
    """Small metal eyelet in the XZ plane, not a rope loop."""
    bm = bmesh.new()
    rows = []
    for i in range(12):
        a = i * math.tau / 12
        row = []
        for j in range(6):
            b = j * math.tau / 6
            r = 0.26 + 0.075 * math.cos(b)
            row.append(bm.verts.new((location[0] + r * math.cos(a),
                                     location[1] + 0.075 * math.sin(b),
                                     location[2] + r * math.sin(a))))
        rows.append(row)
    for i in range(12):
        for j in range(6):
            bm.faces.new((rows[i][j], rows[(i + 1) % 12][j],
                          rows[(i + 1) % 12][(j + 1) % 6], rows[i][(j + 1) % 6]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _mesh_object(name, bm)


def build_clash_stand(span=20.0, height=16.0, hook_gap=3.0, pen_radius=15.0):
    """Low-poly Clash Stand inside a wooden octagon pen (the real-life setup).

    Returns a dict of the created objects. HookA/HookB mark where the strings attach; in
    Roblox, add Attachments at those positions.
    """
    objs = {}
    half = span / 2
    objs["Crossbar"] = paint(chamfer_box("Crossbar", (span + 2.0, 1.3, 1.3), (0, 0, height + 0.3), 0.12), "wood_light")
    # Two complete A-frames, splayed perpendicular to the bar like a playground swing.
    # Keep the original post caps; no braces between legs and crossbar.
    for label, x in (("A", -half), ("B", half)):
        objs[f"PostCap{label}"] = paint(chamfer_box(f"PostCap{label}", (1.45, 1.45, 0.5), (x, 0, height + 1.15)), "wood_dark")
        for side in (-1, 1):
            start = Vector((x, side * 4.3, 0.35))
            end = Vector((x, side * 0.25, height + 0.45))
            name = f"Leg{label}_{'Front' if side < 0 else 'Back'}"
            leg = chamfer_box(name, (1.05, 1.05, (end - start).length), bevel=0.07)
            leg.location = (start + end) / 2
            leg.rotation_euler = (end - start).to_track_quat("Z", "Y").to_euler()
            objs[name] = paint(leg, "wood")
            name = f"Foot{label}_{'Front' if side < 0 else 'Back'}"
            objs[name] = paint(chamfer_box(name, (2.0, 2.0, 0.35), (x, side * 4.3, 0.175)), "wood_dark")
    for key, x in (("HookA", -hook_gap / 2), ("HookB", hook_gap / 2)):
        hook = paint(hook_ring(key, (x, 0, height - 0.65)), "metal")
        hook["attachment_position"] = [x, 0, height - 0.91]
        objs[key] = hook

    # Octagon pen: floor + 8 low wall segments, flat-shaded wood
    floor = paint(prism_column("PenFloor", pen_radius, 0.4, 8, (0, 0, -0.4)), "wood_dark")
    floor.rotation_euler.z = math.pi / 8
    objs["PenFloor"] = floor
    apothem = pen_radius * math.cos(math.pi / 8)
    side = 2 * pen_radius * math.sin(math.pi / 8)
    # Individual clipped boards give the floor readable seams without texture noise.
    for i in range(17):
        name = f"FloorBoard_{i + 1:02d}"
        board = box(name, (pen_radius * 2, 1.57, 0.12), (0, (i - 8) * 1.60, 0.03))
        bm = _bm_from_object(board)
        for j in range(8):
            a = j * math.tau / 8
            no = Vector((math.cos(a), math.sin(a), 0))
            clipped = _cut(bm, no * (apothem - 0.12), no, True)
            bm.free()
            bm = clipped
        bm.to_mesh(board.data)
        bm.free()
        board.data.update()
        objs[name] = paint(board, "wood" if i % 3 else "wood_light")
    for i in range(8):
        angle = i * math.tau / 8
        wall = paint(chamfer_box(f"PenWall_{i + 1}", (side, 0.5, 2.4), (0, 0, 1.2)), "wood")
        wall.location = (math.cos(angle) * (apothem - 0.25), math.sin(angle) * (apothem - 0.25), 0)
        wall.rotation_euler.z = angle + math.pi / 2
        objs[wall.name] = wall
        rail = paint(chamfer_box(f"RailCap_{i + 1}", (side + 0.25, 0.76, 0.28), (0, 0, 2.4)), "wood_light")
        rail.location = wall.location
        rail.rotation_euler.z = wall.rotation_euler.z
        objs[rail.name] = rail
        a = angle + math.pi / 8
        name = f"CornerPost_{i + 1}"
        objs[name] = paint(prism_column(name, 0.48, 2.8, 8,
                                      (math.cos(a) * pen_radius, math.sin(a) * pen_radius, 0)), "wood_dark")
    for obj in objs.values():
        obj["glassclash"] = "clash_stand"
    return objs


# --------------------------------------------------------------------------------------------
# Rendering
# --------------------------------------------------------------------------------------------


def _world_bounds(objects):
    pts = [obj.matrix_world @ Vector(c) for obj in objects for c in obj.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def render_icon(objects, path, tint_hex=None, size=512, samples=48, engine="CYCLES"):
    """Renders `objects` alone with the shared icon camera + lighting to a transparent PNG.
    Restores the scene afterwards (other objects, camera, world and render settings)."""
    scene = bpy.context.scene
    objects = list(objects)
    if tint_hex:
        assign_material(objects, glossy_preview_material(f"GC_Preview_{tint_hex.lstrip('#')}", tint_hex))

    render = scene.render
    saved = dict(
        camera=scene.camera, world=scene.world, engine=render.engine, x=render.resolution_x,
        y=render.resolution_y, pct=render.resolution_percentage, transparent=render.film_transparent,
        filepath=render.filepath, fmt=render.image_settings.file_format, mode=render.image_settings.color_mode,
    )
    hidden = {o.name: o.hide_render for o in scene.objects}
    temp = []
    try:
        for o in scene.objects:
            o.hide_render = o not in objects

        bpy.context.view_layer.update()
        lo, hi = _world_bounds(objects)
        centre = (lo + hi) / 2
        radius = max((hi - lo).length / 2, 0.1)

        cam_data = bpy.data.cameras.new("GC_IconCam")
        cam_data.lens = 70
        cam = bpy.data.objects.new("GC_IconCam", cam_data)
        scene.collection.objects.link(cam)
        temp.append(cam)
        direction = Vector((1.0, -1.35, 0.75)).normalized()
        fov = 2 * math.atan(cam_data.sensor_width / (2 * cam_data.lens))
        distance = radius / math.sin(fov / 2) * 1.08
        cam.location = centre + direction * distance
        cam.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
        scene.camera = cam

        def add_light(name, kind, energy, loc, size_=2.0, color=(1, 1, 1)):
            data = bpy.data.lights.new(name, kind)
            data.energy = energy
            data.color = color
            if kind == "AREA":
                data.size = size_ * radius
            obj = bpy.data.objects.new(name, data)
            scene.collection.objects.link(obj)
            obj.location = loc
            obj.rotation_euler = (centre - obj.location).to_track_quat("-Z", "Y").to_euler()
            temp.append(obj)

        scale = (radius / 1.2) ** 2
        add_light("GC_Key", "AREA", 260 * scale, centre + Vector((-2.0, -3.0, 3.2)) * radius, 2.5)
        add_light("GC_Rim", "AREA", 320 * scale, centre + Vector((2.5, 3.0, 2.0)) * radius, 1.5, (0.85, 0.9, 1.0))
        add_light("GC_Fill", "AREA", 90 * scale, centre + Vector((3.0, -1.5, 0.5)) * radius, 3.0)

        world = bpy.data.worlds.get("GC_IconWorld") or bpy.data.worlds.new("GC_IconWorld")
        try:
            world.use_nodes = True
        except Exception:
            pass
        bg = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"), None)
        if bg:
            bg.inputs["Color"].default_value = (0.18, 0.24, 0.36, 1.0)
            bg.inputs["Strength"].default_value = 0.45
        scene.world = world

        render.engine = engine
        if engine == "CYCLES":
            scene.cycles.samples = samples
            try:
                scene.cycles.use_denoising = True
            except Exception:
                pass
        render.resolution_x = render.resolution_y = size
        render.resolution_percentage = 100
        render.film_transparent = True
        render.image_settings.file_format = "PNG"
        render.image_settings.color_mode = "RGBA"
        os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
        render.filepath = os.path.abspath(path)
        try:
            bpy.ops.render.render(write_still=True)
        except RuntimeError:
            if engine == "CYCLES" and scene.cycles.use_denoising:
                scene.cycles.use_denoising = False
                bpy.ops.render.render(write_still=True)
            else:
                raise
    finally:
        for obj in temp:
            data = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            if isinstance(data, bpy.types.Camera):
                bpy.data.cameras.remove(data)
            elif isinstance(data, bpy.types.Light):
                bpy.data.lights.remove(data)
        for name, value in hidden.items():
            if name in scene.objects:
                scene.objects[name].hide_render = value
        scene.camera = saved["camera"]
        scene.world = saved["world"]
        render.engine = saved["engine"]
        render.resolution_x, render.resolution_y = saved["x"], saved["y"]
        render.resolution_percentage = saved["pct"]
        render.film_transparent = saved["transparent"]
        render.filepath = saved["filepath"]
        render.image_settings.file_format = saved["fmt"]
        render.image_settings.color_mode = saved["mode"]
    return os.path.abspath(path)


# --------------------------------------------------------------------------------------------
# Export
# --------------------------------------------------------------------------------------------


def export_fbx(objects, path):
    """Exports only `objects` to FBX (transforms applied, triangulated, textures embedded)."""
    objects = list(objects)
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    view_layer = bpy.context.view_layer
    view_layer.update()
    previous = [o for o in view_layer.objects if o.select_get(view_layer=view_layer)]
    active = view_layer.objects.active
    visibility = {o: (o.hide_get(view_layer=view_layer), o.hide_viewport) for o in objects}
    for o in previous:
        o.select_set(False, view_layer=view_layer)
    for o in objects:
        o.hide_viewport = False
        o.hide_set(False, view_layer=view_layer)
        o.select_set(True, view_layer=view_layer)
    view_layer.objects.active = objects[0]
    try:
        with bpy.context.temp_override(selected_objects=objects, selected_editable_objects=objects,
                                       active_object=objects[0], object=objects[0]):
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
            bpy.ops.export_scene.fbx(
                filepath=os.path.abspath(path),
                use_selection=True,
                object_types={"MESH"},
                apply_unit_scale=True,
                axis_forward="-Z",
                axis_up="Y",
                bake_space_transform=True,
                use_mesh_modifiers=True,
                mesh_smooth_type="FACE",
                use_triangles=True,
                use_custom_props=True,
                add_leaf_bones=False,
                path_mode="COPY",
                embed_textures=True,
            )
    finally:
        for o in objects:
            o.select_set(False, view_layer=view_layer)
            hidden, disabled = visibility[o]
            o.hide_set(hidden, view_layer=view_layer)
            o.hide_viewport = disabled
        for o in previous:
            o.select_set(True, view_layer=view_layer)
        view_layer.objects.active = active
    return os.path.abspath(path)


def save_blend_copy(path):
    """Saves only the current asset scene and dependencies, preserving the open file."""
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    bpy.data.libraries.write(os.path.abspath(path), {bpy.context.scene}, fake_user=True, compress=True)
    return os.path.abspath(path)


def export_glassy(gid, body, shards, icon=True, blend=True, details=None):
    """Writes assets/blender/glassies/<gid>/<gid>_body.fbx, <gid>_shards.fbx, the .blend copy,
    and assets/icons/<gid>.png."""
    folder = repo_path("assets", "blender", "glassies", gid)
    details = list(details or [])
    body.name = "Body"
    body["studio_color"] = glassy_tint(gid)
    body["studio_material"] = "Glass"
    body["studio_transparency"] = 0.3
    for i, s in enumerate(shards, start=1):
        s.name = f"Shard_{i:02d}"
    assign_material([body, *shards], glossy_preview_material(f"GC_Preview_{gid}", glassy_tint(gid)))
    if gid == "pop":
        # Slight cyan fill compensates for the dark reflection studio in the icon only.
        bsdf = next(n for n in body.data.materials[0].node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        _set_input(bsdf, "Emission Strength", 0.18)
        _set_input(bsdf, "Transmission Weight", 0.95)
        bpy.context.scene.view_settings.view_transform = "Standard"
    out = {
        "body": export_fbx([body], os.path.join(folder, f"{gid}_body.fbx")),
        "shards": export_fbx(shards, os.path.join(folder, f"{gid}_shards.fbx")),
    }
    if details:
        out["details"] = export_fbx(details, os.path.join(folder, f"{gid}_details.fbx"))
    if icon:
        out["icon"] = render_icon([body, *details], repo_path("assets", "icons", f"{gid}.png"))
    if blend:
        for s in shards:
            s.hide_render = True
            s.hide_set(True)
        out["blend"] = save_blend_copy(os.path.join(folder, f"{gid}.blend"))
    return out


def export_clash_stand(icon=True):
    """Builds and exports the stand in an isolated scene, preserving existing work."""
    global COLLECTION
    previous_scene = bpy.context.window.scene
    previous_collection = COLLECTION
    scene = bpy.data.scenes.new("GlassClash_ClashStand")
    scene.unit_settings.system = "NONE"
    scene.unit_settings.scale_length = 1.0
    bpy.context.window.scene = scene
    COLLECTION = scene.name
    try:
        with bpy.context.temp_override(scene=scene, view_layer=scene.view_layers[0]):
            objs = build_clash_stand()
            folder = repo_path("assets", "blender", "map")
            out = {"fbx": export_fbx(objs.values(), os.path.join(folder, "clash_stand.fbx"))}
            if icon:
                out["preview"] = render_icon(objs.values(), os.path.join(folder, "clash_stand_preview.png"), size=768)
            out["blend"] = save_blend_copy(os.path.join(folder, "clash_stand.blend"))
            return out
    finally:
        bpy.context.window.scene = previous_scene
        COLLECTION = previous_collection


# --------------------------------------------------------------------------------------------
# Self check
# --------------------------------------------------------------------------------------------


def self_check():
    """Builds and fractures a test glassy, then removes it. Prints a short report."""
    report = {"blender": bpy.app.version_string, "repo": REPO}
    report["repo_found"] = os.path.exists(repo_path("AGENTS.md"))
    report["assets_writable"] = os.access(repo_path("assets"), os.W_OK)
    body = build_starter("pop")
    shards = make_shards(body, 8, seed=3)
    report["test_body_tris"] = sum(len(p.vertices) - 2 for p in body.data.polygons)
    report["test_shards"] = len(shards)
    for obj in [body, *shards]:
        mesh = obj.data
        bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.meshes.remove(mesh)
    report["ok"] = report["repo_found"] and report["test_shards"] == 8
    if not report["repo_found"]:
        report["hint"] = "Set GLASSCLASH_REPO to the repo folder before exec(), or call set_repo(path)."
    print("[GlassClash] self_check:", report)
    return report


def build_all_starters(pieces=16, gids=("pop", "jam", "prism")):
    """Builds each starter in an isolated scene without clearing existing work."""
    global COLLECTION
    results = {}
    previous_scene = bpy.context.window.scene
    previous_collection = COLLECTION
    try:
        for gid in gids:
            scene = bpy.data.scenes.new(f"GlassClash_{gid}")
            scene.unit_settings.system = "NONE"
            scene.unit_settings.scale_length = 1.0
            bpy.context.window.scene = scene
            COLLECTION = scene.name
            with bpy.context.temp_override(scene=scene, view_layer=scene.view_layers[0]):
                body = build_starter(gid)
                shards = make_shards(body, pieces, seed=sum(map(ord, gid)))
                details = build_starter_details(gid)
                results[gid] = export_glassy(gid, body, shards, details=details)
            # Blender names are global across scenes; free export names for the next asset.
            body.name = f"{gid}_Body"
            for i, shard in enumerate(shards, start=1):
                shard.name = f"{gid}_Shard_{i:02d}"
            for detail in details:
                detail.name = f"{gid}_{detail.name}"
    finally:
        bpy.context.window.scene = previous_scene
        COLLECTION = previous_collection
    return results
