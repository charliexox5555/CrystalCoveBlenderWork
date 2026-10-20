"""Lobby leaderboards v3 (decision 101): three stained-glass window boards. Run through the Blender MCP:

    import os; os.environ["GLASSCLASH_REPO"] = "<repo>"
    ns = {}; exec(open("<repo>/tools/blender/build_leaderboards_v3.py").read(), ns); ns["build_all"]()

Each board gets its own scene (LB3_<Id>), never touching other scenes. Output per board in
assets/blender/map/leaderboards_v3/: <Id>.fbx (all meshes), <Id>.blend (isolated source, editable later),
<Id>_preview.png, plus manifest.json (mesh centres/sizes/colours/materials and the Screen/Title rectangles that the
Studio installer turns into SurfaceGui parts). Blender front = -Y; 1 unit = 1 stud; Blender (x, y, z) -> Roblox
(x, z, -y) before the installer's yaw.

Look: low-poly stone towers with glass spires, a dark lead pointed-arch frame ringed with coloured glass panes, a
rose window in the arch holding the board's emblem (crown / hourglass / gem), a ribbon banner for the title and a dark
screen for the rows. Colours are Studio colours (Stained Glass UI kit palette + lobby stone/copper).
"""
import bpy
import bmesh
import json
import math
import os
from pathlib import Path

ROOT = Path(os.environ.get("GLASSCLASH_REPO", "/Users/charleslamont/Documents/CrystalCoveBlenderWork"))
OUT = ROOT / "assets/blender/map/leaderboards_v3"

COLORS = {
    "Stone": "C8BC9C", "StoneDark": "A99D80", "Copper": "B87E50", "Lead": "1F1830", "Smoke": "261D3B",
    "Screen": "1B1528", "Ruby": "E23A55", "Amber": "F5A524", "Emerald": "22B573", "Sapphire": "2E6BE6",
    "Amethyst": "8B4FE0", "Aqua": "1FC2D3", "Milk": "EEE7D9", "Gold": "F2C14E",
}
GLASS = {"Ruby", "Amber", "Emerald", "Sapphire", "Amethyst", "Aqua", "Milk"}
CYCLE = ["Ruby", "Amber", "Emerald", "Sapphire", "Amethyst", "Aqua"]

BOARDS = [
    {"Id": "WeeklySpend", "Accent": "Aqua", "Emblem": "hourglass", "Scale": 1.0},
    {"Id": "Wins", "Accent": "Amber", "Emblem": "crown", "Scale": 1.1},
    {"Id": "AllTimeSpend", "Accent": "Amethyst", "Emblem": "gem", "Scale": 1.0},
]

# Layout (studs, before Scale).
HALF = 6.1          # frame centreline half-width
BOTTOM = 2.15       # frame bottom centreline
SPRING = 13.0       # where the arch starts
RISE = 5.2          # arch height above SPRING
FRAME_W, FRAME_D = 0.6, 0.9
TOWER_X, TOWER_R, TOWER_TOP = 7.9, 0.95, 14.2
ROSE_Z, ROSE_R = 15.15, 1.85
SCREEN = {"Center": (0, -0.42, 7.15), "Size": (11.0, 0.1, 8.9)}      # rows (SurfaceGui "Display")
TITLE = {"Center": (0, -0.95, 12.45), "Size": (9.0, 0.1, 1.25)}      # banner text (SurfaceGui "Header")

_MATS = {}


def _mat(key):
    if key not in _MATS:
        m = bpy.data.materials.get("LB3_" + key) or bpy.data.materials.new("LB3_" + key)
        m.use_nodes = True
        rgb = [int(COLORS[key][i:i + 2], 16) / 255 for i in (0, 2, 4)]
        lin = tuple(c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in rgb) + (1,)
        m.diffuse_color = lin
        p = m.node_tree.nodes.get("Principled BSDF")
        p.inputs["Base Color"].default_value = lin
        p.inputs["Roughness"].default_value = .25 if key in GLASS else .8
        _MATS[key] = m
    return _MATS[key]


class Board:
    """Collects geometry per colour key, then makes one mesh object per (part name, colour)."""

    def __init__(self, spec):
        self.spec, self.s = spec, spec["Scale"]
        self.parts = {}   # name -> {"key":..., "verts":[], "faces":[]}

    def add(self, name, key, verts, faces):
        part = self.parts.setdefault(name, {"key": key, "verts": [], "faces": []})
        base = len(part["verts"])
        part["verts"] += verts
        part["faces"] += [tuple(i + base for i in f) for f in faces]

    # --- primitives --------------------------------------------------------------------------------------------
    def box(self, name, key, size, loc):
        sx, sy, sz = (v / 2 for v in size)
        x, y, z = loc
        v = [(x + dx * sx, y + dy * sy, z + dz * sz) for dz in (-1, 1) for dy in (-1, 1) for dx in (-1, 1)]
        f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        self.add(name, key, v, f)

    def prism(self, name, key, poly, y0, y1):
        """Extrude a convex-or-not 2D polygon [(x, z)] between y0 (front) and y1 (back)."""
        n = len(poly)
        v = [(x, y0, z) for x, z in poly] + [(x, y1, z) for x, z in poly]
        f = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
        f += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
        self.add(name, key, v, f)

    def column(self, name, key, r0, r1, z0, z1, x=0, y=0, sides=6, rot=0):
        v = []
        for z, r in ((z0, r0), (z1, r1)):
            for i in range(sides):
                a = rot + i * math.tau / sides
                v.append((x + r * math.cos(a), y + r * math.sin(a), z))
        f = [tuple(range(sides - 1, -1, -1)), tuple(range(sides, 2 * sides))]
        f += [(i, (i + 1) % sides, sides + (i + 1) % sides, sides + i) for i in range(sides)]
        self.add(name, key, v, f)

    def band(self, name, key, pts, width, y0, y1, closed):
        """A flat band of `width` following polyline `pts` [(x, z)], mitred at the joints."""
        n = len(pts)

        def normal(a, b):
            dx, dz = b[0] - a[0], b[1] - a[1]
            length = math.hypot(dx, dz) or 1
            return -dz / length, dx / length

        normals = []
        for i in range(n):
            prev = normal(pts[i - 1], pts[i]) if (closed or i > 0) else None
            nxt = normal(pts[i], pts[(i + 1) % n]) if (closed or i < n - 1) else None
            if prev and nxt:
                mx, mz = prev[0] + nxt[0], prev[1] + nxt[1]
                ml = math.hypot(mx, mz) or 1
                mx, mz = mx / ml, mz / ml
                cos = max(.35, mx * prev[0] + mz * prev[1])
                normals.append((mx / cos, mz / cos))
            else:
                normals.append(prev or nxt)
        h = width / 2
        v = []
        for (x, z), (nx, nz) in zip(pts, normals):
            for y in (y0, y1):
                v += [(x - nx * h, y, z - nz * h), (x + nx * h, y, z + nz * h)]
        f = []
        for i in range(n if closed else n - 1):
            a, b = 4 * i, 4 * ((i + 1) % n)
            f += [(a, a + 1, b + 1, b), (a + 2, b + 2, b + 3, a + 3), (a + 1, a + 3, b + 3, b + 1), (a, b, b + 2, a + 2)]
        if not closed:
            e = 4 * (n - 1)
            f += [(0, 2, 3, 1), (e, e + 1, e + 3, e + 2)]
        self.add(name, key, v, f)

    # --- outline -----------------------------------------------------------------------------------------------
    def outline(self, half, bottom, spring, rise, steps=10):
        """Pointed-arch loop (clockwise from bottom-left) for a frame of centreline half-width `half`."""
        c = (rise * rise - half * half) / (2 * half)   # centre offset of each arc (negative = toward its side)
        r = half + c
        left = []
        a0, a1 = math.atan2(0, -half - c), math.atan2(rise, -c)
        for i in range(steps + 1):
            a = a0 + (a1 - a0) * i / steps
            left.append((c + r * math.cos(a), spring + r * math.sin(a)))
        right = [(-x, z) for x, z in reversed(left)]
        return [(-half, bottom)] + left + right[1:] + [(half, bottom)]

    # --- the board ---------------------------------------------------------------------------------------------
    def build(self):
        acc = self.spec["Accent"]
        # Plinth and towers.
        self.box("Plinth", "Stone", (17.4, 3.3, .8), (0, .1, .4))
        self.box("PlinthTrim", "Copper", (16.6, 2.7, .34), (0, 0, .97))
        for x in (-TOWER_X, TOWER_X):
            self.column("Towers", "Stone", TOWER_R, TOWER_R * .92, 1.1, TOWER_TOP, x=x, sides=6, rot=math.pi / 6)
            for z in (1.15, 7.6):
                self.column("TowerBands", "Copper", TOWER_R + .16, TOWER_R + .16, z, z + .38, x=x, sides=6, rot=math.pi / 6)
            self.column("TowerBands", "Copper", TOWER_R + .22, TOWER_R + .05, TOWER_TOP - .1, TOWER_TOP + .35, x=x, sides=6, rot=math.pi / 6)
            self.column("Spires", acc, TOWER_R * .95, .06, TOWER_TOP + .35, TOWER_TOP + 2.9, x=x, sides=6, rot=math.pi / 6)
        # Backing behind the whole window (dark smoke), then the lead frame with coloured panes around it.
        loop = self.outline(HALF, BOTTOM, SPRING, RISE)
        self.prism("Backing", "Smoke", self.outline(HALF - .05, BOTTOM, SPRING, RISE, 14), .05, .55)
        self.band("Frame", "Lead", loop, FRAME_W, -.45, .45, True)
        outer = self.outline(HALF + .62, BOTTOM - .62, SPRING, RISE + .62, 16)
        self.band("FrameOuter", "Lead", outer, .78, -.3, .35, True)
        self.panes(outer)
        # Arch top: rose window with the emblem.
        self.rose(acc)
        self.emblem()
        # Banner for the title and the screen for the rows.
        self.banner(acc)
        cx, cy, cz = SCREEN["Center"]
        sx, _, sz = SCREEN["Size"]
        self.box("ScreenFrame", "Copper", (sx + .5, .22, sz + .5), (0, -.18, cz))
        self.box("Screen", "Screen", (sx, .12, sz), (0, cy + .08, cz))
        # Apex finial.
        apex = SPRING + RISE + .62
        self.column("Finial", acc, .5, .05, apex + .25, apex + 1.4, sides=4)
        self.column("Finial", acc, .05, .5, apex - .2, apex + .25, sides=4)

    def panes(self, outer):
        """Coloured glass tiles along the outer band (lead gaps between them)."""
        dense = []
        for a, b in zip(outer, outer[1:] + [outer[0]]):
            steps = max(1, int(math.hypot(b[0] - a[0], b[1] - a[1]) / .1))
            for i in range(steps):
                t = i / steps
                dense.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
        total = 0
        lengths = [0]
        for a, b in zip(dense, dense[1:] + [dense[0]]):
            total += math.hypot(b[0] - a[0], b[1] - a[1])
            lengths.append(total)
        tile, gap = 1.25, .14
        count = int(total // (tile + gap))
        step = total / count
        for k in range(count):
            s0, s1 = k * step + gap / 2, (k + 1) * step - gap / 2
            pts = [dense[i] for i in range(len(dense)) if s0 <= lengths[i] <= s1]
            if len(pts) >= 2:
                self.band("Panes_" + CYCLE[k % len(CYCLE)], CYCLE[k % len(CYCLE)], pts, .56, -.42, -.28, False)

    def rose(self, acc):
        ring = [(ROSE_R * math.cos(i * math.tau / 24), ROSE_Z + ROSE_R * math.sin(i * math.tau / 24)) for i in range(24)]
        self.band("RoseRing", "Lead", ring, .3, -.5, .1, True)
        petals = 8
        for i in range(petals):
            a0, a1 = (i + .08) * math.tau / petals, (i + .92) * math.tau / petals
            poly = [(.75 * math.cos(a0), ROSE_Z + .75 * math.sin(a0))]
            for j in range(5):
                a = a0 + (a1 - a0) * j / 4
                poly.append(((ROSE_R - .2) * math.cos(a), ROSE_Z + (ROSE_R - .2) * math.sin(a)))
            poly.append((.75 * math.cos(a1), ROSE_Z + .75 * math.sin(a1)))
            key = CYCLE[(i + 2) % len(CYCLE)]
            self.prism("Rose_" + key, key, poly, -.36, -.22)
        hub = [(.78 * math.cos(i * math.tau / 12), ROSE_Z + .78 * math.sin(i * math.tau / 12)) for i in range(12)]
        self.prism("RoseHub", "Lead", hub[::-1], -.5, -.2)

    def emblem(self):
        """Built at unit size, then scaled 1.7x about the rose centre so it reads from the plaza."""
        before = {k: len(v["verts"]) for k, v in self.parts.items()}
        self._emblem()
        k, cz, cy = 1.7, ROSE_Z, -.75
        for name, part in self.parts.items():
            for i in range(before.get(name, 0), len(part["verts"])):
                x, y, z = part["verts"][i]
                part["verts"][i] = (x * k, cy + (y - cy) * k, cz + (z - cz) * k)

    def _emblem(self):
        kind, acc, z, y = self.spec["Emblem"], self.spec["Accent"], ROSE_Z, -.75
        if kind == "crown":
            self.column("Emblem", "Gold", .62, .62, z - .55, z - .1, y=y, sides=8)
            for i, x in enumerate((-.5, -.25, 0, .25, .5)):
                h = .55 if i in (1, 3) else .85
                self.column("Emblem", "Gold", .17, .02, z - .12, z - .12 + h, x=x, y=y - .5, sides=4, rot=math.pi / 4)
            self.column("EmblemGem", "Ruby", .17, .17, z - .45, z - .2, y=y - .62, sides=6)
        elif kind == "hourglass":
            self.column("EmblemFrame", "Copper", .55, .55, z - .8, z - .65, y=y, sides=6)
            self.column("EmblemFrame", "Copper", .55, .55, z + .65, z + .8, y=y, sides=6)
            for x in (-.42, .42):
                self.box("EmblemFrame", "Copper", (.09, .09, 1.45), (x, y - .2, z))
            self.column("Emblem", acc, .4, .05, z - .65, z, y=y, sides=6)
            self.column("Emblem", acc, .05, .4, z, z + .65, y=y, sides=6)
            self.column("EmblemSand", "Amber", .26, .03, z - .65, z - .3, y=y, sides=6)
        else:  # gem
            self.column("Emblem", acc, .72, .45, z - .05, z + .32, y=y, sides=8, rot=math.pi / 8)
            self.column("Emblem", acc, .72, .04, z - .05, z - 1.0, y=y, sides=8, rot=math.pi / 8)
            self.column("EmblemShine", "Milk", .18, .05, z + .32, z + .36, x=-.15, y=y - .1, sides=4)

    def banner(self, acc):
        cx, _, cz = TITLE["Center"]
        w, _, h = TITLE["Size"]
        hw, hh = w / 2 + .35, h / 2 + .18
        # Ribbon with notched tails, accent glass face over a lead backing.
        back = [(-hw - .9, cz + hh - .15), (-hw - .45, cz), (-hw - .9, cz - hh + .15), (-hw + .2, cz - hh + .15),
                (-hw + .2, cz - hh), (hw - .2, cz - hh), (hw - .2, cz - hh + .15), (hw + .9, cz - hh + .15),
                (hw + .45, cz), (hw + .9, cz + hh - .15), (hw - .2, cz + hh - .15), (hw - .2, cz + hh),
                (-hw + .2, cz + hh), (-hw + .2, cz + hh - .15)]
        self.prism("BannerBack", "Lead", back[::-1], -.85, -.5)
        self.box("Banner", acc, (w + .5, .12, h + .16), (0, -.88, cz))

    # --- output ------------------------------------------------------------------------------------------------
    def objects(self, scene):
        made = []
        s = self.s
        for name, part in self.parts.items():
            full = "LB3_%s_%s" % (self.spec["Id"], name)
            mesh = bpy.data.meshes.new(full)
            mesh.from_pydata([(x * s, y * s, z * s) for x, y, z in part["verts"]], [], part["faces"])
            mesh.update()
            bm = bmesh.new()
            bm.from_mesh(mesh)
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            bm.to_mesh(mesh)
            bm.free()
            for p in mesh.polygons:
                p.use_smooth = False
            o = bpy.data.objects.new(full, mesh)
            scene.collection.objects.link(o)
            mesh.materials.append(_mat(part["key"]))
            key = part["key"]
            o["StudioColor"] = COLORS[key]
            # Panes, spires and banners are see-through glass; emblems stay solid so they read from the plaza.
            glass = key in GLASS and not name.startswith("Emblem")
            o["StudioMaterial"] = "Glass" if glass else "SmoothPlastic"
            o["StudioTransparency"] = .12 if glass else 0
            made.append(o)
        return made


def _bounds(o):
    pts = [o.matrix_world @ v.co for v in o.data.vertices]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    return [(lo[i] + hi[i]) / 2 for i in range(3)], [hi[i] - lo[i] for i in range(3)]


def _preview(scene, objects, path):
    cam_data = bpy.data.cameras.new(scene.name + "_cam")
    cam = bpy.data.objects.new(scene.name + "_cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (9, -30, 12)
    direction = (0 - cam.location[0], 0 - cam.location[1], 10 - cam.location[2])
    from mathutils import Vector
    cam.rotation_euler = Vector(direction).to_track_quat("-Z", "Y").to_euler()
    cam_data.lens = 45
    scene.camera = cam
    sun_data = bpy.data.lights.new(scene.name + "_sun", "SUN")
    sun_data.energy = 3.5
    sun = bpy.data.objects.new(scene.name + "_sun", sun_data)
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-30))
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.new(scene.name + "_world")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (.62, .72, .86, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = .9
    scene.world = world
    scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items} else "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x, scene.render.resolution_y = 900, 1000
    scene.render.filepath = str(path)
    scene.render.film_transparent = False
    return [cam, sun]


def build_all(render=True):
    OUT.mkdir(parents=True, exist_ok=True)
    helper = {}
    exec(compile((ROOT / "tools/blender/glassclash_blender.py").read_text(), "glassclash_blender.py", "exec"), helper)
    previous = bpy.context.window.scene
    manifest = {"Units": "1 Blender unit = 1 stud", "Coordinates": "Blender (x,y,z) -> Roblox (x,z,-y); front = -Y",
                "Boards": {}}
    try:
        for spec in BOARDS:
            name = "LB3_" + spec["Id"]
            old = bpy.data.scenes.get(name)
            if old:
                for o in list(old.objects):
                    bpy.data.objects.remove(o, do_unlink=True)
                bpy.data.scenes.remove(old)
            scene = bpy.data.scenes.new(name)
            scene.unit_settings.system = "NONE"
            bpy.context.window.scene = scene
            board = Board(spec)
            board.build()
            objects = board.objects(scene)
            bpy.context.view_layer.update()
            fbx = OUT / (spec["Id"] + ".fbx")
            helper["export_fbx"](objects, str(fbx))
            bpy.data.libraries.write(str(OUT / (spec["Id"] + ".blend")), {scene}, fake_user=True, compress=True)
            rows = []
            tris = 0
            for o in objects:
                o.data.calc_loop_triangles()
                tris += len(o.data.loop_triangles)
                c, sz = _bounds(o)
                rows.append({"Name": o.name, "Center": c, "Size": sz, "Color": o["StudioColor"],
                             "Material": o["StudioMaterial"], "Transparency": o["StudioTransparency"]})
            s = spec["Scale"]
            manifest["Boards"][spec["Id"]] = {
                "Accent": COLORS[spec["Accent"]], "Scale": s, "Triangles": tris, "Meshes": rows,
                "Screen": {"Center": [v * s for v in SCREEN["Center"]], "Size": [v * s for v in SCREEN["Size"]]},
                "Title": {"Center": [v * s for v in TITLE["Center"]], "Size": [v * s for v in TITLE["Size"]]},
                "FBX": fbx.name, "Source": spec["Id"] + ".blend",
            }
            if render:
                extra = _preview(scene, objects, OUT / (spec["Id"] + "_preview.png"))
                bpy.ops.render.render(write_still=True)
                for o in extra:
                    bpy.data.objects.remove(o, do_unlink=True)
        (OUT / "manifest.json").write_text(json.dumps(manifest, indent=1) + "\n")
        return {k: {"Triangles": v["Triangles"], "Meshes": len(v["Meshes"])} for k, v in manifest["Boards"].items()}
    finally:
        bpy.context.window.scene = previous
