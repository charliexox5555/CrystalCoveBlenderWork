"""Starter Pack glassy (Daybreak set): Sunny, a glass rooster that crows up the sun. Headless Blender:

    B=/Applications/Blender.app/Contents/MacOS/Blender
    T=docs/art/starter_pack/tools/build_starter.py
    $B -b --factory-startup --python $T -- preview sunny_rooster [--samples 16] [--out DIR]
    $B -b --factory-startup --python $T -- build sunny_rooster [--samples 96] [--force]
    $B -b --factory-startup --python $T -- validate sunny_rooster

Reuses the Roster V2 launch builder (docs/art/launch_glassies/tools/build_launch.py) as a library, like the Daily
glassies (docs/art/daily_glassies/tools/build_daily.py): same v4 glass, face language, motion tags, rig4 icon camera,
fracture, checks and manifest. Outputs: assets/blender/glassies/sunny_rooster/v4/; previews in docs/art/starter_pack.
"""
import math
import os
import sys

import bmesh
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
STARTER_DOCS = os.path.abspath(os.path.join(HERE, ".."))  # HERE itself is overwritten by the library's globals below
LAUNCH_PATH = os.path.abspath(os.path.join(HERE, "..", "..", "launch_glassies", "tools", "build_launch.py"))
L = {"__name__": "build_launch_lib", "__file__": LAUNCH_PATH}
exec(compile(open(LAUNCH_PATH, encoding="utf-8").read(), LAUNCH_PATH, "exec"), L)
globals().update({k: v for k, v in L.items() if not k.startswith("__")})

L["LAUNCH"].update({
    "sunny_rooster": ("Sunny", "Epic", "#FF9E7A", 0.80),
})
L["doc_path"] = lambda *parts: os.path.join(STARTER_DOCS, *parts)

# Daybreak palette (shared with the Daybreak finisher and the Dawn Kite flyer).
PEACH, ROSE, CORAL, AMBER, GOLD, LILAC, SUN = "#FF9E7A", "#FF5D7E", "#FF8A5C", "#FFB547", "#FFD45C", "#C7A6FF", "#FFF1B0"


def front_hit(surf, x, z):
    """Front surface point with an outward normal. Casts just off the mirror seam (x = 0 rays can slip through)."""
    p, n = surf.hit(Vector((x + 0.004, -5, z)), (0, 1, 0))
    return p, (-n if n.y > 0 else n)


# ------------------------------------------------------------------------------------------
# Sunny (Starter Pack, Epic, Heavy): a plump glass rooster with a dawn-gradient tail and a sun charm.
# ------------------------------------------------------------------------------------------

@launch("sunny_rooster")
def b_sunny_rooster(gid):
    head_c = Vector((0, -0.16, -0.6))
    body_c = Vector((0, 0.06, -1.32))
    lo, hi = Vector((-0.8, -0.8, -1.96)), Vector((0.8, 0.72, -0.2))

    def shape(bm):
        ellipsoid_bm(bm, head_c, (0.38, 0.36, 0.38), 18, 12)
        ellipsoid_bm(bm, body_c, (0.74, 0.66, 0.62), 22, 14)
        ellipsoid_bm(bm, (0, -0.1, -0.94), (0.36, 0.34, 0.28), 12, 8)                # neck
        ellipsoid_bm(bm, (0, -0.3, -1.2), (0.48, 0.34, 0.42), 14, 9)                 # puffed-out chest
        ellipsoid_bm(bm, (0, 0.46, -1.18), (0.34, 0.26, 0.3), 10, 6)                 # tail base
    body = organic("Body", shape, 260, fit=(lo, hi), voxel=0.024, max_tris=390)
    paint(body, PEACH, role="Body", alpha=0.8, transmission=0.55)
    body["plain_normals"] = True
    surf = Surface(body)
    ds = face(surf, head_c, 0.16, head_c.z + 0.07, eye=(0.08, 0.105, 0.05), cheek_dx=0.25, cheek_dz=-0.13,
              seg=(6, 4), shine_seg=((4, 3), (4, 3)), cheek_seg=(5, 3))
    # Beak: a short gold cone, and a rose wattle hanging under it.
    bp, _ = front_hit(surf, 0, head_c.z - 0.06)
    bk = bmesh.new()
    lathe_into(bk, [(0, -0.03), (0.11, -0.03), (0.1, 0.06), (0.055, 0.15), (0, 0.21)],
               Matrix.Translation(bp) @ Matrix.Rotation(math.pi / 2 + 0.3, 4, "X") @ Matrix.Diagonal((1.3, 0.85, 1, 1)), 8)
    beak = paint(_obj("Beak", bk), GOLD, "SmoothPlastic")
    anim(beak, bp, (1, 0, 0), None, kick(12), note="opens on the crow")
    wattle = paint(blob("Wattle", bp + Vector((0, -0.04, -0.15)), (0.075, 0.05, 0.1), 7, 5), ROSE)
    anim(wattle, bp + Vector((0, 0, -0.05)), (1, 0, 0), sway(8, 1.6), kick(22), note="wobbles on hits")
    ds += [beak, wattle]
    # Comb: three round lobes on the crown, a little forward so the hang loop sits behind it.
    cb = bmesh.new()
    crown = head_c + Vector((0, -0.04, 0.34))
    for dy, dz, r in ((-0.17, 0.0, 0.11), (-0.02, 0.09, 0.135), (0.14, 0.02, 0.1)):
        ellipsoid_bm(cb, crown + Vector((0, dy, dz)), (0.075, r, r), 6, 4)
    comb = paint(_obj("Comb", cb), ROSE)
    anim(comb, crown, (1, 0, 0), sway(4, 2.2), kick(18), lod_keep=True, note="comb wobble; stands tall at Ready")
    ds.append(comb)
    # Folded wings on the sides, flaring on hits and in the crow windup.
    wing_pts = [(0.0, 0.18), (0.26, 0.26), (0.52, 0.12), (0.64, -0.12), (0.46, -0.3), (0.26, -0.22), (0.06, -0.14)]
    for s_, label in ((-1, "L"), (1, "R")):
        shoulder = Vector((s_ * 0.7, -0.12, -1.1))
        m = Matrix.Translation(shoulder) @ Matrix.Rotation(math.pi / 2 + s_ * 0.18, 4, "Z") @ Matrix.Diagonal((-s_, 1, 1, 1))
        wgb = bmesh.new()
        slab_bm(wgb, wing_pts, 0.08, 0.02, 1, m)
        bmesh.ops.recalc_face_normals(wgb, faces=wgb.faces)
        wing = paint(_obj("Wing_" + label, wgb, sharp_deg=55), CORAL)
        anim(wing, shoulder, (0, 1, 0) if s_ < 0 else (0, -1, 0), sway(4, 2.0, 0.5 if s_ > 0 else 0.0), flare(26),
             lod_keep=True, note="flap on hits; spread wide in the crow")
        ds.append(wing)
    # Tail: five sickle feathers arching up and over, the dawn sky from rose to gold to lilac.
    root = Vector((0, 0.56, -1.12))
    colors = (ROSE, CORAL, AMBER, GOLD, LILAC)
    for i, (dx, up, back, color) in enumerate(zip((-0.2, -0.1, 0.0, 0.1, 0.2), (0.62, 0.8, 0.9, 0.78, 0.6), (0.34, 0.42, 0.46, 0.42, 0.34), colors)):
        pts = spline([root + Vector((dx * 0.5, 0, 0)),
                      root + Vector((dx * 1.2, back * 0.5, up * 0.7)),
                      root + Vector((dx * 1.7, back * 1.05, up * 0.95)),
                      root + Vector((dx * 2.0, back * 1.35, up * 0.55))], 6)
        tb = bmesh.new()
        tube_bm(tb, pts, [0.1 - 0.082 * k / (len(pts) - 1) for k in range(len(pts))], 4)
        tf = paint(_obj(f"TailFeather_{i + 1}", tb), color)
        anim(tf, root, (1, 0, 0), sway(5 + i % 2, 2.0, i * 0.5), kick(16), lod_keep=(i == 2),
             note="dawn tail; fans up in the crow")
        ds.append(tf)
    # Sun charm on the chest (Epic accent): a gold sun with eight rays; glows at Ready, flares on the crow.
    sp, sn = front_hit(surf, 0, -1.2)
    sb = bmesh.new()
    slab_bm(sb, star_points(8, 0.19, 0.12), 0.05, 0, 1, Matrix.Translation(sp + sn * 0.006) @ Matrix.Rotation(-0.35, 4, "X"))
    charm = paint(_obj("SunCharm", sb, smooth=False), GOLD, "Neon")
    anim(charm, sp, (0, 1, 0), pulse(0.08, 2.0), flash(0.3), note="Epic accent: glows at Ready, flares on the crow")
    ds.append(charm)
    # The sunrise inside: a warm inner glass layer (v4 two-layer look).
    fill = bmesh.new()
    ellipsoid_bm(fill, body_c + Vector((0, -0.04, 0.02)), (0.52, 0.46, 0.44), 10, 6)
    core = as_inner(paint(_obj("SunriseGlow", fill), AMBER, alpha=0.55, transmission=0.6))
    anim(core, body_c, (0, 0, 1), pulse(0.04, 2.4), squash(0.93, 4.0, 0.35), note="inner sunrise glass")
    ds.append(core)
    # Gold feet tucked under the body.
    ft = bmesh.new()
    for s_ in (-1, 1):
        base = Vector((s_ * 0.22, -0.18, -1.86))
        for k_ in (-1, 1):
            tube_bm(ft, [base, base + Vector((k_ * 0.07, -0.13, -0.04)), base + Vector((k_ * 0.09, -0.19, -0.08))], [0.04, 0.03, 0.012], 3)
    feet = paint(_obj("Feet", ft), GOLD, "SmoothPlastic")
    anim(feet, (0, -0.18, -1.86), (1, 0, 0), None, kick(8))
    loop = hang_loop("HangLoop", 0.0, 0.07, 0.026, GOLD, segments=6)
    ds += [feet, loop]
    return body, ds


if __name__ == "__main__":
    L["_main"](sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
