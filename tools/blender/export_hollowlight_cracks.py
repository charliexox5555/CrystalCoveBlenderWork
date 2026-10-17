"""Project Hollowlight crack paths onto the approved v2 pumpkin body (art unchanged).

Run through Blender MCP after loading glassclash_blender.py (needs repo_path). Writes the
`hollowlight` entry of src/shared/Config/ReleaseCrackPaths.luau in Roblox hang-point space at the
standalone glassy's Heavy size (ReleaseGeometry radius). Re-running replaces only that entry.
"""
import re
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

TARGET_RADIUS = 0.9  # studs; keep in sync with ReleaseGeometry.hollowlight.Radius
LINES = [
    (.43, .12, .49, .32), (.49, .32, .39, .48), (.39, .48, .53, .69), (.53, .69, .46, .9),
    (.49, .32, .64, .25), (.39, .48, .25, .54),
    (.53, .69, .72, .61), (.64, .25, .71, .12), (.25, .54, .18, .74), (.49, .32, .59, .47),
    (.59, .47, .75, .51), (.46, .9, .29, .8),
    (.53, .69, .63, .84), (.39, .48, .28, .32), (.28, .32, .18, .27), (.59, .47, .66, .36),
    (.46, .9, .51, .98), (.72, .61, .81, .71),
]


def export_hollowlight_cracks():
    path = repo_path("assets", "blender", "seasonal", "hollowlight_v2", "hollowlight_v2.blend")
    with bpy.data.libraries.load(path, link=False) as (available, loaded):
        loaded.objects = [n for n in available.objects if n == "HH2_Pumpkin_Body"]
    body = loaded.objects[0]
    try:
        vertices = [body.matrix_world @ v.co for v in body.data.vertices]
        tree = BVHTree.FromPolygons(vertices, [list(p.vertices) for p in body.data.polygons])
        lo = Vector(tuple(min(v[i] for v in vertices) for i in range(3)))
        hi = Vector(tuple(max(v[i] for v in vertices) for i in range(3)))
        scale = TARGET_RADIUS / max(abs(lo.x), abs(hi.x))
        rows = []
        for side in (-1, 1):
            for index, (x1, y1, x2, y2) in enumerate(LINES):
                points = []
                for sample in range(5):
                    t = sample / 4
                    x = lo.x + (hi.x - lo.x) * (x1 + (x2 - x1) * t)
                    z = hi.z - (hi.z - lo.z) * (y1 + (y2 - y1) * t)
                    start = Vector((x, side * (max(abs(lo.y), abs(hi.y)) + 1), z))
                    hit, normal, _, _ = tree.ray_cast(start, Vector((0, -side, 0)))
                    points.append(None if hit is None else (hit + normal * .006) * scale)
                for a, b in zip(points, points[1:]):
                    if a is None or b is None:
                        continue
                    values = (a.x, a.z, -a.y, b.x, b.z, -b.y)
                    rows.append("\t\t{" + ", ".join(f"{v:.6f}" for v in values) + f", {index // 6 + 1}}},")
    finally:
        mesh = body.data
        bpy.data.objects.remove(body, do_unlink=True)
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    block = "\thollowlight = {\n" + "\n".join(rows) + "\n\t},\n"
    target = repo_path("src", "shared", "Config", "ReleaseCrackPaths.luau")
    with open(target, encoding="utf-8") as file:
        text = file.read()
    text = re.sub(r"\thollowlight = \{\n.*?\n\t\},\n", "", text, flags=re.S)
    text = text.replace("return {\n", "return {\n" + block, 1)
    with open(target, "w", encoding="utf-8", newline="\n") as file:
        file.write(text)
    return {"segments": len(rows), "scale": scale, "center": -(lo.z + hi.z) / 2 * scale}


result = export_hollowlight_cracks()
