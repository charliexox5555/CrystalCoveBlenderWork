"""Builds the Kilnport + Cullet Yard grey-box blockout in Blender (1 unit = 1 stud).

How to use (Blender 4.2+ / 5.x):
  1. Open Blender, go to the Scripting tab, click Open and pick this file.
  2. Leave REPO empty unless you get a "Couldn't find" error.
  3. Click Run Script (or Alt+P). Everything lands in the "Blockout" collection.
     (No need to edit REPO; the repo folder is found automatically.)

The layout comes from tools/map/village_layout.py (same data as docs/art/blueprint_*.svg).
Colours here are preview materials only; final colours are set in Studio (DECISIONS #14).
Build your real low-poly kit on top of this, then delete or hide the Blockout collection.
"""

import math
import os
import random

REPO = r""  # Leave empty: the folder is found automatically. Only set it if you get a "Couldn't find" error.


def _is_repo(path):
    return bool(path) and os.path.isfile(os.path.join(path, "tools", "map", "village_layout.py"))


def _repo():
    """Finds the repo folder. You normally don't need to set REPO: opening this file in
    Blender's Text Editor (Scripting tab > Open) is enough."""
    candidates = []
    if REPO and "<" not in REPO:
        candidates.append(REPO)
    try:
        import bpy

        for text in bpy.data.texts:
            if text.filepath and "blockout_village" in text.filepath:
                candidates.append(os.path.join(os.path.dirname(bpy.path.abspath(text.filepath)), "..", ".."))
        if bpy.data.filepath:
            candidates.append(os.path.dirname(bpy.data.filepath))
    except Exception:
        pass
    here = globals().get("__file__")
    if here:
        candidates.append(os.path.join(os.path.dirname(here), "..", ".."))
    home = os.path.expanduser("~")
    candidates += [os.path.join(home, "Documents", "CrystalCoveBlenderWork"), os.path.join(home, "OneDrive", "Documents", "CrystalCoveBlenderWork"), os.getcwd()]
    for c in candidates:
        c = os.path.abspath(c)
        # walk up a few levels in case a subfolder was given
        for _ in range(4):
            if _is_repo(c):
                return c
            c = os.path.dirname(c)
    raise RuntimeError(
        "Couldn't find the CrystalCoveBlenderWork folder. Set REPO at the top of this script to its full path, "
        'for example REPO = r"C:\\Users\\YourName\\Documents\\CrystalCoveBlenderWork"'
    )


def _load_layout(repo):
    import importlib.util

    path = os.path.join(repo, "tools", "map", "village_layout.py")
    spec = importlib.util.spec_from_file_location("village_layout", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def build(collection_name="Blockout", clear=True):
    import bpy
    import bmesh
    from mathutils import Vector

    L = _load_layout(_repo())

    col = bpy.data.collections.get(collection_name)
    if col is None:
        col = bpy.data.collections.new(collection_name)
        bpy.context.scene.collection.children.link(col)
    if clear:
        for obj in list(col.objects):
            bpy.data.objects.remove(obj, do_unlink=True)

    subs = {}

    def group(name):
        if name not in subs:
            full = f"{collection_name}_{name}"
            sub = bpy.data.collections.get(full) or bpy.data.collections.new(full)
            if sub.name not in col.children:
                col.children.link(sub)
            for obj in list(sub.objects):
                bpy.data.objects.remove(obj, do_unlink=True)
            subs[name] = sub
        return subs[name]

    mats = {}

    def mat(hex_color, emission=0.0):
        key = (hex_color, emission)
        if key in mats:
            return mats[key]
        h = hex_color.lstrip("#")
        srgb = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
        lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
        m = bpy.data.materials.new(f"BO_{h}_{emission}")
        m.diffuse_color = (*lin, 1.0)
        try:
            m.use_nodes = True
        except Exception:
            pass
        bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (*lin, 1.0)
            bsdf.inputs["Roughness"].default_value = 0.9
            if emission > 0:
                for name in ("Emission Color", "Emission"):
                    if name in bsdf.inputs:
                        bsdf.inputs[name].default_value = (*lin, 1.0)
                bsdf.inputs["Emission Strength"].default_value = emission
        mats[key] = m
        return m

    def obj_from_bm(name, bm, color, grp, emission=0.0, smooth=False):
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        bm.free()
        for poly in mesh.polygons:
            poly.use_smooth = smooth
        ob = bpy.data.objects.new(name, mesh)
        group(grp).objects.link(ob)
        ob.data.materials.append(mat(color, emission))
        return ob

    def prism(name, points, z0, z1, color, grp, emission=0.0):
        """Extrudes a 2D polygon from z0 to z1."""
        bm = bmesh.new()
        bottom = [bm.verts.new((x, y, z0)) for x, y in points]
        face = bm.faces.new(bottom)
        res = bmesh.ops.extrude_face_region(bm, geom=[face])
        top = [e for e in res["geom"] if isinstance(e, bmesh.types.BMVert)]
        bmesh.ops.translate(bm, verts=top, vec=(0, 0, z1 - z0))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        return obj_from_bm(name, bm, color, grp, emission)

    def cyl(name, cx, cy, r, z0, z1, color, grp, sides=16, r_top=None, emission=0.0):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=sides, radius1=r, radius2=r if r_top is None else r_top, depth=z1 - z0)
        bmesh.ops.translate(bm, verts=bm.verts, vec=(cx, cy, (z0 + z1) / 2))
        return obj_from_bm(name, bm, color, grp, emission)

    def box(name, cx, cy, z0, w, d, h, facing, color, grp, emission=0.0):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=(w, d, h), verts=bm.verts)
        ob = obj_from_bm(name, bm, color, grp, emission)
        ob.location = (cx, cy, z0 + h / 2)
        ob.rotation_euler.z = math.radians(facing)
        return ob

    def roof(name, cx, cy, z0, w, d, h, facing, color, grp):
        bm = bmesh.new()
        v = [bm.verts.new(p) for p in [(-w / 2, -d / 2, 0), (w / 2, -d / 2, 0), (w / 2, d / 2, 0), (-w / 2, d / 2, 0), (-w / 2, 0, h), (w / 2, 0, h)]]
        bm.faces.new([v[0], v[1], v[5], v[4]])
        bm.faces.new([v[3], v[4], v[5], v[2]])
        bm.faces.new([v[0], v[4], v[3]])
        bm.faces.new([v[1], v[2], v[5]])
        bm.faces.new([v[0], v[3], v[2], v[1]])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        ob = obj_from_bm(name, bm, color, grp)
        ob.location = (cx, cy, z0)
        ob.rotation_euler.z = math.radians(facing)
        return ob

    def ring(name, cx, cy, r_in, r_out, z0, z1, color, grp, sides=32):
        bm = bmesh.new()
        outer = [bm.verts.new((cx + math.cos(i * math.tau / sides) * r_out, cy + math.sin(i * math.tau / sides) * r_out, z0)) for i in range(sides)]
        inner = [bm.verts.new((cx + math.cos(i * math.tau / sides) * r_in, cy + math.sin(i * math.tau / sides) * r_in, z0)) for i in range(sides)]
        faces = [bm.faces.new((outer[i], outer[(i + 1) % sides], inner[(i + 1) % sides], inner[i])) for i in range(sides)]
        res = bmesh.ops.extrude_face_region(bm, geom=faces)
        top = [e for e in res["geom"] if isinstance(e, bmesh.types.BMVert)]
        bmesh.ops.translate(bm, verts=top, vec=(0, 0, z1 - z0))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        return obj_from_bm(name, bm, color, grp)

    def ramp(name, a, b, width, z_a, z_b, color, grp):
        (ax, ay), (bx, by) = a, b
        length = math.hypot(bx - ax, by - ay)
        ob = box(name, (ax + bx) / 2, (ay + by) / 2, 0, width, length, 1.0, 0, color, grp)
        ob.location.z = (z_a + z_b) / 2 - 0.5
        ob.rotation_euler = (math.atan2(z_b - z_a, length), 0, -math.atan2(bx - ax, by - ay))
        return ob

    def segment(name, a, b, width, z, color, grp, thickness=0.6):
        (ax, ay), (bx, by) = a, b
        length = math.hypot(bx - ax, by - ay)
        ob = box(name, (ax + bx) / 2, (ay + by) / 2, z, width, length, thickness, 0, color, grp)
        ob.rotation_euler.z = math.atan2(bx - ax, by - ay) * -1
        return ob

    # ---- land, sea, hills -------------------------------------------------------------------
    prism("Sea", [(-1200, -1200), (1200, -1200), (1200, 1200), (-1200, 1200)], L.SEA_Z - 2, L.SEA_Z, "#5AA9D6", "Terrain")
    land_colors = {"plateau": "#9DCB7A", "yard_terrace": "#8DBB6A", "beach": "#F2DFA6"}
    for land in L.LAND:
        prism(f"Land_{land['id']}", land["points"], land["bottom"], land["top"], land_colors.get(land["id"], land["color"]), "Terrain")
    for i, (x, y, r, h) in enumerate(L.HILLS):
        cyl(f"Hill_{i + 1}", x, y, r, L.YARD_Z - 1, L.YARD_Z + h, "#7DBB6A", "Terrain", sides=7, r_top=r * 0.25)

    # ---- paths and plazas -------------------------------------------------------------------
    for path in L.PATHS:
        pts = path["points"]
        for i in range(len(pts) - 1):
            if path["id"] == "route1" and i < 2:
                continue  # covered by the Kiln Gate ramp below
            segment(f"Path_{path['id']}_{i + 1}", pts[i], pts[i + 1], path["width"], path["z"] + 0.004 * i, "#E9D7B0", "Paths")
        for i, (x, y) in enumerate(pts[1:-1] if path["id"] != "route1" else pts[2:-1]):
            cyl(f"Path_{path['id']}_Joint{i + 1}", x, y, path["width"] / 2, path["z"], path["z"] + 0.62, "#E9D7B0", "Paths", sides=16)
    # ramp from the Kiln Gate (plateau) down to the Cullet Yard terrace
    route = next(p for p in L.PATHS if p["id"] == "route1")["points"]
    ramp("Ramp_KilnGate", route[0], route[2], 22, L.VILLAGE_Z, L.YARD_Z, "#E9D7B0", "Paths")

    disk_style = {"plaza": ("#EFE3C8", 0.8), "wild": ("#7CDB8A", 0.3), "platform": ("#C9B9E8", 3.0)}
    for d in L.DISKS:
        color, h = disk_style[d["kind"]]
        cyl(f"Disk_{d['id']}", *d["center"], d["radius"], d["z"], d["z"] + h, color, "Plazas", sides=32)

    # ---- landmark: furnace tower ------------------------------------------------------------
    t = L.TOWER
    tx, ty = t["center"]
    cyl("Tower_Chimney", tx, ty, t["radius_base"], 0, t["height"], "#8C4A35", "Landmark", sides=8, r_top=t["radius_top"])
    cyl("Tower_Band_1", tx, ty, t["radius_base"] * 0.92 + 1.2, 40, 44, "#6E3B2E", "Landmark", sides=8)
    cyl("Tower_Band_2", tx, ty, t["radius_base"] * 0.8 + 1.2, 85, 89, "#6E3B2E", "Landmark", sides=8)
    bh = t["bottle_height"]
    cyl("Tower_Bottle_Body", tx, ty, t["radius_top"] * 1.25, t["height"], t["height"] + bh * 0.6, "#8FE3FF", "Landmark", sides=16, emission=0.6)
    cyl("Tower_Bottle_Neck", tx, ty, t["radius_top"] * 1.25, t["height"] + bh * 0.6, t["height"] + bh * 0.85, "#8FE3FF", "Landmark", sides=16, r_top=t["radius_top"] * 0.45, emission=0.6)
    cyl("Tower_Bottle_Cap", tx, ty, t["radius_top"] * 0.5, t["height"] + bh * 0.85, t["height"] + bh, "#E5263F", "Landmark", sides=16)

    # ---- buildings --------------------------------------------------------------------------
    for b in L.BUILDINGS:
        cx, cy = b["center"]
        w, d, h = b["size"]
        z = L.YARD_Z if cy < -190 or cx < -195 else L.VILLAGE_Z
        box(f"B_{b['id']}_Walls", cx, cy, z, w, d, h, b["facing"], b["wall"], "Buildings")
        roof(f"B_{b['id']}_Roof", cx, cy, z + h, w + 2, d + 2, max(5, d * 0.45), b["facing"], b["roof"], "Buildings")
        # glowing door / window strip on the front (local -Y) side
        a = math.radians(b["facing"])
        fx, fy = cx + math.sin(a) * (d / 2 + 0.3), cy - math.cos(a) * (d / 2 + 0.3)
        glow = box(f"B_{b['id']}_Glow", fx, fy, z + 1, min(10, w * 0.5), 0.6, min(8, h * 0.6), b["facing"], "#FFB347", "Buildings", emission=4.0 if b["id"] == "furnace" else 1.5)
        glow["front"] = True

    # ---- clash stands -----------------------------------------------------------------------
    def stand(sd):
        cx, cy = sd["center"]
        z = L.YARD_Z + (2 if sd["kind"] == "boss" else 0) if (cy < -190 or cx < -195) else L.VILLAGE_Z
        scale = {"arena": 1.0, "boss": 1.0, "pvp": 0.8, "small": 0.6, "trainer": 0.7}[sd["kind"]]
        span, height = 20 * scale, 16 * scale
        a = math.radians(sd["facing"])
        ux, uy = math.cos(a), math.sin(a)
        if sd["kind"] in ("arena", "boss"):
            cyl(f"S_{sd['id']}_Pen", cx, cy, 15, z, z + 0.6, "#C98B4E", "Stands", sides=8)
            for i in range(8):
                ang = i * math.tau / 8 + math.pi / 8
                wx, wy = cx + math.cos(ang) * 14, cy + math.sin(ang) * 14
                box(f"S_{sd['id']}_Wall{i}", wx, wy, z, 11.5, 0.6, 2.4, math.degrees(ang) + 90, "#B8763C", "Stands")
            if sd["kind"] == "arena":
                ring("Arena_Seats_Low", cx, cy, 20, 26, z, z + 1.2, "#D8CDB4", "Stands")
                ring("Arena_Seats_High", cx, cy, 26, 32, z, z + 2.4, "#CFC2A6", "Stands")
        for side in (-1, 1):
            lx, ly = cx + ux * side * span / 2, cy + uy * side * span / 2
            for leg in (-1, 1):
                box(f"S_{sd['id']}_Leg", lx + uy * leg * 2.5 * scale, ly - ux * leg * 2.5 * scale, z, 0.8, 0.8, height, sd["facing"], "#C98B4E", "Stands")
        box(f"S_{sd['id']}_Bar", cx, cy, z + height, span + 2, 1.1, 1.1, sd["facing"], "#D99A58", "Stands")

    for sd in L.STANDS:
        stand(sd)

    # ---- points of interest -------------------------------------------------------------------
    for p in L.POINTS:
        x, y = p["pos"]
        z = L.YARD_Z if (y < -190 or x < -195) and p["kind"] != "lift" else L.VILLAGE_Z
        kind = p["kind"]
        if kind == "spawn":
            cyl("POI_Spawn", x, y, 6, z, z + 1, "#FFE45C", "POI", sides=16, emission=1.0)
        elif kind == "pedestal":
            cyl("POI_Pedestal_Base", x, y, 9, z, z + 3, "#D8CDB4", "POI", sides=12)
            cyl("POI_Pedestal_Glassy", x, y, 3.5, z + 3, z + 14, "#C9A8FF", "POI", sides=12, emission=0.8)
        elif kind == "board":
            box("POI_BracketBoard", x, y, z + 14, 34, 1.5, 14, 0, "#1E2A6E", "POI", emission=0.4)
        elif kind == "board_small":
            for dx in (0, -14):
                box("POI_Leaderboard", x + dx, y, z + 3, 10, 1, 9, 0, "#1E2A6E", "POI", emission=0.3)
                box("POI_Leaderboard_Post", x + dx, y + 0.8, z, 1, 1, 12, 0, "#8C5A2B", "POI")
        elif kind in ("gate", "gate_locked"):
            color = "#2FCB3A" if kind == "gate" else "#9AA5B8"
            for side in (-1, 1):
                box(f"POI_{p['id']}_Pillar", x, y + side * 12, z, 4, 4, 18, 0, "#B5654A", "POI")
            box(f"POI_{p['id']}_Arch", x, y, z + 18, 4, 28, 4, 0, color, "POI", emission=0.5)
        elif kind == "lift":
            if p["id"] == "lift":
                box("POI_Lift_Shaft", x, y, L.YARD_Z, 10, 10, (L.VILLAGE_Z - L.YARD_Z) + 14, 0, "#4FA8FF", "POI", emission=0.3)
                box("POI_Lift_Bridge", x, (y + L.POINTS[-1]["pos"][1]) / 2, L.VILLAGE_Z, 8, abs(y - L.POINTS[-1]["pos"][1]), 1, 0, "#E9D7B0", "POI")

    # ---- market stalls and lamps ----------------------------------------------------------------
    for i, st in enumerate(L.STALLS):
        a = math.radians(st["angle"])
        x, y = math.cos(a) * L.STALL_RADIUS, math.sin(a) * L.STALL_RADIUS
        box(f"Stall_{i + 1}_Counter", x, y, L.VILLAGE_Z, 9, 6, 3.5, st["angle"] - 90, "#D9A066", "Decor")
        for dx in (-4, 4):
            box(f"Stall_{i + 1}_Post", x + math.cos(a + math.pi / 2) * dx, y + math.sin(a + math.pi / 2) * dx, L.VILLAGE_Z, 0.6, 0.6, 7, 0, "#8C5A2B", "Decor")
        roof(f"Stall_{i + 1}_Awning", x, y, L.VILLAGE_Z + 7, 10, 8, 2.5, st["angle"] - 90, st["roof"], "Decor")
    for i, (x, y) in enumerate(L.LAMPS):
        z = L.YARD_Z if x < -195 else L.VILLAGE_Z
        cyl(f"Lamp_{i + 1}_Post", x, y, 0.35, z, z + 9, "#4A4F6B", "Decor", sides=6)
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.1)
        bmesh.ops.translate(bm, verts=bm.verts, vec=(x, y, z + 9.6))
        obj_from_bm(f"Lamp_{i + 1}_Globe", bm, "#FFE2A8", "Decor", emission=3.0)

    # ---- harbour (sea level, below the NE cliff) -------------------------------------------
    hx, hy = L.HARBOR["center"]
    box("Harbor_Dock", hx, hy, L.SEA_Z, 12, L.HARBOR["dock_length"], 2, 30, "#A86A33", "Harbor")
    for i, (bx, by) in enumerate([(hx + 25, hy - 10), (hx + 30, hy + 25)]):
        box(f"Harbor_Boat_{i + 1}", bx, by, L.SEA_Z, 8, 20, 4, 30, "#F5F7FF", "Harbor")

    # ---- scatter: trees, cullet piles, bins, crates ----------------------------------------
    rng = random.Random(7)
    cullet_colors = ["#3FB86B", "#D98A2B", "#CFE8FF", "#4FA8FF"]
    for si, s in enumerate(L.SCATTER):
        cx, cy = s["center"]
        for i in range(s["count"]):
            ang, r = rng.uniform(0, math.tau), s["radius"] * math.sqrt(rng.random())
            x, y = cx + math.cos(ang) * r, cy + math.sin(ang) * r
            z = s["z"]
            kind = s["kind"]
            if not L.scatter_allowed(s, x, y):
                continue
            n = f"{kind}_{si}_{i}"
            if kind == "pine":
                cyl(f"Tree_{n}_Trunk", x, y, 1.2, z, z + 6, "#8C5A2B", "Scatter", sides=6)
                cyl(f"Tree_{n}_Top", x, y, rng.uniform(5, 7), z + 5, z + rng.uniform(20, 26), "#3FA874", "Scatter", sides=7, r_top=0.2)
            elif kind == "round":
                cyl(f"Tree_{n}_Trunk", x, y, 1.2, z, z + 7, "#8C5A2B", "Scatter", sides=6)
                bm = bmesh.new()
                bmesh.ops.create_icosphere(bm, subdivisions=1, radius=rng.uniform(6, 8))
                bmesh.ops.translate(bm, verts=bm.verts, vec=(x, y, z + 12))
                obj_from_bm(f"Tree_{n}_Crown", bm, "#62CF9C", "Scatter")
            elif kind == "cullet":
                cyl(f"Cullet_{n}", x, y, rng.uniform(11, 19), z, z + rng.uniform(16, 34), rng.choice(cullet_colors), "Scatter", sides=7, r_top=1.5, emission=0.15)
            elif kind == "bin":
                box(f"Bin_{n}", x, y, z, 4, 4, 5, rng.uniform(0, 90), rng.choice(["#3D7BF2", "#3FB86B", "#FFC93C"]), "Scatter")
            elif kind == "crate":
                box(f"Crate_{n}", x, y, z, 5, 5, rng.choice([4, 8]), rng.uniform(0, 90), "#D9A066", "Scatter")

    print(f"[Blockout] built {sum(len(s.objects) for s in subs.values())} objects in '{collection_name}'")
    return col


def render_previews(out_dir, samples=24):
    """Renders an aerial view and the first view from spawn (for docs)."""
    import bpy
    from mathutils import Vector

    scene = bpy.context.scene
    os.makedirs(out_dir, exist_ok=True)
    world = bpy.data.worlds.get("BO_World") or bpy.data.worlds.new("BO_World")
    try:
        world.use_nodes = True
    except Exception:
        pass
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.62, 0.78, 0.95, 1)
    bg.inputs["Strength"].default_value = 0.7
    scene.world = world

    sun_data = bpy.data.lights.get("BO_Sun") or bpy.data.lights.new("BO_Sun", "SUN")
    sun_data.energy = 3.2
    sun_data.color = (1.0, 0.86, 0.68)
    sun_data.angle = math.radians(3)
    sun = bpy.data.objects.get("BO_Sun") or bpy.data.objects.new("BO_Sun", sun_data)
    if sun.name not in scene.collection.objects:
        scene.collection.objects.link(sun)
    # golden afternoon from the west-south-west, low
    sun.rotation_euler = (math.radians(62), 0, math.radians(-115))

    cam_data = bpy.data.cameras.get("BO_Cam") or bpy.data.cameras.new("BO_Cam")
    cam = bpy.data.objects.get("BO_Cam") or bpy.data.objects.new("BO_Cam", cam_data)
    if cam.name not in scene.collection.objects:
        scene.collection.objects.link(cam)
    scene.camera = cam

    scene.render.engine = "CYCLES"
    scene.cycles.samples = samples
    try:
        scene.cycles.use_denoising = True
    except Exception:
        pass
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"

    shots = {
        "blockout_aerial.png": dict(loc=(330, -560, 330), target=(-60, -110, -10), lens=30, res=(1600, 1000)),
        "blockout_spawn_view.png": dict(loc=(0, -168, 7), target=(0, 60, 26), lens=20, res=(1600, 900)),
        "blockout_yard_view.png": dict(loc=(-150, -230, 40), target=(30, -330, -10), lens=24, res=(1600, 900)),
    }
    paths = []
    for name, shot in shots.items():
        cam.location = shot["loc"]
        direction = Vector(shot["target"]) - Vector(shot["loc"])
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        cam_data.lens = shot["lens"]
        cam_data.clip_end = 5000
        scene.render.resolution_x, scene.render.resolution_y = shot["res"]
        scene.render.filepath = os.path.join(out_dir, name)
        try:
            bpy.ops.render.render(write_still=True)
        except RuntimeError:
            scene.cycles.use_denoising = False
            bpy.ops.render.render(write_still=True)
        paths.append(scene.render.filepath)
    return paths


if __name__ == "__main__":
    build()
