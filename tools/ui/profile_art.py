"""Profile screen artwork (Stained Glass, UI v0.5). Writes editable SVGs and transparent PNGs into
assets/ui/screens/profile/{svg,png}. Reuses the Daily Rewards helpers (same mosaic, palette and Chrome renderer); the
window, title banner, close diamond, level hex and tags come from the kit.

    python3 tools/ui/profile_art.py

Pieces are drawn at the on-screen aspect of the slot they fill in tools/studio/build_profile_screen.luau.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from daily_rewards_art import (  # noqa: E402
    LEAD, P, SV, chamfer, facets, mix, mosaic, poly, render, seed, shrink, size_of, pts,
)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "ui", "screens", "profile")
A = {}


def pane_gradient(top, bottom, gid="t"):
    return ('<defs><linearGradient id="%s" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="%s"/>'
            '<stop offset="1" stop-color="%s"/></linearGradient></defs>' % (gid, top, bottom))


# Side tabs (300x250): the left column of big picture tabs. Active = sapphire glass with a lit pane and a gold inner
# line; idle = slate and smoke. Same mosaic seed in both so a tab doesn't jump when it lights.
TW, TH, TCUT = 300, 250, [24, 10, 26, 10]
seed(41)
s, outer, inner, Li = mosaic(TW, TH, 13, TCUT, ["slate", "milk", "slate"], 12)
A["tab_idle"] = SV(TW, TH, s + poly(inner, P["smoke"], LEAD(5)) + facets(inner, Li, 2, P["smoke2"]) + poly(outer, "none", LEAD(7)))
seed(41)
s, outer, inner, Li = mosaic(TW, TH, 13, TCUT, ["sapphire", "aqua", "sapphire"], 12, shine=0.5)
A["tab_active"] = SV(TW, TH, pane_gradient("#3E62B8", P["viewport"]) + s + poly(inner, "url(#t)", LEAD(5))
                     + facets(inner, Li, 2, "#5C7BD0", 0.6)
                     + poly(shrink(inner, 0.94), "none", 'stroke="%s" stroke-width="3" stroke-opacity="0.8" stroke-linejoin="round"' % P["amber"][1])
                     + poly(outer, "none", LEAD(8)))

# Avatar portrait (300x300): every jewel colour in a thick band, a soft spotlight pane behind the avatar.
seed(77)
s, outer, inner, Li = mosaic(300, 300, 16, [28, 12, 30, 12], ["ruby", "amber", "emerald", "sapphire", "amethyst", "aqua"], 18, shine=0.45)
defs = ('<defs><radialGradient id="g" cx="150" cy="120" r="170" gradientUnits="userSpaceOnUse">'
        '<stop offset="0" stop-color="#6B56A8"/><stop offset="0.6" stop-color="%s"/><stop offset="1" stop-color="%s"/></radialGradient></defs>'
        % (P["viewport"], P["smoke"]))
floor = '<ellipse cx="150" cy="262" rx="92" ry="16" fill="%s" fill-opacity="0.55"/>' % P["lead"]
A["portrait_frame"] = SV(300, 300, defs + s + poly(inner, "url(#g)", LEAD(5)) + floor + poly(outer, "none", LEAD(8)))

# Name plate (1000x110): milk glass with pointed ends, a gold came along the top, like the HUD plaques but bigger.
NP = [[34, 4], [966, 4], [996, 55], [966, 106], [34, 106], [4, 55]]
A["name_plate"] = SV(1000, 110, poly(NP, P["amethyst"][0], LEAD(6))
                     + poly(shrink(NP, 0.965), P["smoke2"], LEAD(4))
                     + poly([[40, 14], [960, 14], [972, 30], [28, 30]], "#FFFFFF", 'fill-opacity="0.08"')
                     + poly(NP, "none", LEAD(7)))

# Stat tiles: a small one (400x205) for Wins / Win Rate and a wide one (810x205) for Best Streak, in the stat's colour.
def stat_tile(w, h, key, sd):
    seed(sd)
    s, outer, inner, Li = mosaic(w, h, 13, [22, 10, 24, 10], [key, key, "slate"], 12 if w < 500 else 20, shine=0.45)
    top = mix(P["viewport"], P[key][0], 0.28)
    return SV(w, h, pane_gradient(top, P["smoke"]) + s + poly(inner, "url(#t)", LEAD(5)) + facets(inner, Li, 2, P["smoke2"], 0.8)
              + poly(outer, "none", LEAD(7)))


A["stat_amber"] = stat_tile(400, 205, "amber", 51)
A["stat_aqua"] = stat_tile(400, 205, "aqua", 52)
A["stat_ruby_wide"] = stat_tile(810, 205, "ruby", 53)

# XP bar (600x84): leaded track with pointed ends and a sapphire glass fill (the fill is drawn full-length and
# clipped by its parent frame's width at runtime).
XT = [[30, 4], [570, 4], [596, 42], [570, 80], [30, 80], [4, 42]]
A["xp_track"] = SV(600, 84, poly(XT, P["lead"]) + poly(shrink(XT, 0.9), P["smoke"], 'stroke="%s" stroke-width="3"' % P["smoke2"]))
XF = [[22, 4], [578, 4], [596, 32], [578, 60], [22, 60], [4, 32]]
A["xp_fill"] = SV(600, 64, poly(XF, P["sapphire"][0], LEAD(4)) + poly([[24, 10], [574, 10], [582, 22], [16, 22]], P["sapphire"][1], 'fill-opacity="0.75"')
                  + poly([[14, 44], [584, 44], [578, 54], [20, 54]], P["sapphire"][2], 'fill-opacity="0.6"')
                  + poly([[60, 10], [84, 10], [70, 54], [46, 54]], "#FFFFFF", 'fill-opacity="0.3"') + poly(XF, "none", LEAD(4)))

# Level rewards strip (1300x150): an empty, dim leaded pane kept for level rewards later; faint stepping stones show
# that something will live here.
RS = chamfer(4, 4, 1292, 142, [20, 8, 22, 8])
stones = ""
for i in range(8):
    x = 120 + i * 152
    stones += '<circle cx="%d" cy="75" r="15" fill="%s" stroke="%s" stroke-width="4"/>' % (x, P["smoke2"], P["lead"])
A["rewards_strip"] = SV(1300, 150, poly(RS, P["lead"]) + poly(shrink(RS, 0.985), "#211932", 'stroke="%s" stroke-width="3"' % P["slate"][2])
                        + '<line x1="120" y1="75" x2="1184" y2="75" stroke="%s" stroke-width="8" stroke-linecap="round"/>' % P["smoke2"]
                        + stones)


# Icons (128x128) --------------------------------------------------------------------------------------------
def crown():
    c = P["amber"]
    body = [[14, 44], [40, 70], [64, 26], [88, 70], [114, 44], [104, 104], [24, 104]]
    s = poly(body, c[0], LEAD(6)) + poly([[24, 92], [104, 92], [104, 104], [24, 104]], c[2], LEAD(4))
    s += poly([[30, 62], [40, 72], [58, 42]], c[1], 'fill-opacity="0.7"')
    for x, y in ((14, 40), (64, 22), (114, 40)):
        s += '<circle cx="%d" cy="%d" r="9" fill="%s" stroke="%s" stroke-width="4"/>' % (x, y, P["ruby"][0], P["lead"])
    s += poly([[56, 70], [64, 60], [72, 70], [64, 80]], P["sapphire"][1], LEAD(3))
    return SV(128, 128, s)


def winrate():
    """Aqua gem dial with a three-quarter lit ring: 'how often you win'."""
    c = P["aqua"]
    cx, cy, r0, r1 = 64, 64, 34, 56
    ring = ""
    n = 12
    for i in range(n):
        a0, a1 = i / n * 2 * math.pi - math.pi / 2, (i + 1) / n * 2 * math.pi - math.pi / 2
        pc = [[cx + r1 * math.cos(a0), cy + r1 * math.sin(a0)], [cx + r1 * math.cos(a1), cy + r1 * math.sin(a1)],
              [cx + r0 * math.cos(a1), cy + r0 * math.sin(a1)], [cx + r0 * math.cos(a0), cy + r0 * math.sin(a0)]]
        ring += poly(pc, c[0] if i < 9 else P["smoke2"], LEAD(4))
    centre = '<circle cx="64" cy="64" r="28" fill="%s" stroke="%s" stroke-width="5"/>' % (P["milk"][0], P["lead"])
    tick = '<path d="M50 65 L60 75 L79 54" fill="none" stroke="%s" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>' % P["emerald"][0]
    return SV(128, 128, ring + centre + tick)


def flame():
    outer = "M64 6 C78 30 104 44 104 78 C104 104 86 122 64 122 C42 122 24 104 24 78 C24 58 36 46 44 34 C46 50 52 58 58 60 C56 40 58 22 64 6 Z"
    inner = "M64 56 C72 70 86 78 86 94 C86 108 76 116 64 116 C52 116 42 108 42 94 C42 82 52 76 56 66 C58 74 62 78 66 78 C64 70 62 64 64 56 Z"
    return SV(128, 128, '<path d="%s" fill="%s" stroke="%s" stroke-width="6" stroke-linejoin="round"/>' % (outer, P["ruby"][0], P["lead"])
              + '<path d="%s" fill="%s" stroke="%s" stroke-width="4" stroke-linejoin="round"/>' % (inner, P["amber"][0], P["lead"])
              + '<path d="M60 92 C62 100 70 104 72 96" fill="none" stroke="%s" stroke-width="5" stroke-linecap="round"/>' % P["amber"][1])


def bottle():
    """A glassy: round bottle with a cork, the tab icon for Glassies."""
    body = "M50 30 L78 30 L78 48 C96 56 104 70 104 86 C104 108 86 120 64 120 C42 120 24 108 24 86 C24 70 32 56 50 48 Z"
    return SV(128, 128, '<rect x="48" y="10" width="32" height="22" rx="5" fill="%s" stroke="%s" stroke-width="5"/>' % (P["amber"][2], P["lead"])
              + '<path d="%s" fill="%s" fill-opacity="0.95" stroke="%s" stroke-width="6" stroke-linejoin="round"/>' % (body, P["aqua"][0], P["lead"])
              + '<path d="M38 80 C38 70 44 62 52 58" fill="none" stroke="#FFFFFF" stroke-width="7" stroke-linecap="round" stroke-opacity="0.8"/>'
              + '<circle cx="78" cy="92" r="8" fill="%s" fill-opacity="0.8"/>' % P["aqua"][1])


def burst():
    """A finisher: shatter burst with flying shards."""
    pts_ = []
    for i in range(16):
        a, r = i / 16 * 2 * math.pi, 58 if i % 2 == 0 else 28
        pts_.append([64 + r * math.cos(a), 64 + r * math.sin(a)])
    s = poly(pts_, P["amethyst"][0], LEAD(6)) + poly(shrink(pts_, 0.5), P["amethyst"][1], LEAD(4))
    s += '<circle cx="64" cy="64" r="12" fill="#FFFFFF" stroke="%s" stroke-width="4"/>' % P["lead"]
    return SV(128, 128, s)


def wing():
    """A flyer: one glass wing over a hover board."""
    s = '<path d="M20 70 C30 30 70 10 112 14 C100 30 98 44 84 54 C92 56 96 60 98 66 C80 70 60 72 20 70 Z" fill="%s" stroke="%s" stroke-width="6" stroke-linejoin="round"/>' % (P["emerald"][0], P["lead"])
    s += '<path d="M36 60 C48 40 70 28 96 24" fill="none" stroke="%s" stroke-width="5" stroke-linecap="round"/>' % P["emerald"][1]
    s += '<rect x="14" y="88" width="100" height="20" rx="10" fill="%s" stroke="%s" stroke-width="6"/>' % (P["sapphire"][0], P["lead"])
    s += '<path d="M30 112 L40 122 M64 112 L64 124 M98 112 L88 122" stroke="%s" stroke-width="5" stroke-linecap="round"/>' % P["aqua"][1]
    return SV(128, 128, s)


def arrow_badge():
    """Small amber diamond with an outward arrow: 'opens your Inventory' (option B tabs)."""
    D = [[40, 3], [77, 40], [40, 77], [3, 40]]
    arrow = "M26 40 H52 M42 28 L54 40 L42 52"
    return SV(80, 80, poly(D, P["amber"][0], LEAD(5)) + poly([[40, 3], [77, 40], [40, 40]], P["amber"][1], 'fill-opacity="0.6"')
              + poly(D, "none", LEAD(6))
              + '<path d="%s" fill="none" stroke="%s" stroke-width="12" stroke-linecap="round" stroke-linejoin="round"/>' % (arrow, P["lead"])
              + '<path d="%s" fill="none" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>' % arrow)


A["icon_crown"] = crown()
A["icon_winrate"] = winrate()
A["icon_flame"] = flame()
A["icon_glassies"] = bottle()
A["icon_finishers"] = burst()
A["icon_flyers"] = wing()
A["badge_open"] = arrow_badge()

if __name__ == "__main__":
    os.makedirs(os.path.join(OUT, "svg"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "png"), exist_ok=True)
    for name, svg in A.items():
        open(os.path.join(OUT, "svg", name + ".svg"), "w").write(svg)
    pngs = render(A)
    for name, data in pngs.items():
        open(os.path.join(OUT, "png", name + ".png"), "wb").write(data)
        print(name, size_of(A[name]))
    print("%d of %d pieces written to %s" % (len(pngs), len(A), OUT))
