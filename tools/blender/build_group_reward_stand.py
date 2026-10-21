"""Group reward stand (Glass Clash, decision 114): a small lobby kiosk for the group gift.

A dark Stained Glass plinth carrying a mini Marble Kiln (cream dome, terracotta arch, glowing marble-blue mouth,
copper chimney). The front of the pedestal holds a round aqua window with three gold figures (the group emblem: three
friends, original, no Roblox logo). A smooth glass heart floats above the kiln (the hero piece; it bobs in game), and
glass marbles rest on the base.

Low-poly flat-shaded world pieces, smooth glossy glass. 1 Blender unit = 1 stud, Z up, origin at the floor centre, the
front faces +Y in Blender (-Z in Roblox after export, the model's LookVector). Each colour is a separate mesh;
colours and materials are set in Studio (Blender materials are previews). Builds its own scene and exports
assets/blender/map/group_reward_stand/GroupRewardStand.fbx, the .blend and a preview render. Run inside Blender:

    exec(open(r"<repo>/tools/blender/glassclash_blender.py").read()); set_repo(r"<repo>")
    exec(open(r"<repo>/tools/blender/build_group_reward_stand.py").read())
"""
import math
import os

import bmesh
import bpy
from mathutils import Vector

REPO = globals().get("GLASSCLASH_REPO") or os.path.abspath(".")
OUT = os.path.join(REPO, "assets", "blender", "map", "group_reward_stand")
SCENE = "GroupRewardStand"
# Preview colours (Studio colours are listed in the README next to the export).
PREVIEW = {
    "Lead": "#2A2140", "Gold": "#F4B73A", "Milk": "#F0E6D8", "Brick": "#C8734F", "Copper": "#B8693D",
    "Glow": "#93BCFF", "Aqua": "#2FC4D6", "Amethyst": "#8C4FE0",
}
GLASS = {"Heart": "#FF5C8A", "MarbleBlue": "#6FA8FF", "MarbleAqua": "#5FE0D0", "MarblePink": "#FF8FC8"}


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple((int(h[i:i + 2], 16) / 255) ** 2.2 for i in (0, 2, 4))


def scene():
    sc = bpy.data.scenes.get(SCENE) or bpy.data.scenes.new(SCENE)
    for o in list(sc.collection.all_objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.window.scene = sc
    sc.unit_settings.system = "NONE"
    return sc


def flat_material(name):
    m = bpy.data.materials.get("GRS_" + name) or bpy.data.materials.new("GRS_" + name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    rgb = hex_rgb(PREVIEW[name])
    m.diffuse_color = (*rgb, 1.0)
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.65 if name not in ("Gold", "Copper") else 0.35
    bsdf.inputs["Metallic"].default_value = 0.6 if name in ("Gold", "Copper") else 0.0
    if name == "Glow":
        bsdf.inputs["Emission Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 1.2
    return m


def glass_material(name):
    m = bpy.data.materials.get("GRS_" + name) or bpy.data.materials.new("GRS_" + name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    rgb = hex_rgb(GLASS[name])
    m.diffuse_color = (*rgb, 1.0)
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.04
    bsdf.inputs["Transmission Weight"].default_value = 0.65
    bsdf.inputs["IOR"].default_value = 1.45
    bsdf.inputs["Coat Weight"].default_value = 1.0
    bsdf.inputs["Emission Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Emission Strength"].default_value = 0.25
    return m


class Mesh:
    """Collects geometry for one coloured mesh, then links it as one object (flat or smooth)."""

    def __init__(self, name, colour, glass=False):
        self.name, self.colour, self.glass, self.bm = name, colour, glass, bmesh.new()

    def ring(self, sides, radius, z, rot, cx=0.0, cy=0.0, sy=1.0):
        return [self.bm.verts.new((cx + math.cos(rot + i * 2 * math.pi / sides) * radius,
                                   cy + math.sin(rot + i * 2 * math.pi / sides) * radius * sy, z))
                for i in range(sides)]

    def lathe(self, sides, profile, rot=0.0, cx=0.0, cy=0.0, cap_bottom=True, cap_top=True):
        """profile = [(radius, z), ...] bottom to top; radius 0 makes a point."""
        rings = []
        for r, z in profile:
            rings.append(self.ring(sides, max(r, 1e-4), z, rot, cx, cy))
        if cap_bottom:
            self.bm.faces.new(list(reversed(rings[0])))
        if cap_top:
            self.bm.faces.new(rings[-1])
        for a, b in zip(rings, rings[1:]):
            for i in range(sides):
                j = (i + 1) % sides
                self.bm.faces.new((a[i], a[j], b[j], b[i]))

    def prism(self, sides, radius, z0, z1, rot=0.0, cx=0.0, cy=0.0, top=None):
        self.lathe(sides, [(radius, z0), (radius if top is None else top, z1)], rot, cx, cy)

    def box(self, cx, cy, cz, sx, sy, sz):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co = Vector((cx + v.co.x * sx, cy + v.co.y * sy, cz + v.co.z * sz))
        self.merge(bm)

    def slab(self, points, y0, y1):
        """A flat piece from an XZ outline, between y0 and y1 (a panel facing +Y)."""
        front = [self.bm.verts.new((x, y1, z)) for x, z in points]
        back = [self.bm.verts.new((x, y0, z)) for x, z in points]
        self.bm.faces.new(front)
        self.bm.faces.new(list(reversed(back)))
        n = len(points)
        for i in range(n):
            j = (i + 1) % n
            self.bm.faces.new((front[j], front[i], back[i], back[j]))

    def sphere(self, cx, cy, cz, r, subdiv=2):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r)
        for v in bm.verts:
            v.co += Vector((cx, cy, cz))
        self.merge(bm)

    def merge(self, other):
        data = bpy.data.meshes.new("tmp")
        other.to_mesh(data)
        other.free()
        self.bm.from_mesh(data)
        bpy.data.meshes.remove(data)

    def link(self, collection):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        data = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(data)
        self.bm.free()
        for p in data.polygons:
            p.use_smooth = self.glass
        data.materials.append(glass_material(self.colour) if self.glass else flat_material(self.colour))
        obj = bpy.data.objects.new(self.name, data)
        collection.objects.link(obj)
        return obj


def arch(width, z0, spring, steps=6):
    """Round-topped arch outline in XZ (x centred), from the sill z0, semicircle starting at `spring`."""
    half = width / 2
    pts = [(-half, z0), (half, z0)]
    for i in range(steps + 1):
        a = i * math.pi / steps
        pts.append((math.cos(a) * half, spring + math.sin(a) * half))
    # outline order: bottom-left, bottom-right, then the arc right -> left
    return [pts[0], pts[1]] + pts[2:]


def heart_outline(n=28, size=1.0):
    pts = []
    for i in range(n):
        t = i * 2 * math.pi / n
        x = 16 * math.sin(t) ** 3
        z = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x / 17 * size, (z + 2.5) / 17 * size))
    return pts


def build_heart(collection, cz, depth=0.42, rings=5):
    """Puffy smooth glass heart (origin at its centre, so it can bob and spin in game): the outline is inflated like
    a pillow, rings shrinking toward the middle while they bulge out front and back."""
    outline = heart_outline(28, 0.95)
    cx = sum(x for x, _ in outline) / len(outline)
    cz0 = sum(z for _, z in outline) / len(outline)
    m = Mesh("GlassHeart", "Heart", glass=True)
    bm = m.bm
    edge = [bm.verts.new((x, 0.0, z)) for x, z in outline]
    sides = {}
    for sign in (1, -1):
        prev = edge
        for k in range(1, rings + 1):
            t = k / rings * math.pi / 2
            s_, y = math.cos(t) * 0.97 + 0.03, math.sin(t) * depth * sign
            ring = [bm.verts.new((cx + (x - cx) * s_, y, cz0 + (z - cz0) * s_)) for x, z in outline]
            n = len(outline)
            for i in range(n):
                j = (i + 1) % n
                quad = (prev[i], prev[j], ring[j], ring[i])
                bm.faces.new(quad if sign > 0 else tuple(reversed(quad)))
            prev = ring
        tip = bm.verts.new((cx, depth * sign * 1.02, cz0))
        n = len(outline)
        for i in range(n):
            j = (i + 1) % n
            tri = (prev[i], prev[j], tip)
            bm.faces.new(tri if sign > 0 else tuple(reversed(tri)))
    obj = m.link(collection)
    for p in obj.data.polygons:
        p.use_smooth = True
    obj.location.z = cz
    return obj


def build(sc):
    col = bpy.data.collections.new("GroupRewardStand")
    sc.collection.children.link(col)
    lead, gold, milk = Mesh("Stand_Lead", "Lead"), Mesh("Stand_Gold", "Gold"), Mesh("Stand_Milk", "Milk")
    brick, copper, glow = Mesh("Stand_Brick", "Brick"), Mesh("Stand_Copper", "Copper"), Mesh("Stand_Glow", "Glow")
    aqua, amethyst = Mesh("Stand_Aqua", "Aqua"), Mesh("Stand_Amethyst", "Amethyst")
    oct_rot = math.pi / 8  # a flat octagon face points at +Y (the front)

    # Plinth: two octagon steps with a gold band.
    lead.prism(8, 3.1, 0.0, 0.45, oct_rot, top=3.0)
    gold.prism(8, 2.95, 0.45, 0.62, oct_rot)
    lead.prism(8, 2.6, 0.62, 0.95, oct_rot, top=2.5)

    # Pedestal: a chamfered octagon column with amethyst glass panes on the sides and back, aqua window in front.
    lead.prism(8, 1.75, 0.95, 3.35, oct_rot, top=1.65)
    face = 1.75 * math.cos(math.pi / 8)
    for k in range(1, 8):  # side/back panes (k = 0 is the front, it holds the emblem)
        a = math.pi / 2 + k * math.pi / 4
        p = Mesh("pane", "Amethyst")
        p.slab([(-0.42, 1.25), (0.42, 1.25), (0.42, 2.85), (0.0, 3.1), (-0.42, 2.85)], -0.02, 0.06)
        for v in p.bm.verts:
            v.co.y += face
            x, y = v.co.x, v.co.y
            ang = a - math.pi / 2
            v.co.x, v.co.y = x * math.cos(ang) - y * math.sin(ang), x * math.sin(ang) + y * math.cos(ang)
        amethyst.merge(p.bm)
    gold.prism(8, 1.95, 3.35, 3.6, oct_rot, top=2.0)  # cap slab

    # Emblem: a round aqua window with a gold rim on the front, three gold friends standing together.
    ey, ez = face + 0.02, 2.15
    rim = Mesh("rim", "Gold")
    rim.lathe(12, [(0.92, 0), (0.92, 0.1)], 0, 0, 0)
    for v in rim.bm.verts:
        v.co = Vector((v.co.x, ey + v.co.z, ez + v.co.y))
    gold.merge(rim.bm)
    disc = Mesh("disc", "Aqua")
    disc.lathe(12, [(0.8, 0), (0.8, 0.14)], 0, 0, 0)
    for v in disc.bm.verts:
        v.co = Vector((v.co.x, ey + v.co.z, ez + v.co.y))
    aqua.merge(disc.bm)
    fy0, fy1 = ey + 0.14, ey + 0.22
    for fx, s in ((-0.4, 0.78), (0.4, 0.78), (0.0, 1.0)):
        head = [(fx + math.cos(i * math.pi / 4) * 0.15 * s, ez + 0.12 * s + math.sin(i * math.pi / 4) * 0.15 * s)
                for i in range(8)]
        body = [(fx - 0.26 * s, ez - 0.42 * s), (fx + 0.26 * s, ez - 0.42 * s), (fx + 0.22 * s, ez - 0.16 * s),
                (fx + 0.1 * s, ez - 0.06 * s), (fx - 0.1 * s, ez - 0.06 * s), (fx - 0.22 * s, ez - 0.16 * s)]
        lift = 0.03 if s == 1.0 else 0.0  # the middle friend sits in front of the other two
        gold.slab(head, fy0, fy1 + lift)
        gold.slab(body, fy0, fy1 + lift)

    # Mini Marble Kiln on the cap: cream dome, terracotta arch, glowing marble-blue mouth, copper chimney.
    kz = 3.6
    milk.lathe(8, [(1.45, kz), (1.45, kz + 1.05), (1.32, kz + 1.6), (0.98, kz + 2.05), (0.5, kz + 2.32),
                   (0.0, kz + 2.4)], oct_rot)
    kface = 1.45 * math.cos(math.pi / 8)
    brick.slab(arch(1.3, kz, kz + 0.75, 6), kface - 0.05, kface + 0.12)
    glow.slab(arch(0.86, kz + 0.04, kz + 0.75, 6), kface + 0.06, kface + 0.16)
    copper.prism(6, 0.24, kz + 1.6, kz + 2.85, 0, 0.35, -0.55)
    copper.prism(6, 0.33, kz + 2.85, kz + 3.05, 0, 0.35, -0.55)

    objs = [m.link(col) for m in (lead, gold, milk, brick, copper, glow, aqua, amethyst)]

    # Glass marbles resting on the lower step, front-left / front-right / back.
    for name, colour, (x, y), r in (("Marble_Blue", "MarbleBlue", (-2.1, 1.35), 0.38),
                                    ("Marble_Aqua", "MarbleAqua", (2.05, 1.45), 0.34),
                                    ("Marble_Pink", "MarblePink", (1.6, -1.95), 0.3)):
        m = Mesh(name, colour, glass=True)
        m.sphere(x, y, 0.62 + r, r, 2)
        objs.append(m.link(col))

    objs.append(build_heart(col, kz + 3.05 + 1.25))
    return objs


def preview(sc, objs, path):
    cam_data = bpy.data.cameras.new("GRS_Cam")
    cam = bpy.data.objects.new("GRS_Cam", cam_data)
    sc.collection.objects.link(cam)
    cam.location = (6.5, 14.5, 5.6)
    direction = Vector((0, 0, 4.0)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    cam_data.lens = 50
    sc.camera = cam
    for name, loc, energy, size in (("GRS_Key", (6, 8, 12), 900, 6), ("GRS_Rim", (-6, -6, 9), 500, 5),
                                    ("GRS_Fill", (-8, 8, 4), 200, 6)):
        light = bpy.data.objects.new(name, bpy.data.lights.new(name, "AREA"))
        light.data.energy, light.data.size = energy, size
        light.location = loc
        light.rotation_euler = (Vector((0, 0, 3)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        sc.collection.objects.link(light)
    world = bpy.data.worlds.get("GRS_World") or bpy.data.worlds.new("GRS_World")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.55, 0.72, 0.95, 1)
    bg.inputs["Strength"].default_value = 0.6
    sc.world = world
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 64
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 900, 1100
    sc.render.film_transparent = False
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True, scene=sc.name)


def tris(objs):
    total = {}
    for o in objs:
        total[o.name] = sum(len(p.vertices) - 2 for p in o.data.polygons)
    return total


sc = scene()
objects = build(sc)
os.makedirs(OUT, exist_ok=True)
result = {"tris": tris(objects), "total": sum(tris(objects).values())}
