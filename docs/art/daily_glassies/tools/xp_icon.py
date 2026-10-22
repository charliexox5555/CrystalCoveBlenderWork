"""XP reward icon (decision 115): a glossy gold glass star with "XP" on it, 512 px, transparent background.
    /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python docs/art/daily_glassies/tools/xp_icon.py
Writes assets/icons/reward/xp.png (uploaded as a Decal; the image id goes in Config/UIAssets "icon/xp")."""
import math
import os

import bmesh
import bpy
from mathutils import Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
OUT = os.path.join(REPO, "assets", "icons", "reward", "xp.png")

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)
scene = bpy.context.scene


def mat(name, rgb, rough=0.12, emit=0.0, coat=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*rgb, 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Coat Weight"].default_value = coat
    p.inputs["Emission Color"].default_value = (*rgb, 1)
    p.inputs["Emission Strength"].default_value = emit
    return m


# Star: 5 points, extruded and bevelled so it reads as chunky glass.
bm = bmesh.new()
pts = []
for i in range(10):
    r = 1.0 if i % 2 == 0 else 0.48
    a = math.pi / 2 + i * math.pi / 5
    pts.append(bm.verts.new((r * math.cos(a), 0, r * math.sin(a))))
bm.faces.new(pts)
ext = bmesh.ops.extrude_face_region(bm, geom=bm.faces[:])
bmesh.ops.translate(bm, vec=(0, 0.32, 0), verts=[v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)])
bmesh.ops.bevel(bm, geom=bm.edges[:], offset=0.09, segments=4, affect="EDGES", profile=0.6, clamp_overlap=True)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
me = bpy.data.meshes.new("Star")
bm.to_mesh(me)
for f in me.polygons:
    f.use_smooth = True
star = bpy.data.objects.new("Star", me)
scene.collection.objects.link(star)
star.location = (0, -0.16, 0)
star.data.materials.append(mat("Gold", (0.95, 0.42, 0.02), 0.08, 0.05))

# "XP" letters on the front face.
bpy.ops.object.text_add(location=(0, -0.2, -0.02))
txt = bpy.context.object
txt.data.body = "XP"
txt.data.align_x, txt.data.align_y = "CENTER", "CENTER"
txt.data.size = 0.62
txt.data.extrude = 0.05
txt.data.bevel_depth = 0.012
txt.rotation_euler = (math.radians(90), 0, 0)
txt.data.materials.append(mat("White", (1, 1, 1), 0.2, 0.25))
outline = txt.copy()
outline.data = txt.data.copy()
outline.data.offset = 0.035
outline.data.extrude = 0.03
outline.location.y += 0.02
outline.data.materials.clear()
outline.data.materials.append(mat("Navy", (0.04, 0.05, 0.18), 0.4, 0.0, 0.0))
scene.collection.objects.link(outline)

cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.type, cam.data.ortho_scale = "ORTHO", 2.35
cam.location, cam.rotation_euler = (0, -6, 0), (math.radians(90), 0, 0)
scene.collection.objects.link(cam)
scene.camera = cam
for name, loc, energy, size in (("Key", (-2.5, -4, 3), 600, 3), ("Rim", (3, 2, 2), 400, 3), ("Fill", (2, -4, -1), 200, 4)):
    light = bpy.data.objects.new(name, bpy.data.lights.new(name, "AREA"))
    light.data.energy, light.data.size = energy, size
    light.location = loc
    direction = Vector((0, 0, 0)) - Vector(loc)
    light.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(light)
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.7, 0.75, 0.85, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
scene.world = world
scene.render.engine = "CYCLES"
scene.cycles.samples = 64
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = 512
scene.view_settings.view_transform = "Standard"
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.filepath = OUT
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.render.render(write_still=True)
print("XP_ICON", OUT)
