"""Badge icons (decision 118): one round stained-glass medallion template, one symbol per badge. Writes editable SVGs
and 512x512 PNGs into assets/badges/{svg,png}, plus preview.png (every badge after Roblox's circular crop, on light
and dark backgrounds).

    python3 tools/ui/badge_art.py

Roblox crops a badge to the circle inscribed in its 512x512 image (Creator Docs, "Badges"), so everything that
matters sits inside r = 236: a lead rim, a mosaic band of jewel glass in the badge's colours, a gold came, a lit
pane with stained-glass rays, and the symbol. Symbols are the game's own item pictures (assets/icons/items/512) or
leaded glass drawn here; no words, so nothing is cropped or needs translating. Same palette, mosaic and Chrome
renderer as the Stained Glass UI (tools/ui/daily_rewards_art.py).
"""
import base64
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import daily_rewards_art as kit  # noqa: E402
from daily_rewards_art import LEAD, P, SV, poly, rnd, seed, shrink  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "badges")
ITEMS = os.path.join(ROOT, "assets", "icons", "items", "512")
S, C = 512, 256  # canvas, centre
R_RIM, R_BAND, R_PANE = 236, 226, 176  # lead rim, outside of the jewel band, the pane inside the gold came


def ring(r0, r1, a0, a1, step=4):
    """A ring segment between radii r0 < r1 from angle a0 to a1 (degrees, 0 = up, clockwise)."""
    n = max(2, int(abs(a1 - a0) / step) + 1)
    out = [(C + r1 * math.sin(math.radians(a0 + (a1 - a0) * i / (n - 1))),
            C - r1 * math.cos(math.radians(a0 + (a1 - a0) * i / (n - 1)))) for i in range(n)]
    out += [(C + r0 * math.sin(math.radians(a1 - (a1 - a0) * i / (n - 1))),
             C - r0 * math.cos(math.radians(a1 - (a1 - a0) * i / (n - 1)))) for i in range(n)]
    return out


def circle(r, fill, extra=""):
    return '<circle cx="%d" cy="%d" r="%.1f" fill="%s" %s/>' % (C, C, r, fill, extra)


def star(cx, cy, r, points=5, inner=0.45, rot=0):
    out = []
    for i in range(points * 2):
        a = math.radians(rot + i * 180 / points)
        k = r if i % 2 == 0 else r * inner
        out.append((cx + k * math.sin(a), cy - k * math.cos(a)))
    return out


def picture(name, x, y, size, flip=False, rot=0):
    data = base64.b64encode(open(os.path.join(ITEMS, name + ".png"), "rb").read()).decode()
    tf = "rotate(%s %s %s)" % (rot, x + size / 2, y + size / 2)
    if flip:
        tf += " translate(%s 0) scale(-1 1)" % (2 * x + size)
    return '<image href="data:image/png;base64,%s" x="%s" y="%s" width="%s" height="%s" transform="%s"/>' % (
        data, x, y, size, size, tf)


def shadow(svg_id):
    """A soft drop shadow so a pale glass picture reads on the lit pane."""
    return ('<filter id="%s" x="-20%%" y="-20%%" width="140%%" height="140%%"><feDropShadow dx="0" dy="6" '
            'stdDeviation="7" flood-color="%s" flood-opacity="0.75"/></filter>' % (svg_id, P["lead"]))


def medallion(colors, pane, rays, symbol, sd, pieces=16):
    """The shared template. colors: palette keys for the jewel band; pane: (centre, edge) of the lit pane;
    rays: palette key of the stained-glass rays behind the symbol; symbol: SVG drawn last, inside the pane."""
    seed(sd)
    defs = ('<defs><radialGradient id="pane" cx="%d" cy="%d" r="%d" gradientUnits="userSpaceOnUse">'
            '<stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></radialGradient>%s</defs>'
            % (C, C - 30, R_PANE + 20, pane[0], pane[1], shadow("drop")))
    s = defs + circle(R_RIM + 4, P["lead"])
    # Jewel band: jittered cuts like the window mosaic, each piece with a lighter inner shine.
    cuts = [i * 360 / pieces + (rnd() - 0.5) * 0.5 * 360 / pieces for i in range(pieces)] + [360]
    cuts[0] = 0
    for i in range(pieces):
        col = P[colors[int(rnd() * len(colors))]]
        pc = ring(R_PANE + 12, R_BAND, cuts[i], cuts[i + 1])
        s += poly(pc, col[0], LEAD(5)) + poly(shrink(pc, 0.5), col[1], 'fill-opacity="0.4"')
    # Gold came between the band and the pane, then the pane.
    s += circle(R_PANE + 8, P["amber"][0], 'stroke="%s" stroke-width="5"' % P["lead"])
    s += circle(R_PANE + 8, "none", 'stroke="%s" stroke-width="2" stroke-opacity="0.8"' % P["amber"][1])
    s += circle(R_PANE, "url(#pane)", LEAD(5))
    # Rays: alternate panes of lighter glass, leaded, like a rose window.
    n = 12
    for i in range(n):
        a0, a1 = i * 360 / n, (i + 0.5) * 360 / n
        s += poly(ring(28, R_PANE - 3, a0, a1), P[rays][1], 'fill-opacity="0.16" stroke="%s" stroke-width="3" stroke-opacity="0.55"' % P["lead"])
    s += symbol
    # Glass glint across the top left and a lead rim on top of everything.
    s += poly(ring(R_PANE - 22, R_PANE - 8, -70, -15), "#FFFFFF", 'fill-opacity="0.22"')
    s += poly(ring(R_BAND - 14, R_BAND - 6, -60, -25), "#FFFFFF", 'fill-opacity="0.35"')
    s += circle(R_BAND, "none", LEAD(6)) + circle(R_RIM, "none", 'stroke="%s" stroke-width="14"' % P["lead"])
    return SV(S, S, s)


def burst(cx, cy, r, color, pieces=10):
    """Shatter burst: leaded glass shards flying out of a point (the game's verb)."""
    s = ""
    for i in range(pieces):
        a = i * 360 / pieces + (rnd() - 0.5) * 14
        k = r * (0.75 + rnd() * 0.35)
        tip = (cx + k * math.sin(math.radians(a)), cy - k * math.cos(math.radians(a)))
        side = 15 + rnd() * 8
        base = [(cx + 40 * math.sin(math.radians(a - side)), cy - 40 * math.cos(math.radians(a - side))),
                (cx + 40 * math.sin(math.radians(a + side)), cy - 40 * math.cos(math.radians(a + side)))]
        col = P[color[i % len(color)]]
        s += poly([base[0], tip, base[1]], col[0], LEAD(4)) + poly(shrink([base[0], tip, base[1]], 0.45), col[1], 'fill-opacity="0.6"')
    return s


def hex_gem(cx, cy, r, key):
    c = P[key]
    outer = [(cx + r * math.sin(math.radians(30 + 60 * i)), cy - r * math.cos(math.radians(30 + 60 * i))) for i in range(6)]
    inner = shrink(outer, 0.72)
    s = poly(outer, c[2], LEAD(7))
    for i in range(6):
        face = [outer[i], outer[(i + 1) % 6], inner[(i + 1) % 6], inner[i]]
        s += poly(face, c[1] if i in (5, 0) else (c[0] if i in (1, 4) else c[2]), 'stroke="%s" stroke-width="3" stroke-opacity="0.6" stroke-linejoin="round"' % P["lead"])
    s += poly(inner, c[0], LEAD(4)) + poly([inner[5], inner[0], (cx, cy)], "#FFFFFF", 'fill-opacity="0.18"')
    return s


A = {}

# Welcome: Pop, the first bottle everyone knows, waving in on a sunny aqua window.
A["welcome"] = medallion(
    ["aqua", "emerald", "amber", "aqua"], ("#4FB6C9", P["smoke"]), "aqua",
    picture("glassies_pop", 106, 96, 300, rot=-8).replace("<image", '<image filter="url(#drop)"')
    + poly(star(372, 170, 26), P["amber"][0], LEAD(4)) + poly(star(150, 330, 16), P["amber"][1], LEAD(3)),
    sd=101,
)

# First Win: two glassies clash and the glass shatters between them, ruby and gold.
seed(7)
A["first_win"] = medallion(
    ["ruby", "amber", "ruby", "milk"], ("#C8546A", P["smoke"]), "amber",
    picture("glassies_pop", 40, 170, 210, rot=-28).replace("<image", '<image filter="url(#drop)"')
    + picture("glassies_jam", 262, 170, 210, rot=26).replace("<image", '<image filter="url(#drop)"')
    + burst(C, 250, 128, ["amber", "milk", "amber", "ruby"], 11)
    + poly(star(C, 250, 46), P["amber"][0], LEAD(5)) + poly(star(C, 250, 20), "#FFFFFF", 'fill-opacity="0.75"'),
    sd=202,
)

# Legendary Find: the Unicorn rises out of a golden Kiln glow.
A["legendary_find"] = medallion(
    ["amber", "amber", "milk", "ruby"], ("#E6A93A", P["smoke"]), "amber",
    '<ellipse cx="256" cy="372" rx="120" ry="26" fill="%s" fill-opacity="0.65"/>' % P["amber"][1]
    + picture("glassies_glass_unicorn", 86, 70, 345).replace("<image", '<image filter="url(#drop)"')
    + poly(star(150, 150, 22), P["amber"][1], LEAD(4)) + poly(star(380, 300, 18), P["amber"][1], LEAD(3))
    + poly(star(360, 130, 12), "#FFFFFF", LEAD(2)),
    sd=303,
)

# Level 10: the profile's sapphire level hex with a big 10.
A["level_10"] = medallion(
    ["sapphire", "aqua", "sapphire", "amethyst"], ("#4C78D8", P["smoke"]), "sapphire",
    hex_gem(C, C, 128, "sapphire")
    + '<text x="256" y="300" text-anchor="middle" font-family="Arial Black, Arial, sans-serif" font-weight="900" '
      'font-size="132" fill="#FFFFFF" stroke="%s" stroke-width="12" paint-order="stroke" letter-spacing="-4">10</text>' % P["lead"]
    + poly(star(C, 92, 22), P["amber"][0], LEAD(4)),
    sd=404,
)

# Daily week: Midnight (the Day 7 glassy) in a night sky with seven stars, one per day.
night = "".join(poly(star(C + 150 * math.sin(math.radians(a)), C - 150 * math.cos(math.radians(a)) + 6, 15 if i != 3 else 22),
                     P["amber"][1] if i != 3 else P["amber"][0], LEAD(3))
                for i, a in enumerate([-120, -80, -40, 0, 40, 80, 120]))
A["daily_week"] = medallion(
    ["amethyst", "sapphire", "amethyst", "milk"], ("#5A47A8", "#1A1430"), "amethyst",
    night + picture("glassies_midnight_moon", 118, 108, 290, rot=4).replace("<image", '<image filter="url(#drop)"'),
    sd=505,
)


def preview(pngs):
    """Every badge after the circular crop, on Roblox's light and dark page colours."""
    names = list(pngs)
    w, h = 40 + 280 * len(names), 640
    s = '<rect width="%d" height="320" fill="#F2F4F5"/><rect y="320" width="%d" height="320" fill="#232527"/>' % (w, w)
    for i, name in enumerate(names):
        data = base64.b64encode(pngs[name]).decode()
        for row in (0, 1):
            x, y = 40 + 280 * i, 40 + 320 * row
            s += ('<clipPath id="c%d%d"><circle cx="%d" cy="%d" r="120"/></clipPath><image href="data:image/png;base64,%s" '
                  'x="%d" y="%d" width="240" height="240" clip-path="url(#c%d%d)"/>' % (i, row, x + 120, y + 120, data, x, y, i, row))
    return SV(w, h, s)


if __name__ == "__main__":
    os.makedirs(os.path.join(OUT, "svg"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "png"), exist_ok=True)
    for name, svg in A.items():
        open(os.path.join(OUT, "svg", name + ".svg"), "w").write(svg)
    kit.size_of = lambda svg: tuple(int(v) for v in kit.re.search(r'width="(\d+)" height="(\d+)"', svg).groups())
    pngs = kit.render(A)
    for name in A:
        open(os.path.join(OUT, "png", name + ".png"), "wb").write(pngs[name])
    sheet = kit.render({"preview": preview({n: pngs[n] for n in A})})
    open(os.path.join(OUT, "preview.png"), "wb").write(sheet["preview"])
    print("%d badges written to %s" % (len(pngs), OUT))
