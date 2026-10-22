"""Starter Pack flyer (Daybreak set): Dawn Kite, a glass kiteboard pulled by a sunrise kite. Headless Blender:

    /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \\
        --python docs/art/starter_pack/tools/build_dawn_kite.py -- [--render] [--samples N]

Loads tools/blender/build_flyers_launch.py as a library (its main() never runs) and registers one more builder, so
the output matches the launch flyers: assets/blender/round_cosmetics/flyers_v3/dawn_kite/{dawn_kite.fbx, .blend,
manifest.json, _preview.png, _rider_scale.png, _icon.png}.

Family HandleStand (docs/art/FLYERS_V3.md section 6): the rider stands on the board (origin = deck top under the
feet, nose +Y) and holds the kite's control bar on RideFamilies.StandardGrips.HandleStand. The canopy, its lines and
its streamers sway together about the bar (one Fin rig), so the lines stay on the bar while the kite leans into turns.
"""
import math
import os
import sys

from mathutils import Matrix, Vector

REPO = os.environ.get("GLASSCLASH_REPO") or os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
_LAUNCH = os.path.join(REPO, "tools", "blender", "build_flyers_launch.py")
F = {"__name__": "flyers_launch_lib", "__file__": _LAUNCH}
exec(compile(open(_LAUNCH, encoding="utf-8").read(), _LAUNCH, "exec"), F)
H = F["H"]
add, loft, lathe, tube, sphere, merge, spaced, rrect = (H[k] for k in ("add", "loft", "lathe", "tube", "sphere", "merge", "spaced", "rrect"))
flat_slab, catmull_pt, flyer, GRIPS = F["flat_slab"], F["catmull_pt"], F["flyer"], F["GRIPS"]
PEARL, NAVY, TAU = H["PEARL"], H["NAVY"], H["TAU"]
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))

# Daybreak palette (shared with Sunny and the Daybreak finisher).
DAWN = {"peach": "#FF9E7A", "rose": "#FF5D7E", "coral": "#FF8A5C", "amber": "#FFB547", "gold": "#FFD45C",
        "lilac": "#C7A6FF", "sun": "#FFF1B0", "core": "#E2674F"}


@flyer("dawn_kite", 7500, "HandleStand")
def build_dawn_kite():
    gl, gr = GRIPS["HandleStand"]
    # Board: a glass kiteboard with a rockered nose and tail; deck top at z = 0 under the feet.
    Y0, Y1 = -1.85, 2.05
    L = Y1 - Y0

    def rocker(u):
        return 0.34 * max(0.0, (u - 0.78) / 0.22) ** 2 + 0.16 * max(0.0, (0.12 - u) / 0.12) ** 2

    board = []
    for u in spaced(24, 0.6):
        k = rrect(u, 3)
        board.append((Vector((0, Y0 + L * u, -0.08 + rocker(u))), X, Z, max(0.66 * k, 0.03), 0.08 * max(k, 0.4), 0.08 * max(k, 0.4), 3.2))
    add("Board", loft(board, n=20), DAWN["peach"], "Glass")
    core = [(c + Vector((0, 0, -0.01)), u_, v_, a * 0.78, b * 0.5, d * 0.5, e) for c, u_, v_, a, b, d, e in board[2:-2]]
    add("BoardCore", loft(core, n=14), DAWN["core"], "Core")
    # Gold rail round the deck edge (one closed loop at deck height).
    rail = []
    for i in range(40):
        a = TAU * i / 40
        u = 0.5 + 0.5 * math.sin(a)
        k = rrect(u, 3)
        rail.append(Vector((math.cos(a) * 0.64 * max(k, 0.12), Y0 + L * u, -0.02 + rocker(u))))
    add("Rail", tube(rail, 0.035, n=5, cap=False, closed=True), DAWN["gold"], "Gold")
    # Deck pad under the feet and two foot straps.
    pad = []
    for u in spaced(8, 0.8):
        k = rrect(u, 4)
        pad.append((Vector((0, -1.15 + 2.2 * u, 0.0)), X, Z, max(0.5 * k, 0.03), 0.02, 0.02, 4.0))
    add("DeckPad", loft(pad, n=14), DAWN["lilac"], "Matte")
    straps = []
    for y in (-0.62, 0.62):
        arc = [Vector((0.34 * math.cos(a), y, 0.02 + 0.2 * math.sin(a))) for a in [math.pi * i / 10 for i in range(11)]]
        straps.append(tube(arc, 0.055, n=6, flat=0.5))
    add("FootStraps", merge(*straps), PEARL, "Pearl")
    # The sunrise on the nose: a half sun with rays, glowing.
    sun = []
    for i in range(13):
        a = math.pi * i / 12
        sun.append((0.3 * math.cos(a), 0.3 * math.sin(a)))
    nose_m = Matrix.Translation((0, 1.45, 0.012 + rocker((1.45 - Y0) / L))) @ Matrix.Rotation(math.pi / 2, 4, "X") @ Matrix.Rotation(math.pi, 4, "Z")
    rays = []
    for k in range(7):
        a = math.pi * (k + 0.5) / 7
        d = Vector((math.cos(a), math.sin(a)))
        p = [(d * 0.36).to_tuple(), (d * 0.6 + Vector((-d.y, d.x)) * 0.03).to_tuple(), (d * 0.6 - Vector((-d.y, d.x)) * 0.03).to_tuple()]
        rays.append(flat_slab([q[:2] for q in p], 0.02, nose_m, bevel=0, segs=1))
    add("NoseSun", merge(flat_slab(sun, 0.025, nose_m, bevel=0, segs=1), *rays), DAWN["gold"], "Neon", sharp_deg=30)
    # Two small fins under the tail.
    fins = []
    for sx in (-1, 1):
        root = Vector((sx * 0.38, -1.45, -0.14))
        fins.append(flat_slab([(0, 0), (0.42, 0), (0.12, -0.32)], 0.05,
                              Matrix.Translation(root) @ Matrix.Rotation(math.pi / 2, 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "X"), bevel=0.015, segs=1))
    add("Fins", merge(*fins), DAWN["rose"], "Frost")
    # Control bar on the standard HandleStand grips, navy grips, gold end caps.
    bar_y, bar_z = gl[1], gl[2]
    add("Bar", tube([Vector((x, bar_y, bar_z)) for x in (-1.18, -0.6, 0.0, 0.6, 1.18)], 0.055, n=10), DAWN["gold"], "Gold")
    grips = [tube([Vector((sx * 0.72, bar_y, bar_z)), Vector((sx * 1.08, bar_y, bar_z))], 0.085, n=10) for sx in (-1, 1)]
    caps = [sphere(Vector((sx * 1.2, bar_y, bar_z)), 0.09, 10, 6) for sx in (-1, 1)]
    add("Grips", merge(*grips, *caps), NAVY, "Matte")

    # Canopy: an arched parafoil ahead of and above the rider, five dawn cells (lilac, rose, gold, rose, lilac).
    swing = {"RideMotion": "Fin", "MotionPivotWorld": Vector((0, bar_y, bar_z)), "FinAxis": "Z", "FinAngle": 0.05,
             "FinHz": 0.45, "FinPhase": 0.0, "FinBank": 0.45}
    centre = Vector((0, 4.7, 4.35))
    R, half = 3.0, math.radians(60)
    chord, thick = 1.7, 0.26

    def arc_pt(t):
        a = -half + 2 * half * t
        return centre + Vector((R * math.sin(a), 0, R * math.cos(a)))

    def cell(t0, t1, n=8, inset=0.0):
        frames = []
        for i in range(n + 1):
            t = t0 + (t1 - t0) * i / n
            p = arc_pt(t)
            tip = abs(2 * t - 1)
            c = chord * (1 - 0.32 * tip ** 2)
            outward = (p - centre).normalized()
            frames.append((p, Y, outward, c / 2 - inset, thick * (1 - 0.45 * tip) - inset, thick * 0.55 * (1 - 0.45 * tip) - inset, 2.6))
        return loft(frames, n=12, cap=True)
    colors = (DAWN["lilac"], DAWN["rose"], DAWN["gold"], DAWN["rose"], DAWN["lilac"])
    for i, color in enumerate(colors):
        add(f"Canopy_{i + 1}", cell(i / 5 + 0.004, (i + 1) / 5 - 0.004), color, "Glass", motion=dict(swing),
            studio={"Transparency": 0.22})
    # Pearl seams between the cells and along the leading edge.
    seams = []
    for i in range(6):
        t = min(max(i / 5, 0.002), 0.998)
        p = arc_pt(t)
        out = (p - centre).normalized()
        c = chord * (1 - 0.32 * abs(2 * t - 1) ** 2) / 2
        seams.append(tube([p + Y * c + out * 0.02, p + out * 0.15, p - Y * c + out * 0.02], 0.03, n=5))
    lead = [arc_pt(t) + Y * chord * (1 - 0.32 * abs(2 * t - 1) ** 2) / 2 * 0.96 for t in [i / 30 for i in range(31)]]
    seams.append(tube(lead, 0.035, n=5))
    add("CanopySeams", merge(*seams), PEARL, "Pearl", motion=dict(swing))
    # A glowing sun on the centre cell, facing the rider and the camera behind.
    sun_at = arc_pt(0.5) + Vector((0, -0.02, -thick * 0.62))
    disc = sphere(sun_at, 0.42, 16, 8, (1, 0.12, 1))
    sun_rays = []
    for k in range(10):
        a = TAU * k / 10
        d = Vector((math.cos(a), 0, math.sin(a)))
        sun_rays.append(tube([sun_at + d * 0.5, sun_at + d * 0.74], [0.05, 0.012], n=4))
    add("CanopySun", merge(disc, *sun_rays), DAWN["sun"], "Neon", motion=dict(swing))
    # Lines: bar ends to the outer cells, bar centre to the inner seams.
    lines = []
    for sx, g in ((-1, gl), (1, gr)):
        for t in ((0.06, 0.28) if sx < 0 else (0.94, 0.72)):
            top = arc_pt(t) + Vector((0, 0, -thick * 0.5))
            lines.append(tube([Vector((g[0] * 1.15, g[1], g[2])), top], 0.016, n=4, cap=False))
    add("Lines", merge(*lines), "#FFF6EC", "Neon", motion=dict(swing), studio={"Transparency": 0.2})
    # Ribbon streamers from the wingtips with bows, fluttering behind.
    tails = []
    for sx, t in ((-1, 0.0), (1, 1.0)):
        root = arc_pt(t) + Vector((0, -chord * 0.3, -0.1))
        pts = [root + Vector((sx * 0.06 * k, -0.4 * k, -0.1 * k - 0.015 * k * k)) for k in range(6)]
        ribbon = tube(pts, [0.11, 0.1, 0.095, 0.09, 0.075, 0.04], n=4, flat=0.3, up_hint=Vector((1, 0, 0)))
        bows = []
        for k in (2, 4):
            c = pts[k]
            bows.append(sphere(c + Vector((0.13, 0, 0)), 0.11, 6, 4, (1, 0.45, 0.7)))
            bows.append(sphere(c + Vector((-0.13, 0, 0)), 0.11, 6, 4, (1, 0.45, 0.7)))
        add("Streamer_" + ("L" if sx < 0 else "R"), merge(ribbon, *bows), "#FF8FB0", "Frost",
            motion={"RideMotion": "Tail", "MotionPivotWorld": root, "TailAngle": 0.22, "TailLag": 0.6})
    tip_l, tip_r = arc_pt(0.0), arc_pt(1.0)
    return {
        "Id": "dawn_kite", "Name": "Dawn Kite", "Contact": "Feet",
        "Attachments": {
            "RiderFeet": ("Board", (0, 0, 0)),
            "GripL": ("Grips", gl), "GripR": ("Grips", gr),
            "Trail0": ("Board", (-0.5, Y0 + 0.15, 0.02)),
            "Trail1": ("Board", (0.5, Y0 + 0.15, 0.02)),
            "KiteTrail0": ("Canopy_1", tuple(tip_l + Vector((0, -chord * 0.4, 0)))),
            "KiteTrail1": ("Canopy_5", tuple(tip_r + Vector((0, -chord * 0.4, 0)))),
            "Sun": ("CanopySun", tuple(sun_at)),
            "Wake": ("Board", (0, Y1, 0.2)),
            "Launch": ("Board", (0, 0.0, -0.5)),
        },
        "Notes": "HandleStand: feet on DeckPad, hands on the bar (StandardGrips). Canopy, seams, sun and lines share one Fin "
                 "rig about the bar centre (FinBank leans the kite into turns); streamers flutter with Tail.",
    }


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    render = "--render" in argv
    samples = int(argv[argv.index("--samples") + 1]) if "--samples" in argv else 32
    m = F["build"]("dawn_kite", render, samples)
    print("FLYER dawn_kite", {"Tris": m["Tris"], "Budget": m["Budget"], "Family": m["Family"], "Extents": m["Extents"], "Parts": len(m["Parts"]),
                              "RoundTrip": m["FbxRoundTrip"]["ok"]})
