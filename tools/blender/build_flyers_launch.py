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
# HandleSit was (+-0.9, 1.45, -1.55) when Dragonfly and Carousel were built; H moved it to (+-0.62, 1.46, -1.74) (IK covers both).
GRIPS = {"HandleStand": ((-0.96, 1.56, 2.58), (0.96, 1.56, 2.58)), "HandleSit": ((-0.62, 1.74, 1.46), (0.62, 1.74, 1.46))}
GRIPS_BUILT = {"dragonfly": ((-0.9, 1.55, 1.45), (0.9, 1.55, 1.45)), "carousel": ((-0.9, 1.55, 1.45), (0.9, 1.55, 1.45))}
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


def flat_slab(points2d, depth, matrix, bevel=0.03, segs=2):
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
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=segs, affect="EDGES", profile=0.5, clamp_overlap=True)
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
            motion={"RideMotion": "Fin", "MotionPivotWorld": tip_root, "FinAxis": "Z", "FinAngle": 0.1, "FinHz": 1.1, "FinPhase": 0 if side < 0 else 0.5, "FinBank": 0.25})
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
# 4. Dragonfly (Rare, HandleSit)
# ---------------------------------------------------------------------------------------------
DFLY = {"teal": "#2FD0B5", "core": "#0E6B5C", "wing": "#E6FFF8", "gold": "#F5D99A", "eye": "#B9FFF0", "veinA": "#FFB3E6", "veinB": "#9FE8FF"}


def wing_outline(L, w, n=7):
    """Long rounded dragonfly wing in (u, v): root at u=0, tip at u=L; slightly wider toward the tip."""
    top, bot = [], []
    for i in range(n + 1):
        u = L * i / n
        t = i / n
        half = w * (0.35 + 0.65 * math.sin(math.pi * min(1.0, t * 0.95 + 0.05)) ** 0.6) * (1 - 0.15 * t)
        top.append((u, half * 0.85))
        bot.append((u, -half))
    return top + list(reversed(bot))


@flyer("dragonfly", 7500, "HandleSit")
def build_dragonfly():
    GRIPS["HandleSit"] = GRIPS_BUILT["dragonfly"]  # keep the shipped (uploaded) layout; rebuilding must not move the grips
    zc = -0.72
    # Thorax under the saddle.
    th = []
    for u in spaced(12, 0.6):
        y = -1.0 + 2.4 * u
        k = math.sin(math.pi * u) ** 0.55
        th.append((Vector((0, y, zc)), X, Z, max(0.78 * k, 0.05), max(0.64 * k, 0.05), max(0.6 * k, 0.05), 2.2))
    add("Thorax", loft(th, n=20), DFLY["teal"], "Glass")
    thc = [(c + Vector((0, 0, -0.04)), u_, v_, a * 0.7, b * 0.6, d * 0.6, e) for c, u_, v_, a, b, d, e in th[1:-1]]
    add("ThoraxCore", loft(thc, n=12), DFLY["core"], "Core")
    head = sphere(Vector((0, 1.85, zc + 0.2)), 0.62, 18, 12, (1.05, 0.85, 0.82))
    add("Head", head, DFLY["teal"], "Glass")
    eyes, pup, shine = [], [], []
    for sx in (-1, 1):
        c = Vector((sx * 0.46, 2.1, zc + 0.48))
        eyes.append(sphere(c, 0.42, 14, 9))
        pup.append(sphere(c + Vector((sx * 0.08, 0.33, 0.04)), 0.17, 10, 7, (1, 0.6, 1.2)))
        shine.append(sphere(c + Vector((sx * 0.02, 0.42, 0.16)), 0.065, 8, 5))
    add("Eyes", merge(*eyes), DFLY["eye"], "Neon", studio={"Transparency": 0.1})
    add("Pupils", merge(*pup), EYE, "Matte")
    add("EyeShine", merge(*shine), SHINE, "Matte")
    # Long segmented abdomen with gold joints; sways behind like a tail.
    seg_y = [-0.95 - 0.86 * i for i in range(7)]
    ab, joints = [], []
    for u in spaced(26, 0.2):
        y = -0.9 - 5.3 * u
        r = 0.48 * (1 - 0.66 * u) + 0.04 * math.cos(u * 6 * TAU) ** 2
        ab.append((Vector((0, y, zc + 0.1 * u)), X, Z, r, r * 0.92, r * 0.92, 2.0))
    tail_pivot = Vector((0, -0.95, zc))
    tail_motion = {"RideMotion": "Tail", "MotionPivotWorld": tail_pivot, "TailAngle": 0.14, "TailLag": 0.9}
    add("Abdomen", loft(ab, n=14), DFLY["teal"], "Glass", motion=dict(tail_motion))
    abc = [(c + Vector((0, 0, -0.02)), u_, v_, a * 0.6, b * 0.6, d * 0.6, e) for c, u_, v_, a, b, d, e in ab[2:-2]]
    add("AbdomenCore", loft(abc, n=8), DFLY["core"], "Core", motion=dict(tail_motion))
    for i, y in enumerate(seg_y[1:]):
        u = (-0.9 - y) / 5.3
        r = 0.48 * (1 - 0.66 * u) + 0.03
        ring = [Vector((r * math.cos(a), y, zc + 0.1 * u + r * 0.92 * math.sin(a))) for a in [TAU * j / 12 for j in range(12)]]
        joints.append(tube(ring, 0.035 + 0.01 * (1 - u), n=4, cap=False, closed=True))
    tipy = -0.9 - 5.3
    for sx in (-1, 1):
        joints.append(tube([Vector((0, tipy + 0.1, zc + 0.12)), Vector((sx * 0.14, tipy - 0.25, zc + 0.2)), Vector((sx * 0.24, tipy - 0.5, zc + 0.3))], [0.07, 0.05, 0.02], n=6))
    add("TailJoints", merge(*joints), DFLY["gold"], "Gold", motion=dict(tail_motion))
    # Four wings: clear glass with coloured veins; front and back pairs flutter out of phase (Fin about the nose axis).
    wings = (("FL", -1, 0.62, 3.7, 0.62, 0.1, DFLY["veinA"], 0.0), ("FR", 1, 0.62, 3.7, 0.62, 0.1, DFLY["veinA"], 0.0),
             ("BL", -1, -0.25, 3.5, 0.7, -0.18, DFLY["veinB"], 0.5), ("BR", 1, -0.25, 3.5, 0.7, -0.18, DFLY["veinB"], 0.5))
    for tag, sd, y0, L, w, sweep, vein_c, ph in wings:
        hinge = Vector((sd * 0.5, y0, zc + 0.42))
        m = Matrix.Translation(hinge) @ Matrix.Rotation(sd * 0.1, 4, "Y") @ Matrix.Rotation(-sweep * sd, 4, "Z") @ Matrix.Diagonal((sd, 1, 1, 1)) @ Matrix.Rotation(math.pi / 2, 4, "X")
        outline = wing_outline(L, w * 0.5)
        add("Wing_" + tag, flat_slab(outline, 0.05, m, bevel=0.018, segs=1), DFLY["wing"], "Glass", studio={"Transparency": 0.55},
            motion={"RideMotion": "Fin", "MotionPivotWorld": hinge, "FinAxis": "Z", "FinAngle": 0.32 * sd, "FinHz": 3.2, "FinPhase": ph, "FinBank": 0.1 * sd})
        veins = []
        mid = [Vector((L * t, 0, -0.03 * w)) for t in [i / 8 for i in range(9)]]
        veins.append(tube([m @ p for p in mid], [0.03 - 0.018 * i / 8 for i in range(9)], n=4))
        for t in (0.25, 0.45, 0.65, 0.82):
            half = w * 0.5 * (0.35 + 0.65 * math.sin(math.pi * min(1.0, t * 0.95 + 0.05)) ** 0.6) * (1 - 0.15 * t)
            veins.append(tube([m @ Vector((L * t, 0.03, -half * 0.85)), m @ Vector((L * (t + 0.06), 0.03, 0)), m @ Vector((L * t, 0.03, half * 0.75))], 0.012, n=4))
        edge = [m @ Vector((u, 0.0, v)) for u, v in outline[:: 2]] + [m @ Vector(outline[0][:1] + (0.0,) + outline[0][1:])]
        veins.append(tube(edge, 0.016, n=4, cap=False))
        add("WingVeins_" + tag, merge(*veins), vein_c, "Neon", studio={"Transparency": 0.15},
            motion={"RideMotion": "Fin", "MotionPivotWorld": hinge, "FinAxis": "Z", "FinAngle": 0.32 * sd, "FinHz": 3.2, "FinPhase": ph, "FinBank": 0.1 * sd})
    # Saddle (seat top = origin), antenna handlebar to the standard HandleSit grips, footpegs, little legs.
    sad = []
    for u in spaced(10, 0.7):
        y = -0.75 + 1.4 * u
        k = rrect(u, 3)
        sad.append((Vector((0, y, -0.11 + 0.07 * (1 - k))), X, Z, max(0.62 * k, 0.04), 0.11 * max(k, 0.3), 0.09 * max(k, 0.3), 3.0))
    add("Saddle", loft(sad, n=16), PEARL, "Pearl")
    rim = [Vector((0.64 * math.sin(a) * 1.0, 0.0 + 0.72 * math.cos(a), -0.12)) for a in [TAU * i / 24 for i in range(24)]]
    add("SaddleTrim", tube(rim, 0.04, n=5, cap=False, closed=True), DFLY["gold"], "Gold")
    gl, gr = GRIPS["HandleSit"]
    bars, knobs = [], []
    for g in (gl, gr):
        sx = 1 if g[0] > 0 else -1
        path = [Vector((sx * 0.18, 2.15, zc + 0.75)), Vector((sx * 0.38, 2.38, zc + 1.5)), Vector((sx * 0.72, 2.08, zc + 2.1)), Vector((g[0] * 0.92, g[1] + 0.15, g[2]))]
        bars.append(tube([catmull_pt(path, t) for t in [i / 14 for i in range(15)]], [0.07 - 0.02 * i / 14 for i in range(15)], n=8))
        knobs.append(tube([Vector((g[0] - sx * 0.12, g[1], g[2])), Vector((g[0] + sx * 0.2, g[1] - 0.03, g[2] + 0.02))], 0.085, n=10))
        knobs.append(sphere(Vector((g[0] + sx * 0.22, g[1] - 0.03, g[2] + 0.02)), 0.1, 10, 6))
    add("Antennae", merge(*bars), DFLY["gold"], "Gold")
    add("Grips", merge(*knobs), NAVY, "Matte")
    legs = []
    for i, y in enumerate((0.85, 0.15, -0.55)):
        for sx in (-1, 1):
            legs.append(tube([Vector((sx * 0.45, y, zc - 0.35)), Vector((sx * 0.85, y + 0.15, zc - 0.85)), Vector((sx * 0.7, y + 0.35, zc - 1.35))], [0.06, 0.05, 0.03], n=6))
    for sx in (-1, 1):
        legs.append(tube([Vector((sx * 0.62, 1.0, zc - 0.25)), Vector((sx * 1.05, 1.15, zc - 0.3))], 0.07, n=8))
    add("Legs", merge(*legs), DFLY["gold"], "Gold")
    tips = {tag: (sd * (0.5 + 3.5), y0 - 0.2, zc + 0.42 + 0.35) for tag, sd, y0, L, w, sweep, vc, ph in wings}
    return {
        "Id": "dragonfly", "Name": "Dragonfly", "Contact": "Seat",
        "Attachments": {
            "RiderSeat": ("Saddle", (0, 0, 0)),
            "GripL": ("Grips", gl), "GripR": ("Grips", gr),
            "WingTrail0": ("Wing_FL", tips["FL"]), "WingTrail1": ("Wing_FR", tips["FR"]),
            "WingTrail2": ("Wing_BL", tips["BL"]), "WingTrail3": ("Wing_BR", tips["BR"]),
            "Wake": ("Abdomen", (0, -6.3, zc + 0.3)),
            "Launch": ("Thorax", (0, 0.2, zc - 0.8)),
        },
        "Notes": "Wings flutter with Fin about the nose axis (FinHz 3.2, front/back pairs half a cycle apart). Grips on RideFamilies.StandardGrips.HandleSit.",
    }


def catmull_pt(pts, t):
    """Point on a Catmull-Rom curve through pts (Vectors), t in [0, 1]."""
    n = len(pts) - 1
    f = min(t * n, n - 1e-6)
    i = int(f)
    u = f - i
    p0, p1, p2, p3 = pts[max(i - 1, 0)], pts[i], pts[min(i + 1, n)], pts[min(i + 2, n)]
    return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u ** 3)


# ---------------------------------------------------------------------------------------------
# 5. Carousel (Epic, HandleSit; the pony bobs on its pole and carries the rider)
# ---------------------------------------------------------------------------------------------
CAROUSEL = {"pink": "#FFD6F5", "rose": "#E58FC7", "gold": "#F5D99A", "mint": "#7CE7D5", "white": "#FFFFFF", "bulb": "#FFF4A8",
            "mane1": "#FF9CD6", "mane2": "#C9A8FF", "mane3": "#8FE3FF"}


@flyer("carousel", 7500, "HandleSit")
def build_carousel():
    gl, gr = GRIPS_BUILT["carousel"]  # shipped layout (see GRIPS)
    pole_y = gl[1]
    bob = {"RideMotion": "Bob", "BobAmp": 0.45, "BobHz": 0.45, "BobPhase": 0.0}
    # Pony: one smooth glass body (voxel union), prancing (front legs curled, hind legs reaching back).
    balls = [((0, -0.05, -0.75), 1.0, (0.62, 1.25, 0.62)), ((0, 0.85, -0.55), 0.75, (0.62, 0.7, 0.75)),
             ((0, 1.35, 0.0), 0.5, (0.62, 0.62, 1.1)), ((0, 1.75, 0.55), 0.55, (0.72, 1.0, 0.8)), ((0, 2.25, 0.38), 0.33, (0.85, 1.0, 0.8))]
    for sx in (-1, 1):
        for t in range(5):
            u = t / 4
            balls.append(((sx * 0.3, 1.05 + 0.45 * math.sin(u * 2.4), -1.05 - 0.55 * u + 0.5 * u * u), 0.19 - 0.03 * u, (1, 1, 1)))
            balls.append(((sx * 0.3, -1.0 - 0.75 * u, -1.15 - 0.3 * u), 0.22 - 0.04 * u, (1, 1, 1)))
    PS = 1.25  # pony scale about the saddle (origin)
    balls = [(tuple(c * PS for c in cen), r * PS, sc) for cen, r, sc in balls]
    pony = H["voxel_union"]("Pony", balls, voxel=0.06, smooth_iter=6, target_tris=1700)
    add("Pony", pony, CAROUSEL["pink"], "Glass", motion=dict(bob))
    core = H["voxel_union"]("PonyCore", [((0, 0.0, -0.75 * PS), 0.8 * PS, (0.55, 1.15, 0.5)), ((0, 0.9 * PS, -0.5 * PS), 0.55 * PS, (0.6, 0.7, 0.7))], voxel=0.08, smooth_iter=4, target_tris=300)
    add("PonyCore", core, CAROUSEL["rose"], "Core", motion=dict(bob))
    tree = None
    pony_obj = bpy.data.objects["Pony"]
    tree = H["bvh_of"](pony_obj)
    # Face on the head (eyes facing forward-out, carousel style) and a little horn.
    eyes, shine = [], []
    for sx in (-1, 1):
        o = Vector((sx * 2.0, 1.95 * PS, 0.72 * PS))
        hit = tree.ray_cast(o, Vector((-sx, -0.25, 0)).normalized())
        if hit[0] is not None:
            p, n = hit[0], hit[1]
            eyes.append(sphere(p + n * 0.02, 0.1, 9, 6, (0.7, 0.9, 1.25)))
            shine.append(sphere(p + n * 0.09 + Vector((0, 0.04, 0.05)), 0.035, 6, 4))
    add("PonyEyes", merge(*eyes), EYE, "Matte", motion=dict(bob))
    add("PonyEyeShine", merge(*shine), SHINE, "Matte", motion=dict(bob))
    horn = lathe([(0.001, -0.02)] + [((0.1 * (1 - i / 6) + 0.006) * (1.15 if i % 2 else 1.0), 0.07 * i) for i in range(7)] + [(0.001, 0.46)],
                 Vector((0, 2.0 * PS, 0.98 * PS)), (0, 0.45, 1), segs=8)
    add("Horn", horn, CAROUSEL["gold"], "Gold", motion=dict(bob))
    # Saddle (seat top = origin) with a gold rim and stirrups; mane and tail ribbons in three colours.
    sad = []
    for u in spaced(10, 0.7):
        y = -0.75 + 1.4 * u
        k = rrect(u, 3)
        sad.append((Vector((0, y, -0.1 + 0.06 * (1 - k))), X, Z, max(0.66 * k, 0.04), 0.1 * max(k, 0.3), 0.1 * max(k, 0.3), 3.0))
    add("Saddle", loft(sad, n=16), CAROUSEL["mint"], "Pearl", motion=dict(bob))
    trim = [Vector((0.68 * math.sin(a), 0.74 * math.cos(a), -0.1)) for a in [TAU * i / 18 for i in range(18)]]
    stir = []
    for sx in (-1, 1):
        stir.append(tube([Vector((sx * 0.62, 0.2, -0.3)), Vector((sx * 0.66, 0.3, -0.95))], 0.03, n=4))
        ring = [Vector((sx * 0.67, 0.3 + 0.12 * math.cos(a), -1.05 + 0.1 * math.sin(a))) for a in [TAU * i / 8 for i in range(8)]]
        stir.append(tube(ring, 0.03, n=4, cap=False, closed=True))
    add("SaddleTrim", merge(tube(trim, 0.045, n=5, cap=False, closed=True), *stir), CAROUSEL["gold"], "Gold", motion=dict(bob))
    for i, (col, dx) in enumerate(zip((CAROUSEL["mane1"], CAROUSEL["mane2"], CAROUSEL["mane3"]), (-0.12, 0.0, 0.12))):
        mpath = [Vector((dx, 1.95, 1.0)) * PS, Vector((dx * 1.4, 1.45, 0.75)) * PS, Vector((dx * 1.8 + 0.05 * (i - 1), 1.1, 0.3)) * PS, Vector((dx * 2.2, 0.85, -0.1)) * PS]
        pts = [catmull_pt(mpath, t / 10) for t in range(11)]
        rib = tube(pts, [0.12 - 0.08 * t / 10 for t in range(11)], n=6, flat=0.45, up_hint=Vector((1, 0, 0)))
        tpath = [Vector((dx, -1.35, -0.55)) * PS, Vector((dx * 1.5, -1.85, -0.75)) * PS, Vector((dx * 2.0, -2.15, -1.2)) * PS, Vector((dx * 2.3, -2.2, -1.65)) * PS]
        tpts = [catmull_pt(tpath, t / 10) for t in range(11)]
        tail = tube(tpts, [0.13 - 0.09 * t / 10 for t in range(11)], n=6, flat=0.45, up_hint=Vector((1, 0, 0)))
        add("ManeTail_%d" % (i + 1), merge(rib, tail), col, "Glass", studio={"Transparency": 0.2}, motion=dict(bob))
    # Twisted gold pole (fixed) through the withers; a sleeve with the crossbar rides the pony (grips move with it).
    rings = []
    for k in range(28):
        z = -3.3 + 7.5 * k / 27
        ring = []
        for j in range(8):
            a = TAU * j / 8 + z * 1.6
            r = 0.12 if j % 2 == 0 else 0.085
            ring.append(Vector((r * math.cos(a), pole_y + r * math.sin(a), z)))
        rings.append(ring)
    add("Pole", merge(ring_loft(rings), sphere(Vector((0, pole_y, -3.38)), 0.2, 12, 8)), CAROUSEL["gold"], "Gold")
    sleeve = lathe([(0.001, -0.05), (0.2, 0.0), (0.22, 0.25), (0.2, 0.5), (0.001, 0.55)], Vector((0, pole_y, gl[2] - 0.3)), Z, segs=12)
    bar = [Vector((x, pole_y, gl[2] + 0.04 * (abs(x) / 0.9) ** 2)) for x in [-0.95 + 1.9 * i / 10 for i in range(11)]]
    add("Crossbar", merge(sleeve, tube(bar, 0.065, n=8)), CAROUSEL["gold"], "Gold", motion=dict(bob))
    grips = []
    for g in (gl, gr):
        sx = 1 if g[0] > 0 else -1
        grips.append(tube([Vector((g[0] - sx * 0.2, g[1], g[2] + 0.03)), Vector((g[0] + sx * 0.22, g[1], g[2] + 0.05))], 0.09, n=8))
        grips.append(sphere(Vector((g[0] + sx * 0.25, g[1], g[2] + 0.05)), 0.11, 8, 6))
    add("Grips", merge(*grips), "#FFFFFF", "Pearl", motion=dict(bob))
    # Canopy: striped tent top that turns slowly, a scalloped valance, a ring of chase-blinking bulbs, a finial.
    top_z, apex = 4.2, 5.15
    Rc = 1.8
    for name, col, parity in (("CanopyWhite", CAROUSEL["white"], 0), ("CanopyMint", CAROUSEL["mint"], 1)):
        panels = []
        for k in range(12):
            if k % 2 != parity:
                continue
            a0, a1 = TAU * k / 12, TAU * (k + 1) / 12
            rings_ = []
            for i in range(5):
                t = i / 4
                z = top_z + (apex - top_z) * t ** 1.2
                r = Rc * (1 - t) + 0.02
                droop = 0.08 * math.sin(math.pi * t)
                ring = []
                for j in range(4):
                    a = a0 + (a1 - a0) * j / 3
                    ring.append(Vector((r * math.cos(a), pole_y + r * math.sin(a), z - droop * math.sin(math.pi * j / 3))))
                rings_.append(ring)
            inner = [[p + Vector((0, 0, -0.06)) for p in ring] for ring in rings_]
            bm = bmesh.new()
            vo = [[bm.verts.new(p) for p in ring] for ring in rings_]
            vi = [[bm.verts.new(p) for p in ring] for ring in inner]
            for a_, b_ in zip(range(4), range(1, 5)):
                for j in range(3):
                    bm.faces.new((vo[a_][j], vo[a_][j + 1], vo[b_][j + 1], vo[b_][j]))
                    bm.faces.new((vi[b_][j], vi[b_][j + 1], vi[a_][j + 1], vi[a_][j]))
            for r_ in range(4):
                for side_j in (0, 3):
                    bm.faces.new((vo[r_][side_j], vo[r_ + 1][side_j], vi[r_ + 1][side_j], vi[r_][side_j]))
            for j in range(3):
                bm.faces.new((vo[0][j + 1], vo[0][j], vi[0][j], vi[0][j + 1]))
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            # scalloped valance flap under this panel
            val = []
            for i in range(9):
                a = a0 + (a1 - a0) * i / 8
                val.append(Vector(((Rc + 0.02) * math.cos(a), pole_y + (Rc + 0.02) * math.sin(a), top_z - 0.02)))
            flap = []
            for i in range(6):
                a = a0 + (a1 - a0) * i / 5
                drop = 0.32 + 0.12 * math.sin(math.pi * i / 5)
                flap.append([Vector(((Rc + 0.03) * math.cos(a), pole_y + (Rc + 0.03) * math.sin(a), top_z - 0.02 - drop * d)) for d in (0.0, 1.0)])
            fb = bmesh.new()
            fv = [[fb.verts.new(p) for p in col_] for col_ in flap]
            fvi = [[fb.verts.new(p * 1.0 - Vector((math.cos(a0 + (a1 - a0) * i / 5), math.sin(a0 + (a1 - a0) * i / 5), 0)) * 0.04) for p in col_] for i, col_ in enumerate(flap)]
            for i in range(5):
                fb.faces.new((fv[i][0], fv[i + 1][0], fv[i + 1][1], fv[i][1]))
                fb.faces.new((fvi[i][1], fvi[i + 1][1], fvi[i + 1][0], fvi[i][0]))
                fb.faces.new((fv[i][1], fv[i + 1][1], fvi[i + 1][1], fvi[i][1]))
            fb.faces.new((fv[0][0], fv[0][1], fvi[0][1], fvi[0][0]))
            fb.faces.new((fv[5][1], fv[5][0], fvi[5][0], fvi[5][1]))
            bmesh.ops.recalc_face_normals(fb, faces=fb.faces)
            panels += [bm, fb]
        add(name, merge(*panels), col, "Pearl", motion={"RideMotion": "Spin", "SpinAxis": "Y", "SpinSpeed": 0.35})
    ring = [Vector((Rc * 0.98 * math.cos(a), pole_y + Rc * 0.98 * math.sin(a), top_z - 0.06)) for a in [TAU * i / 28 for i in range(28)]]
    add("CanopyRing", merge(tube(ring, 0.06, n=5, cap=False, closed=True),
                            lathe([(0.001, -0.02), (0.2, 0.0), (0.24, 0.12), (0.12, 0.3), (0.2, 0.42), (0.001, 0.6)], Vector((0, pole_y, apex - 0.05)), Z, segs=12),
                            lathe([(0.3, -0.1), (0.36, 0.0), (0.3, 0.1), (0.001, 0.12), (0.001, -0.12)], Vector((0, pole_y, top_z - 0.12)), Z, segs=14)),
        CAROUSEL["gold"], "Gold")
    bulbs = []
    for k in range(16):
        a = TAU * (k + 0.5) / 16
        bulbs.append(sphere(Vector((Rc * 1.0 * math.cos(a), pole_y + Rc * math.sin(a), top_z - 0.16)), 0.09, 6, 4))
    bulbs.append(sphere(Vector((0, pole_y, apex + 0.62)), 0.13, 8, 6))
    add("Bulbs", merge(*bulbs), CAROUSEL["bulb"], "Neon", motion={"RideMotion": "Pulse"})
    return {
        "Id": "carousel", "Name": "Carousel", "Contact": "Seat",
        "Attachments": {
            "RiderSeat": ("Saddle", (0, 0, 0)),
            "GripL": ("Crossbar", gl), "GripR": ("Crossbar", gr),
            "Trail0": ("CanopyRing", (-Rc, pole_y, top_z - 0.2)), "Trail1": ("CanopyRing", (Rc, pole_y, top_z - 0.2)),
            "Notes": ("Bulbs", (0, pole_y, apex + 0.6)),
            "Wake": ("Pony", (0, -2.7, -1.5)),
            "Launch": ("Pole", (0, pole_y, -3.4)),
        },
        "ModelAttributes": {"RiderMount": "Pony"},
        "Notes": "Bob (BobAmp 0.45, BobHz 0.45) on Pony, PonyCore, eyes, Horn, Saddle, SaddleTrim, ManeTail_n, Crossbar and Grips; "
                 "RiderSeat, GripL and GripR sit on bobbing parts and RiderMount = Pony. Pole, canopy ring and bulbs stay fixed; "
                 "CanopyWhite/CanopyMint Spin about the pole; Bulbs Pulse (chase blink if your Pulse supports a phase).",
    }


# ---------------------------------------------------------------------------------------------
# 6. Sunwing (Legendary, Kneel) - set: Glass Phoenix, Emberwing
# ---------------------------------------------------------------------------------------------
SUN = {"orange": "#FF7A2E", "gold": "#FFD34E", "core": "#B8321A", "trim": "#F5D99A", "ember": "#FFB13D", "flame": "#FFE38A"}


@flyer("sunwing", 8000, "Kneel")
def build_sunwing():
    SW = 1.2  # bird scale about the saddle (origin); the saddle stays rider-sized
    balls = [((0, 0.1, -1.0), 1.0, (1.15, 2.1, 0.92)), ((0, -1.6, -0.85), 0.8, (1.0, 1.1, 0.8)), ((0, 1.7, -0.75), 0.75, (0.95, 0.9, 0.9))]
    for i in range(7):
        t = i / 6
        balls.append(((0, 2.2 + 1.3 * t, -0.5 + 1.75 * t ** 0.85), 0.5 - 0.17 * t, (1, 1, 1)))
    balls.append(((0, 3.65, 1.42), 0.62, (0.95, 1.1, 0.9)))
    balls = [(tuple(c * SW for c in cen), r * SW, sc) for cen, r, sc in balls]
    body = H["voxel_union"]("Body", balls, voxel=0.08, smooth_iter=6, target_tris=1700)
    add("Body", body, SUN["orange"], "Glass")
    add("BodyCore", H["voxel_union"]("BodyCore", [((0, 0.1 * SW, -1.05 * SW), 0.8 * SW, (1.1, 2.0, 0.85))], voxel=0.1, smooth_iter=4, target_tris=260),
        SUN["core"], "Core")
    tree = H["bvh_of"](bpy.data.objects["Body"])
    # Face: beak, eyes with shine.
    head = Vector((0, 3.65, 1.42)) * SW
    add("Beak", lathe([(0.001, -0.05), (0.22, 0.0), (0.18, 0.2), (0.08, 0.42), (0.001, 0.55)], head + Vector((0, 0.6, -0.12)), (0, 1, -0.45), segs=12),
        SUN["gold"], "Gold")
    eyes, shine = [], []
    for sx in (-1, 1):
        hit = tree.ray_cast(head + Vector((sx * 3, 0.35, 0.12)), Vector((-sx, 0, 0)))
        if hit[0] is not None:
            p, n = hit[0], hit[1]
            eyes.append(sphere(p + n * 0.02, 0.15, 12, 8, (0.6, 1.0, 1.25)))
            shine.append(sphere(p + n * 0.11 + Vector((0, 0.05, 0.07)), 0.05, 6, 4))
    add("Eyes", merge(*eyes), EYE, "Matte")
    add("EyeShine", merge(*shine), SHINE, "Matte")
    crest = []
    for i, (dx, lean, L) in enumerate(((-0.18, -0.35, 0.95), (0.0, -0.15, 1.25), (0.18, -0.35, 0.95))):
        pts = [head + Vector((dx, -0.1, 0.45)), head + Vector((dx * 1.5, -0.35 + lean * 0.4, 0.45 + L * 0.55)), head + Vector((dx * 2.0, -0.75 + lean, 0.45 + L))]
        crest.append(tube([catmull_pt(pts, t / 7) for t in range(8)], [0.17, 0.16, 0.14, 0.11, 0.08, 0.05, 0.025, 0.008], n=6))
    add("Crest", merge(*crest), SUN["ember"], "Glass", studio={"Transparency": 0.15}, motion={"RideMotion": "Flame", "FlamePhase": 0.6})
    # Wings: swept up, scalloped trailing edge, gold coverts, Neon ember veins, gold tips that over-bend on the beat.
    wing_pts = [(0.0, -0.4), (0.4, 0.25), (1.1, 0.95), (2.0, 1.55), (3.0, 1.95), (4.1, 2.1), (4.9, 1.85), (4.6, 1.45), (4.85, 1.05), (4.3, 0.85),
                (4.4, 0.4), (3.7, 0.35), (3.6, -0.15), (2.9, -0.05), (2.7, -0.55), (2.0, -0.4), (1.7, -0.85), (1.05, -0.6), (0.6, -0.95)]
    covert = [(0.05, -0.3), (0.45, 0.25), (1.15, 0.85), (2.0, 1.35), (2.4, 0.95), (2.1, 0.45), (1.5, 0.0), (0.9, -0.4)]
    tips = [((4.75, 1.45), 0.55), ((4.5, 0.95), 0.25), ((4.15, 0.45), 0.0), ((3.5, -0.05), -0.35), ((2.65, -0.42), -0.6), ((1.75, -0.7), -0.85)]
    for side, tag in ((-1, "L"), (1, "R")):
        hinge = Vector((side * 0.95, 0.35, -0.55)) * SW
        m = Matrix.Translation(hinge) @ Matrix.Rotation(side * -0.42, 4, "Y") @ Matrix.Rotation(side * 0.18, 4, "Z") @ Matrix.Diagonal((side * SW, SW, SW, 1))
        beat = {"RideMotion": "Wing", "WingSide": side, "MotionPivotWorld": hinge, "WingAngle": 0.32}
        add("Wing_" + tag, flat_slab(wing_pts, 0.12, m, bevel=0.035, segs=1), SUN["orange"], "Glass", motion=dict(beat))
        add("WingCovert_" + tag, flat_slab(covert, 0.08, m @ Matrix.Translation((0, -0.08, 0)), bevel=0.025, segs=1), SUN["gold"], "Glass",
            studio={"Transparency": 0.2}, motion=dict(beat))
        tb = []
        for (u, v), ang in tips:
            mm = m @ Matrix.Translation((u - 0.15 * math.cos(ang), -0.06, v - 0.15 * math.sin(ang))) @ Matrix.Rotation(-ang, 4, "Y")
            tb.append(flat_slab([(-0.25, 0.0), (0.05, 0.16), (0.35, 0.07), (0.42, -0.04), (0.05, -0.16)], 0.08, mm, bevel=0.02, segs=1))
        add("WingTips_" + tag, merge(*tb), SUN["gold"], "Gold", motion={"RideMotion": "Wing", "WingSide": side, "MotionPivotWorld": hinge, "WingAngle": 0.4})
        veins = []
        for (u, v), _ in tips:
            veins.append(tube([m @ Vector((0.3, 0.07, 0.0)), m @ Vector((u * 0.5, 0.07, v * 0.42 + 0.08)), m @ Vector((u * 0.78, 0.07, v * 0.74))], [0.03, 0.026, 0.01], n=4))
        add("EmberVeins_" + tag, merge(*veins), SUN["flame"], "Neon", studio={"Transparency": 0.1}, motion=dict(beat))
    # Three tail feathers (5 long) sweeping back and down, each with a glowing eye-spot.
    for i, (dx, droop, L, lag) in enumerate(((-0.5, 0.55, 4.4, 0.7), (0.0, 0.3, 5.0, 0.9), (0.5, 0.55, 4.4, 1.1))):
        root = Vector((dx * 0.4, -2.3, -0.8)) * SW
        L, droop = L * SW, droop * SW
        pts = [root, root + Vector((dx * 0.6, -L * 0.35, -droop * 0.6)), root + Vector((dx * 1.3, -L * 0.7, -droop * 1.1)), root + Vector((dx * 1.7, -L, -droop * 1.2))]
        cp = [catmull_pt(pts, t / 12) for t in range(13)]
        feather = tube(cp, [(0.14 + 0.46 * math.sin(math.pi * min(1.0, t / 12 * 1.1)) ** 1.3) * SW for t in range(13)], n=8, flat=0.22, up_hint=Vector((0, 0, 1)))
        tail_m = {"RideMotion": "Tail", "MotionPivotWorld": root, "TailAngle": 0.16, "TailLag": lag}
        add("TailFeather_%d" % (i + 1), feather, SUN["orange"] if i != 1 else SUN["ember"], "Glass", motion=dict(tail_m))
        spot = sphere(cp[10] + Vector((0, 0, 0.06)), 0.36 * SW, 12, 6, (1.0, 1.25, 0.22))
        add("TailEye_%d" % (i + 1), spot, SUN["gold"], "Neon", studio={"Transparency": 0.1}, motion=dict(tail_m))
    # Feathered kneeling saddle (origin = pad top) and body ember veins.
    sad = []
    for u in spaced(10, 0.7):
        y = -1.35 + 2.3 * u
        k = rrect(u, 3)
        sad.append((Vector((0, y, -0.1)), X, Z, max(0.85 * k, 0.04), 0.1 * max(k, 0.3), 0.12 * max(k, 0.3), 3.0))
    add("Saddle", loft(sad, n=16), SUN["core"], "Pearl")
    rim = [Vector((0.9 * math.sin(a), -0.2 + 1.22 * math.cos(a), -0.12)) for a in [TAU * i / 24 for i in range(24)]]
    plumes = [tube(rim, 0.06, n=5, cap=False, closed=True)]
    for sx in (-1, 1):
        for k in range(3):
            y = 0.75 - 0.75 * k
            mm = Matrix.Translation((sx * 0.92, y, -0.08)) @ Matrix.Rotation(sx * 0.5, 4, "Y") @ Matrix.Rotation(math.pi / 2, 4, "Z") @ Matrix.Rotation(-0.5, 4, "Y")
            plumes.append(flat_slab([(0.0, -0.12), (0.35, -0.16), (0.62, -0.06), (0.7, 0.04), (0.35, 0.14), (0.0, 0.1)], 0.06, mm @ Matrix.Rotation(math.pi / 2, 4, "X"), bevel=0.02, segs=1))
    add("SaddleTrim", merge(*plumes), SUN["trim"], "Gold")
    bv = []
    for sx in (-1, 1):
        for zoff in (-0.45, -0.95):
            pts = []
            for t in range(8):
                y = (1.6 - 3.6 * t / 7) * SW
                hit = tree.ray_cast(Vector((sx * 5, y, zoff * SW)), Vector((-sx, 0, 0)))
                if hit[0] is not None:
                    pts.append(hit[0] + hit[1] * 0.02)
            if len(pts) > 2:
                bv.append(tube(pts, 0.03, n=4))
    add("BodyVeins", merge(*bv), SUN["flame"], "Neon", studio={"Transparency": 0.1}, motion={"RideMotion": "Pulse"})
    return {
        "Id": "sunwing", "Name": "Sunwing", "Contact": "Feet",
        "Attachments": {
            "RiderFeet": ("Saddle", (0, 0, 0)),
            "WingTrail0": ("WingTips_L", (-5.3 * SW, 1.9 * SW, 1.9 * SW)), "WingTrail1": ("WingTips_R", (5.3 * SW, 1.9 * SW, 1.9 * SW)),
            "Embers": ("Body", (0, -0.6 * SW, -1.9 * SW)),
            "Wake": ("TailFeather_2", (0, -7.2 * SW, -1.1 * SW)),
            "Launch": ("Body", (0, 0, -1.9 * SW)),
            "Cry": ("Beak", (0, 4.5 * SW, 1.2 * SW)),
        },
        "Notes": "Wing beat = Wing (WingAngle 0.32); the gold tips use Wing with 0.4 so they over-bend like lagging feather tips. "
                 "Crest = Flame, tail feathers and eye-spots = Tail (lag 0.7/0.9/1.1), BodyVeins = Pulse.",
    }


# ---------------------------------------------------------------------------------------------
# 7. Starwhale (Mythic, Sit)
# ---------------------------------------------------------------------------------------------
WHALE = {"indigo": "#2B2A7A", "violet": "#7A5CFF", "star": "#FFE9A8", "white": "#F4F1FF", "swirl": "#C9A8FF", "pink": "#FF9FE0"}


@flyer("starwhale", 9000, "Sit")
def build_starwhale():
    zc = -2.15
    Y0, Y1 = -6.2, 4.6
    L = Y1 - Y0
    hw = [(0, 0.12), (0.06, 0.32), (0.22, 0.95), (0.45, 1.75), (0.66, 2.0), (0.82, 1.92), (0.93, 1.6), (0.985, 1.05), (1.0, 0.25)]
    ht = [(0, 0.12), (0.06, 0.3), (0.22, 0.85), (0.45, 1.5), (0.66, 1.9), (0.82, 1.85), (0.93, 1.55), (0.985, 1.0), (1.0, 0.25)]
    hb = [(0, 0.12), (0.06, 0.3), (0.22, 0.8), (0.45, 1.55), (0.66, 1.8), (0.82, 1.7), (0.93, 1.4), (0.985, 0.95), (1.0, 0.22)]

    def zof(u):
        return zc + 0.55 * (1 - u) ** 3

    def st(u, k=1.0):
        return Vector((0, Y0 + L * u, zof(u))), catmull(hw, u) * k, catmull(ht, u) * k, catmull(hb, u) * k
    frames = []
    for u in spaced(30, 0.45):
        c, a, bt, bb = st(u)
        frames.append((c, X, Z, max(a, 0.03), max(bt, 0.03), max(bb, 0.03), 2.15))
    add("Body", loft(frames, n=28), WHALE["indigo"], "Glass", studio={"Transparency": 0.45})   # H: the galaxy only reads through a clearer body
    core = []
    for u in spaced(16, 0.4)[1:-1]:
        u = 0.15 + 0.78 * u
        c, a, bt, bb = st(u, 0.72)
        core.append((c + Vector((0, 0, -0.05)), X, Z, a, bt, bb, 2.1))
    add("BodyCore", loft(core, n=16), WHALE["violet"], "Core", studio={"Transparency": 0.65})
    # Inner galaxy: two-arm spiral (180-degree symmetric, so Spin turns it about its own centre) plus star points.
    gc = Vector((0, Y0 + L * 0.66, zc + 0.05))
    arms = []
    for arm in range(2):
        pts, rad = [], []
        for i in range(14):
            t = i / 13
            a = arm * math.pi + t * 3.9
            r = 0.15 + 1.35 * t
            pts.append(gc + Vector((r * math.cos(a), r * math.sin(a) * 1.2, 0.05 * math.sin(t * 9))))
            rad.append(0.3 * (1 - 0.75 * t) + 0.04)
        arm_bm = tube(pts, rad, n=5)
        for v in arm_bm.verts:
            v.co.z = gc.z + (v.co.z - gc.z) * 0.3
        arms.append(arm_bm)
    arms.append(sphere(gc, 0.45, 14, 9, (1, 1, 0.6)))
    add("GalaxySwirl", merge(*arms), "#F2B8FF", "Neon", studio={"Transparency": 0.1},
        motion={"RideMotion": "Spin", "SpinAxis": "Y", "SpinSpeed": 0.3})
    rng = random.Random(23)
    stars, star_pts = [], []
    while len(star_pts) < 20:
        u = rng.uniform(0.12, 0.92)
        c, a, bt, bb = st(u, 0.62)
        p = c + Vector((rng.uniform(-1, 1) * a, 0, rng.uniform(-0.8, 1) * bt * 0.9))
        if any((p - q).length < 0.75 for q in star_pts):
            continue
        star_pts.append(p)
        s_ = rng.uniform(0.07, 0.13)
        tmp = bmesh.new()
        for ax in (X, Y, Z):
            stars.append(lathe([(0.001, -s_ * 2.2), (s_ * 0.45, 0.0), (0.001, s_ * 2.2)], p, ax, segs=4))
    add("StarPoints", merge(*stars), WHALE["star"], "Neon", motion={"RideMotion": "Pulse"})
    # Constellation lines on the shell joining the stars near the top (Pulse draws/fades them).
    lines = []
    top_stars = sorted(star_pts, key=lambda q: -q.z)[:9]
    chain = sorted(top_stars, key=lambda q: q.y)
    tree = H["bvh_of"](bpy.data.objects["Body"])
    for a_, b_ in zip(chain, chain[1:]):
        seg = []
        for t in range(6):
            q = a_.lerp(b_, t / 5)
            hit = tree.ray_cast(Vector((q.x, q.y, 6)), Vector((0, 0, -1)))
            if hit[0] is not None:
                seg.append(hit[0] + hit[1] * 0.03)
        if len(seg) >= 2:
            lines.append(tube(seg, 0.012, n=4))
            lines.append(sphere(seg[0], 0.06, 6, 4))
    add("ConstellationLines", merge(*lines), "#FFE07A", "Neon", studio={"Transparency": 0.35}, motion={"RideMotion": "Pulse"})
    # Pearl belly with throat grooves.
    belly = []
    for u in spaced(16, 0.4):
        u = 0.4 + 0.55 * u
        c, a, bt, bb = st(u)
        belly.append((c + Vector((0, 0, -bb * 0.86)), X, Z, a * 0.62, 0.1, bb * 0.17, 2.4))
    grooves = []
    for k in range(-2, 3):
        x = k * 0.32
        pts = []
        for t in range(8):
            u = 0.6 + 0.33 * t / 7
            c, a, bt, bb = st(u)
            pts.append(Vector((x * (1 - 0.3 * t / 7), c.y, c.z - bb * 1.0 - 0.02)))
        grooves.append(tube(pts, 0.035, n=4))
    add("Belly", merge(loft(belly, n=16), *grooves), WHALE["white"], "Pearl")
    # Fluke (Swing about the tail stock) and pectoral fins (Fin paddle).
    stock = Vector((0, Y0 + 0.25, zof(0.02) + 0.1))
    fluke_pts = [(0.0, 0.25), (0.8, 0.5), (1.7, 0.75), (2.5, 0.65), (2.85, 0.25), (2.4, 0.05), (1.6, -0.05), (0.8, -0.25), (0.0, -0.4),
                 (-0.8, -0.25), (-1.6, -0.05), (-2.4, 0.05), (-2.85, 0.25), (-2.5, 0.65), (-1.7, 0.75), (-0.8, 0.5)]
    fm = Matrix.Translation(stock + Vector((0, -0.85, 0.1))) @ Matrix.Rotation(-math.pi / 2, 4, "X") @ Matrix.Rotation(math.pi, 4, "Z") @ Matrix.Diagonal((1.3, 1.3, 1.3, 1))
    add("Fluke", merge(flat_slab(fluke_pts, 0.2, fm, bevel=0.06, segs=1), tube([stock + Vector((0, 0.3, 0)), stock + Vector((0, -0.8, 0.1))], [0.28, 0.2], n=12)),
        WHALE["indigo"], "Glass", motion={"RideMotion": "Swing", "MotionPivotWorld": stock + Vector((0, 0.4, 0))})
    for side, tag in ((-1, "L"), (1, "R")):
        u = 0.7
        c, a, bt, bb = st(u)
        root = c + Vector((side * a * 0.88, 0, -bb * 0.45))
        fin_pts = [(0.0, 0.3), (0.9, 0.35), (1.8, 0.1), (2.2, -0.2), (1.6, -0.35), (0.7, -0.3), (0.0, -0.3)]
        mm = Matrix.Translation(root) @ Matrix.Rotation(side * -0.55, 4, "Y") @ Matrix.Rotation(side * 0.35, 4, "Z") @ Matrix.Diagonal((side, 1, 1, 1)) @ Matrix.Rotation(math.pi / 2, 4, "X")
        add("Fin_" + tag, flat_slab(fin_pts, 0.16, mm, bevel=0.05, segs=1), WHALE["indigo"], "Glass",
            motion={"RideMotion": "Fin", "MotionPivotWorld": root, "FinAxis": "Z", "FinAngle": 0.22 * side, "FinHz": 0.6, "FinPhase": 0 if side < 0 else 0.5})
    # Face: eyes with shine and a soft smile; blowhole ring.
    head_u = 0.9
    eyes, shine = [], []
    for sx in (-1, 1):
        c, a, bt, bb = st(head_u)
        hit = tree.ray_cast(Vector((sx * 6, c.y, c.z + 0.1)), Vector((-sx, 0, 0)))
        if hit[0] is not None:
            p, n = hit[0], hit[1]
            eyes.append(sphere(p + n * 0.03, 0.24, 14, 9, (0.5, 0.9, 1.2)))
            shine.append(sphere(p + n * 0.13 + Vector((0, 0.07, 0.11)), 0.075, 8, 5))
            shine.append(sphere(p + n * 0.12 + Vector((0, -0.06, -0.09)), 0.035, 6, 4))
    add("Eyes", merge(*eyes), EYE, "Matte")
    add("EyeShine", merge(*shine), SHINE, "Matte")
    smile = []
    for sx in (-1, 1):
        pts = []
        for t in range(7):
            y = Y0 + L * (0.955 - 0.13 * t / 6)
            hit = tree.ray_cast(Vector((sx * 6, y, zof(0.95) - 0.45 - 0.12 * math.sin(math.pi * t / 6))), Vector((-sx, 0, 0)))
            if hit[0] is not None:
                pts.append(hit[0] + hit[1] * 0.02)
        if len(pts) > 2:
            smile.append(tube(pts, 0.04, n=4))
    bh = Vector((0, Y0 + L * 0.82, 0))
    hit = tree.ray_cast(Vector((0, bh.y, 6)), Vector((0, 0, -1)))
    if hit[0] is not None:
        ring = [hit[0] + Vector((0.16 * math.cos(a), 0.1 * math.sin(a), 0.02)) for a in [TAU * i / 12 for i in range(12)]]
        smile.append(tube(ring, 0.04, n=4, cap=False, closed=True))
        spout = hit[0]
    else:
        spout = Vector((0, bh.y, 0))
    add("SmileBlowhole", merge(*smile), EYE, "Matte")
    # Saddle (seat top = origin) on the back with a glass backrest and a pearl rim.
    sad = []
    for u in spaced(10, 0.7):
        y = -0.85 + 1.6 * u
        k = rrect(u, 3)
        sad.append((Vector((0, y, -0.12 + 0.05 * (1 - k))), X, Z, max(0.78 * k, 0.04), 0.12 * max(k, 0.3), 0.3 * max(k, 0.3), 3.0))
    add("Saddle", loft(sad, n=16), WHALE["violet"], "Pearl")
    back = []
    for u in spaced(8, 0.7):
        z = -0.1 + 1.45 * u
        k = rrect(u, 4)
        back.append((Vector((0, -1.0 - 0.18 * u, z)), X, Y, max(0.75 * k, 0.04), 0.07, 0.07, 3.0))
    add("Backrest", loft(back, n=14), "#C9DBFF", "Glass", studio={"Transparency": 0.35})
    rim = [Vector((0.82 * math.sin(a), -0.05 + 0.86 * math.cos(a), -0.13)) for a in [TAU * i / 24 for i in range(24)]]
    add("SaddleRim", tube(rim, 0.05, n=5, cap=False, closed=True), PEARL, "Pearl")
    return {
        "Id": "starwhale", "Name": "Starwhale", "Contact": "Seat",
        "Attachments": {
            "RiderSeat": ("Saddle", (0, 0, 0)),
            "Spout": ("SmileBlowhole", tuple(spout)),
            "Wake": ("Fluke", (0, Y0 - 1.6, zc + 0.6)),
            "Trail0": ("Fin_L", (-3.6, Y0 + L * 0.7, zc - 0.9)), "Trail1": ("Fin_R", (3.6, Y0 + L * 0.7, zc - 0.9)),
            "Launch": ("Body", (0, 0, zc - 2.0)),
            "StarRing": ("Body", (0, Y1 + 2.0, zc)),
        },
        "Notes": "GalaxySwirl spins (Y) about its own centre (2-arm spiral, 180-degree symmetric). StarPoints and ConstellationLines Pulse. "
                 "Fluke = Swing about the tail stock; Fin_L/R paddle (Fin about the nose axis, half a cycle apart). Spout = blowhole emitter; "
                 "StarRing = where the Mythic launch ring of stars forms ahead of the nose.",
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
    meta_box = {}

    def run():
        meta_box.update(fn())
        return meta_box
    H["BUILDERS"][gid] = run
    H["BUDGET"][gid] = budget
    manifest = H["build"](gid, False, samples)
    folder = os.path.join(H["OUT"], gid)
    manifest["Family"] = family
    if meta_box.get("ModelAttributes"):
        manifest["ModelAttributes"] = meta_box["ModelAttributes"]   # set on the Model in Studio (e.g. RiderMount)
        if "RiderMount" in meta_box["ModelAttributes"]:
            manifest["RiderMount"] = meta_box["ModelAttributes"]["RiderMount"]   # top-level key read by H's installer
    if meta_box.get("Notes"):
        manifest["Notes"] = meta_box["Notes"]
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
