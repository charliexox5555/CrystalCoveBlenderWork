"""Roster V2 launch glassies (workstream F). Headless Blender only (the revamp session owns the MCP window):

    B=/Applications/Blender.app/Contents/MacOS/Blender
    T=docs/art/launch_glassies/tools/build_launch.py
    $B -b --factory-startup --python $T -- preview cookie_jar [--samples 16] [--out DIR]   # quick look, exports nothing
    $B -b --factory-startup --python $T -- build cookie_jar [--samples 48] [--force]       # export + icon + manifest
    $B -b --factory-startup --python $T -- validate cookie_jar                             # FBX round-trip (fresh process)
    $B -b --factory-startup --python $T -- sheet "Title" out.png cookie_jar fishbowl ...   # labelled preview sheet

Reuses the revamp tools without copying them: glassclash_blender.py (helper), then
docs/art/glassy_revamp/tools/build_glassy_v3.py (which execs build_combat_release.py) for the
geometry primitives, materials, motion tags (anim/sway/spin/...), render_views and shard cutting.
If the revamp file is mid-edit and fails to load, its last committed version is used.

Writes only assets/blender/glassies/<id>/v4/ and docs/art/launch_glassies/. build_v4() itself cannot run here: it
needs bpy.context.window (absent with -b) and release_v2/v3 baselines new glassies do not have, so build() below
mirrors it (same checks, rcut4 fracture, render_views4 icons, rig cards removed before saving, same manifest keys).
Conventions match v3: origin = hang point, body hangs down -Z, front faces -Y, 1 unit = 1 stud,
Pivot_<Detail> empties (local Z = motion axis), motion in Blender and Roblox (x, z, -y) coordinates.
Additions to the v3 motion schema: `follows` (a part that rides another part's motion; its own
idle/hit apply in the parent's frame) and the `drip` idle type (Honey Bear).
"""
import hashlib
import json
import math
import os
import random
import subprocess
import sys

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
GLASSCLASH_REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
exec(compile(open(os.path.join(GLASSCLASH_REPO, "tools", "blender", "glassclash_blender.py"), encoding="utf-8").read(), "glassclash_blender.py", "exec"))
set_repo(GLASSCLASH_REPO)
_V3_REL = "docs/art/glassy_revamp/tools/build_glassy_v3.py"
_V4_REL = "docs/art/glassy_revamp/tools/build_glassy_v4.py"
HAS_V4 = False
try:  # v4 = the shelf's current quality bar (rig4 icons, glass4 two-layer materials, weighted normals); it execs v3
    exec(compile(open(repo_path(_V4_REL), encoding="utf-8").read(), _V4_REL, "exec"))
    V3_SOURCE, HAS_V4 = "v4 working copy", True
except Exception as _err:  # the revamp session may be mid-edit
    print("build_glassy_v4 failed (%r); falling back to v3" % (_err,))
    try:
        exec(compile(open(repo_path(_V3_REL), encoding="utf-8").read(), _V3_REL, "exec"))
        V3_SOURCE = "v3 working copy"
    except Exception as _err3:
        print("build_glassy_v3 working copy failed (%r); using HEAD" % (_err3,))
        _src = subprocess.run(["git", "-C", GLASSCLASH_REPO, "show", "HEAD:" + _V3_REL], capture_output=True, text=True, check=True).stdout
        exec(compile(_src, _V3_REL + "@HEAD", "exec"))
        V3_SOURCE = "v3 HEAD"

VERSION = "v4"   # shares the v4 revamp bar, look and icon framing (folder name agreed with workstreams A/C)
LAUNCH = {
    "cookie_jar": ("Cookie Jar", "Common", "#E8B77A", 0.88),
    "fishbowl": ("Fishbowl", "Common", "#5BC8FF", 0.90),
    "glass_top": ("Glass Top", "Uncommon", "#FF6FB1", 0.65),
    "piggy_bank": ("Piggy Bank", "Uncommon", "#FF9CC2", 0.85),
    "bubble_wand": ("Bubble Wand", "Uncommon", "#B9F3FF", 0.60),
    "crystal_ball": ("Crystal Ball", "Epic", "#C9B5FF", 0.80),
    "honey_bear": ("Honey Bear", "Epic", "#FFB92E", 0.80),
    "potion_flask": ("Potion Flask", "Rare", "#6CFF9A", 0.75),
    "light_bulb": ("Light Bulb", "Rare", "#FFF4A8", 0.75),
    "grizzly_guardian": ("Grizzly Guardian", "Legendary", "#FFC96B", 1.00),
    "glass_unicorn": ("Glass Unicorn", "Legendary", "#FFD6F5", 0.80),
    "glass_phoenix": ("Glass Phoenix", "Mythic", "#FF7A2E", 0.85),
}
ORDER = list(LAUNCH)
SHARDS = {"Common": 16, "Uncommon": 16, "Rare": 16, "Epic": 18, "Legendary": 20, "Mythic": 20}
TRI_BUDGET = {"Legendary": 3000, "Mythic": 3000}
RADIUS_TOLERANCE = 0.03
LAUNCH_BUILDERS = {}

# Shared face language (matches the v3 Dragon/Duck: dark glossy eyes, white shine, pink cheeks).
EYE, SHINE, CHEEK = "#1B2440", "#FFFFFF", "#FF8FB0"


def launch(gid):
    def wrap(fn):
        LAUNCH_BUILDERS[gid] = fn
        return fn
    return wrap


def out_folder(gid):
    return repo_path("assets", "blender", "glassies", gid, VERSION)


def doc_path(*parts):
    return repo_path("docs", "art", "launch_glassies", *parts)


# ------------------------------------------------------------------------------------------
# Extra helpers (shapes the v3 file does not have)
# ------------------------------------------------------------------------------------------

def follow(obj, parent, note=None):
    """Marks a part that rides another part's motion (its own idle/hit apply in the parent's frame)."""
    m = json.loads(obj["motion_json"])
    m["follows"] = parent
    if note:
        m["note"] = note
    obj["motion_json"] = json.dumps(m)
    return obj


def xform_bm(bm, matrix):
    bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts)
    return bm


def lathe_into(bm, profile, matrix, segments=16, sharp_deg=None):
    """Lathe around local Z (profile = (r, z)), transformed by `matrix`, merged into bm."""
    tmp = lathe3("_tmp_lathe_into", profile, 0.0, segments, sharp_deg=None)
    t = bmesh.new()
    t.from_mesh(tmp.data)
    mesh = tmp.data
    bpy.data.objects.remove(tmp, do_unlink=True)
    bpy.data.meshes.remove(mesh)
    xform_bm(t, matrix)
    _merge_bm(bm, t)
    return bm


def disc_profile(r, t, round_k=0.35):
    """Rounded puck profile, centred on z=0, thickness t."""
    e = t * round_k
    return [(0, -t / 2), (r - e, -t / 2), (r - e * 0.15, -t * 0.2), (r - e * 0.15, t * 0.2), (r - e, t / 2), (0, t / 2)]


def resample(points, n):
    """n points spaced evenly by arc length along a polyline (keeps both ends)."""
    pts = [Vector(p) for p in points]
    seg = [(b - a).length for a, b in zip(pts, pts[1:])]
    total = sum(seg)
    out, acc, i = [pts[0]], 0.0, 0
    for k in range(1, n - 1):
        target = total * k / (n - 1)
        while acc + seg[i] < target:
            acc += seg[i]
            i += 1
        t = (target - acc) / seg[i]
        out.append(pts[i].lerp(pts[i + 1], t))
    out.append(pts[-1])
    return out


def smooth_profile(ctrl, n):
    """Smooth (r, z) lathe profile through control points, resampled to n rings."""
    pts = resample(spline([(r, 0, z) for r, z in ctrl], 64), n)
    prof = [(max(p.x, 0.0), p.z) for p in pts]
    prof[0], prof[-1] = (0.0, ctrl[0][1]), (0.0, ctrl[-1][1])
    return prof


def facing(normal):
    """Rotation matrix whose local Z points along `normal` (for flattening features onto a surface)."""
    return Vector(normal).normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()


class Surface:
    """Ray casts against a body to sit face features and decals on the glass."""

    def __init__(self, obj):
        self.tree = BVHTree.FromPolygons([v.co.copy() for v in obj.data.vertices], [list(p.vertices) for p in obj.data.polygons])

    def hit(self, origin, direction):
        d = Vector(direction).normalized()
        for jitter in ((0, 0, 0), (0.0021, 0.0013, 0.0017), (-0.0023, -0.0011, 0.0019)):  # rays exactly on a seam can slip through
            p, n, _, _ = self.tree.ray_cast(Vector(origin) + Vector(jitter), d)
            if p is not None:
                return p, n
        raise AssertionError(("surface miss", origin, direction))

    def toward(self, centre, direction):
        """Point where a ray from outside, heading back to `centre` along -direction, meets the body."""
        d = Vector(direction).normalized()
        return self.hit(Vector(centre) + d * 5, -d)


def feature_bm(bm, point, normal, radii, sink=0.35, segments=10, rings=6, spin_deg=0.0):
    """Ellipsoid flattened along the surface normal; radii = (across, up, depth)."""
    n = Vector(normal).normalized()
    rot = facing(n) @ Matrix.Rotation(math.radians(spin_deg), 4, "Z")
    tmp = bmesh.new()
    bmesh.ops.create_uvsphere(tmp, u_segments=segments, v_segments=rings, radius=1)
    xform_bm(tmp, Matrix.Translation(Vector(point) + n * radii[2] * (1 - 2 * sink)) @ rot @ Matrix.Diagonal((radii[0], radii[1], radii[2], 1)))
    _merge_bm(bm, tmp)
    return bm


def face(surf, centre, eye_dx, eye_z, eye=(0.085, 0.11, 0.05), cheeks=True, cheek_dx=None, cheek_dz=-0.13,
         look=(0, -1, 0), prefix="", blink_s=4.0, shine_scale=1.0, seg=(9, 6), shine_seg=((6, 4), (5, 3)), cheek_seg=(8, 3)):
    """Shared cute face: Eyes + EyeShine (blink together) + Cheeks. Eyes sit on the surface found by
    casting from in front of `centre` along `look`; returns the detail list."""
    look = Vector(look).normalized()
    eyes, shine, cheek = bmesh.new(), bmesh.new(), bmesh.new()
    side = look.cross(Vector((0, 0, 1))).normalized() * -1  # +X when looking down -Y
    pivots = []
    for s in (-1, 1):
        aim = Vector(centre) + side * s * eye_dx + Vector((0, 0, eye_z - centre[2]))
        p, n = surf.hit(aim + look * 5, -look)
        feature_bm(eyes, p, n, eye, 0.45, *seg)
        up = Vector((0, 0, 1))
        sp = p + n * eye[2] * 0.25 + up * eye[1] * 0.38 - side * eye[0] * 0.3   # big shine upper-left (v4 light)
        feature_bm(shine, sp, n, (eye[0] * 0.36, eye[1] * 0.3, eye[2] * 0.6), 0.1, *shine_seg[0])
        sp2 = p + n * eye[2] * 0.25 - up * eye[1] * 0.35 + side * eye[0] * 0.3
        feature_bm(shine, sp2, n, (eye[0] * 0.17 * shine_scale, eye[1] * 0.14 * shine_scale, eye[2] * 0.5), 0.1, *shine_seg[1])
        pivots.append(p)
        if cheeks:
            cdx = cheek_dx if cheek_dx is not None else eye_dx * 1.35
            ca = Vector(centre) + side * s * cdx + Vector((0, 0, eye_z + cheek_dz - centre[2]))
            cp, cn = surf.hit(ca + look * 5, -look)
            feature_bm(cheek, cp, cn, (eye[0] * 1.15, eye[1] * 0.6, 0.03), 0.5, *cheek_seg)
    mid = (pivots[0] + pivots[1]) / 2
    e = paint(_obj(prefix + "Eyes", eyes), EYE, "SmoothPlastic")
    anim(e, mid, (0, 0, 1), blink(blink_s, 0.12))
    sh = paint(_obj(prefix + "EyeShine", shine), SHINE, "SmoothPlastic")
    anim(sh, mid, (0, 0, 1), blink(blink_s, 0.12), note="blinks with Eyes")
    follow(sh, prefix + "Eyes", "blinks with Eyes")
    out = [e, sh]
    if cheeks:
        c = paint(_obj(prefix + "Cheeks", cheek), CHEEK, "SmoothPlastic")
        c["studio_transparency"] = 0.35
        out.append(c)
    return out


def smile_bm(bm, surf, centre, width, z, depth=0.03, look=(0, -1, 0), curve=0.05, steps=7, r=0.018):
    """A small curved smile line on the surface."""
    look = Vector(look).normalized()
    side = look.cross(Vector((0, 0, 1))).normalized() * -1
    pts = []
    for i in range(steps):
        t = i / (steps - 1) * 2 - 1
        a = Vector(centre) + side * t * width / 2 + Vector((0, 0, z - centre[2] - curve * (1 - t * t)))
        p, n = surf.hit(a + look * 5, -look)
        pts.append(p + n * (r * 0.4))
    tube_bm(bm, pts, [r * (0.7 + 0.3 * (1 - abs(i / (steps - 1) * 2 - 1))) for i in range(steps)], 5)
    return bm


def as_inner(obj):
    """Marks a glass detail as the saturated inner layer (v4 two-layer look: clear shell, tinted inside)."""
    obj["glass_layer"] = "inner"
    return obj


def inset_shell(name, src, d, color, alpha=0.5, transmission=None):
    """Second glass layer: a copy of `src` pushed inward along vertex normals by d (two-layer depth)."""
    bm = _bm_from_object(src)
    bm.normal_update()
    for v in bm.verts:
        v.co -= v.normal * d
    obj = _obj(name, bm)
    return paint(obj, color, alpha=alpha, transmission=transmission)


def hang_loop(name, top_z, r=0.11, tube_r=0.035, color="#EAFBFF", material="Glass", axis="X", segments=10):
    """Small ring whose top is the hang point (z = top_z)."""
    bm = bmesh.new()
    rot = Matrix.Rotation(math.pi / 2, 4, axis)
    torus_bm(bm, (0, 0, top_z - r - tube_r), r, tube_r, segments, 4, rot)
    return paint(_obj(name, bm), color, material)


# ------------------------------------------------------------------------------------------
# Packaging (v3 package logic without the release_v2 comparison)
# ------------------------------------------------------------------------------------------

def _clear_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)
    for m in list(bpy.data.meshes):
        bpy.data.meshes.remove(m)


def release_geometry(body):
    lo, hi = _world_bounds([body])
    return {"Radius": round(max(-lo.x, hi.x, -lo.y, hi.y), 6), "Center": round(-(lo.z + hi.z) / 2, 6)}


def finish_v4(body, details):
    """Shelf consistency with the v4 revamp: glass4 materials (clear shell / tinted inner / detail) and weighted
    normals on every smooth part. The Body keeps its full tint when nothing tinted sits inside it."""
    if not HAS_V4:
        return
    has_inner = any(d.get("glass_layer") == "inner" for d in details)
    for o in [body, *details]:
        if all(not p.use_smooth for p in o.data.polygons):
            continue
        if o.get("studio_material") == "Glass":
            color = o["studio_color"]
            if o is body:
                glass4(o, color, "shell", role="Body")
                if not has_inner:
                    _set_input(next(n for n in o.data.materials[0].node_tree.nodes if n.type == "BSDF_PRINCIPLED"), "Base Color", (*hex_to_rgb(color), 1))
            else:
                glass4(o, color, o.get("glass_layer", "detail"))
        if not any(m.type == "WEIGHTED_NORMAL" for m in o.modifiers):
            mod = o.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
            mod.mode, mod.weight, mod.keep_sharp = "FACE_AREA", 50, True


def _render(objs, icon, prev, samples):
    if HAS_V4:
        render_views4(bpy.context.scene, objs, icon, prev, samples)
        for o in list(bpy.context.scene.objects):
            if o.get("rig_only"):
                bpy.data.objects.remove(o, do_unlink=True)
    else:
        render_views(bpy.context.scene, objs, icon, prev, samples)


def build_objects(gid):
    _clear_scene()
    body, details = LAUNCH_BUILDERS[gid](gid)
    finish_v4(body, details)
    body["glassy_id"], body["asset_role"], body["source_name"] = gid, "Body", "Body"
    for d in details:
        d["glassy_id"] = gid
    for o in [body, *details]:
        assert o.name == o["source_name"], ("name clash", o.name, o["source_name"])
    return body, details


def stats(gid, body, details):
    name, rarity, tint, target = LAUNCH[gid]
    tris = {o.name: _tris(o) for o in [body, *details]}
    geo = release_geometry(body)
    lo, hi = _world_bounds([body, *details])
    return {"id": gid, "rarity": rarity, "tris_total": sum(tris.values()), "budget": TRI_BUDGET.get(rarity, 1500),
            "tris": tris, "geometry": geo, "radius_target": target, "body_closed": rclosed(body),
            "overall_bounds": [[round(c, 3) for c in lo], [round(c, 3) for c in hi]],
            "moving_parts": sum(1 for o in details if "motion_json" in o and (json.loads(o["motion_json"])["idle"]["type"] != "static" or json.loads(o["motion_json"])["hit"]["type"] != "none"))}


def preview(gid, out_dir, samples=16):
    body, details = build_objects(gid)
    s = stats(gid, body, details)
    os.makedirs(out_dir, exist_ok=True)
    for o in details:
        o.hide_render = bool(o.get("effect_only", False))
    _render([body, *details], os.path.join(out_dir, gid + "_front.png"), os.path.join(out_dir, gid + "_34.png"), samples)
    return s


def build(gid, samples=96, force=False):
    folder = out_folder(gid)
    manifest_path = os.path.join(folder, "manifest.json")
    if os.path.exists(manifest_path) and not force:
        return {"id": gid, "status": "existing v4 preserved (--force to rebuild)"}
    os.makedirs(folder, exist_ok=True)
    name, rarity, tint, target = LAUNCH[gid]
    body, details = build_objects(gid)
    tris = sum(_tris(o) for o in [body, *details])
    budget = TRI_BUDGET.get(rarity, 1500)
    assert tris <= budget, (gid, "intact budget", tris, budget)
    geo = release_geometry(body)
    assert abs(geo["Radius"] - target) <= RADIUS_TOLERANCE, (gid, "radius", geo["Radius"], target)
    count = SHARDS[rarity]
    for attempt in range(16):
        shards = make_shards(body, count, seed=4040 + sum(map(ord, gid)) + attempt * 7919, cut=rcut4 if HAS_V4 else rcut, min_volume_ratio=0.3 / count)
        if len(shards) == count and all(rclosed(s)["nonmanifold_edges"] == 0 and rclosed(s)["boundary_edges"] == 0 and rclosed(s)["volume"] > 1e-7 for s in shards):
            break
        for s in shards:
            bpy.data.objects.remove(s, do_unlink=True)
    else:
        raise AssertionError((gid, "no valid fracture seed"))
    checks = {o.name: rclosed(o) for o in [body, *shards]}
    assert all(c["nonmanifold_edges"] == 0 and c["boundary_edges"] == 0 for c in checks.values()), checks
    ratio = sum(rclosed(s)["volume"] for s in shards) / rclosed(body)["volume"]
    assert abs(ratio - 1) < 0.001, (gid, "volume ratio", ratio)
    for i, s in enumerate(shards):
        s["source_name"], s["asset_role"], s["glassy_id"] = f"Shard_{i + 1:02d}", "Shard", gid
        assert s.name == s["source_name"]
        paint(s, body["studio_color"], role="Shard")
    cracks = rcracks(body)
    assert len(cracks) > 20, (gid, "cracks", len(cracks))
    files = {}
    for role, objs in (("body", [body]), ("details", details), ("shards", shards), ("bundle", [body, *details, *shards])):
        files[role] = export_fbx(objs, os.path.join(folder, f"{gid}_{role}.fbx"))
    for s in shards:
        s.hide_render = True
    for o in details:
        o.hide_render = bool(o.get("effect_only", False))
    icon = os.path.join(folder, f"{gid}_icon.png")
    prev = doc_path("previews", f"{gid}_34.png")
    os.makedirs(os.path.dirname(prev), exist_ok=True)
    _render([body, *details], icon, prev, samples)
    files["icon"] = icon
    for s in shards:
        s.hide_set(True)
    files["blend"] = save_blend_copy(os.path.join(folder, f"{gid}.blend"))
    crack_path = os.path.join(folder, "cracks.json")
    with open(crack_path, "w", newline="\n") as fh:
        json.dump(cracks, fh, indent=2)
    files["cracks"] = crack_path
    meshes = []
    for o in [body, *details, *shards]:
        lo, hi = _world_bounds([o])
        entry = {"name": o.name, "source_name": o["source_name"], "role": o["asset_role"], "triangles": _tris(o),
                 "bounds_blender": [list(lo), list(hi)], "origin": [0, 0, 0], "color": o["studio_color"],
                 "material": o["studio_material"], "transparency": o.get("studio_transparency", 0),
                 "animation_pivot": list(o.get("animation_pivot", [0, 0, 0])), "effect_only": bool(o.get("effect_only", False))}
        if "motion_json" in o:
            entry["motion"] = json.loads(o["motion_json"])
            entry["pivot_empty"] = "Pivot_" + o["source_name"]
        meshes.append(entry)
    blo, bhi = _world_bounds([body])
    dims = bhi - blo
    report = {
        "id": gid, "name": name, "version": VERSION, "rarity": rarity, "tint": tint,
        "status": {"exported": True, "blender_validated": False, "studio_imported": False, "uploaded": False, "playtested": False},
        "units": "1 Blender unit = 1 stud", "axis_conversion": "Blender (x,y,z) -> Roblox (x,z,-y)", "hang_origin": [0, 0, 0],
        "intact_triangles": tris, "triangle_budget": budget, "shard_count": len(shards), "fracture_volume_ratio": ratio,
        "checks": checks, "crack_segments": len(cracks), "meshes": meshes,
        "files": {k: _rel(v) for k, v in files.items()}, "hashes": {k: _sha(v) for k, v in files.items()},
        "release_geometry": geo, "radius_target": target,
        "measured_body_dimensions_roblox": [dims.x, dims.z, dims.y],
        "preview": _rel(prev), "builder": {"script": _rel(os.path.abspath(__file__)), "v3_helpers": V3_SOURCE, "blender": bpy.app.version_string},
        "remaining_checks": ["Roblox FBX import scale/orientation/pivot", "Glass/Neon material against live sky",
                             "idle motion implementation in Studio", "phone performance with all details animated"],
    }
    with open(manifest_path, "w") as fh:
        json.dump(report, fh, indent=2)
    return {"id": gid, "tris": tris, "budget": budget, "shards": len(shards), "ratio": round(ratio, 8), "geometry": geo,
            "target": target, "details": len(details)}


def validate(gid):
    path = os.path.join(out_folder(gid), "manifest.json")
    report = json.load(open(path))
    _clear_scene()
    bpy.ops.import_scene.fbx(filepath=repo_path(report["files"]["bundle"]), use_custom_props=True)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    assert len(meshes) == len(report["meshes"]), (gid, "mesh count", len(meshes), len(report["meshes"]))
    rows = []
    for entry in report["meshes"]:
        obj = next(o for o in meshes if o.get("source_name") == entry["source_name"])
        lo, hi = _world_bounds([obj])
        delta = max((lo - Vector(entry["bounds_blender"][0])).length, (hi - Vector(entry["bounds_blender"][1])).length)
        assert delta < 1e-4, (gid, entry["source_name"], "bounds", delta)
        assert obj.location.length < 1e-5, (gid, "origin", list(obj.location))
        check = rclosed(obj)
        if entry["role"] in ("Body", "Shard"):
            assert check["nonmanifold_edges"] == 0 and check["boundary_edges"] == 0, (entry["source_name"], check)
        rows.append({"name": entry["source_name"], "bounds_error": delta, "nonmanifold_edges": check["nonmanifold_edges"]})
    for key, rel in report["files"].items():
        assert _sha(repo_path(rel)) == report["hashes"][key], (gid, key, "hash changed")
    body = next(o for o in meshes if o.get("asset_role") == "Body")
    shards = [o for o in meshes if o.get("asset_role") == "Shard"]
    a, b = _world_bounds([body])
    c, d = _world_bounds(shards)
    assert max((a - c).length, (b - d).length) < 1e-4, (gid, "shards do not recombine to body bounds")
    geo = release_geometry(body)
    assert abs(geo["Radius"] - report["release_geometry"]["Radius"]) < 1e-4 and abs(geo["Center"] - report["release_geometry"]["Center"]) < 1e-4
    report["fbx_roundtrip"] = {"passed": True, "application": "Blender " + bpy.app.version_string, "format": "FBX bundle round-trip",
                               "mesh_count": len(meshes), "shard_count": len(shards), "checks": rows, "roblox_import": False}
    report["status"]["blender_validated"] = True
    with open(path, "w") as fh:
        json.dump(report, fh, indent=2)
    return {"id": gid, "passed": True, "meshes": len(meshes), "shards": len(shards), "geometry": geo}


def sheet(title, gids, out, cell=300):
    """Labelled sheet: per glassy the icon (front, shared rig) and the 3/4 preview. Emission planes, EEVEE."""
    _clear_scene()
    scene = bpy.context.scene
    entries = []
    for g in gids:
        name, rarity, tint, target = LAUNCH[g]
        m = json.load(open(os.path.join(out_folder(g), "manifest.json")))
        label = "%s  (%s)   r %.2f   %d tris" % (name, rarity, m["release_geometry"]["Radius"], m["intact_triangles"])
        entries.append((label, [os.path.join(out_folder(g), g + "_icon.png"), doc_path("previews", g + "_34.png")]))
    cols = 2 if len(entries) > 1 else 1
    per = 2
    rows = math.ceil(len(entries) / cols)
    gw, gh = per * 1.0 + 0.25, 1.0 + 0.3
    W, H = cols * gw + 0.25, rows * gh + 0.45

    def emit(color=None, image=None):
        mat = bpy.data.materials.new("SheetMat")
        mat.use_nodes = True
        nt = mat.node_tree
        nt.nodes.clear()
        out_n = nt.nodes.new("ShaderNodeOutputMaterial")
        em = nt.nodes.new("ShaderNodeEmission")
        if image is not None:
            tex = nt.nodes.new("ShaderNodeTexImage")
            tex.image = image
            mix = nt.nodes.new("ShaderNodeMixShader")
            tr = nt.nodes.new("ShaderNodeBsdfTransparent")
            nt.links.new(tex.outputs["Color"], em.inputs["Color"])
            nt.links.new(tex.outputs["Alpha"], mix.inputs[0])
            nt.links.new(tr.outputs[0], mix.inputs[1])
            nt.links.new(em.outputs[0], mix.inputs[2])
            nt.links.new(mix.outputs[0], out_n.inputs["Surface"])
        else:
            em.inputs["Color"].default_value = (*color, 1)
            nt.links.new(em.outputs[0], out_n.inputs["Surface"])
        return mat

    def text(body, x, y, size, color=(0.85, 0.9, 1.0)):
        cu = bpy.data.curves.new("T", "FONT")
        cu.body, cu.size, cu.align_x = body, size, "CENTER"
        ob = bpy.data.objects.new("T", cu)
        ob.location = (x, y, 0.01)
        ob.data.materials.append(emit(color))
        scene.collection.objects.link(ob)

    for i, (label, paths) in enumerate(entries):
        r, c = divmod(i, cols)
        gx, gy = 0.25 + c * gw, H - 0.45 - r * gh
        for j, p in enumerate(paths):
            img = bpy.data.images.load(p, check_existing=False)
            mesh = bpy.data.meshes.new("P")
            x0, y0 = gx + j * 1.0, gy - 1.0
            mesh.from_pydata([(x0, y0, 0), (x0 + 1, y0, 0), (x0 + 1, y0 + 1, 0), (x0, y0 + 1, 0)], [], [(0, 1, 2, 3)])
            uv = mesh.uv_layers.new()
            for k, co in enumerate(((0, 0), (1, 0), (1, 1), (0, 1))):
                uv.data[k].uv = co
            ob = bpy.data.objects.new("P", mesh)
            ob.data.materials.append(emit(image=img))
            scene.collection.objects.link(ob)
        text(label, gx + per * 0.5, gy - 1.14, 0.075)
    text(title, W / 2, H - 0.3, 0.12, (1, 1, 1))
    cam = bpy.data.objects.new("SheetCam", bpy.data.cameras.new("SheetCam"))
    cam.data.type, cam.data.ortho_scale = "ORTHO", max(W, H)
    cam.location = (W / 2, H / 2, 5)
    scene.collection.objects.link(cam)
    scene.camera = cam
    world = bpy.data.worlds.new("SheetWorld")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.012, 0.02, 0.045, 1)
    scene.world = world
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 8
    scene.cycles.use_denoising = False
    _gpu(scene)
    scene.render.resolution_x, scene.render.resolution_y = int(W * cell), int(H * cell)
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    return out


# ------------------------------------------------------------------------------------------
# 1. Cookie Jar (Common, Heavy)
# ------------------------------------------------------------------------------------------

def cookie_bm(bm, at, r, t, rot, lobes=9, wobble=0.035, segments=18):
    tmp = bmesh.new()
    lathe_into(tmp, disc_profile(r, t), Matrix.Identity(4), segments)
    for v in tmp.verts:
        rr = math.hypot(v.co.x, v.co.y)
        if rr > 0.02:
            k = 1 + wobble * math.cos(lobes * math.atan2(v.co.y, v.co.x)) * (rr / r)
            v.co.x *= k
            v.co.y *= k
    xform_bm(tmp, Matrix.Translation(Vector(at)) @ rot)
    _merge_bm(bm, tmp)
    return bm


def chips_bm(bm, at, r, t, rot, n, seed, both=True):
    rng = random.Random(seed)
    m = Matrix.Translation(Vector(at)) @ rot
    for side in ((-1, 1) if both else (1,)):
        for i in range(n):
            a = i * math.tau / n + rng.uniform(-0.4, 0.4)
            rr = r * rng.uniform(0.25, 0.68)
            p = m @ Vector((rr * math.cos(a), rr * math.sin(a), side * t * 0.47))
            nrm = (m.to_3x3() @ Vector((0, 0, side))).normalized()
            s = rng.uniform(0.75, 1.15)
            feature_bm(bm, p, nrm, (r * 0.14 * s, r * 0.12 * s, t * 0.3), 0.25, 5, 3, rng.uniform(0, 180))
    return bm


@launch("cookie_jar")
def b_cookie_jar(gid):
    tint, lid_c, cookie_c, chip_c = "#E8B77A", "#F2CC98", "#E89A4A", "#5A3420"
    jar_top = 1.36
    knob_r, knob_t = 0.27, 0.13
    lid_top = 1.62
    h = lid_top + knob_r * 2 - 0.04
    prof = [(0, 0), (0.6, 0), (0.79, 0.06), (0.87, 0.22), (0.88, 0.5), (0.85, 0.84), (0.78, 1.02),
            (0.66, 1.15), (0.6, 1.21), (0.6, 1.28), (0.67, 1.3), (0.67, 1.36), (0, 1.36)]
    body = paint(lathe3("Body", prof, h, 20, sharp_deg=40), tint, role="Body")
    lid_prof = [(0, 1.355), (0.7, 1.355), (0.72, 1.4), (0.62, 1.49), (0.42, 1.575), (0.18, 1.615), (0, 1.62)]
    lid = paint(lathe3("Lid", lid_prof, h, 18, sharp_deg=45), lid_c, alpha=0.85, transmission=0.8)
    anim(lid, (0, 0, jar_top - h), (0, 0, 1), None, hop(0.07, 6.0, 0.25), lod_keep=True, note="lid rattle: client hops it once per Charge and on hits")
    kb = bmesh.new()
    kc = Vector((0, 0, lid_top + knob_r - 0.06 - h))
    knob_rot = Matrix.Rotation(math.pi / 2, 4, "X")
    cookie_bm(kb, kc, knob_r, knob_t, knob_rot, 10, 0.015, 20)
    knob = paint(_obj("LidCookie", kb), cookie_c)
    anim(knob, (0, 0, jar_top - h), (0, 0, 1), None, hop(0.07, 6.0, 0.25))
    follow(knob, "Lid", "the knob cookie is the hang point; it rides the lid rattle")
    kch = bmesh.new()
    chips_bm(kch, kc, knob_r, knob_t, knob_rot, 3, 3, both=False)
    kchips = paint(_obj("LidChips", kch), chip_c, "SmoothPlastic")
    anim(kchips, (0, 0, jar_top - h), (0, 0, 1), None, hop(0.07, 6.0, 0.25))
    follow(kchips, "Lid")
    ds = [lid, knob, kchips]
    # A tumbled stack on the floor of the jar plus one cookie leaning on the front glass.
    stack = (((0.1, 0.12, 0.17), 0.36, (0.12, -0.08, 0.4)), ((-0.12, 0.05, 0.36), 0.34, (-0.22, 0.18, -0.3)),
             ((0.2, -0.26, 0.56), 0.32, (0.62, 0.5, 0.9)))
    for i, (at, r, (rx, ry, rz)) in enumerate(stack):
        at = Vector((at[0], at[1], at[2] - h))
        rot = (Matrix.Rotation(rz, 4, "Z") @ Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rx, 4, "X"))
        cb = bmesh.new()
        cookie_bm(cb, at, r, 0.12, rot, 6, 0.035, 12)
        ck = as_inner(paint(_obj(f"Cookie_{i + 1}", cb), cookie_c))
        anim(ck, at, (0, 0, 1), None, hop(0.05 + 0.015 * i, 4.5 - 0.4 * i, 0.3),
             note="shuffle: client hops/turns each cookie on Charge (staggered)")
        chb = bmesh.new()
        chips_bm(chb, at, r, 0.12, rot, 2, 10 + i * 7, both=False)
        chp = paint(_obj(f"CookieChips_{i + 1}", chb), chip_c, "SmoothPlastic")
        anim(chp, at, (0, 0, 1), None, hop(0.05 + 0.015 * i, 4.5 - 0.4 * i, 0.3))
        follow(chp, f"Cookie_{i + 1}")
        ds += [ck, chp]
    rb = bmesh.new()
    torus_bm(rb, (0, 0, 1.235 - h), 0.632, 0.042, 10, 4)
    bow_c = Vector((0, -0.66, 1.235 - h))
    for s in (-1, 1):
        loop = [(0, 0), (s * 0.15, 0.12), (s * 0.3, 0.07), (s * 0.29, -0.07), (s * 0.14, -0.1)][::s]
        slab_bm(rb, loop, 0.07, 0.03, 1, Matrix.Translation(bow_c))
        tail = [(0, 0), (s * 0.12, -0.25), (s * 0.04, -0.22)][::s]
        slab_bm(rb, tail, 0.045, 0, 1, Matrix.Translation(bow_c + Vector((0, -0.01, -0.03))))
    ellipsoid_bm(rb, bow_c + Vector((0, -0.02, 0)), (0.075, 0.055, 0.075), 6, 4)
    ribbon = paint(_obj("Ribbon", rb), "#E8525F", "SmoothPlastic")
    anim(ribbon, bow_c, (0, 1, 0), None, kick(8))
    ds.append(ribbon)
    return body, ds


# ------------------------------------------------------------------------------------------
# 2. Fishbowl (Common, Heavy)
# ------------------------------------------------------------------------------------------

def arc_pts(radius, cz, a0, a1, steps):
    return [(radius * math.cos(math.radians(a0 + (a1 - a0) * i / steps)), cz + radius * math.sin(math.radians(a0 + (a1 - a0) * i / steps))) for i in range(steps + 1)]


@launch("fishbowl")
def b_fishbowl(gid):
    # The Body is the glass and the water as one solid (two surfaces to see through, so the fish reads);
    # only the rolled rim rises above the waterline. The deeper Water core inside is the second layer.
    tint, R, wall = "#5BC8FF", 0.9, 0.06
    cz = R
    outer = [(0, 0.0), (0.28, 0.0)] + arc_pts(R, cz, -76, 50, 9)[1:]
    rim_r, rim_z = outer[-1]
    water_z = rim_z - 0.1
    lip = [(rim_r + 0.06, rim_z + 0.07), (rim_r + 0.02, rim_z + 0.12), (rim_r - 0.045, rim_z + 0.08), (rim_r - 0.055, water_z + 0.02)]
    inner = [(rim_r - 0.08, water_z), (0, water_z)]
    prof = outer + lip + inner
    bowl_top = rim_z + 0.12
    handle_top = bowl_top + 0.52
    h = handle_top + 0.05
    body = paint(lathe3("Body", prof, h, 26, sharp_deg=60), tint, role="Body")
    ds = []
    # Glass bail handle over the opening; its top is the hang point (static so the string point never moves).
    hb = bmesh.new()
    path = spline([(-rim_r - 0.04, 0, rim_z + 0.06 - h), (-rim_r * 0.85, 0, bowl_top + 0.3 - h), (0, 0, handle_top - h),
                   (rim_r * 0.85, 0, bowl_top + 0.3 - h), (rim_r + 0.04, 0, rim_z + 0.06 - h)], 16)
    tube_bm(hb, path, 0.045, 5)
    for s in (-1, 1):
        ellipsoid_bm(hb, (s * (rim_r + 0.045), 0, rim_z + 0.07 - h), (0.075, 0.075, 0.075), 5, 3)
    handle = paint(_obj("Handle", hb), "#D6F4FF")
    ds.append(handle)
    wpivot = (0, 0, water_z - h)
    wtop_r = rim_r - 0.07
    sb = bmesh.new()
    lathe_into(sb, [(0, -0.006), (wtop_r - 0.03, -0.006), (wtop_r - 0.02, 0.006), (0, 0.016)], Matrix.Translation((0, 0, water_z - h + 0.008)), 16)
    surface = paint(_obj("WaterSurface", sb), "#D6F4FF", alpha=0.5)
    anim(surface, wpivot, (1, 0, 0), slosh(12, 0.3), kick(6, 3.5, 0.25), lod_keep=True,
         extra_idle=[sway(3, 1.7)], note="the water surface disc: stays level as the bowl swings and wobbles")
    ds += [surface]
    # The fish: swims a slow loop (spin about the bowl's vertical axis), head along the loop tangent.
    fish_c = Vector((0.04, -0.36, 0.9 - h))
    fish_rot = Matrix.Rotation(-0.12, 4, "Z")
    fb = bmesh.new()
    ellipsoid_bm(fb, fish_c, (0.29, 0.17, 0.23), 12, 7, fish_rot.to_quaternion())
    fish = as_inner(paint(_obj("Fish", fb), "#FF7A1F", alpha=0.95, transmission=0.12))
    loop_pivot = (0, 0, 0.9 - h)
    anim(fish, loop_pivot, (0, 0, 1), spin(24), hop(0.06, 4.0, 0.3), extra_idle=[bob(0.05, 2.2)], lod_keep=True,
         note="swims a slow loop around the bowl axis; anticipation: turns to face out. Stays whole on shatter and drops with the shards")
    surf = Surface(fish)
    eb, shb = bmesh.new(), bmesh.new()
    for side in (-1, 1):
        p, n = surf.hit(fish_c + fish_rot.to_3x3() @ Vector((0.13, 0, 0.05)) + Vector((0, side * 2, 0)), Vector((0, -side, 0)))
        feature_bm(eb, p, n, (0.072, 0.085, 0.04), 0.4, 7, 4)
        feature_bm(shb, p + n * 0.014 + Vector((0.022, 0, 0.03)), n, (0.026, 0.026, 0.022), 0.1, 5, 3)
    eyes = paint(_obj("FishEyes", eb), EYE, "SmoothPlastic")
    anim(eyes, fish_c, (0, 0, 1), blink(4.5, 0.12))
    follow(eyes, "Fish")
    shine = paint(_obj("FishEyeShine", shb), SHINE, "SmoothPlastic")
    anim(shine, fish_c, (0, 0, 1), blink(4.5, 0.12))
    follow(shine, "Fish", "blinks with FishEyes")
    finb = bmesh.new()
    m = Matrix.Translation(fish_c + Vector((-0.02, 0, 0.19))) @ fish_rot
    slab_bm(finb, [(-0.14, 0.0), (-0.03, 0.14), (0.09, 0.11), (0.11, 0.0)], 0.04, 0.012, 1, m)
    for side in (-1, 1):
        m = Matrix.Translation(fish_c + fish_rot.to_3x3() @ Vector((0.0, side * 0.15, -0.08))) @ fish_rot @ Matrix.Rotation(side * 0.5, 4, "X")
        slab_bm(finb, [(-0.07, 0.0), (0.0, 0.04), (0.06, 0.0), (0.0, -0.06)], 0.025, 0, 1, m)
    fins = paint(_obj("FishFins", finb), "#FFB067")
    anim(fins, fish_c, (0, 0, 1), sway(6, 0.9))
    follow(fins, "Fish")
    tail_root = fish_c + fish_rot.to_3x3() @ Vector((-0.27, 0, 0))
    tb = bmesh.new()
    slab_bm(tb, [(0.02, 0.0), (-0.15, 0.17), (-0.23, 0.15), (-0.17, 0.0), (-0.23, -0.15), (-0.15, -0.17)], 0.045, 0.015, 1,
            Matrix.Translation(tail_root) @ fish_rot)
    tail = paint(_obj("FishTail", tb), "#FFB067")
    anim(tail, tail_root, (0, 0, 1), sway(18, 0.55), kick(25, 5.0, 0.3))
    follow(tail, "Fish", "tail wag about its root, in the fish's frame")
    ds += [fish, eyes, shine, fins, tail]
    for i, (x, y, z, r) in enumerate(((0.36, -0.32, 1.2, 0.06),)):
        bub = paint(blob(f"Bubble_{i + 1}", (x, y, z - h), (r, r, r), 6, 4), "#EAFBFF", alpha=0.6)
        anim(bub, (x, y, z - h), (0, 0, 1), bob(0.07, 1.2 + 0.3 * i, i * 1.7))
        ds.append(bub)
    return body, ds


# ------------------------------------------------------------------------------------------
# 3. Glass Top (Uncommon, Sharp)
# ------------------------------------------------------------------------------------------

@launch("glass_top")
def b_glass_top(gid):
    tint, stripe_c = "#FF6FB1", "#FFF4FA"
    # Tip down, handle knob up. Smooth spline profile from the tip (z=0) to the crown under the knob.
    ctrl = [(0.0, 0.0), (0.12, 0.1), (0.3, 0.3), (0.5, 0.52), (0.635, 0.7), (0.65, 0.82), (0.57, 0.97), (0.36, 1.08), (0.12, 1.14), (0.0, 1.16)]
    prof = smooth_profile(ctrl, 15)
    crown_z = 1.16
    knob_top = crown_z + 0.5
    h = knob_top
    body = paint(lathe3("Body", prof, h, 28, sharp_deg=None), tint, role="Body", alpha=0.85, transmission=0.55)
    spin_idle, spin_hit = spin(40), spin_boost(260, 1.0)
    note = "cosmetic spin about the hang axis (keeps the hang point); speeds up through windup"
    anim(body, (0, 0, 0), (0, 0, 1), spin_idle, spin_hit, lod_keep=True, note=note)

    def surf_r(z):
        pts = sorted(prof, key=lambda p: p[1])
        for (r0, z0), (r1, z1) in zip(pts, pts[1:]):
            if z0 <= z <= z1 and z1 > z0:
                return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
        return 0.0
    # Candy stripes: thin closed bands lying on the glass, spiralling from the tip to the crown.
    sb = bmesh.new()
    n_stripes, steps = 5, 8
    for k in range(n_stripes):
        rings = []
        for i in range(steps):
            t = i / (steps - 1)
            z = 0.06 + t * 0.72          # lower cone only, ending under the equator ring
            a = k * math.tau / n_stripes + t * 1.5
            w = 0.5 * min(1.0, 0.2 + t * 3.0)
            r = surf_r(z)
            ring = []  # three across (so the wide band follows the curve), inner then outer layer
            for lift, da in ((0.006, -w / 2), (0.006, 0.0), (0.006, w / 2), (0.02, w / 2), (0.02, 0.0), (0.02, -w / 2)):
                ring.append(sb.verts.new(((r + lift) * math.cos(a + da), (r + lift) * math.sin(a + da), z - h)))
            rings.append(ring)
        for r0, r1 in zip(rings, rings[1:]):
            for j in range(6):
                sb.faces.new((r0[j], r0[(j + 1) % 6], r1[(j + 1) % 6], r1[j]))
        sb.faces.new(list(reversed(rings[0])))
        sb.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(sb, faces=sb.faces)
    stripes = paint(_obj("CandyStripes", sb), stripe_c)
    anim(stripes, (0, 0, 0), (0, 0, 1), spin_idle, spin_hit, note="rides the Body spin")
    follow(stripes, "Body", "rides the Body spin")
    rb = bmesh.new()
    torus_bm(rb, (0, 0, 0.82 - h), 0.655, 0.045, 20, 3)
    ring = paint(_obj("EquatorRing", rb), "#FFFFFF")
    anim(ring, (0, 0, 0), (0, 0, 1), spin_idle, spin_hit)
    follow(ring, "Body")
    knob = paint(lathe3("HandleKnob", [(0, crown_z - 0.03), (0.14, crown_z - 0.03), (0.1, crown_z + 0.05), (0.08, crown_z + 0.2),
                                       (0.11, crown_z + 0.27), (0.15, crown_z + 0.34), (0.15, crown_z + 0.41), (0.1, crown_z + 0.48), (0, knob_top)],
                       h, 8, sharp_deg=None), "#FFFFFF")
    anim(knob, (0, 0, 0), (0, 0, 1), spin_idle, spin_hit)
    follow(knob, "Body")
    tip = paint(lathe3("Tip", [(0, -0.09), (0.045, -0.06), (0.085, 0.02), (0.13, 0.12), (0, 0.14)], h, 12, sharp_deg=None), "#FFFFFF")
    anim(tip, (0, 0, 0), (0, 0, 1), spin_idle, spin_hit)
    follow(tip, "Body")
    return body, [knob, stripes, ring, tip]


# ------------------------------------------------------------------------------------------
# 4. Piggy Bank (Uncommon, Heavy)
# ------------------------------------------------------------------------------------------

def coin_stack_bm(bm, at, r, n, t=0.07, segments=10, tilt=None):
    prof = [(0, 0)]
    for i in range(n):
        z0 = i * t
        prof += [(r * 0.9, z0), (r, z0 + t * 0.22), (r, z0 + t * 0.78)]
    prof += [(r * 0.9, n * t), (0, n * t)]
    m = Matrix.Translation(Vector(at)) @ (tilt if tilt is not None else Matrix.Identity(4))
    lathe_into(bm, prof, m, segments)
    return bm


@launch("piggy_bank")
def b_piggy_bank(gid):
    tint, snout_c, dark, gold = "#FF9CC2", "#FFC0DA", "#8A3A5E", "#FFE07A"
    zc = -0.95
    lo, hi = Vector((-0.8, -0.85, zc - 0.82)), Vector((0.8, 0.85, zc + 0.7))

    def shape(bm):
        ellipsoid_bm(bm, (0, 0.02, zc), (0.8, 0.83, 0.7), 22, 14)
        ellipsoid_bm(bm, (0, -0.35, zc + 0.08), (0.62, 0.48, 0.55), 16, 10)  # chubby cheeks / face
        for x in (-0.42, 0.42):
            for y in (-0.38, 0.4):
                ellipsoid_bm(bm, (x, y, zc - 0.6), (0.17, 0.17, 0.22), 12, 8)
    body = organic("Body", shape, 260, fit=(lo, hi), voxel=0.028, max_tris=490) if HAS_V4 else remesh_union("Body", shape, voxel=0.028, target_tris=520, fit=(lo, hi))
    paint(body, tint, role="Body", alpha=0.85, transmission=0.45)
    surf = Surface(body)
    ds = face(surf, (0, 0, zc), 0.27, zc + 0.24, eye=(0.085, 0.105, 0.05), cheek_dx=0.44, cheek_dz=-0.2,
              seg=(8, 5), shine_seg=((5, 3), (4, 3)), cheek_seg=(6, 3))
    sp, sn = surf.hit((0, -5, zc - 0.04), (0, 1, 0))
    sb = bmesh.new()
    lathe_into(sb, [(0, -0.02), (0.2, -0.02), (0.235, 0.03), (0.235, 0.1), (0.2, 0.15), (0, 0.15)],
               Matrix.Translation(sp - Vector((0, 0.0, 0))) @ Matrix.Rotation(math.pi / 2, 4, "X") @ Matrix.Diagonal((1, 0.78, 1, 1)), 10)
    snout = paint(_obj("Snout", sb), snout_c)
    anim(snout, sp, (0, 1, 0), None, squash(0.85, 6.0, 0.3), note="snout squish on hits")
    nb = bmesh.new()
    for s in (-1, 1):
        ellipsoid_bm(nb, sp + Vector((s * 0.075, -0.15, 0.0)), (0.042, 0.03, 0.06), 5, 3)
    nostrils = paint(_obj("Nostrils", nb), dark, "SmoothPlastic")
    anim(nostrils, sp, (0, 1, 0), None, squash(0.85, 6.0, 0.3))
    follow(nostrils, "Snout")
    smb = bmesh.new()
    smile_bm(smb, surf, (0, 0, zc), 0.16, zc - 0.25, curve=0.04, steps=4, r=0.017)
    smile = paint(_obj("Smile", smb), dark, "SmoothPlastic")
    ds += [snout, nostrils, smile]
    for side, label in ((-1, "L"), (1, "R")):
        root = Vector((side * 0.42, -0.2, zc + 0.52))
        q = Quaternion((0, 0, 1), side * -0.35) @ Quaternion((1, 0, 0), -0.55) @ Quaternion((0, 1, 0), side * -0.35)
        eb = bmesh.new()
        ellipsoid_bm(eb, root + q @ Vector((0, 0, 0.13)), (0.15, 0.06, 0.17), 9, 6, q)
        for v in eb.verts:  # pinch the top into a soft point and curl it forward
            local = q.inverted() @ (v.co - root)
            if local.z > 0.13:
                k = 1 - 0.55 * (local.z - 0.13) / 0.17
                local.x *= k
                local.y -= 0.06 * ((local.z - 0.13) / 0.17) ** 2
                v.co = root + q @ local
        ear = paint(_obj("Ear_" + label, eb), "#FF8CB8")
        anim(ear, root, q @ Vector((1, 0, 0)), sway(4, 2.6, 0.8 * side), flare(20), lod_keep=(side < 0), note="ear twitch")
        ds.append(ear)
    slot_p, slot_n = surf.hit((0.003, 0.12, 2.0), (0, 0, -1))
    slb = bmesh.new()
    slab_bm(slb, [(-0.19, -0.045), (0.19, -0.045), (0.19, 0.045), (-0.19, 0.045)], 0.035, 0, 1,
            Matrix.Translation(slot_p) @ facing(slot_n) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    ds.append(paint(_obj("CoinSlot", slb), dark, "SmoothPlastic"))
    cb = bmesh.new()
    coin_stack_bm(cb, slot_p + Vector((0, 0, 0.12)), 0.12, 1, 0.045, 7, Matrix.Rotation(math.pi / 2, 4, "Y"))
    peek = paint(_obj("SlotCoin", cb), gold)
    anim(peek, slot_p, (0, 0, 1), None, hop(0.1, 5.0, 0.3), lod_keep=False, note="coins jingle up the slot (anticipation / Charge)")
    ds.append(peek)
    for i, (x, y, k) in enumerate(((-0.24, 0.12, 2), (0.06, 0.24, 2), (0.3, 0.02, 1))):
        sb = bmesh.new()
        base = Vector((x, y, zc - 0.48))
        coin_stack_bm(sb, base, 0.15, k, 0.075, 6, Matrix.Rotation(0.12 * (i - 1), 4, "X"))
        st = as_inner(paint(_obj(f"CoinStack_{i + 1}", sb), gold))
        anim(st, base, (0, 0, 1), None, hop(0.04, 5.0, 0.35), note="savings stage %d: client shows stacks 1..3 as Stored rises" % (i + 1))
        ds.append(st)
    tp, tn = surf.hit((0.3, 5, zc + 0.3), (0, -1, 0))
    path = [tp + Vector((0, -0.02, 0))]
    for k in range(1, 9):
        a = k / 8 * math.tau * 1.15
        path.append(tp + Vector((0.07 * math.sin(a), 0.05 + 0.03 * k, 0.07 * (1 - math.cos(a)) + 0.008 * k)))
    tb = bmesh.new()
    tube_bm(tb, path, [0.05 - 0.004 * k for k in range(9)], 4)
    tail = paint(_obj("Tail", tb), "#FF8CB8")
    anim(tail, tp, (0, 1, 0), sway(12, 1.3), kick(25, 4.5, 0.3), lod_keep=True)
    ds.append(tail)
    loop = hang_loop("HangLoop", 0.0, 0.1, 0.035, "#FFC0DA", segments=8)
    ds.append(loop)
    return body, ds


# ------------------------------------------------------------------------------------------
# 5. Bubble Wand (Uncommon, Fizzy)
# ------------------------------------------------------------------------------------------

@launch("bubble_wand")
def b_bubble_wand(gid):
    tint = "#B9F3FF"
    R, tr, bead = 0.47, 0.075, 0.105
    neck_z = -0.98
    rc = Vector((0, 0, neck_z - R - bead + 0.02))
    lo, hi = Vector((-0.6, -0.12, rc.z - R - bead - 0.01)), Vector((0.6, 0.12, 0.0))
    ring_m = Matrix.Translation(rc) @ Matrix.Rotation(math.pi / 2, 4, "X")   # ring plane = XZ, local +Z -> world -Y (front)

    def shape(bm):
        torus_bm(bm, (0, 0, 0), R, tr, 40, 10, ring_m)
        for k in range(8):                                                       # flower beads round the ring
            a = math.pi / 2 + k * math.tau / 8
            ellipsoid_bm(bm, rc + Vector((R * math.cos(a), 0, R * math.sin(a))), (bead, bead * 0.95, bead), 12, 8)
        ellipsoid_bm(bm, (0, 0, -0.1), (0.12, 0.12, 0.11), 12, 8)            # hang knob
        for k in range(3):                                                       # braided twisted handle
            pts = []
            for i in range(14):
                t = i / 13
                a = k * math.tau / 3 + t * math.tau * 1.25
                pts.append((0.045 * math.cos(a), 0.045 * math.sin(a), -0.12 + t * (neck_z + 0.16)))
            tube_bm(bm, pts, 0.05, 8)
        ellipsoid_bm(bm, (0, 0, neck_z + 0.02), (0.11, 0.11, 0.09), 12, 8)       # collar into the ring
    body = remesh_union("Body", shape, voxel=0.018, target_tris=640, fit=(lo, hi))
    paint(body, tint, role="Body")
    ds = []
    Rf, dome = R - 0.02, 0.16

    def dome_pt(rho, ang, lift=0.004):
        z = dome * max(0.0, 1 - (rho / Rf) ** 2) + lift
        return ring_m @ Vector((rho * math.cos(ang), rho * math.sin(ang), z))
    fprof = [(0, -0.012), (Rf, -0.004)] + [(Rf * (1 - k / 5), dome * (1 - (1 - k / 5) ** 2) + 0.004) for k in range(0, 6)]
    fb = bmesh.new()
    lathe_into(fb, fprof, ring_m, 18)
    film = paint(_obj("Film", fb), "#F4E6FF", alpha=0.3, transmission=0.85)
    anim(film, rc, (0, -1, 0), pulse(0.06, 2.2), squash(1.6, 3.0, 0.3), lod_keep=True,
         note="soap film bulging out of the ring: idle = breathe along the axis; windup stretches it (1.6x)")
    bands = []
    for name, color, r0, a0, span in (("FilmRainbow_Pink", "#FF9CE0", 0.3, 2.3, 1.5), ("FilmRainbow_Cyan", "#8FF0FF", 0.22, 2.45, 1.25)):
        bb = bmesh.new()
        pts = [dome_pt(r0, a0 + span * k / 6, 0.012) for k in range(7)]
        tube_bm(bb, pts, [0.01, 0.022, 0.03, 0.032, 0.03, 0.022, 0.01], 4)
        band = paint(_obj(name, bb), color, alpha=0.75)
        anim(band, rc, (0, -1, 0), pulse(0.06, 2.2))
        follow(band, "Film", "iridescent band on the film; client may hue-cycle it")
        bands.append(band)
    gb = bmesh.new()
    tube_bm(gb, [dome_pt(0.3, -0.25 + 0.2 * k, 0.014) for k in range(5)], [0.012, 0.026, 0.03, 0.026, 0.012], 4)
    ellipsoid_bm(gb, dome_pt(0.16, 0.55, 0.02), (0.035, 0.035, 0.02), 6, 4)
    glint = paint(_obj("FilmGlint", gb), "#FFFFFF", "Neon")
    anim(glint, rc, (0, -1, 0), pulse(0.06, 2.2))
    follow(glint, "Film", "rides the film bulge")
    ds += [film, *bands, glint]
    for i, (p, r) in enumerate((((0.66, -0.06, rc.z + 0.5), 0.11), ((-0.72, -0.02, rc.z - 0.28), 0.075))):
        bb = bmesh.new()
        ellipsoid_bm(bb, p, (r, r, r), 8, 5)
        bub = paint(_obj(f"Bubble_{i + 1}", bb), "#F2FCFF", alpha=0.3, transmission=0.85)
        anim(bub, p, (0, 0, 1), bob(0.06, 1.6 + 0.35 * i, i * 1.9), hop(0.08, 3.0, 0.3))
        ds.append(bub)
    grip = paint(lathe3("HandleGrip", [(0, -0.82), (0.085, -0.82), (0.105, -0.78), (0.105, -0.7), (0.09, -0.66), (0.105, -0.62), (0.105, -0.5),
                                        (0.09, -0.46), (0.105, -0.42), (0.105, -0.34), (0.085, -0.3), (0, -0.3)], 0.0, 8, sharp_deg=40), "#C9A8FF")
    ds.append(grip)
    bow_c = Vector((0, -0.11, neck_z + 0.02))
    bw = bmesh.new()
    for sgn in (-1, 1):
        slab_bm(bw, [(0, 0), (sgn * 0.13, 0.1), (sgn * 0.22, 0.0), (sgn * 0.11, -0.08)][::sgn], 0.05, 0.02, 1, Matrix.Translation(bow_c))
        slab_bm(bw, [(0, 0), (sgn * 0.09, -0.2), (sgn * 0.03, -0.17)][::sgn], 0.035, 0, 1, Matrix.Translation(bow_c + Vector((0, -0.01, -0.03))))
    ellipsoid_bm(bw, bow_c + Vector((0, -0.015, 0)), (0.05, 0.04, 0.05), 6, 4)
    bow = paint(_obj("Bow", bw), "#FF9CE0", "SmoothPlastic")
    anim(bow, bow_c, (0, 1, 0), sway(5, 1.9), kick(14))
    ds.append(bow)
    return body, ds


# ------------------------------------------------------------------------------------------
# 6. Crystal Ball (Epic, Fizzy)
# ------------------------------------------------------------------------------------------

@launch("crystal_ball")
def b_crystal_ball(gid):
    tint, gold, mist = "#C9B5FF", "#FFE07A", "#9B7BFF"
    R = 0.8
    c = Vector((0, 0, -0.24 - R))
    prof = [(0, -R)] + [(R * math.cos(math.radians(a)), R * math.sin(math.radians(a))) for a in range(-72, 73, 18)] + [(0.2, R * 0.975), (0, R * 0.985)]
    prof = [(r, z + R + 0.0) for r, z in prof]
    body = paint(lathe3("Body", prof, -c.z + R, 22, sharp_deg=None), tint, role="Body")
    ds = []
    cap = lathe3("HangCap", [(0, -0.3), (0.2, -0.3), (0.25, -0.26), (0.22, -0.18), (0.08, -0.14), (0, -0.14)], 0.0, 12, sharp_deg=40)
    paint(cap, gold, "Metal")
    lp = hang_loop("HangLoop", 0.0, 0.08, 0.03, gold, "Metal")
    ds += [cap, lp]
    # Claw-foot stand under the ball.
    stb = bmesh.new()
    lathe_into(stb, [(0, -0.1), (0.4, -0.1), (0.44, -0.03), (0.34, 0.05), (0.12, 0.2), (0, 0.2)],
               Matrix.Translation(c + Vector((0, 0, -R - 0.17))), 12)
    band_z = c.z - R * 0.62
    band_r = math.sqrt(R * R - (band_z - c.z) ** 2) + 0.03
    torus_bm(stb, (0, 0, band_z), band_r, 0.04, 16, 3)
    for k in range(3):
        a = k * math.tau / 3 + math.pi / 2 + math.pi / 3
        pts = []
        for i in range(5):
            t = i / 4
            ang = math.radians(-118 + t * 62)
            rr = (R + 0.03) * math.cos(ang)
            pts.append((rr * math.cos(a), rr * math.sin(a), c.z + (R + 0.03) * math.sin(ang)))
        tube_bm(stb, pts, [0.065, 0.06, 0.05, 0.04, 0.025], 5)
    stand = paint(_obj("Stand", stb), gold, "Metal")
    anim(stand, (0, 0, c.z), (1, 0, 0), None, kick(4), note="the stand is part of the toy; small rattle on hits")
    rb = bmesh.new()
    for k in range(6):
        a = k * math.tau / 6 + math.pi / 6
        gem_bm(rb, (band_r * math.cos(a), band_r * math.sin(a), band_z), 0.035, 0.07, 4, Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "Y"))
    runes = paint(_obj("RuneGems", rb, smooth=False), gold, "Neon")
    anim(runes, (0, 0, band_z), (0, 0, 1), pulse(0.06, 1.8), flash(0.25), note="gold rune lights; windup = rune circle glow")
    ds += [stand, runes]
    shell = as_inner(paint(blob("MistShell", c, (0.68, 0.68, 0.68), 12, 7), mist, alpha=0.4, transmission=0.6))
    anim(shell, c, (0, 0, 1), spin(10), spin_boost(160, 1.2), note="inner mist layer (two-layer glass)")
    sw = bmesh.new()
    tilt = Matrix.Translation(c) @ Matrix.Rotation(-0.35, 4, "X") @ Matrix.Rotation(0.25, 4, "Y")
    for arm in range(2):
        pts = []
        for i in range(10):
            t = i / 9
            a = arm * math.tau / 2 + t * 3.4
            rr = 0.1 + 0.46 * t
            pts.append(tilt @ Vector((rr * math.cos(a), rr * math.sin(a), 0.05 * math.sin(t * 6))))
        tube_bm(sw, pts, [0.11 * (1 - 0.7 * i / 9) + 0.02 for i in range(10)], 4)
    inv = tilt.inverted()
    for v in sw.verts:  # flatten the tubes into wispy ribbons lying in the swirl plane
        local = inv @ v.co
        local.z *= 0.3
        v.co = tilt @ local
    swirl = paint(_obj("NebulaSwirl", sw), "#F08CFF", "Neon")
    anim(swirl, c, tilt.to_3x3() @ Vector((0, 0, 1)), spin(30), flash(0.2), lod_keep=True,
         note="speeds up through windup (Foresight anticipation)")
    eb = bmesh.new()
    eye_pts = [(-0.15, 0.01), (-0.08, 0.035), (0.0, 0.04), (0.08, 0.035), (0.15, 0.01), (0.08, -0.06), (0.0, -0.075), (-0.08, -0.06)]
    for s in (-1, 1):
        slab_bm(eb, eye_pts, 0.04, 0, 1, Matrix.Translation(c + Vector((s * 0.22, -0.56, 0.16))) @ Matrix.Rotation(-s * 0.12, 4, "Y"))
    eyes = paint(_obj("MistEyes", eb), "#FFE9A0", "Neon")
    anim(eyes, c + Vector((0, -0.5, 0.12)), (0, 0, 1), pulse(0.12, 2.6), flash(0.3), extra_idle=[blink(5.0, 0.18)], lod_keep=True,
         note="smug half-lidded eyes in the mist; glow at Ready")
    star = bmesh.new()
    slab_bm(star, star_points(4, 0.09, 0.03), 0.04, 0, 1, Matrix.Translation(c + Vector((0, -0.2, -0.18))) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    core = paint(_obj("StarSeed", star), "#FFFFFF", "Neon")
    anim(core, c + Vector((0, -0.2, -0.18)), (0, 1, 0), spin(45), flash(0.25), extra_idle=[pulse(0.15, 1.3)])
    ds += [shell, swirl, eyes, core]
    for i, (a, z, r) in enumerate(((-0.35, 0.42, 0.98), (3.5, -0.2, 1.0), (2.2, 0.62, 0.86))):
        p = c + Vector((r * math.cos(a), r * math.sin(a), z))
        spb = bmesh.new()
        slab_bm(spb, star_points(4, 0.11, 0.032), 0.035, 0, 1, Matrix.Translation(p) @ Matrix.Rotation(0.3 * i, 4, "Y"))
        spk = paint(_obj(f"Sparkle_{i + 1}", spb), gold, "Neon")
        anim(spk, c, (0, 0, 1), spin(35 + 10 * i), spin_boost(260))
        ds.append(spk)
    return body, ds


# ------------------------------------------------------------------------------------------
# 7. Honey Bear (Epic, Heavy)
# ------------------------------------------------------------------------------------------

def drip(period=3.2, grow=2.2, fall=0.3):
    return {"type": "drip", "period_s": period, "grow_s": grow, "fall_studs": fall}


def hex_points(r, rot=0.0):
    return [(r * math.cos(rot + k * math.tau / 6), r * math.sin(rot + k * math.tau / 6)) for k in range(6)]


@launch("honey_bear")
def b_honey_bear(gid):
    tint, honey, cream, dark = "#FFB92E", "#E87A00", "#FFE2A8", "#5A3214"
    head_c = Vector((0, -0.04, -0.74))
    torso_c = Vector((0, 0.02, -1.48))
    lo, hi = Vector((-0.8, -0.66, -2.14)), Vector((0.8, 0.62, -0.31))

    def shape(bm):
        ellipsoid_bm(bm, head_c, (0.5, 0.46, 0.43), 18, 12)
        ellipsoid_bm(bm, torso_c, (0.66, 0.6, 0.6), 20, 12)
        ellipsoid_bm(bm, (0, -0.02, -1.08), (0.36, 0.34, 0.2), 12, 8)                     # neck fill
        for s in (-1, 1):
            ellipsoid_bm(bm, (s * 0.56, -0.26, -1.36), (0.2, 0.2, 0.3), 10, 8, Quaternion((0, 1, 0), s * 0.5))  # paws
            ellipsoid_bm(bm, (s * 0.36, -0.3, -1.98), (0.22, 0.26, 0.16), 10, 6)           # feet
    body = remesh_union("Body", shape, voxel=0.03, target_tris=400, fit=(lo, hi))
    paint(body, tint, role="Body", alpha=0.8, transmission=0.55)
    surf = Surface(body)
    ds = face(surf, head_c, 0.19, head_c.z + 0.08, eye=(0.075, 0.095, 0.045), cheek_dx=0.3, cheek_dz=-0.14,
              seg=(8, 5), shine_seg=((5, 3), (4, 3)), cheek_seg=(6, 3))
    mp, mn = surf.hit(head_c + Vector((0, -5, -0.13)), (0, 1, 0))
    muzzle = paint(blob("Muzzle", mp + mn * 0.02, (0.2, 0.12, 0.14), 8, 5), cream)
    nose = paint(blob("Nose", mp + mn * 0.13 + Vector((0, 0, 0.06)), (0.07, 0.045, 0.05), 6, 4), dark, "SmoothPlastic")
    smb = bmesh.new()
    msurf = Surface(muzzle)
    smile_bm(smb, msurf, mp, 0.12, mp.z - 0.035, curve=0.035, steps=4, r=0.014)
    smile = paint(_obj("Smile", smb), dark, "SmoothPlastic")
    ds += [muzzle, nose, smile]
    for side, label in ((-1, "L"), (1, "R")):
        root = head_c + Vector((side * 0.33, 0.02, 0.32))
        eb = bmesh.new()
        lathe_into(eb, [(0, -0.05), (0.13, -0.05), (0.16, 0.0), (0.13, 0.05), (0, 0.05)],
                   Matrix.Translation(root) @ Matrix.Rotation(math.pi / 2, 4, "X") @ Matrix.Rotation(side * -0.3, 4, "Y"), 10)
        ear = paint(_obj("Ear_" + label, eb), tint)
        anim(ear, root + Vector((0, 0, -0.08)), (0, 1, 0), sway(6, 1.8, side * 0.7), flare(18), lod_keep=(side < 0), note="ear wiggle")
        ds.append(ear)
    cap = lathe3("Cap", [(0, -0.4), (0.25, -0.4), (0.27, -0.36), (0.27, -0.3), (0.2, -0.26), (0.11, -0.2), (0.06, -0.15), (0.05, -0.04), (0.03, 0.0), (0, 0.0)], 0.0, 12, sharp_deg=40)
    paint(cap, "#FF7A3D", "SmoothPlastic")
    anim(cap, (0, 0, -0.35), (1, 0, 0), None, kick(6))
    dp = Vector((0.13, -0.1, -0.33))
    db = bmesh.new()
    lathe_into(db, [(0, -0.07), (0.035, -0.055), (0.045, -0.025), (0.03, 0.01), (0.012, 0.04), (0, 0.05)], Matrix.Translation(dp), 6)
    drop = paint(_obj("HoneyDrip", db), honey, alpha=0.85)
    anim(drop, dp + Vector((0, 0, 0.05)), (0, 0, -1), drip(3.4, 2.4, 0.32), None, lod_keep=True,
         note="a drop swells at the cap rim, slides down the head and resets")
    ds += [cap, drop]
    fill = bmesh.new()
    ellipsoid_bm(fill, torso_c + Vector((0, 0, -0.02)), (0.56, 0.5, 0.52), 14, 9)
    fill = rcut(fill, torso_c + Vector((0, 0, 0.16)), Vector((0, 0, 1)), True)
    honey_fill = as_inner(paint(_obj("HoneyFill", fill), honey, alpha=0.65, transmission=0.6))
    anim(honey_fill, torso_c + Vector((0, 0, 0.16)), (1, 0, 0), slosh(10, 0.25), squash(0.9, 4.0, 0.35),
         note="amber honey inside (second glass layer)")
    hb = bmesh.new()
    hc = torso_c + Vector((0, -0.4, -0.04))
    for dx, dz in ((0, 0), (-0.13, -0.075), (0.13, -0.075)):
        slab_bm(hb, hex_points(0.072, math.pi / 6), 0.04, 0, 1, Matrix.Translation(hc + Vector((dx, 0, dz))) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    comb = paint(_obj("HoneycombCore", hb, smooth=False), "#FFC23A", "Neon")
    anim(comb, hc, (0, 1, 0), pulse(0.08, 1.4), flash(0.25), note="Epic core: glows brighter at Ready")
    ds += [honey_fill, comb]
    bow_c = surf.hit(Vector((0, -5, -1.09)), (0, 1, 0))[0] + Vector((0, -0.03, 0))
    bw = bmesh.new()
    for s in (-1, 1):
        slab_bm(bw, [(0, 0), (s * 0.14, 0.1), (s * 0.24, 0.02), (s * 0.13, -0.09)][::s], 0.06, 0.025, 1, Matrix.Translation(bow_c))
    ellipsoid_bm(bw, bow_c + Vector((0, -0.02, 0)), (0.06, 0.045, 0.06), 6, 4)
    bow = paint(_obj("Bow", bw), "#FF9DB8", "SmoothPlastic")
    anim(bow, bow_c, (0, 1, 0), sway(4, 2.2), kick(14), note="Jam family cue (pink gingham bow)")
    ds.append(bow)
    return body, ds


# ------------------------------------------------------------------------------------------
# 8. Potion Flask (Rare, Fizzy)
# ------------------------------------------------------------------------------------------

@launch("potion_flask")
def b_potion_flask(gid):
    tint, brew = "#6CFF9A", "#2EE87A"
    R = 0.75
    cz = 0.75
    neck_r = 0.15
    a0 = math.degrees(math.asin(neck_r / R))
    arc = [(R * math.cos(math.radians(a)), cz + R * math.sin(math.radians(a))) for a in (-75, -60, -45, -30, -15, 0, 15, 30, 45, 58, 70, 90 - a0 - 4)]
    neck_top = cz + R + 0.5
    prof = [(0, 0.0)] + arc + [(neck_r, cz + R + 0.12), (neck_r - 0.01, neck_top - 0.12), (neck_r + 0.05, neck_top - 0.06), (neck_r + 0.05, neck_top - 0.01), (0.1, neck_top), (0, neck_top)]
    cork_top = neck_top + 0.22
    h = cork_top
    body = paint(lathe3("Body", prof, h, 22, sharp_deg=50), tint, role="Body")
    ds = []
    cork = paint(lathe3("Cork", [(0, neck_top - 0.13), (0.11, neck_top - 0.13), (0.14, neck_top + 0.02), (0.16, neck_top + 0.17),
                                  (0.14, cork_top - 0.01), (0, cork_top)], h, 12, sharp_deg=40), "#C8955A", "SmoothPlastic")
    anim(cork, (0, 0, neck_top - h), (0, 0, 1), None, hop(0.12, 5.0, 0.3), lod_keep=True, note="cork pops up on anticipation")
    ds.append(cork)
    liquid_z = cz + 0.22
    lr = R - 0.07
    top_a = math.degrees(math.asin((liquid_z - cz) / lr))
    lprof = [(0, cz - lr)] + [(lr * math.cos(math.radians(a)), cz + lr * math.sin(math.radians(a))) for a in (-70, -45, -20, 0, top_a)] + [(0, liquid_z)]
    liquid = as_inner(paint(lathe3("BrewLiquid", lprof, h, 16, sharp_deg=50), brew, alpha=0.6, transmission=0.6))
    lpivot = (0, 0, liquid_z - h)
    anim(liquid, lpivot, (1, 0, 0), slosh(14, 0.35), None, lod_keep=True,
         note="client tweens Color to the next brew: slow #6CFF9A (green), mark #FF7AC8 (pink), heal #FFD34E (gold)")
    sr = lr * math.cos(math.radians(top_a))
    sb = bmesh.new()
    lathe_into(sb, [(0, -0.008), (sr - 0.015, -0.008), (sr - 0.005, 0.006), (0, 0.014)], Matrix.Translation((0, 0, liquid_z - h + 0.006)), 18)
    surface = paint(_obj("BrewSurface", sb), "#C6FFD9", alpha=0.6)
    anim(surface, lpivot, (0, 1, 0), sway(3, 1.3), None)
    follow(surface, "BrewLiquid", "tints with the brew (lighter)")
    glow = paint(blob("BrewGlow", (0, 0, cz - 0.08 - h), (0.24, 0.24, 0.22), 8, 5), "#B8FFD0", "Neon")
    anim(glow, (0, 0, cz - 0.08 - h), (0, 0, 1), pulse(0.12, 1.5), flash(0.3), note="Rare emissive accent; tints with the brew")
    ds += [liquid, surface, glow]
    for i, (x, y, z, r) in enumerate(((0.28, -0.32, 0.5, 0.07), (-0.24, -0.36, 0.72, 0.055), (0.08, -0.42, 0.9, 0.045))):
        bub = paint(blob(f"Bubble_{i + 1}", (x, y, z - h), (r, r, r), 6, 4), "#F0FFF5", alpha=0.7)
        anim(bub, (x, y, z - h), (0, 0, 1), bob(0.08, 1.0 + 0.25 * i, i * 2.1), hop(0.1, 4.0, 0.3), note="rising bubbles; boil on anticipation")
        ds.append(bub)
    tw = bmesh.new()
    torus_bm(tw, (0, 0, cz + R + 0.17 - h), neck_r + 0.03, 0.028, 10, 3)
    tag_top = Vector((0.12, -0.12, cz + R + 0.15 - h))
    tube_bm(tw, [tag_top, tag_top + Vector((0.08, -0.04, -0.12)), tag_top + Vector((0.14, -0.06, -0.24))], 0.014, 4)
    twine = paint(_obj("Twine", tw), "#9A6BE0", "SmoothPlastic")
    tg = bmesh.new()
    tag_c = tag_top + Vector((0.17, -0.07, -0.36))
    slab_bm(tg, [(-0.1, -0.13), (0.1, -0.13), (0.1, 0.08), (0.0, 0.14), (-0.1, 0.08)], 0.03, 0.012, 1,
            Matrix.Translation(tag_c) @ Matrix.Rotation(0.25, 4, "Y") @ Matrix.Rotation(-0.35, 4, "Z"))
    tag = paint(_obj("PotionTag", tg), "#FFF1D6", "SmoothPlastic")
    anim(tag, tag_top, (0, 1, 0), sway(9, 1.6), kick(22), note="little label tag swings")
    stb = bmesh.new()
    slab_bm(stb, star_points(5, 0.06, 0.026), 0.012, 0, 1,
            Matrix.Translation(tag_c + Vector((0, -0.02, -0.02))) @ Matrix.Rotation(0.25, 4, "Y") @ Matrix.Rotation(-0.35, 4, "Z"))
    tstar = paint(_obj("TagStar", stb), "#FF7AC8", "SmoothPlastic")
    anim(tstar, tag_top, (0, 1, 0), sway(9, 1.6), kick(22))
    follow(tstar, "PotionTag")
    ds += [twine, tag, tstar]
    return body, ds


# ------------------------------------------------------------------------------------------
# 9. Light Bulb (Rare, Sharp)
# ------------------------------------------------------------------------------------------

@launch("light_bulb")
def b_light_bulb(gid):
    tint, metal = "#FFF4A8", "#C9D3E0"
    # Hung upside down from the base tip: z is measured downward from the hang point here, then negated.
    base_bot = 0.52
    ctrl = [(0.18, base_bot - 0.04), (0.2, base_bot + 0.08), (0.27, base_bot + 0.3), (0.5, base_bot + 0.62), (0.7, base_bot + 0.98),
            (0.75, base_bot + 1.22), (0.68, base_bot + 1.5), (0.42, base_bot + 1.7), (0.0, base_bot + 1.76)]
    pts = resample(spline([(r, 0, z) for r, z in ctrl], 64), 15)
    prof = [(0, base_bot - 0.04)] + [(max(p.x, 0.0), p.z) for p in pts]
    prof[-1] = (0.0, prof[-1][1])
    prof = [(r, -z) for r, z in prof]            # flip: tip down
    prof.reverse()
    body = paint(lathe3("Body", prof, 0.0, 22, sharp_deg=None), tint, role="Body")
    # lathe3 shifts by -hang (0) so z already equals the hung position.
    ds = []
    thread = []
    for k in range(12):
        z = 0.11 + k * (base_bot - 0.11) / 11
        thread.append((0.255 if k % 2 == 0 else 0.285, z))
    bprof = [(0, 0.1), (0.2, 0.1)] + thread + [(0.21, base_bot + 0.02), (0, base_bot + 0.02)]
    base = paint(lathe3("ScrewBase", [(r, -z) for r, z in reversed(bprof)], 0.0, 12, sharp_deg=35), metal, "Metal")
    anim(base, (0, 0, -0.1), (1, 0, 0), None, kick(4))
    tip = paint(lathe3("BaseTip", [(0, -0.12), (0.17, -0.12), (0.17, -0.07), (0.08, -0.03), (0, 0.0)], 0.0, 12, sharp_deg=35), "#3A3F4A", "SmoothPlastic")
    ds += [base, tip]
    gc = Vector((0, 0, -(base_bot + 1.12)))
    stem = paint(lathe3("Stem", [(0, -(base_bot + 0.62)), (0.06, -(base_bot + 0.58)), (0.1, -(base_bot + 0.12)), (0.14, -(base_bot - 0.02)), (0, -(base_bot - 0.02))], 0.0, 10, sharp_deg=None),
                 "#FFFBE0", alpha=0.6)
    wb = bmesh.new()
    ends = []
    for s in (-1, 1):
        a = Vector((s * 0.03, 0, -(base_bot + 0.58)))
        b = gc + Vector((s * 0.2, 0, 0.06))
        tube_bm(wb, [a, a.lerp(b, 0.5) + Vector((s * 0.03, 0, 0)), b], 0.012, 4)
        ends.append(b)
    wires = paint(_obj("SupportWires", wb), metal, "Metal")
    fb = bmesh.new()
    coil = []
    for i in range(22):
        t = i / 21
        p = ends[0].lerp(ends[1], t)
        a = t * math.tau * 5
        coil.append(p + Vector((0, 0.035 * math.cos(a), 0.035 * math.sin(a) - 0.05 * math.sin(math.pi * t))))
    tube_bm(fb, coil, 0.016, 4)
    fil = paint(_obj("Filament", fb), "#FFE680", "Neon")
    anim(fil, gc, (0, 0, 1), flicker(0.06, 9), flash(0.3), lod_keep=True,
         note="idle flicker; brightens one step per Charge; blazes during the 4 s drain arm")
    glow = as_inner(paint(blob("InnerGlow", gc + Vector((0, 0, 0.02)), (0.36, 0.36, 0.33), 12, 7), "#FFF08A", alpha=0.35, transmission=0.7))
    anim(glow, gc, (0, 0, 1), pulse(0.06, 1.8), flash(0.3), note="soft inner glow layer (second glass layer); add a PointLight here in Studio")
    ds += [stem, wires, fil, glow]
    spb = bmesh.new()
    zig = [(-0.05, 0.22), (0.08, 0.22), (0.02, 0.04), (0.1, 0.04), (-0.06, -0.22), (-0.01, -0.02), (-0.09, -0.02)]
    slab_bm(spb, zig, 0.03, 0, 1, Matrix.Translation(gc + Vector((0.42, -0.55, 0.32))) @ Matrix.Rotation(-0.2, 4, "Y"))
    spark = paint(_obj("IdeaSpark", spb, smooth=False), "#FFFFFF", "Neon")
    spark["effect_only"] = True
    anim(spark, gc, (0, 0, 1), None, flash(0.3), note="effect-only: a little lightning glint the client pops at Ready")
    ds.append(spark)
    return body, ds


# ------------------------------------------------------------------------------------------
# 10. Grizzly Guardian (Legendary, Heavy)
# ------------------------------------------------------------------------------------------

def plate_bm(bm, centre, normal, w, hgt, depth=0.06, tilt=0.0):
    """Faceted crystal shield plate lying on a surface (flat-shaded gem cut)."""
    pts = [(-w * 0.5, hgt * 0.32), (0.0, hgt * 0.5), (w * 0.5, hgt * 0.32), (w * 0.42, -hgt * 0.22), (0.0, -hgt * 0.5), (-w * 0.42, -hgt * 0.22)]
    m = Matrix.Translation(Vector(centre)) @ facing(normal) @ Matrix.Rotation(math.radians(tilt), 4, "Z") @ Matrix.Rotation(-math.pi / 2, 4, "X")
    slab_bm(bm, pts, depth, depth * 0.45, 1, m)
    return bm


@launch("grizzly_guardian")
def b_grizzly_guardian(gid):
    tint, ice, cream, dark, gold = "#FFC96B", "#EAF6FF", "#FFE6B8", "#4A2E1A", "#FFE9A8"
    head_c = Vector((0, -0.16, -0.68))
    torso_c = Vector((0, 0.02, -1.66))
    lo, hi = Vector((-1.0, -0.98, -2.56)), Vector((1.0, 0.82, -0.2))

    def shape(bm):
        ellipsoid_bm(bm, head_c, (0.56, 0.5, 0.48), 20, 14)
        ellipsoid_bm(bm, torso_c, (0.9, 0.78, 0.8), 24, 16)
        ellipsoid_bm(bm, (0, -0.06, -1.15), (0.52, 0.46, 0.3), 14, 10)
        for s in (-1, 1):
            ellipsoid_bm(bm, (s * 0.78, -0.24, -1.52), (0.27, 0.28, 0.48), 12, 10, Quaternion((0, 1, 0), s * 0.35))
            ellipsoid_bm(bm, (s * 0.6, -0.46, -1.96), (0.22, 0.22, 0.2), 10, 8)
            ellipsoid_bm(bm, (s * 0.5, -0.5, -2.3), (0.3, 0.44, 0.26), 14, 10)
    body = remesh_union("Body", shape, voxel=0.028, target_tris=980, fit=(lo, hi))
    paint(body, tint, role="Body", alpha=0.85, transmission=0.5)
    surf = Surface(body)
    ds = face(surf, head_c, 0.21, head_c.z + 0.1, eye=(0.09, 0.115, 0.05), cheek_dx=0.34, cheek_dz=-0.16, seg=(10, 7))
    eye_motion = json.loads(ds[0]["motion_json"])
    eye_motion["note"] = "eyes glow gold (#FFE9A8 Neon) at Ready"
    ds[0]["motion_json"] = json.dumps(eye_motion)
    mp, mn = surf.hit(head_c + Vector((0, -5, -0.15)), (0, 1, 0))
    muzzle = paint(blob("Muzzle", mp + mn * 0.03, (0.25, 0.15, 0.18), 12, 8), cream)
    msurf = Surface(muzzle)
    np_, nn = msurf.hit(mp + Vector((0, -5, 0.07)), (0, 1, 0))
    nose = paint(blob("Nose", np_ + nn * 0.02, (0.1, 0.06, 0.07), 8, 6), dark, "SmoothPlastic")
    smb = bmesh.new()
    smile_bm(smb, msurf, mp, 0.14, mp.z - 0.06, curve=0.04, steps=5, r=0.016)
    smile = paint(_obj("Smile", smb), dark, "SmoothPlastic")
    bb = bmesh.new()
    for s in (-1, 1):
        bp, bn = surf.hit(head_c + Vector((s * 0.2, -5, 0.29)), (0, 1, 0))
        feature_bm(bb, bp, bn, (0.095, 0.028, 0.022), 0.3, 8, 4, s * 18)
    brows = paint(_obj("Brows", bb), "#8A5A30", "SmoothPlastic")
    anim(brows, head_c + Vector((0, -0.45, 0.29)), (0, 0, 1), None, hop(0.03, 5.0, 0.4), note="brows furrow (hop down) at Ready")
    ds += [muzzle, nose, smile, brows]
    for side, label in ((-1, "L"), (1, "R")):
        root = head_c + Vector((side * 0.4, 0.04, 0.36))
        eb = bmesh.new()
        lathe_into(eb, [(0, -0.06), (0.15, -0.06), (0.18, 0.0), (0.15, 0.06), (0, 0.06)],
                   Matrix.Translation(root) @ Matrix.Rotation(math.pi / 2, 4, "X") @ Matrix.Rotation(side * -0.35, 4, "Y"), 12)
        ear = paint(_obj("Ear_" + label, eb), tint)
        anim(ear, root + Vector((0, 0, -0.1)), (0, 0, 1), sway(10, 3.0, side * 1.1), flare(16), lod_keep=(side < 0), note="ears swivel")
        ib = bmesh.new()
        lathe_into(ib, [(0, -0.02), (0.09, -0.02), (0.1, 0.0), (0.09, 0.02), (0, 0.02)],
                   Matrix.Translation(root + Vector((0, -0.06, -0.01))) @ Matrix.Rotation(math.pi / 2, 4, "X") @ Matrix.Rotation(side * -0.35, 4, "Y"), 10)
        inner = paint(_obj("EarInner_" + label, ib), "#FFB08A", "SmoothPlastic")
        anim(inner, root + Vector((0, 0, -0.1)), (0, 0, 1), sway(10, 3.0, side * 1.1), flare(16))
        follow(inner, "Ear_" + label)
        ds += [ear, inner]
    # Crystal guard plates: fold across the chest when the guard is raised.
    for side, label in ((-1, "L"), (1, "R")):
        pp, pn = surf.hit(torso_c + Vector((side * 0.34, -5, 0.3)), (0, 1, 0))
        pb = bmesh.new()
        plate_bm(pb, pp + pn * 0.03, pn, 0.36, 0.5, 0.07, side * 8)
        plate = paint(_obj("ChestPlate_" + label, pb, smooth=False), ice)
        hinge = torso_c + Vector((side * 0.62, -0.5, 0.45))
        anim(plate, hinge, (0, 0, 1), pulse(0.02, 3.2), kick(8), lod_keep=(side < 0),
             note="guard: client folds the plate ~60 deg about this hinge so the two plates meet over the chest; lights ice-white")
        ds.append(plate)
    hp, hn = surf.hit(torso_c + Vector((0, -5, 0.28)), (0, 1, 0))
    gb = bmesh.new()
    gem_bm(gb, hp + hn * 0.06, 0.1, 0.24, 6, facing(hn) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    heart = paint(_obj("HeartCore", gb, smooth=False), gold, "Neon")
    anim(heart, hp, (0, 0, 1), pulse(0.06, 3.2), flash(0.3), lod_keep=True, note="Legendary core; breathes with the chest")
    belly = as_inner(paint(blob("BellyGlass", torso_c + Vector((0, -0.04, -0.02)), (0.76, 0.64, 0.66), 14, 9), "#FFF1D0", alpha=0.35, transmission=0.6))
    anim(belly, torso_c, (0, 0, 1), pulse(0.03, 3.2), squash(0.92, 4.0, 0.35), note="inner glass layer; the chest heave (breathing)")
    ds += [heart, belly]
    sc = bmesh.new()
    for s in (-1, 1):
        base = Vector((s * 0.72, 0.0, -1.08))
        for k, (dx, dz, tilt, size) in enumerate(((0, 0.1, 0.25, 1.0), (s * 0.13, 0.0, 0.7, 0.75), (-s * 0.12, 0.02, -0.25, 0.7))):
            gem_bm(sc, base + Vector((dx, 0.05 * k, dz)), 0.07 * size, 0.3 * size, 5, Matrix.Rotation(s * tilt, 4, "Y"))
    shoulders = paint(_obj("ShoulderCrystals", sc, smooth=False), ice)
    anim(shoulders, (0, 0, -1.08), (0, 0, 1), None, flash(0.25))
    bg = bmesh.new()
    gp, gn = surf.hit(head_c + Vector((0, -5, 0.32)), (0, 1, 0))
    gem_bm(bg, gp + gn * 0.03, 0.05, 0.12, 4, facing(gn) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    browgem = paint(_obj("BrowGem", bg, smooth=False), "#8FE3FF", "Neon")
    anim(browgem, gp, (0, 0, 1), pulse(0.08, 2.4), flash(0.3), note="flares at Ready")
    pad = bmesh.new()
    for s in (-1, 1):
        sole = Vector((s * 0.5, -0.5, -2.3))
        pp, pn = surf.hit(sole + Vector((0, -5, -0.02)), (0, 1, 0))
        feature_bm(pad, pp, pn, (0.13, 0.1, 0.03), 0.4, 8, 5)
        for k, (dx, dz) in enumerate(((-0.12, 0.13), (0.0, 0.17), (0.12, 0.13))):
            tp, tn = surf.hit(sole + Vector((dx, -5, dz)), (0, 1, 0))
            feature_bm(pad, tp, tn, (0.05, 0.045, 0.025), 0.4, 6, 4)
    pads = paint(_obj("PawPads", pad), "#E8957A", "SmoothPlastic")
    ring = hang_loop("HangRing", 0.0, 0.11, 0.04, "#E9D2A0", "Metal")
    ds += [shoulders, browgem, pads, ring]
    return body, ds


# ------------------------------------------------------------------------------------------
# 11. Glass Unicorn (Legendary, Sharp)
# ------------------------------------------------------------------------------------------

@launch("glass_unicorn")
def b_glass_unicorn(gid):
    tint, horn_c, hoof_c = "#FFD6F5", "#FFF1C9", "#C9A8FF"
    rainbow = ("#FF8FC8", "#FFD36E", "#8FE3FF")
    # Plush-style chibi sitting up on its haunches with one front hoof raised (the prance), so the head stacks
    # over the body and the hang point sits on top of the head behind the horn (like the Dragon).
    # Authored facing -Y at scale 1; `turn` gives a slight three-quarter head-on look; k scales to Radius 0.8.
    turn = Matrix.Rotation(-0.32, 4, "Z")
    tq = turn.to_quaternion()
    parts = [((0, -0.04, -0.6), (0.42, 0.38, 0.38), None),                        # head
             ((0, -0.36, -0.74), (0.24, 0.2, 0.19), Quaternion((1, 0, 0), 0.2)),   # snout
             ((0, 0.04, -0.98), (0.25, 0.25, 0.27), None),                          # neck
             ((0, 0.08, -1.4), (0.46, 0.48, 0.48), None),                           # chest / belly
             ((0, -0.2, -1.66), (0.12, 0.12, 0.3), None),                           # planted front leg (left)
             ((0.24, -0.36, -1.36), (0.1, 0.1, 0.24), Quaternion((1, 0, 0), 1.05)), # raised front leg (right), upper
             ((0.25, -0.56, -1.48), (0.085, 0.085, 0.16), Quaternion((1, 0, 0), 0.2))]
    parts[4] = ((-0.2, -0.2, -1.66), parts[4][1], None)
    for s_ in (-1, 1):
        parts += [((s_ * 0.27, 0.24, -1.74), (0.3, 0.36, 0.3), None),               # haunches
                  ((s_ * 0.33, -0.12, -1.96), (0.12, 0.3, 0.11), None)]              # folded back legs

    def shape(bm):
        for at, radii, q in parts:
            ellipsoid_bm(bm, turn @ Vector(at), radii, 14, 10, tq @ q if q is not None else tq)
    body = remesh_union("Body", shape, voxel=0.02, target_tris=1010)
    lo, hi = _world_bounds([body])
    k = 0.8 / max(-lo.x, hi.x, -lo.y, hi.y)
    top = hi.z * k
    for v in body.data.vertices:
        v.co = v.co * k - Vector((0, 0, top + 0.06))
    body.data.update()

    def P(x, y, z):
        return (turn @ Vector((x, y, z))) * k - Vector((0, 0, top + 0.06))
    paint(body, tint, role="Body", alpha=0.85, transmission=0.5)
    surf = Surface(body)
    head = P(0, -0.04, -0.6)
    ds = face(surf, head, 0.17 * k, head.z + 0.03 * k, eye=(0.08 * k, 0.11 * k, 0.045 * k), cheek_dx=0.25 * k, cheek_dz=-0.13 * k, seg=(10, 7))
    lb = bmesh.new()
    for s_ in (-1, 1):
        lp, ln = surf.hit(head + Vector((s_ * 0.26 * k, -5, 0.08 * k)), (0, 1, 0))
        tube_bm(lb, [lp + ln * 0.01, lp + ln * 0.03 + Vector((s_ * 0.05, 0, 0.05)) * k, lp + ln * 0.035 + Vector((s_ * 0.1, 0, 0.06)) * k],
                [0.018 * k, 0.012 * k, 0.005 * k], 4)
    lashes = paint(_obj("Lashes", lb), "#22323F", "SmoothPlastic")
    anim(lashes, head, (0, 0, 1), blink(4.0, 0.12))
    follow(lashes, "Eyes", "blinks with Eyes")
    np_, nn = surf.hit(P(0, -0.36, -0.78) + Vector((0, -5, 0)), (0, 1, 0))
    nb = bmesh.new()
    for s_ in (-1, 1):
        feature_bm(nb, surf.hit(np_ + Vector((s_ * 0.07 * k, -5, 0.0)), (0, 1, 0))[0], nn, (0.03 * k, 0.02 * k, 0.015 * k), 0.3, 6, 4)
    smile_bm(nb, surf, np_, 0.13 * k, np_.z - 0.075 * k, curve=0.03 * k, steps=5, r=0.014 * k)
    snout = paint(_obj("Nostrils", nb), "#C2508A", "SmoothPlastic")
    ds += [lashes, snout]
    # Spiral horn on the forehead (up and slightly forward) and the sparkle that climbs it.
    hb_ = P(0, -0.2, -0.3)
    hdir = (turn.to_3x3() @ Vector((0, -0.35, 1))).normalized()
    hm = Matrix.Translation(hb_) @ hdir.to_track_quat("Z", "Y").to_matrix().to_4x4()
    horn_len = 0.62 * k
    hprof = [(0, -0.02)]
    for i in range(9):
        t = i / 8
        hprof.append(((0.11 * (1 - t) + 0.008) * k * (1.0 + 0.12 * (i % 2)), t * horn_len))
    hprof.append((0, horn_len + 0.02 * k))
    hb = bmesh.new()
    lathe_into(hb, hprof, hm, 10)
    for v in hb.verts:  # twist the ridges into a spiral
        local = hm.inverted() @ v.co
        v.co = hm @ (Matrix.Rotation(local.z / horn_len * math.tau * 1.4, 3, "Z") @ local)
    horn = paint(_obj("Horn", hb), horn_c)
    anim(horn, hb_, hdir, None, kick(6), note="charges up (Neon flash) at Ready")
    spb = bmesh.new()
    slab_bm(spb, star_points(4, 0.07 * k, 0.022 * k), 0.025 * k, 0, 1, Matrix.Translation(hb_ + hdir * horn_len * 0.35 + Vector((0.07, -0.05, 0)) * k))
    sparkle = paint(_obj("HornSparkle", spb), "#FFFFFF", "Neon")
    anim(sparkle, hb_, hdir, spin(220), flash(0.3), lod_keep=True, extra_idle=[bob(0.18 * k, 1.4)],
         note="spins round the horn axis while bobbing along it, so it climbs the spiral")
    ds += [horn, sparkle]
    eb = bmesh.new()
    for s_ in (-1, 1):
        ellipsoid_bm(eb, P(s_ * 0.27, 0.06, -0.3), (0.07 * k, 0.05 * k, 0.13 * k), 8, 5, tq @ Quaternion((0, 1, 0), s_ * 0.35))
    ears = paint(_obj("Ears", eb), tint)
    anim(ears, P(0, 0.06, -0.38), (0, 0, 1), sway(4, 2.8), flare(15))
    ds.append(ears)
    # Mane (forelock + two flowing ribbons down the back of the neck) and tail (sweeps out to the right).
    manes = [[(-0.06, -0.12, -0.24), (-0.2, -0.2, -0.32), (-0.3, -0.22, -0.5), (-0.36, -0.16, -0.66)],
             [(0.02, 0.1, -0.22), (0.12, 0.3, -0.42), (0.16, 0.42, -0.72), (0.12, 0.42, -1.0), (0.06, 0.36, -1.2)],
             [(-0.08, 0.16, -0.26), (-0.2, 0.34, -0.5), (-0.24, 0.44, -0.8), (-0.18, 0.42, -1.06), (-0.1, 0.36, -1.22)]]
    for i, (col, path) in enumerate(zip(rainbow, manes)):
        mp = spline([P(*q) for q in path], 9)
        mb = bmesh.new()
        tube_bm(mb, mp, [(0.085 - 0.065 * t / (len(mp) - 1)) * k for t in range(len(mp))], 5)
        mane = paint(_obj(f"Mane_{i + 1}", mb), col)
        anim(mane, mp[0], turn.to_3x3() @ Vector((1, 0, 0)), sway(6, 1.6, i * 0.7), flare(16), lod_keep=(i == 1),
             note="mane ribbon; lifts (flare) through windup")
        ds.append(mane)
    for i, col in enumerate(rainbow):
        off = (i - 1) * 0.06
        path = [(0.18, 0.52, -1.8 + off), (0.48, 0.6, -1.72 + off), (0.68 + 0.04 * i, 0.5, -1.48 + off),
                (0.72 + 0.06 * i, 0.38, -1.2 + off * 1.5), (0.6 + 0.08 * i, 0.3, -1.02 + off * 2)]
        tp = spline([P(*q) for q in path], 9)
        tb = bmesh.new()
        tube_bm(tb, tp, [(0.09 - 0.07 * t / (len(tp) - 1)) * k for t in range(len(tp))], 5)
        tail = paint(_obj(f"Tail_{i + 1}", tb), col)
        anim(tail, tp[0], (0, 0, 1), sway(9, 1.9, i * 0.8), kick(18))
        ds.append(tail)
    hv = bmesh.new()
    ellipsoid_bm(hv, P(-0.2, -0.2, -1.93), (0.13 * k, 0.13 * k, 0.07 * k), 10, 5, tq)
    ellipsoid_bm(hv, P(0.26, -0.62, -1.6), (0.1 * k, 0.1 * k, 0.065 * k), 10, 5, tq @ Quaternion((1, 0, 0), 0.2))
    for s_ in (-1, 1):
        ellipsoid_bm(hv, P(s_ * 0.33, -0.4, -1.98), (0.12 * k, 0.07 * k, 0.11 * k), 10, 5, tq)
    hooves = paint(_obj("Hooves", hv), hoof_c)
    anim(hooves, P(0, -0.2, -1.8), (0, 0, 1), None, flash(0.2), note="hoof-spark flash on the dash")
    cp = P(0, -0.3, -1.38)
    cb = bmesh.new()
    heart = [(0.0, -0.11), (0.1, -0.01), (0.11, 0.05), (0.07, 0.09), (0.025, 0.08), (0.0, 0.05), (-0.025, 0.08), (-0.07, 0.09), (-0.11, 0.05), (-0.1, -0.01)]
    slab_bm(cb, [(u * k * 1.4, v * k * 1.4) for u, v in heart], 0.06 * k, 0.015 * k, 1, Matrix.Translation(cp) @ turn)
    core = paint(_obj("RainbowCore", cb), "#FF9CE0", "Neon")
    anim(core, cp, (0, 0, 1), pulse(0.08, 1.3), flash(0.3), note="Legendary core; client may hue-cycle it during the rainbow dash")
    loop = hang_loop("HangLoop", 0.0, 0.07, 0.028, horn_c, segments=10)
    ds += [hooves, core, loop]
    return body, ds


# ------------------------------------------------------------------------------------------
# 12. Glass Phoenix (Mythic, Sharp)
# ------------------------------------------------------------------------------------------

def feather_outline(L, w, tip=0.85, lean=False):
    if lean:
        return [(0.0, -w * 0.6), (L * 0.55, -w), (L, 0.0), (L * 0.55, w), (0.0, w * 0.6)]
    return [(0.0, -w * 0.55), (L * 0.4, -w), (L * tip, -w * 0.55), (L, 0.0), (L * tip, w * 0.55), (L * 0.4, w), (0.0, w * 0.55)]


@launch("glass_phoenix")
def b_glass_phoenix(gid):
    tint, flame, gold, ember = "#FF7A2E", "#FFB13D", "#FFD34E", "#FFE38A"
    head_c = Vector((0, -0.2, -0.56))
    body_c = Vector((0, 0.0, -1.26))
    lo, hi = Vector((-0.85, -0.74, -1.98)), Vector((0.85, 0.66, -0.12))

    def shape(bm):
        ellipsoid_bm(bm, head_c, (0.46, 0.42, 0.42), 20, 14)
        ellipsoid_bm(bm, body_c, (0.74, 0.64, 0.68), 24, 16)
        ellipsoid_bm(bm, (0, -0.12, -0.92), (0.42, 0.38, 0.26), 14, 10)
        for s in (-1, 1):
            ellipsoid_bm(bm, (s * 0.38, -0.12, -0.78), (0.2, 0.2, 0.18), 10, 8)        # cheek fluff
    body = remesh_union("Body", shape, voxel=0.026, target_tris=800, fit=(lo, hi))
    paint(body, tint, role="Body", alpha=0.85, transmission=0.5)
    surf = Surface(body)
    ds = face(surf, head_c, 0.17, head_c.z + 0.06, eye=(0.08, 0.11, 0.05), cheek_dx=0.29, cheek_dz=-0.14, seg=(9, 6),
              shine_seg=((6, 4), (4, 3)), cheek_seg=(6, 3))
    bp, bn = surf.hit(head_c + Vector((0, -5, -0.1)), (0, 1, 0))
    bk = bmesh.new()
    lathe_into(bk, [(0, -0.02), (0.09, -0.02), (0.085, 0.05), (0.05, 0.12), (0, 0.16)],
               Matrix.Translation(bp) @ facing(bn + Vector((0, 0, -0.35))) @ Matrix.Diagonal((1.2, 0.8, 1, 1)), 10)
    beak = paint(_obj("Beak", bk), gold, "SmoothPlastic")
    anim(beak, bp, (1, 0, 0), None, kick(12), note="opens a little on the Rebirth cry")
    ds.append(beak)
    # Crest: three flame feathers sweeping up and back from the crown.
    cr = bmesh.new()
    crown = head_c + Vector((0, 0.05, 0.36))
    for i, (dx, tilt, L) in enumerate(((-0.12, -0.45, 0.42), (0.0, -0.15, 0.55), (0.12, 0.15, 0.42))):
        path = spline([crown + Vector((dx, 0, 0)), crown + Vector((dx * 1.4, 0.12, L * 0.55)), crown + Vector((dx * 1.8 + tilt * 0.1, 0.32, L))], 6)
        tube_bm(cr, path, [0.075, 0.068, 0.055, 0.04, 0.025, 0.012, 0.004][:len(path)], 4)
    crest = paint(_obj("Crest", cr), flame)
    anim(crest, crown, (1, 0, 0), sway(5, 1.5), kick(20), lod_keep=False, note="crest flares on Rebirth")
    ds.append(crest)
    # Wings: one swept wing per side (arched leading edge, scalloped feather trailing edge), a gold covert
    # patch in front near the shoulder, and gold feather tips at each scallop.
    wing_pts = [(0.0, -0.08), (0.18, 0.26), (0.46, 0.56), (0.8, 0.74), (1.1, 0.72), (1.3, 0.56), (1.12, 0.44), (1.2, 0.26),
                (0.98, 0.2), (1.0, 0.0), (0.78, 0.04), (0.76, -0.18), (0.56, -0.08), (0.5, -0.28), (0.34, -0.14), (0.2, -0.26)]
    covert = [(0.02, -0.02), (0.2, 0.24), (0.44, 0.46), (0.68, 0.52), (0.62, 0.3), (0.48, 0.12), (0.3, 0.0), (0.14, -0.1)]
    tip_at = [((1.24, 0.5), 0.35), ((1.12, 0.24), -0.1), ((0.94, 0.02), -0.5), ((0.72, -0.15), -0.9), ((0.48, -0.24), -1.2)]
    for side, label in ((-1, "L"), (1, "R")):
        shoulder = Vector((side * 0.6, 0.16, -1.02))
        sweep = Matrix.Translation(shoulder) @ Matrix.Rotation(side * 0.38, 4, "Z") @ Matrix.Diagonal((side * 0.95, 1, 0.95, 1))
        wb, cb, tb = bmesh.new(), bmesh.new(), bmesh.new()
        slab_bm(wb, wing_pts, 0.07, 0.025, 1, sweep)
        slab_bm(cb, covert, 0.05, 0.018, 1, sweep @ Matrix.Translation((0, -0.05, 0)))
        for (u, v), ang in tip_at:
            m = sweep @ Matrix.Translation((u - 0.05 * math.cos(ang), -0.03, v - 0.05 * math.sin(ang))) @ Matrix.Rotation(-ang, 4, "Y")
            slab_bm(tb, [(-0.12, 0.0), (0.02, 0.075), (0.15, 0.03), (0.17, -0.02), (0.02, -0.075)], 0.05, 0, 1, m)
        for bm_ in (wb, cb, tb):
            bmesh.ops.recalc_face_normals(bm_, faces=bm_.faces)
        axis = (sweep.to_3x3() @ Vector((0, 0, 1))).normalized() * -side
        wing = paint(_obj("Wing_" + label, wb, sharp_deg=55), "#FF8A3A")
        anim(wing, shoulder, axis, sway(14, 1.5), flare(30), lod_keep=True, note="slow wing beat; flares wide on Rebirth")
        cov = paint(_obj("WingCovert_" + label, cb, sharp_deg=55), "#FFB13D")
        anim(cov, shoulder, axis, sway(14, 1.5), flare(30))
        follow(cov, "Wing_" + label)
        tips = paint(_obj("WingTips_" + label, tb, sharp_deg=55), gold)
        anim(tips, shoulder, axis, sway(14, 1.5), flare(30))
        follow(tips, "Wing_" + label)
        ds += [wing, cov, tips]
    # Tail: three long feathers hanging behind, each with a glowing eye-spot.
    tail_root = Vector((0, 0.5, -1.6))
    gems = bmesh.new()
    for i, (ang, L) in enumerate(((-38, 1.05), (0, 1.3), (38, 1.05))):
        rot = Matrix.Rotation(math.radians(ang), 4, "Y") @ Matrix.Rotation(math.radians(14), 4, "X") @ Matrix.Rotation(math.pi / 2, 4, "Y")
        m = Matrix.Translation(tail_root + Vector((math.sin(math.radians(ang)) * 0.1, 0.05 * abs(i - 1), 0))) @ rot
        fb = bmesh.new()
        slab_bm(fb, feather_outline(L, 0.2, 0.8), 0.06, 0.022, 1, m)
        bmesh.ops.recalc_face_normals(fb, faces=fb.faces)
        tf = paint(_obj(f"TailFeather_{i + 1}", fb, sharp_deg=55), flame if i != 1 else "#FF9440")
        anim(tf, tail_root, (0, 1, 0), sway(7, 1.8, i * 0.8), kick(16), lod_keep=(i == 1))
        ds.append(tf)
        tip = m @ Vector((L * 0.8, -0.04, 0))
        ellipsoid_bm(gems, tip, (0.11, 0.035, 0.11), 8, 4, rot.to_quaternion())
    tg = paint(_obj("TailGems", gems), gold, "Neon")
    anim(tg, tail_root, (0, 1, 0), pulse(0.08, 1.8), flash(0.3), note="eye-spots on the tail feathers; ride them (client may parent per feather)")
    ds.append(tg)
    fs = bmesh.new()
    ellipsoid_bm(fs, body_c + Vector((0, -0.02, 0)), (0.6, 0.52, 0.55), 12, 8)
    ellipsoid_bm(fs, head_c + Vector((0, 0.02, 0)), (0.36, 0.33, 0.33), 10, 7)
    shell = as_inner(paint(_obj("FlameShell", fs), gold, alpha=0.35, transmission=0.6))
    anim(shell, body_c, (0, 0, 1), pulse(0.03, 2.2), None, note="inner sunfire glass layer; brighter in phase 2")
    core = paint(blob("EmberCore", body_c + Vector((0, -0.12, 0.02)), (0.22, 0.2, 0.24), 10, 6), ember, "Neon")
    anim(core, body_c, (0, 0, 1), pulse(0.12, 1.1), flash(0.35), lod_keep=False, extra_idle=[flicker(0.05, 8)],
         note="Mythic ember core: stronger glow and faster pulse in phase 2 (after Rebirth)")
    fp, fn = surf.hit(body_c + Vector((0, -5, -0.05)), (0, 1, 0))
    flb = bmesh.new()
    fl = [(0.0, -0.24), (0.15, -0.14), (0.18, 0.02), (0.1, 0.12), (0.12, 0.26), (0.03, 0.16), (0.0, 0.3), (-0.04, 0.15), (-0.12, 0.24), (-0.1, 0.1), (-0.18, 0.0), (-0.15, -0.14)]
    slab_bm(flb, fl, 0.04, 0, 1, Matrix.Translation(fp + fn * 0.005) @ facing(fn) @ Matrix.Rotation(-math.pi / 2, 4, "X"))
    belly = paint(_obj("BellyFlame", flb), ember)
    ds += [shell, core, belly]
    ft = bmesh.new()
    for s in (-1, 1):
        base = Vector((s * 0.24, -0.34, -1.88))
        for k_ in (-1, 1):
            tube_bm(ft, [base, base + Vector((k_ * 0.06, -0.12, -0.04)), base + Vector((k_ * 0.08, -0.17, -0.1))], [0.04, 0.03, 0.012], 4)
    feet = paint(_obj("Talons", ft), gold, "SmoothPlastic")
    anim(feet, (0, -0.34, -1.88), (1, 0, 0), None, kick(8))
    ds.append(feet)
    return body, ds


# ------------------------------------------------------------------------------------------
# CLI
# ------------------------------------------------------------------------------------------

def _main(argv):
    if not argv:
        return
    cmd, rest = argv[0], argv[1:]
    opts = {"--samples": None, "--out": None}
    flags = set()
    pos = []
    i = 0
    while i < len(rest):
        a = rest[i]
        if a in opts:
            opts[a] = rest[i + 1]
            i += 2
            continue
        if a.startswith("--"):
            flags.add(a)
        else:
            pos.append(a)
        i += 1
    if cmd == "preview":
        out = opts["--out"] or os.environ.get("LAUNCH_PREVIEW_DIR") or doc_path("wip")
        for g in pos:
            print("RESULT", json.dumps(preview(g, out, int(opts["--samples"] or 16))))
    elif cmd == "stats":
        for g in pos:
            body, details = build_objects(g)
            print("RESULT", json.dumps(stats(g, body, details)))
    elif cmd == "build":
        for g in pos:
            print("RESULT", json.dumps(build(g, int(opts["--samples"] or 96), "--force" in flags)))
    elif cmd == "validate":
        for g in pos:
            print("RESULT", json.dumps(validate(g)))
    elif cmd == "sheet":
        print("RESULT", sheet(pos[0], pos[2:], pos[1]))
    else:
        raise SystemExit("unknown command " + cmd)


if __name__ == "__main__":
    _main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
