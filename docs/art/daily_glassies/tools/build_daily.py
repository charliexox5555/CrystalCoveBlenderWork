"""Daily Rewards glassies (decision 115): Whiskers (Day 2, Epic) and Midnight (Day 7, Legendary). Headless Blender:

    B=/Applications/Blender.app/Contents/MacOS/Blender
    T=docs/art/daily_glassies/tools/build_daily.py
    $B -b --factory-startup --python $T -- preview whiskers [--samples 16] [--out DIR]
    $B -b --factory-startup --python $T -- build whiskers [--samples 96] [--force]
    $B -b --factory-startup --python $T -- validate whiskers
    $B -b --factory-startup --python $T -- sheet "Title" out.png whiskers midnight_moon

Reuses the Roster V2 launch builder (docs/art/launch_glassies/tools/build_launch.py) as a library: same v4 glass
materials, face language, motion tags, rig4 icon camera, fracture, checks and manifest. Only the two builders and the
output folder for previews live here. Outputs: assets/blender/glassies/<id>/v4/ (like every other glassy).
"""
import math
import os
import sys

import bmesh
from mathutils import Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
LAUNCH_PATH = os.path.abspath(os.path.join(HERE, "..", "..", "launch_glassies", "tools", "build_launch.py"))
L = {"__name__": "build_launch_lib", "__file__": LAUNCH_PATH}
exec(compile(open(LAUNCH_PATH, encoding="utf-8").read(), LAUNCH_PATH, "exec"), L)
globals().update({k: v for k, v in L.items() if not k.startswith("__")})

L["LAUNCH"].update({
    "whiskers": ("Whiskers", "Epic", "#B9A7FF", 0.74),
    "midnight_moon": ("Midnight", "Legendary", "#9AA2FF", 0.62),
})
L["doc_path"] = lambda *parts: os.path.join(HERE, "..", *parts)


# ------------------------------------------------------------------------------------------
# Whiskers (Day 2, Epic, Sharp): a chubby glass kitty with a gold bell collar.
# ------------------------------------------------------------------------------------------

@launch("whiskers")
def b_whiskers(gid):
    tint, inner, pink, cream, gold = "#B9A7FF", "#8E74F2", "#FF8FB8", "#F4EEFF", "#FFC94A"
    head_c = Vector((0, -0.03, -0.62))
    torso_c = Vector((0, 0.04, -1.42))
    lo, hi = Vector((-0.74, -0.62, -1.98)), Vector((0.74, 0.62, -0.12))

    def shape(bm):
        ellipsoid_bm(bm, head_c, (0.56, 0.48, 0.44), 20, 12)
        ellipsoid_bm(bm, torso_c, (0.5, 0.48, 0.52), 18, 12)
        ellipsoid_bm(bm, (0, 0.0, -1.02), (0.34, 0.32, 0.2), 12, 8)                 # neck fill
        for s_ in (-1, 1):
            ellipsoid_bm(bm, (s_ * 0.3, 0.12, -1.72), (0.24, 0.3, 0.22), 10, 6)     # haunches
    body = organic("Body", shape, 260, fit=(lo, hi), voxel=0.024, max_tris=420)
    paint(body, tint, role="Body", alpha=0.82, transmission=0.55)
    body["full_tint"] = True  # creature: tinted lilac shell (like Honey Bear); InnerGlow is the inner layer
    body["plain_normals"] = True
    surf = Surface(body)
    ds = face(surf, head_c, 0.2, head_c.z - 0.02, eye=(0.085, 0.11, 0.05), cheek_dx=0.31, cheek_dz=-0.15,
              seg=(7, 5), shine_seg=((4, 3), (4, 3)), cheek_seg=(5, 3))
    # Nose + little "w" mouth.
    np_, nn = surf.hit(head_c + Vector((0, -5, -0.13)), (0, 1, 0))
    nose = paint(blob("Nose", np_ + nn * 0.02, (0.05, 0.03, 0.035), 6, 4), pink, "SmoothPlastic")
    mb = bmesh.new()
    for s_ in (-1, 1):
        smile_bm(mb, surf, np_ + Vector((s_ * 0.045, 0, 0)), 0.09, np_.z - 0.06, curve=0.025, steps=3, r=0.011)
    mouth = paint(_obj("Mouth", mb), "#3A2A5C", "SmoothPlastic")
    # Whiskers: three thin glass strands per side, sway together.
    wb = bmesh.new()
    for s_ in (-1, 1):
        root, rn = surf.hit(head_c + Vector((s_ * 0.24, -5, -0.12)), (0, 1, 0))
        for k, dz in enumerate((0.035, -0.035)):
            a = root + rn * 0.01
            b = a + Vector((s_ * 0.22, -0.04, dz * 1.6 + 0.01))
            c = a + Vector((s_ * 0.42, -0.02, dz * 3.0 + 0.03))
            tube_bm(wb, [a, b, c], [0.011, 0.008, 0.004], 3)
    whisk = paint(_obj("Whiskers", wb), "#FFFFFF", "SmoothPlastic")
    anim(whisk, np_, (0, 1, 0), sway(3, 2.4), kick(10), note="whiskers twitch on hits")
    ds += [nose, mouth, whisk]
    # Pointy ears with pink inner glass (one mesh each, so the pair twitches together).
    eb, ib = bmesh.new(), bmesh.new()
    for s_ in (-1, 1):
        root = head_c + Vector((s_ * 0.3, 0.02, 0.3))
        tilt = Matrix.Translation(root) @ Matrix.Rotation(s_ * -0.32, 4, "Y")
        lathe_into(eb, [(0, -0.02), (0.17, -0.02), (0.13, 0.12), (0.06, 0.24), (0, 0.3)], tilt, 7)
        lathe_into(ib, [(0, 0.0), (0.1, 0.0), (0.07, 0.12), (0.03, 0.2), (0, 0.23)], tilt @ Matrix.Translation((0, -0.07, 0.01)) @ Matrix.Diagonal((1, 0.35, 1, 1)), 6)
    ears = paint(_obj("Ears", eb), tint)
    anim(ears, head_c + Vector((0, 0.02, 0.24)), (0, 0, 1), sway(4, 2.6), flare(16), note="ear twitch")
    ear_in = paint(_obj("EarInners", ib), pink)
    anim(ear_in, head_c + Vector((0, 0.02, 0.24)), (0, 0, 1), None, None)
    follow(ear_in, "Ears", "pink inside of the ears")
    ds += [ears, ear_in]
    # Front paws (cream mittens) tucked in front of the tummy.
    pw = bmesh.new()
    for s_ in (-1, 1):
        ellipsoid_bm(pw, (s_ * 0.2, -0.42, -1.86), (0.15, 0.17, 0.11), 7, 4)
    paws = paint(_obj("Paws", pw), "#E9E1FF")
    anim(paws, torso_c, (1, 0, 0), None, kick(4))
    # Belly patch and the saturated inner layer (v4 two-layer look).
    fill = bmesh.new()
    ellipsoid_bm(fill, torso_c, (0.38, 0.36, 0.4), 10, 6)
    core = as_inner(paint(_obj("InnerGlow", fill), inner, alpha=0.6, transmission=0.6))
    anim(core, torso_c, (0, 0, 1), pulse(0.05, 1.8), squash(0.92, 4.0, 0.35), note="lilac inner glass")
    ds += [paws, core]
    # Curly tail behind, swishing.
    tp = spline([(0.3, 0.4, -1.84), (0.6, 0.5, -1.76), (0.76, 0.46, -1.5), (0.7, 0.42, -1.24), (0.76, 0.4, -1.02), (0.9, 0.38, -0.96)], 12)
    tb = bmesh.new()
    tube_bm(tb, tp, [0.085 - 0.04 * i / (len(tp) - 1) for i in range(len(tp))], 4)
    tail = paint(_obj("Tail", tb), tint)
    anim(tail, tp[0], (0, 0, 1), sway(12, 1.8), kick(20), lod_keep=True, note="tail swish; wiggles hard in the pounce windup")
    # Collar + gold bell (rings on hits, glows at Ready).
    cz = -1.06
    cb = bmesh.new()
    torus_bm(cb, (0, 0.0, cz), 0.36, 0.04, 12, 4, Matrix.Diagonal((1.0, 0.95, 1, 1)))
    collar = paint(_obj("Collar", cb), "#FF5C8A", "SmoothPlastic")
    bell_at = surf.hit(Vector((0, -5, cz - 0.06)), (0, 1, 0))[0] + Vector((0, -0.08, -0.04))
    bb = bmesh.new()
    lathe_into(bb, [(0, -0.07), (0.07, -0.065), (0.085, -0.03), (0.075, 0.02), (0.045, 0.05), (0, 0.06)], Matrix.Translation(bell_at), 8)
    bell = paint(_obj("Bell", bb), gold, "SmoothPlastic")
    anim(bell, bell_at + Vector((0, 0, 0.06)), (1, 0, 0), sway(6, 1.4), kick(28), lod_keep=True, note="jingles on every clash")
    slot = paint(blob("BellGlow", bell_at + Vector((0, -0.07, -0.02)), (0.03, 0.012, 0.02), 6, 3), "#FFF6C2", "Neon")
    anim(slot, bell_at + Vector((0, 0, 0.06)), (1, 0, 0), pulse(0.15, 1.6), flash(0.3), note="Epic accent: glows at Ready")
    follow(slot, "Bell")
    loop = hang_loop("HangLoop", 0.0, 0.07, 0.026, "#FFE7A8", segments=8)
    ds += [tail, collar, bell, slot, loop]
    return body, ds


# ------------------------------------------------------------------------------------------
# Midnight (Day 7, Legendary, Fizzy): a sleepy crescent moon in a nightcap, for Midnights Studio.
# ------------------------------------------------------------------------------------------

@launch("midnight_moon")
def b_midnight_moon(gid):
    shell, night, gold, cap_c, pale = "#9AA2FF", "#2B2F95", "#FFD25A", "#8C5CFF", "#FFF3B8"
    # Crescent in the camera plane (XZ), opening to +X: the outer circle (centre O, radius RO) minus an inner circle
    # (centre O + (D, 0), radius RI). Spheres sit on the medial line with radius = the local half width, then the
    # union is voxel-remeshed, so the moon is a puffy pillow with round horn tips. Face on the thick left bulge.
    RO, RI, D, SX = 0.95, 1.07, 0.83, 0.3

    def band(theta):
        u = Vector((math.cos(theta), 0.0, math.sin(theta)))
        ui = u.x * D
        t = ui + math.sqrt(max(0.0, ui * ui - D * D + RI * RI))  # where the ray from O leaves the inner circle
        w = (RO - t) / 2
        return u * ((RO + t) / 2) + Vector((SX, 0, 0)), w

    samples = []
    for i in range(121):
        th = math.radians(20 + 320 * i / 120)
        c, w = band(th)
        if w > 0.035:
            samples.append((c, w))

    def shape(bm, shrink=0.0):
        for c, w in samples:
            r = max(0.02, w - shrink)
            ellipsoid_bm(bm, c, (r, r * 0.82, r), 10, 7)
    body = remesh_union("Body", shape, voxel=0.02, target_tris=940)  # asymmetric: organic() mirrors X
    top = max(v.co.z for v in body.data.vertices)
    drop = Vector((0, 0, top + 0.07))  # hang point = just above the top of the moon (origin)
    for v in body.data.vertices:
        v.co -= drop
    body.data.update()
    samples = [(c - drop, w) for c, w in samples]
    paint(body, shell, role="Body", alpha=0.72, transmission=0.6)
    body["full_tint"] = True
    body["plain_normals"] = True
    surf = Surface(body)
    mid = band(math.pi)[0] - drop  # thickest point, faces the camera
    ds = face(surf, mid, 0.12, mid.z + 0.05, eye=(0.07, 0.095, 0.045), cheek_dx=0.21, cheek_dz=-0.14,
              seg=(7, 5), shine_seg=((4, 3), (4, 3)), cheek_seg=(5, 3))
    smb = bmesh.new()
    smile_bm(smb, surf, mid, 0.12, mid.z - 0.09, curve=0.035, steps=5, r=0.013)
    smile = paint(_obj("Smile", smb), "#1A1C4A", "SmoothPlastic")
    ds.append(smile)
    # Inner night sky: a smaller navy crescent inside the shell (v4 two-layer look) with gold star specks.
    sky = remesh_union("NightSky", lambda bm: shape(bm, 0.11), voxel=0.024, target_tris=520)  # samples already dropped
    as_inner(paint(sky, night, alpha=0.75, transmission=0.4))
    anim(sky, mid, (0, 0, 1), pulse(0.03, 3.0), squash(0.94, 4.0, 0.35), note="the night inside the moon")
    sb = bmesh.new()
    rng = random.Random(7)
    placed = 0
    for _ in range(200):
        if placed >= 12:
            break
        c, w = samples[rng.randrange(len(samples))]
        if w < 0.12 or (c - mid).length < 0.25:  # keep the thin horns and the face clear
            continue
        p = c + Vector((rng.uniform(-0.35, 0.35) * w, -rng.uniform(0.2, 0.45) * w, rng.uniform(-0.35, 0.35) * w))
        sz = rng.uniform(0.04, 0.065)
        slab_bm(sb, star_points(4, sz, sz * 0.38, rng.uniform(0, 1)), sz * 0.5, 0, 1,
                Matrix.Translation(p) @ Matrix.Rotation(rng.uniform(-0.4, 0.4), 4, "Z"))
        placed += 1
    stars = paint(_obj("StarSpecks", sb, smooth=False), gold, "Neon")
    centre = Vector((SX, 0, 0)) - drop
    anim(stars, centre, (0, 1, 0), pulse(0.12, 2.2), flash(0.35), note="twinkle; flare at Ready and on the lullaby")
    ds += [sky, stars]
    # Legendary core: a small glowing crescent inside the thick bulge, behind the face.
    pts = [(0.15 * math.cos(math.radians(100 + 160 * i / 8)), 0.15 * math.sin(math.radians(100 + 160 * i / 8))) for i in range(9)]
    pts += [(0.05 + 0.11 * math.cos(math.radians(250 - 140 * i / 8)), 0.11 * math.sin(math.radians(250 - 140 * i / 8))) for i in range(9)]
    core_at = mid + Vector((0.1, 0.06, -0.34))
    kb = bmesh.new()
    slab_bm(kb, pts, 0.05, 0.012, 1, Matrix.Translation(core_at))
    core = paint(_obj("MoonCore", kb), pale, "Neon")
    anim(core, core_at, (0, 1, 0), pulse(0.1, 2.6), flash(0.35), note="Legendary core: glows brighter at Ready")
    ds.append(core)
    # Nightcap on the upper horn, flopping over to the right, with a pom-pom.
    hc, hw = samples[0]
    for c, w in samples:
        if w >= 0.11:
            hc, hw = c, w
            break
    hdir = (samples[0][0] - hc).normalized()
    cp = spline([hc + hdir * 0.02, hc + hdir * 0.2 + Vector((0.02, 0, 0.08)), hc + hdir * 0.32 + Vector((0.16, 0, 0.1)), hc + hdir * 0.3 + Vector((0.3, 0, -0.02))], 9)
    cb = bmesh.new()
    tube_bm(cb, cp, [hw * 1.15 - (hw * 1.15 - 0.02) * i / (len(cp) - 1) for i in range(len(cp))], 8)
    cap = paint(_obj("Nightcap", cb), cap_c)
    anim(cap, cp[0], (0, 1, 0), sway(6, 2.6), kick(16), note="floppy nightcap")
    rb = bmesh.new()
    torus_bm(rb, cp[0], hw * 1.12, 0.035, 14, 4, hdir.to_track_quat("Z", "Y").to_matrix().to_4x4())
    brim = paint(_obj("CapBrim", rb), "#F4F0FF", "SmoothPlastic")
    anim(brim, cp[0], (0, 1, 0), None, None)
    follow(brim, "Nightcap")
    pom = paint(blob("PomPom", cp[-1] + Vector((0.02, 0, -0.04)), (0.07, 0.07, 0.07), 7, 5), "#FFFFFF", "SmoothPlastic")
    anim(pom, cp[0], (0, 1, 0), None, None)
    follow(pom, "Nightcap")
    ds += [cap, brim, pom]
    # A gold star dangling from the lower horn on a short thread (swings like a pendulum).
    lc, lw = samples[-1]
    thread_top = lc + Vector((0, 0, -lw * 0.6))
    star_c = thread_top + Vector((0, 0, -0.3))
    thb = bmesh.new()
    tube_bm(thb, [thread_top, star_c + Vector((0, 0, 0.1))], 0.008, 4)
    slab_bm(thb, star_points(5, 0.12, 0.055), 0.05, 0.015, 1, Matrix.Translation(star_c))
    hanging = paint(_obj("HangingStar", thb), gold, "Neon")
    anim(hanging, thread_top, (0, 1, 0), sway(14, 2.0), kick(30), lod_keep=True, note="pendulum star; flashes when the lullaby lands")
    # Two tiny sparkles orbit the moon.
    spb = bmesh.new()
    for dx, dz in ((-0.95, -0.2), (0.55, 0.42)):
        slab_bm(spb, star_points(4, 0.06, 0.02), 0.02, 0, 1, Matrix.Translation(centre + Vector((dx, -0.25, dz))))
    sparkles = paint(_obj("Sparkles", spb, smooth=False), "#FFFFFF", "Neon")
    anim(sparkles, centre, (0, 1, 0), spin(24), flash(0.3), extra_idle=[pulse(0.25, 1.3)])
    loop = hang_loop("HangLoop", 0.0, 0.075, 0.028, gold, segments=10)
    ds += [hanging, sparkles, loop]
    return body, ds


if __name__ == "__main__":
    L["_main"](sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
