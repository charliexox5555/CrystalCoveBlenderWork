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
glossy; the world is low-poly, flat-shaded and coloured from one shared palette texture.
Everything this script creates goes into the "GlassClash" collection, so it never touches
your other objects.
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


def gc_collection(name=COLLECTION):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
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
    # Pop: classic soda bottle with a cap ring
    "pop": dict(
        segments=24,
        flat=False,
        profile=[
            (0.0, 0.0), (0.50, 0.0), (0.60, 0.06), (0.62, 0.20), (0.62, 1.20), (0.58, 1.38),
            (0.42, 1.62), (0.26, 1.82), (0.22, 1.98), (0.22, 2.12), (0.28, 2.14), (0.28, 2.30),
            (0.24, 2.34), (0.0, 2.34),
        ],
    ),
    # Jam: short, wide jar with a chunky screw lid
    "jam": dict(
        segments=24,
        flat=False,
        profile=[
            (0.0, 0.0), (0.70, 0.0), (0.82, 0.08), (0.86, 0.25), (0.86, 1.15), (0.80, 1.30),
            (0.70, 1.36), (0.74, 1.40), (0.78, 1.44), (0.78, 1.68), (0.72, 1.74), (0.0, 1.74),
        ],
    ),
    # Prism: faceted perfume bottle with a gem stopper (6 sides, flat shaded = crystal look)
    "prism": dict(
        segments=6,
        flat=True,
        profile=[
            (0.0, 0.0), (0.50, 0.0), (0.72, 0.42), (0.72, 0.95), (0.52, 1.30), (0.20, 1.42),
            (0.16, 1.56), (0.32, 1.62), (0.40, 1.80), (0.26, 2.02), (0.0, 2.10),
        ],
    ),
}


def build_starter(gid):
    """Builds the v0 body for a starter glassy. Improve the shape freely; keep the origin
    at the hang point (top centre) and the size around 2-2.5 studs."""
    spec = STARTER_PROFILES[gid]
    obj = lathe(f"{gid}_Body", spec["profile"], spec["segments"], spec["flat"])
    obj["glassy_id"] = gid
    return obj


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


def make_shards(body, pieces=16, seed=1, min_volume_ratio=0.01):
    """Cuts the body into `pieces` closed shards with random planes. Each shard keeps the body's
    origin (the hang point), so in Roblox the shards line up exactly where the body was."""
    rng = random.Random(seed)
    total = _volume(_bm_from_object(body)) or 1.0
    parts = [_bm_from_object(body)]
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
        a, b = _cut(target, co, no, True), _cut(target, co, no, False)
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
    _set_input(bsdf, "Roughness", 0.12)
    _set_input(bsdf, ["Coat Weight", "Clearcoat"], 1.0)
    _set_input(bsdf, ["Coat Roughness", "Clearcoat Roughness"], 0.03)
    _set_input(bsdf, ["Transmission Weight", "Transmission"], 0.35)
    _set_input(bsdf, "IOR", 1.45)
    _set_input(bsdf, ["Emission Color", "Emission"], (*rgb, 1.0))
    _set_input(bsdf, "Emission Strength", 0.15)
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
    """Colours a whole low-poly object with one palette swatch (all UVs on the swatch centre)."""
    row, col, _ = PALETTE[swatch]
    u = (col + 0.5) / PALETTE_CELLS
    v = 1 - (row + 0.5) / PALETTE_CELLS
    mesh = obj.data
    if not mesh.uv_layers:
        mesh.uv_layers.new(name="UVMap")
    for loop_uv in mesh.uv_layers.active.data:
        loop_uv.uv = (u, v)
    assign_material([obj], palette_material())
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


def build_clash_stand(span=20.0, height=16.0, hook_gap=3.0, pen_radius=15.0):
    """Low-poly Clash Stand inside a wooden octagon pen (the real-life setup).

    Returns a dict of the created objects. HookA/HookB mark where the strings attach; in
    Roblox, add Attachments at those positions.
    """
    objs = {}
    half = span / 2
    objs["PostA"] = paint(prism_column("PostA", 0.55, height, 8, (-half, 0, 0), top_radius=0.48), "wood")
    objs["PostB"] = paint(prism_column("PostB", 0.55, height, 8, (half, 0, 0), top_radius=0.48), "wood")
    objs["FootA"] = paint(box("FootA", (2.6, 2.6, 0.5), (-half, 0, 0.25)), "wood_dark")
    objs["FootB"] = paint(box("FootB", (2.6, 2.6, 0.5), (half, 0, 0.25)), "wood_dark")
    objs["Crossbar"] = paint(box("Crossbar", (span + 2.0, 1.1, 1.1), (0, 0, height + 0.3)), "wood_light")
    for key, x in (("HookA", -hook_gap / 2), ("HookB", hook_gap / 2)):
        hook = paint(prism_column(key, 0.18, 0.6, 6, (x, 0, height - 0.85)), "metal")
        objs[key] = hook

    # Octagon pen: floor + 8 low wall segments, flat-shaded wood
    floor = paint(prism_column("PenFloor", pen_radius, 0.4, 8, (0, 0, -0.4)), "wood_dark")
    floor.rotation_euler.z = math.pi / 8
    objs["PenFloor"] = floor
    apothem = pen_radius * math.cos(math.pi / 8)
    side = 2 * pen_radius * math.sin(math.pi / 8)
    for i in range(8):
        angle = i * math.tau / 8
        wall = paint(box(f"PenWall_{i + 1}", (side, 0.5, 2.4), (0, 0, 1.2)), "wood")
        wall.location = (math.cos(angle) * (apothem - 0.25), math.sin(angle) * (apothem - 0.25), 0)
        wall.rotation_euler.z = angle + math.pi / 2
        objs[wall.name] = wall
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
            bg.inputs["Color"].default_value = (0.75, 0.82, 1.0, 1.0)
            bg.inputs["Strength"].default_value = 0.6
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
    previous = [o for o in view_layer.objects if o.select_get()]
    active = view_layer.objects.active
    for o in previous:
        o.select_set(False)
    for o in objects:
        o.select_set(True)
    view_layer.objects.active = objects[0]
    try:
        bpy.ops.export_scene.fbx(
            filepath=os.path.abspath(path),
            use_selection=True,
            object_types={"MESH"},
            apply_unit_scale=True,
            bake_space_transform=True,
            use_mesh_modifiers=True,
            mesh_smooth_type="FACE",
            use_triangles=True,
            add_leaf_bones=False,
            path_mode="COPY",
            embed_textures=True,
        )
    finally:
        for o in objects:
            o.select_set(False)
        for o in previous:
            o.select_set(True)
        view_layer.objects.active = active
    return os.path.abspath(path)


def save_blend_copy(path):
    """Saves a copy of the current file (your open file keeps its own path)."""
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(path), copy=True)
    return os.path.abspath(path)


def export_glassy(gid, body, shards, icon=True, blend=True):
    """Writes assets/blender/glassies/<gid>/<gid>_body.fbx, <gid>_shards.fbx, the .blend copy,
    and assets/icons/<gid>.png."""
    folder = repo_path("assets", "blender", "glassies", gid)
    body.name = "Body"
    for i, s in enumerate(shards, start=1):
        s.name = f"Shard_{i:02d}"
    out = {
        "body": export_fbx([body], os.path.join(folder, f"{gid}_body.fbx")),
        "shards": export_fbx(shards, os.path.join(folder, f"{gid}_shards.fbx")),
    }
    if icon:
        out["icon"] = render_icon([body], repo_path("assets", "icons", f"{gid}.png"), glassy_tint(gid))
    if blend:
        out["blend"] = save_blend_copy(os.path.join(folder, f"{gid}.blend"))
    return out


def export_clash_stand(icon=True):
    objs = build_clash_stand()
    folder = repo_path("assets", "blender", "map")
    out = {"fbx": export_fbx(objs.values(), os.path.join(folder, "clash_stand.fbx"))}
    if icon:
        out["preview"] = render_icon(objs.values(), os.path.join(folder, "clash_stand_preview.png"), size=768)
    return out


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


def build_all_starters(pieces=16):
    """Convenience: builds, fractures and exports the three starters."""
    results = {}
    for gid in ("pop", "jam", "prism"):
        clear_collection()
        body = build_starter(gid)
        shards = make_shards(body, pieces, seed=sum(map(ord, gid)))
        results[gid] = export_glassy(gid, body, shards)
    clear_collection()
    return results
