"""Launch flyers (docs/design/COSMETICS_V2.md §3, build order §5.1; workstream F).

Headless:
    /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/blender/build_flyers_launch.py -- [ids] [--render] [--samples N]

Loads H's tools/blender/build_flyers_v3.py as a library (its own main() never runs) and reuses its part
builder (add/loft/lathe/tube/sphere, Studio material kinds, weighted normals), manifest, FBX round-trip
and preview renders, so the output matches the four v3 flyers exactly:
assets/blender/round_cosmetics/flyers_v3/<id>/{<id>.fbx, <id>.blend, manifest.json, <id>_preview.png,
<id>_rider_scale.png} plus <id>_icon.png (512, transparent, flyer camera). Summary: launch_build_summary.json.

Conventions (docs/art/FLYERS_V3.md): 1 BU = 1 stud, Z up, nose +Y; origin = RiderFeet (deck top) for
Surf/Kneel/HandleStand, RiderSeat (seat top) for Sit/HandleSit. Handle flyers place GripL/GripR on
RideFamilies.StandardGrips. Orbiting satellites are a symmetric set on one mesh spun with `Spin` (the
part spins about its own bounds centre), so they need no new RideMotion kind.
"""
import json
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector

REPO = os.environ.get("GLASSCLASH_REPO") or os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
_H_PATH = os.path.join(REPO, "tools", "blender", "build_flyers_v3.py")
H = {"__name__": "flyers_v3_lib", "__file__": _H_PATH}
exec(compile(open(_H_PATH, encoding="utf-8").read(), _H_PATH, "exec"), H)

add, loft, lathe, tube, sphere, merge, spaced, catmull, rrect, bevel_bm = (
    H[k] for k in ("add", "loft", "lathe", "tube", "sphere", "merge", "spaced", "catmull", "rrect", "bevel_bm"))
PARTS, SCALE, TAU = H["PARTS"], H["SCALE"], H["TAU"]
PEARL, GOLD, NAVY, WHITE = H["PEARL"], H["GOLD"], H["NAVY"], H["WHITE"]
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))

# RideFamilies.StandardGrips (Roblox rider space) -> Blender (x, -z, y)
GRIPS = {"HandleStand": ((-0.96, 1.56, 2.58), (0.96, 1.56, 2.58)), "HandleSit": ((-0.9, 1.55, 1.45), (0.9, 1.55, 1.45))}
LAUNCH = {}   # id -> (builder, budget, family)
EYE, SHINE, BLUSH = "#1B2440", "#FFFFFF", "#FF9FC4"


def flyer(gid, budget, family):
    def wrap(fn):
        LAUNCH[gid] = (fn, budget, family)
        return fn
    return wrap


# ---------------------------------------------------------------------------------------------
# Extra geometry
# ---------------------------------------------------------------------------------------------

def ring_loft(rings, cap=True):
    """Closed mesh through rings of equal length (lists of Vectors); caps both ends with a centre fan."""
    bm = bmesh.new()
    vr = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(rings[0])
    for a, b in zip(vr, vr[1:]):
        for j in range(n):
            bm.faces.new((a[j], a[(j + 1) % n], b[(j + 1) % n], b[j]))
    if cap:
        for ring, src, flip in ((vr[0], rings[0], True), (vr[-1], rings[-1], False)):
            c = bm.verts.new(sum(src, Vector()) / n)
            for j in range(n):
                f = (ring[j], ring[(j + 1) % n], c)
                bm.faces.new(f[::-1] if flip else f)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def round_hex(R, corner=0.18, per_corner=4, rot=math.pi / 2, sx=1.0, sy=1.0):
    """Rounded hexagon outline (2D points), circumradius R, pointy along `rot`."""
    pts = []
    rc = corner / math.sin(math.pi / 3)
    for k in range(6):
        a = rot + k * TAU / 6
        c = Vector((math.cos(a), math.sin(a))) * (R - rc)
        for i in range(per_corner):
            b = a - math.pi / 6 + (math.pi / 3) * (i / (per_corner - 1) if per_corner > 1 else 0.5)
            p = c + Vector((math.cos(b), math.sin(b))) * corner
            pts.append(Vector((p.x * sx, p.y * sy)))
    return pts


def slab_rings(outline, profile, centre=Vector()):
    """profile: [(inset, z)] -> rings of the outline pulled in toward `centre` by `inset` (studs) at height z."""
    rings = []
    for inset, z in profile:
        ring = []
        for p in outline:
            d = Vector((p.x, p.y)) - Vector((centre.x, centre.y))
            k = max(d.length - inset, 0.01) / max(d.length, 1e-6)
            ring.append(Vector((centre.x + d.x * k, centre.y + d.y * k, z)))
        rings.append(ring)
    return rings


def ellipsoid(centre, radii, segs=14, rings=9, rot=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1)
    m = Matrix.Diagonal((*radii, 1))
    if rot is not None:
        m = rot.to_matrix().to_4x4() @ m
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(centre)) @ m, verts=bm.verts)
    return bm


def flat_slab(points2d, depth, matrix, bevel=0.03):
    """Extruded 2D outline (u, v) in local XZ, depth along local Y, bevelled; transformed by matrix."""
    bm = bmesh.new()
    n = len(points2d)
    vs = [bm.verts.new((u, d, v)) for d in (-depth / 2, depth / 2) for u, v in points2d]
    bm.faces.new(list(reversed(vs[:n])))
    bm.faces.new(vs[n:])
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((vs[i], vs[j], vs[j + n], vs[i + n]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if bevel:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, affect="EDGES", profile=0.5, clamp_overlap=True)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def face_on(bm_target_obj, centre, look, eye_dx, eye_z, size=(0.16, 0.2), prefix="", cheeks=True, spin=None):
    """Cute face (eyes, two shines, cheeks) ray-cast onto a part; returns the meshes (not yet added)."""
    tree = H["bvh_of"](bm_target_obj)
    look = Vector(look).normalized()
    side = look.cross(Z).normalized() * -1
    eyes, shine, blush = bmesh.new(), bmesh.new(), bmesh.new()
    for s in (-1, 1):
        o = Vector(centre) + side * s * eye_dx + Z * (eye_z - centre[2]) + look * 6
        p, n, _, _ = tree.ray_cast(o, -look)
        if p is None:
            continue
        q = n.to_track_quat("Z", "Y")
        sx, sz = size
        for src, c, r, sg in ((eyes, p + n * sx * 0.05, (sx, sz, sx * 0.4), (12, 8)),
                              (shine, p + n * sx * 0.32 + Z * sz * 0.35 - side * sx * 0.32, (sx * 0.34, sx * 0.34, sx * 0.15), (8, 5)),
                              (shine, p + n * sx * 0.32 - Z * sz * 0.32 + side * sx * 0.3, (sx * 0.16, sx * 0.16, sx * 0.1), (6, 4))):
            tmp = ellipsoid(Vector((0, 0, 0)), (r[0], r[1], r[2]), *sg)
            bmesh.ops.transform(tmp, matrix=Matrix.Translation(c) @ q.to_matrix().to_4x4() @ Matrix.Rotation(math.pi / 2, 4, "X"), verts=tmp.verts)
            src_mesh = bpy.data.meshes.new("_t")
            tmp.to_mesh(src_mesh)
            tmp.free()
            src.from_mesh(src_mesh)
            bpy.data.meshes.remove(src_mesh)
        if cheeks:
            o2 = Vector(centre) + side * s * eye_dx * 1.55 + Z * (eye_z - size[1] * 1.25 - centre[2]) + look * 6
            p2, n2, _, _ = tree.ray_cast(o2, -look)
            if p2 is not None:
                tmp = ellipsoid(Vector((0, 0, 0)), (size[0] * 1.0, size[0] * 0.55, 0.02), 10, 5)
                bmesh.ops.transform(tmp, matrix=Matrix.Translation(p2 + n2 * 0.01) @ n2.to_track_quat("Z", "Y").to_matrix().to_4x4(), verts=tmp.verts)
                src_mesh = bpy.data.meshes.new("_t")
                tmp.to_mesh(src_mesh)
                tmp.free()
                blush.from_mesh(src_mesh)
                bpy.data.meshes.remove(src_mesh)
    return eyes, shine, blush


# ---------------------------------------------------------------------------------------------
# 1. Honey Hover (Uncommon, Stand-Surf)
# ---------------------------------------------------------------------------------------------
HONEY = {"amber": "#FFB92E", "core": "#C77A00", "wax": "#FFF1C9", "glint": "#FFE38A", "bee": "#FFD23F", "stripe": "#3A2A1A", "wing": "#EAFBFF"}


@flyer("honey_hover", 5500, "Surf")
def build_honey_hover():
    R = 3.4                      # pointy nose/tail along Y: 6.8 long x 5.9 wide
    T = 0.7
    outline = round_hex(R, corner=0.42, per_corner=5, rot=math.pi / 2)
    prof = [(0.2, -T), (0.06, -T + 0.06), (0.0, -T + 0.2), (0.0, -0.16), (0.05, -0.04), (0.16, 0.0)]
    add("Deck", ring_loft(slab_rings(outline, prof)), HONEY["amber"], "Glass")
    core_out = round_hex(R - 0.45, corner=0.3, per_corner=4, rot=math.pi / 2)
    add("DeckCore", ring_loft(slab_rings(core_out, [(0.1, -T + 0.16), (0.0, -T + 0.24), (0.0, -0.26), (0.1, -0.2)])), HONEY["core"], "Core")
    # Wax honeycomb frames on the deck: a ring of open cells around the rim, a plain centre for the feet.
    cell_r, frames, glints = 0.56, [], []
    w = cell_r * math.sqrt(3)
    rng = random.Random(7)
    for qi in range(-5, 6):
        for ri in range(-5, 6):
            cx = w * (qi + ri / 2)
            cy = 1.5 * cell_r * ri
            d = math.hypot(cx / (R * 0.866), cy / R)
            if 0.48 < d < 0.84:
                ring = [Vector((cx + cell_r * 0.96 * math.cos(math.pi / 2 + k * TAU / 6), cy + cell_r * 0.96 * math.sin(math.pi / 2 + k * TAU / 6), 0.035)) for k in range(6)]
                frames.append(tube(ring, 0.06, n=4, cap=False, closed=True))
                if rng.random() < 0.3:
                    gl = round_hex(cell_r * 0.5, 0.06, 1, rot=math.pi / 2)
                    glints.append(ring_loft(slab_rings([Vector((cx + p.x, cy + p.y)) for p in gl], [(0.0, -0.01), (0.04, 0.03)], Vector((cx, cy, 0)))))
    add("WaxCells", merge(*frames), HONEY["wax"], "Pearl")
    add("CellGlints", merge(*glints), HONEY["glint"], "Neon", motion={"RideMotion": "Pulse"})
    rim = [Vector((p.x, p.y, -0.02)) for p in round_hex(R - 0.1, 0.36, 5, rot=math.pi / 2)]
    add("WaxRim", tube(rim, 0.075, n=6, cap=False, closed=True), HONEY["wax"], "Pearl")
    pad = round_hex(1.15, 0.25, 4, rot=math.pi / 2, sx=0.85)
    add("FootPad", ring_loft(slab_rings(pad, [(0.0, -0.02), (0.0, 0.03), (0.05, 0.05)])), HONEY["wax"], "Matte")
    # Honey drips hanging off the rim; two sets breathe out of phase (Pulse).
    for tag, ks in (("A", (0, 2, 4)), ("B", (1, 3, 5))):
        drips = []
        for k in ks:
            a = math.pi / 2 + k * TAU / 6 + 0.35
            p = Vector((math.cos(a) * (R - 0.55) * 0.92, math.sin(a) * (R - 0.55), -T + 0.05))
            L = 0.45 + 0.12 * (k % 3)
            drips.append(lathe([(0.001, 0.0), (0.16, -0.05), (0.11, -L * 0.6), (0.17, -L), (0.12, -L - 0.14), (0.001, -L - 0.2)], p, Z, segs=8))
        add("HoneyDrips_" + tag, merge(*drips), HONEY["amber"], "Glass", studio={"Transparency": 0.15},
            motion={"RideMotion": "Pulse"})
    add("UnderGlow", ring_loft(slab_rings(round_hex(1.5, 0.3, 4, rot=math.pi / 2), [(0.0, -T - 0.02), (0.25, -T - 0.12)])),
        HONEY["glint"], "Neon", studio={"Transparency": 0.25}, motion={"RideMotion": "Pulse"})
    # Two glass bees on patrol: a symmetric pair on one mesh per material, spun about the deck's vertical axis.
    bodies, stripes, wings, eyes = [], [], [], []
    orbit_r, bz = 3.9, 1.35
    for k in (0, 1):
        a = k * math.pi
        c = Vector((orbit_r * math.cos(a), orbit_r * math.sin(a), bz + (0.25 if k else -0.1)))
        heading = Vector((-math.sin(a), math.cos(a), 0))
        q = heading.to_track_quat("Y", "Z")
        m = Matrix.Translation(c) @ q.to_matrix().to_4x4()
        bodies.append(ellipsoid(Vector(), (0.34, 0.46, 0.34), 14, 9))
        bmesh.ops.transform(bodies[-1], matrix=m, verts=bodies[-1].verts)
        head = ellipsoid(Vector((0, 0.42, 0.08)), (0.26, 0.24, 0.25), 12, 8)
        bmesh.ops.transform(head, matrix=m, verts=head.verts)
        bodies.append(head)
        for yy in (-0.12, 0.12):
            st = tube([Vector((0.34 * math.cos(t), yy, 0.34 * math.sin(t))) * 1.02 for t in [TAU * i / 12 for i in range(12)]], 0.055, n=4, cap=False, closed=True)
            bmesh.ops.scale(st, vec=Vector((1.0, 1.0, 1.0)), verts=st.verts)
            bmesh.ops.transform(st, matrix=m, verts=st.verts)
            stripes.append(st)
        stinger = lathe([(0.001, -0.42), (0.07, -0.5), (0.001, -0.66)], Vector((0, 0, 0)), (0, 1, 0), segs=6)
        bmesh.ops.transform(stinger, matrix=m, verts=stinger.verts)
        stripes.append(stinger)
        for s in (-1, 1):
            e = ellipsoid(Vector((s * 0.11, 0.62, 0.14)), (0.055, 0.04, 0.07), 6, 4)
            bmesh.ops.transform(e, matrix=m, verts=e.verts)
            eyes.append(e)
            wg = ellipsoid(Vector((s * 0.36, 0.0, 0.36)), (0.34, 0.2, 0.05), 10, 5, Quaternion((0, 1, 0), s * 0.5))
            bmesh.ops.transform(wg, matrix=m, verts=wg.verts)
            wings.append(wg)
    orbit = {"RideMotion": "Spin", "SpinAxis": "Y", "SpinSpeed": 0.9}
    add("Bees", merge(*bodies), HONEY["bee"], "Glass", motion=dict(orbit))
    add("BeeStripes", merge(*stripes), HONEY["stripe"], "Matte", motion=dict(orbit))
    add("BeeEyes", merge(*eyes), EYE, "Matte", motion=dict(orbit))
    add("BeeWings", merge(*wings), HONEY["wing"], "Glass", studio={"Transparency": 0.45}, motion=dict(orbit))
    return {
        "Id": "honey_hover", "Name": "Honey Hover", "Contact": "Feet",
        "Attachments": {
            "RiderFeet": ("Deck", (0, 0, 0)),
            "Trail0": ("Deck", (-2.4, -1.6, -0.35)), "Trail1": ("Deck", (2.4, -1.6, -0.35)),
            "Drip0": ("HoneyDrips_A", (0, 2.6, -1.3)), "Drip1": ("HoneyDrips_B", (0, -2.6, -1.3)),
            "Wake": ("Deck", (0, -3.3, -0.35)),
            "Launch": ("Deck", (0, 0, -1.0)),
        },
        "Notes": "Bees/BeeStripes/BeeEyes/BeeWings orbit as one symmetric set (Spin about their shared bounds centre = deck axis).",
    }


# ---------------------------------------------------------------------------------------------
# 2. Bubble Pod (Uncommon, Sit)
# ---------------------------------------------------------------------------------------------
BUBBLE = {"film": "#E9DDFF", "mint": "#80E8DA", "pink": "#FF9CE0", "cyan": "#8FF0FF", "wand": "#B9F3FF", "foam": "#F4FBFF"}


def heart_points(n, w, centre, normal_axis="Y"):
    raw = []
    for k in range(n):
        t = k / n * TAU
        raw.append((16 * math.sin(t) ** 3, 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)))
    xm = max(abs(x) for x, _ in raw)
    k = w / xm
    zmid = (max(z for _, z in raw) + min(z for _, z in raw)) / 2
    return [Vector(centre) + Vector((x * k, 0, (z - zmid) * k)) for x, z in raw]


@flyer("bubble_pod", 5500, "Sit")
def build_bubble_pod():
    R, t = 2.45, 0.09
    C = Vector((0, -0.4, 1.05))
    open_deg = 54
    # Thick shell lathed about the nose axis (+Y): back pole -> front opening rim -> inner wall -> back.
    outer = [(R * math.sin(math.radians(a)), -R * math.cos(math.radians(a))) for a in [1] + [8 + (180 - open_deg - 8) * i / 12 for i in range(13)]]
    rim_a = math.radians(180 - open_deg)
    lip = [(R * math.sin(rim_a) - 0.02, -R * math.cos(rim_a) + 0.06), ((R - t) * math.sin(rim_a) - 0.02, -(R - t) * math.cos(rim_a) + 0.04)]
    inner = [((R - t) * math.sin(math.radians(a)), -(R - t) * math.cos(math.radians(a))) for a in [180 - open_deg - 8 * i / 1 for i in range(1)] +
             [(180 - open_deg) - (180 - open_deg - 8) * i / 9 for i in range(1, 10)] + [1]]
    prof = outer + lip + inner
    add("Shell", lathe(prof, C, (0, 1, 0), segs=28), BUBBLE["film"], "Glass", studio={"Transparency": 0.5},
        motion={"RideMotion": "Pulse"})
    rim = [C + Vector((R * math.sin(rim_a) * math.cos(a), -R * math.cos(rim_a) + 0.03, R * math.sin(rim_a) * math.sin(a))) for a in [TAU * i / 32 for i in range(32)]]
    add("RimTrim", tube(rim, 0.075, n=6, cap=False, closed=True), "#FFE3F4", "Pearl")
    # Iridescent sheen bands (pink and cyan) lying on the film.
    # On the side players see (right flank and top-back); the left flank mirrors nothing so the film reads asymmetric.
    for name, col, tilt, a0, span, lift in (("SheenPink", BUBBLE["pink"], 0.35, -0.75, 2.1, 0.02), ("SheenCyan", BUBBLE["cyan"], -0.3, -0.35, 1.9, 0.035),
                                            ("SheenGold", "#FFE58A", 0.1, 1.55, 1.3, 0.028)):
        rot = Matrix.Rotation(tilt, 3, "Y")
        pts = []
        for i in range(14):
            a = a0 + span * i / 13
            d = rot @ Vector((math.cos(a), -0.45, math.sin(a))).normalized()
            pts.append(C + d * (R + lift))
        radii = [0.02 + 0.11 * math.sin(math.pi * i / 13) for i in range(14)]
        band = tube(pts, radii, n=5)
        for v in band.verts:  # flatten onto the film so it reads as a sheen band, not a pipe
            d = (v.co - C)
            r_ = d.length
            v.co = C + d * ((R + lift) + (r_ - R - lift) * 0.3) / r_
        add(name, band, col, "Frost", studio={"Transparency": 0.2}, motion={"RideMotion": "Pulse"})
    gl = []
    for i in range(6):
        a = 2.35 + 0.12 * i
        d = Vector((0.55 * math.cos(a), 0.2, 0.75 + 0.06 * math.sin(a))).normalized()
        gl.append(C + d * (R + 0.03))
    add("Glint", merge(tube(gl, [0.03, 0.06, 0.07, 0.07, 0.06, 0.03], n=5),
                       sphere(C + Vector((0.42, 0.25, 0.85)).normalized() * (R + 0.04), 0.07, 8, 5)), WHITE, "Neon")
    # Mint cushioned bench with a backrest; the seat top is the origin.
    seat = []
    for u in spaced(10, 0.7):
        y = -0.95 + 1.55 * u
        k = rrect(u, 5)
        seat.append((Vector((0, y, -0.2)), X, Z, max(0.95 * k, 0.04), 0.2 * max(k, 0.2), 0.16 * max(k, 0.2), 3.0))
    back = []
    for u in spaced(8, 0.7):
        z = -0.25 + 1.75 * u
        k = rrect(u, 5)
        back.append((Vector((0, -1.05 - 0.12 * u, z)), X, Y, max(0.92 * k, 0.04), 0.18 * max(k, 0.2), 0.16 * max(k, 0.2), 3.0))
    add("Bench", merge(loft(seat, n=18), loft(back, n=18)), BUBBLE["mint"], "Pearl")
    add("BenchPost", lathe([(0.35, 0.0), (0.22, 0.12), (0.18, 0.6), (0.4, 0.72), (0.001, 0.75)], C + Vector((0, 0, -R + 0.03)), (0, 0, 1), segs=14),
        PEARL, "Pearl")
    # Heart wand ring as a spoiler behind (matches the Bubble Wand glassy), with a short stem to the shell.
    hc = C + Vector((0, -R - 0.55, 1.05))
    heart = [Matrix.Rotation(-0.35, 3, "X") @ (p - hc) + hc for p in heart_points(32, 1.05, hc)]
    add("WandHeart", merge(tube(heart, 0.11, n=6, cap=False, closed=True),
                           tube([C + Vector((0, -R + 0.2, 0.8)), hc + Vector((0, 0.15, -0.55))], [0.09, 0.07], n=8)),
        BUBBLE["wand"], "Glass", motion={"RideMotion": "Fin", "MotionPivotWorld": C + Vector((0, -R + 0.15, 0.8)), "FinAxis": "X", "FinAngle": 0.08, "FinBank": 0.3})
    film = ellipsoid(hc, (0.9, 0.06, 0.82), 16, 8)
    bmesh.ops.rotate(film, cent=hc, matrix=Matrix.Rotation(-0.35, 3, "X"), verts=film.verts)
    add("WandFilm", film, BUBBLE["pink"], "Glass", studio={"Transparency": 0.6},
        motion={"RideMotion": "Fin", "MotionPivotWorld": C + Vector((0, -R + 0.15, 0.8)), "FinAxis": "X", "FinAngle": 0.08, "FinBank": 0.3})
    # Soap foam under the pod and four orbiting bubbles (180-degree symmetric set, spun about the pod's axis).
    rng = random.Random(3)
    foam = []
    for i in range(9):
        a = TAU * i / 9 + rng.uniform(-0.2, 0.2)
        rr = rng.uniform(0.6, 1.3)
        foam.append(sphere(C + Vector((rr * math.cos(a), rr * math.sin(a), -R * 0.9 + rng.uniform(-0.1, 0.15))), rng.uniform(0.28, 0.42), 10, 6))
    add("Foam", merge(*foam), BUBBLE["foam"], "Frost", motion={"RideMotion": "Puff", "PuffPhase": 0.0})
    orb = []
    for (rr, z, sz) in ((3.1, 1.6, 0.34), (2.9, -0.6, 0.24)):
        for k in (0, 1):
            a = 0.6 + k * math.pi + (0.8 if z < 0 else 0)
            orb.append(sphere(C + Vector((rr * math.cos(a), rr * math.sin(a), z)), sz, 12, 7))
    add("OrbitBubbles", merge(*orb), BUBBLE["wand"], "Glass", studio={"Transparency": 0.45},
        motion={"RideMotion": "Spin", "SpinAxis": "Y", "SpinSpeed": 0.7})
    return {
        "Id": "bubble_pod", "Name": "Bubble Pod", "Contact": "Seat",
        "Attachments": {
            "RiderSeat": ("Bench", (0, 0, 0)),
            "Trail0": ("Shell", (-1.6, -2.2, 0.4)), "Trail1": ("Shell", (1.6, -2.2, 0.4)),
            "Wake": ("Shell", (0, -2.7, 0.6)),
            "Launch": ("Foam", (0, -0.35, -1.6)),
        },
        "Notes": "OrbitBubbles orbit by Spin about their own bounds centre (= pod axis). Shell wobble = Pulse.",
    }


# ---------------------------------------------------------------------------------------------
# 3. Paper Jet (Common, Kneel)
# ---------------------------------------------------------------------------------------------
PAPER = {"frost": "#F4F8FF", "core": "#BFD8FF", "pencil": "#FFD84D", "tip": "#9FE3FF"}


@flyer("paper_jet", 5500, "Kneel")
def build_paper_jet():
    nose, tail = 3.6, -3.4
    span = 2.6
    dihedral = 0.16

    def wing_pts(side, inset=0.0):
        # dart planform in (x, y): root along the keel, leading edge from nose to the tip, trailing edge back to root
        return [Vector((side * (0.42 + inset), nose - 0.5 - inset * 2)), Vector((side * (span - inset * 1.6), tail + 0.25 + inset)),
                Vector((side * (span - 0.2 - inset), tail + inset)), Vector((side * (0.42 + inset), tail + 0.55 + inset))]

    def plate(pts, z_of, thick, bev):
        """Bevelled plate from a convex 2D outline (Blender XY), heights from z_of(x, y)."""
        cen = sum(pts, Vector((0, 0))) / len(pts)
        rings = []
        for inset, dz in ((bev, -thick / 2), (0.0, -thick / 2 + bev), (0.0, thick / 2 - bev), (bev, thick / 2)):
            ring = []
            for i in range(len(pts)):
                a, b = pts[i], pts[(i + 1) % len(pts)]
                for k in range(6):
                    q = a.lerp(b, k / 6)
                    d = q - cen
                    q2 = cen + d * max(d.length - inset, 0.01) / max(d.length, 1e-6)
                    ring.append(Vector((q2.x, q2.y, z_of(q2.x, q2.y) + dz)))
            rings.append(ring)
        return ring_loft(rings)

    def wz(x, y):
        return abs(x) * dihedral - 0.18 + 0.12 * max(0.0, (y - 1.0) / 2.6)
    for side, tag in ((-1, "L"), (1, "R")):
        add("Wing_" + tag, plate(wing_pts(side), wz, 0.16, 0.05), PAPER["frost"], "Frost")
        add("WingCore_" + tag, plate(wing_pts(side, 0.35), lambda x, y: wz(x, y) - 0.005, 0.08, 0.025), PAPER["core"], "Core")
        tip_root = Vector((side * (span - 0.7), tail + 0.5, wz(span - 0.7, tail + 0.5)))
        tipp = [Vector((side * (span - 0.7), tail + 0.85)), Vector((side * (span - 0.04), tail + 0.27)), Vector((side * (span - 0.24), tail + 0.02)), Vector((side * (span - 0.7), tail + 0.3))]
        add("WingTip_" + tag, plate(tipp, lambda x, y: wz(x, y) + 0.04, 0.1, 0.03), PAPER["frost"], "Frost",
            motion={"RideMotion": "Fin", "MotionPivotWorld": tip_root, "FinAxis": "Y", "FinAngle": 0.1, "FinHz": 1.1, "FinPhase": 0 if side < 0 else 0.5, "FinBank": 0.25})
        flap_root = Vector((side * 1.2, tail + 0.42, wz(1.2, tail + 0.42)))
        flp = [Vector((side * 0.6, tail + 0.62)), Vector((side * 1.9, tail + 0.36)), Vector((side * 1.9, tail + 0.05)), Vector((side * 0.6, tail + 0.3))]
        add("TailFlap_" + tag, plate(flp, lambda x, y: wz(x, y) + 0.05, 0.08, 0.025), PAPER["core"], "Core",
            motion={"RideMotion": "Fin", "MotionPivotWorld": flap_root, "FinAxis": "X", "FinAngle": 0.05, "FinBank": 0.6 * side})
        crease = [Vector((side * 0.42, nose - 0.5, wz(0.42, nose - 0.5) + 0.085))]
        for k in range(1, 9):
            q = Vector((side * 0.42, nose - 0.5)).lerp(Vector((side * (span - 0.2), tail)), k / 8)
            crease.append(Vector((q.x, q.y, wz(q.x, q.y) + 0.085)))
        add("PencilLine_" + tag, tube(crease, 0.035, n=5), PAPER["pencil"], "Pearl")
    # Raised keel (the rider kneels on its flat top; origin = top centre) and the fold below.
    keel = []
    for u in spaced(18, 0.5):
        y = tail + 0.2 + (nose - tail - 0.2) * u
        k = rrect(u, 3) if u < 0.6 else max(0.04, (1 - u) / 0.4) ** 0.8
        keel.append((Vector((0, y, -0.14)), X, Z, max(0.62 * k, 0.03), 0.14 * max(k, 0.3), 0.32 * max(k, 0.3), 3.2))
    add("Keel", loft(keel, n=18), PAPER["frost"], "Frost")
    fold = []
    for u in spaced(14, 0.4):
        y = tail + 0.3 + (nose - 0.3 - tail - 0.3) * u
        dep = 0.42 * math.sin(math.pi * min(1.0, u * 1.1)) ** 0.7 + 0.04
        fold.append((Vector((0, y, -0.3 - dep * 0.5)), X, Z, 0.075, dep * 0.5, dep * 0.5, 2.0))
    add("Fold", loft(fold, n=8), PAPER["core"], "Core")
    add("NoseTip", lathe([(0.001, 0.0), (0.22, 0.2), (0.12, 0.55), (0.001, 0.72)], Vector((0, nose - 0.3, -0.12)), (0, 1, 0), segs=12), PAPER["tip"], "Neon")
    pad = []
    for u in spaced(8, 0.8):
        y = -1.3 + 2.0 * u
        k = rrect(u, 4)
        pad.append((Vector((0, y, -0.01)), X, Z, max(0.48 * k, 0.03), 0.025, 0.02, 4.0))
    add("KneelPad", loft(pad, n=14), PAPER["core"], "Matte")
    return {
        "Id": "paper_jet", "Name": "Paper Jet", "Contact": "Feet",
        "Attachments": {
            "RiderFeet": ("Keel", (0, 0, 0)),
            "Trail0": ("WingTip_L", (-(span - 0.1), tail + 0.1, span * dihedral - 0.1)),
            "Trail1": ("WingTip_R", (span - 0.1, tail + 0.1, span * dihedral - 0.1)),
            "Wake": ("Keel", (0, tail, -0.2)),
            "Launch": ("Fold", (0, 0, -1.0)),
        },
        "Notes": "Kneel family: knees on KneelPad (y -1.3..0.7), hands forward on the keel fold.",
    }


# ---------------------------------------------------------------------------------------------
# Build driver (H's build() with our builders registered), icon render, summary
# ---------------------------------------------------------------------------------------------

def icon(path, size=512, samples=48):
    """512 transparent icon on the lights H's preview() just set up: flyer camera direction, square, no ground."""
    scene = bpy.context.scene
    objs = [o for o, _ in PARTS]
    for o in list(scene.objects):
        if o.type == "MESH" and o not in objs:
            o.hide_render = True          # the preview ground plane
    res = (scene.render.resolution_x, scene.render.resolution_y, scene.render.film_transparent, scene.cycles.samples)
    scene.render.film_transparent = True
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.cycles.samples = samples
    lo = Vector((min(H["bounds"](o)[0][k] for o in objs) for k in range(3)))
    hi = Vector((max(H["bounds"](o)[1][k] for o in objs) for k in range(3)))
    centre, extent = (lo + hi) / 2, (hi - lo).length
    cam = scene.camera
    direction = Vector((1.25, 1.15, 0.55)).normalized()
    cam.location = centre + direction * extent * 1.2
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    scene.render.resolution_x, scene.render.resolution_y, scene.render.film_transparent, scene.cycles.samples = res
    for o in list(scene.objects):
        o.hide_render = False
    return path


def kneel_mannequin():
    """R15-sized kneeling stand-in (one knee down, leaning forward, hands forward); preview only."""
    m = bpy.data.materials.new("Mannequin")
    m.use_nodes = True
    next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.5, 0.5, 0.55, 1)

    def box(c, sz, rot=(0, 0, 0)):
        bpy.ops.mesh.primitive_cube_add(size=1, location=c, rotation=rot)
        o = bpy.context.active_object
        o.scale = sz
        o.data.materials.append(m)
    box((0, -0.1, 2.35), (2.0, 1.0, 2.0), (math.radians(-20), 0, 0))     # torso leaning forward
    box((0, 0.35, 3.85), (1.2, 1.2, 1.2))                                 # head
    box((-0.5, -0.45, 0.25), (0.9, 1.9, 0.5))                             # left shin flat on the pad (knee down)
    box((-0.5, 0.35, 0.85), (0.9, 0.9, 1.3), (math.radians(30), 0, 0))    # left thigh
    box((0.5, 0.75, 0.5), (0.9, 0.9, 1.0))                                # right shin upright (foot planted)
    box((0.5, 0.35, 1.25), (0.9, 1.4, 0.9))                               # right thigh forward
    for sx in (-1.15, 1.15):
        box((sx, 1.0, 2.0), (0.9, 0.9, 2.0), (math.radians(-55), 0, 0))  # arms reaching forward


def build(gid, render=False, samples=32):
    fn, budget, family = LAUNCH[gid]
    H["BUILDERS"][gid] = fn
    H["BUDGET"][gid] = budget
    manifest = H["build"](gid, False, samples)
    folder = os.path.join(H["OUT"], gid)
    manifest["Family"] = family
    manifest["Source"] = "tools/blender/build_flyers_launch.py (on build_flyers_v3.py)"
    assert manifest["Tris"] <= budget, (gid, manifest["Tris"], budget)
    assert manifest["FbxRoundTrip"]["ok"], (gid, manifest["FbxRoundTrip"])
    bad = {n: (p["loose_verts"], p["degenerate_faces"]) for n, p in manifest["Parts"].items() if (p["loose_verts"], p["degenerate_faces"]) != (0, 0)}
    assert not bad, (gid, "mesh problems", bad)
    with open(os.path.join(folder, "manifest.json"), "w") as fh:
        json.dump(manifest, fh, indent=1)
    if render:
        H["preview"](os.path.join(folder, gid + "_preview.png"), samples)
        icon(os.path.join(folder, gid + "_icon.png"), 512, samples)
        pose = {"Sit": "seat", "HandleSit": "seat"}.get(family, "stand")
        if family == "Kneel":
            kneel_mannequin()
        else:
            H["add_mannequin"](manifest["Contact"], pose)
        H["preview"](os.path.join(folder, gid + "_rider_scale.png"), max(16, samples // 2), (800, 640), mannequin=True)
    return manifest


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    render = "--render" in argv
    samples = int(argv[argv.index("--samples") + 1]) if "--samples" in argv else 32
    ids = [a for a in argv if a in LAUNCH] or list(LAUNCH)
    path = os.path.join(H["OUT"], "launch_build_summary.json")
    summary = json.load(open(path)) if os.path.exists(path) else {}
    for gid in ids:
        m = build(gid, render, samples)
        summary[gid] = {"Tris": m["Tris"], "Budget": m["Budget"], "Family": m["Family"], "Extents": m["Extents"], "Parts": len(m["Parts"]),
                        "RoundTrip": m["FbxRoundTrip"]}
        print("FLYER", gid, json.dumps(summary[gid]))
        with open(path, "w") as fh:
            json.dump(summary, fh, indent=1)


if __name__ == "__main__":
    main()
