"""Daily Rewards screen artwork (Stained Glass, UI v0.5). Writes editable SVGs and transparent PNGs into
assets/ui/screens/daily_rewards/{svg,png}. Same shapes and palette as tools/ui/stained_glass.mjs (the window mosaic
is ported here so that file stays untouched); the accent is amber, the screen's banner colour. Everything else on
the screen reuses the kit (tags, gem buttons, plaques, close diamond, window).

    python3 tools/ui/daily_rewards_art.py

PNGs are 2x the SVG size, capped at 1024 px on the long side so Roblox never resamples them. Rendering uses headless
Google Chrome (this Mac has no Node/resvg): every SVG is drawn to a canvas in one page and read back as PNG data.
"""
import base64
import json
import math
import os
import re
import subprocess
import tempfile
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "ui", "screens", "daily_rewards")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

P = {
    "lead": "#1F1830", "smoke": "#261D3B", "smoke2": "#332854", "viewport": "#3B2F5E",
    "ruby": ["#E23A55", "#FF8EA0", "#9E1D38"], "amber": ["#F5A524", "#FFD98A", "#B26E0B"],
    "emerald": ["#22B573", "#86EDB8", "#11703F"], "sapphire": ["#2E6BE6", "#93BCFF", "#1A409C"],
    "amethyst": ["#8B4FE0", "#CDAAFF", "#57299F"], "aqua": ["#1FC2D3", "#9BF3F8", "#0F7C88"],
    "milk": ["#EEE7D9", "#FFFFFF", "#B9AE99"], "slate": ["#7C7896", "#B7B3CC", "#4F4B69"],
}
_seed = [11]


def rnd():
    _seed[0] = (_seed[0] * 16807) % 2147483647
    return (_seed[0] - 1) / 2147483646


def seed(v):
    _seed[0] = v


def pts(a):
    return " ".join("%.1f,%.1f" % (p[0], p[1]) for p in a)


def poly(a, fill, extra=""):
    return '<polygon points="%s" fill="%s" %s/>' % (pts(a), fill, extra)


def SV(w, h, s):
    return '<svg width="%d" height="%d" viewBox="0 0 %d %d" xmlns="http://www.w3.org/2000/svg">%s</svg>' % (w, h, w, h, s)


def LEAD(w):
    return 'stroke="%s" stroke-width="%s" stroke-linejoin="round"' % (P["lead"], w)


def chamfer(x, y, w, h, c):
    return [[x + c[0], y], [x + w - c[1], y], [x + w, y + c[1]], [x + w, y + h - c[2]], [x + w - c[2], y + h],
            [x + c[3], y + h], [x, y + h - c[3]], [x, y + c[0]]]


def along(pl):
    L = [0]
    for i in range(len(pl)):
        a, b = pl[i], pl[(i + 1) % len(pl)]
        L.append(L[i] + math.hypot(b[0] - a[0], b[1] - a[1]))
    return L


def at(pl, L, t):
    d = t * L[-1]
    for i in range(len(pl)):
        if d <= L[i + 1] + 1e-6:
            a, b = pl[i], pl[(i + 1) % len(pl)]
            u = (d - L[i]) / ((L[i + 1] - L[i]) or 1)
            return [a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u]
    return pl[0]


def arc(pl, L, t0, t1):
    T, o = L[-1], [at(pl, L, t0)]
    for i in range(1, len(pl) + 1):
        if t0 < L[i] / T < t1:
            o.append(pl[i % len(pl)])
    o.append(at(pl, L, t1))
    return o


def shrink(a, f):
    cx, cy = sum(p[0] for p in a) / len(a), sum(p[1] for p in a) / len(a)
    return [[cx + (p[0] - cx) * f, cy + (p[1] - cy) * f] for p in a]


def mix(a, b, t):
    """Blend hex colour a toward b (used to make the "claimed" glass read as spent)."""
    ca, cb = [int(a[i:i + 2], 16) for i in (1, 3, 5)], [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join("%02X" % round(x * (1 - t) + y * t) for x, y in zip(ca, cb))


def mosaic(w, h, band, cut, colors, pieces, pal=None, shine=0.35):
    """Mosaic border band of jewel pieces (the kit's windowSvg construction). Returns (svg, outer, inner, Li)."""
    pal = pal or P
    outer = chamfer(4, 4, w - 8, h - 8, cut)
    inner = chamfer(4 + band, 4 + band, w - 8 - 2 * band, h - 8 - 2 * band, [max(6, v - band * 0.45) for v in cut])
    Lo, Li = along(outer), along(inner)
    ts = [0] + [i / pieces + (rnd() - 0.5) * 0.55 / pieces for i in range(1, pieces)] + [1]
    s = poly(outer, P["lead"])
    for i in range(pieces):
        pc = arc(outer, Lo, ts[i], ts[i + 1]) + list(reversed(arc(inner, Li, ts[i], ts[i + 1])))
        col = pal[colors[int(rnd() * len(colors))]]
        s += poly(pc, col[0], LEAD(5)) + poly(shrink(pc, 0.45), col[1], 'fill-opacity="%s"' % shine)
    return s, outer, inner, Li


def facets(inner, Li, n, color, opacity=1):
    s = ""
    for _ in range(n):
        t = rnd()
        p1, p2 = at(inner, Li, t), at(inner, Li, (t + 0.3 + rnd() * 0.35) % 1)
        s += '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="4" stroke-opacity="%s"/>' % (
            p1[0], p1[1], p2[0], p2[1], color, opacity)
    return s


A = {}

# Day cells (Days 1-6): 300x242, the grid cell's on-screen aspect (1.24). Same mosaic layout in every state, so
# swapping a cell's state doesn't make its border jump.
CW, CH, CCUT = 300, 242, [24, 10, 26, 10]
seed(23)
s, outer, inner, Li = mosaic(CW, CH, 13, CCUT, ["slate", "milk", "slate"], 12)
A["cell_locked"] = SV(CW, CH, s + poly(inner, P["smoke"], LEAD(5)) + facets(inner, Li, 2, P["smoke2"]) + poly(outer, "none", LEAD(7)))

seed(23)
spent = {k: [mix(c, P["lead"], 0.35) for c in P[k]] for k in ("emerald", "slate")}
s, outer, inner, Li = mosaic(CW, CH, 13, CCUT, ["emerald", "emerald", "slate"], 12, pal=spent, shine=0.2)
A["cell_claimed"] = SV(CW, CH, s + poly(inner, mix(mix(P["smoke"], P["lead"], 0.35), P["emerald"][2], 0.18), LEAD(5)) + facets(inner, Li, 2, P["smoke"]) + poly(outer, "none", LEAD(7)))

seed(23)
s, outer, inner, Li = mosaic(CW, CH, 13, CCUT, ["amber", "amber", "ruby"], 12, shine=0.5)
defs = '<defs><linearGradient id="t" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#5A4590"/><stop offset="1" stop-color="%s"/></linearGradient></defs>' % P["viewport"]
A["cell_today"] = SV(CW, CH, defs + s + poly(inner, "url(#t)", LEAD(5)) + facets(inner, Li, 2, "#6A55A3", 0.7)
                     + poly(shrink(inner, 0.94), "none", 'stroke="%s" stroke-width="3" stroke-opacity="0.7" stroke-linejoin="round"' % P["amber"][1])
                     + poly(outer, "none", LEAD(8)))

# Day 7 cell: 300x386 (aspect 0.778), spans both rows. Every jewel colour in a thick band, an inner gold rim, and a
# leaded sunburst pane centred where the big reward sits.
D7W, D7H = 300, 386
seed(71)
s, outer, rim, Li = mosaic(D7W, D7H, 18, [32, 14, 34, 14], ["ruby", "amber", "emerald", "sapphire", "amethyst", "aqua"], 20, shine=0.45)
pane = chamfer(29, 29, D7W - 58, D7H - 58, [20, 8, 22, 8])
cx, cy, R, n = D7W / 2, D7H * 0.47, 400, 18
rays = ""
for i in range(n):
    a0, a1 = i / n * 2 * math.pi - math.pi / 2, (i + 1) / n * 2 * math.pi - math.pi / 2
    rays += poly([[cx, cy], [cx + R * math.cos(a0), cy + R * math.sin(a0)], [cx + R * math.cos(a1), cy + R * math.sin(a1)]],
                 "#4B3A78" if i % 2 == 0 else P["smoke2"], 'stroke="%s" stroke-width="2.5" stroke-opacity="0.8"' % P["lead"])
defs = ('<defs><clipPath id="c"><polygon points="%s"/></clipPath>'
        '<radialGradient id="g" cx="%.1f" cy="%.1f" r="150" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="%s" stop-opacity="0.75"/>'
        '<stop offset="0.55" stop-color="%s" stop-opacity="0.25"/><stop offset="1" stop-color="%s" stop-opacity="0"/></radialGradient></defs>'
        % (pts(pane), cx, cy, P["amber"][1], P["amber"][0], P["amber"][0]))
A["cell_day7"] = SV(D7W, D7H, defs + s + poly(rim, P["amber"][0], LEAD(5))
                    + poly(shrink(rim, 0.985), "none", 'stroke="%s" stroke-width="2" stroke-opacity="0.8"' % P["amber"][1])
                    + '<g clip-path="url(#c)"><polygon points="%s" fill="%s"/>%s<polygon points="%s" fill="url(#g)"/></g>' % (pts(pane), P["smoke"], rays, pts(pane))
                    + poly(pane, "none", LEAD(5)) + poly(outer, "none", LEAD(8)))

# Soft amber halo behind today's cell (360x290 = the cell x1.2; shown at 1.2x the cell, behind it).
blur = '<defs><filter id="b" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="11"/></filter></defs>'
A["glow_today"] = SV(360, 290, blur + poly(chamfer(26, 22, 308, 246, [28, 12, 30, 12]), P["amber"][1], 'filter="url(#b)" fill-opacity="0.95"')
                     + poly(chamfer(30, 26, 300, 238, [26, 10, 28, 10]), "#FFFFFF", 'filter="url(#b)" fill-opacity="0.5"'))

# Radial burst behind Day 7's reward icon.
rays = ""
for i in range(12):
    a, r = i / 12 * 2 * math.pi, 118 if i % 2 else 146
    rays += poly([[150 + 26 * math.cos(a - 0.27), 150 + 26 * math.sin(a - 0.27)], [150 + r * math.cos(a), 150 + r * math.sin(a)],
                  [150 + 26 * math.cos(a + 0.27), 150 + 26 * math.sin(a + 0.27)]], "#FFFFFF", 'fill-opacity="0.55"')
A["glow_burst"] = SV(300, 300, '<defs><radialGradient id="g"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.95"/>'
                     '<stop offset="0.3" stop-color="%s" stop-opacity="0.85"/><stop offset="0.65" stop-color="%s" stop-opacity="0.35"/>'
                     '<stop offset="1" stop-color="%s" stop-opacity="0"/></radialGradient><filter id="b"><feGaussianBlur stdDeviation="3"/></filter></defs>'
                     '<circle cx="150" cy="150" r="148" fill="url(#g)"/><g filter="url(#b)">%s</g>' % (P["amber"][1], P["amber"][0], P["amber"][0], rays))

# Claimed check: the close diamond's shape in emerald with a white check (close = ruby X, done = emerald check).
D = [[40, 3], [77, 40], [40, 77], [3, 40]]
CHECK = "M22 41 L34 53 L58 28"
A["check_badge"] = SV(80, 80, poly(D, P["emerald"][0], LEAD(5)) + poly([[40, 3], [77, 40], [40, 40]], P["emerald"][1], 'fill-opacity="0.6"')
                      + poly([[40, 40], [40, 77], [3, 40]], P["emerald"][2], 'fill-opacity="0.6"') + poly(D, "none", LEAD(6))
                      + '<path d="%s" fill="none" stroke="%s" stroke-width="13" stroke-linecap="round" stroke-linejoin="round"/>' % (CHECK, P["lead"])
                      + '<path d="%s" fill="none" stroke="#FFFFFF" stroke-width="6.5" stroke-linecap="round" stroke-linejoin="round"/>' % CHECK)

# Progress bar: a leaded track (1145x50, the bar's on-screen aspect) holding seven slanted glass segments
# (172x44), with a faceted gem for Day 7 at its right end.
A["progress_track"] = SV(1145, 50, poly([[22, 3], [1123, 3], [1142, 25], [1123, 47], [22, 47], [3, 25]], P["lead"])
                         + poly([[26, 8], [1119, 8], [1134, 25], [1119, 42], [26, 42], [11, 25]], P["smoke"], 'stroke="%s" stroke-width="3"' % P["smoke2"]))
SEG = [[14, 3], [169, 3], [158, 41], [3, 41]]
A["seg_off"] = SV(172, 44, poly(SEG, P["smoke2"], LEAD(4)) + poly([[16, 7], [164, 7], [162, 14], [14, 14]], "#FFFFFF", 'fill-opacity="0.08"'))
for name, c in (("seg_lit", P["amber"]), ("seg_today", [P["amber"][1], "#FFFFFF", P["amber"][0]])):
    A[name] = SV(172, 44, poly(SEG, c[0], LEAD(4)) + poly([[16, 7], [164, 7], [161, 17], [13, 17]], c[1], 'fill-opacity="0.75"')
                 + poly([[9, 31], [156, 31], [154, 37], [7, 37]], c[2], 'fill-opacity="0.6"')
                 + poly([[34, 7], [50, 7], [40, 37], [24, 37]], "#FFFFFF", 'fill-opacity="0.35"') + poly(SEG, "none", LEAD(4)))


def gem(key):
    """Octagonal cut gem: eight crown facets around a table."""
    c = P[key]
    o = [[38, 4], [82, 4], [116, 38], [116, 82], [82, 116], [38, 116], [4, 82], [4, 38]]
    t = shrink(o, 0.52)
    shade = [c[1], c[1], c[0], c[2], c[2], c[2], c[0], c[1]]
    s = poly(o, c[0], LEAD(5))
    for j in range(8):
        s += poly([o[j], o[(j + 1) % 8], t[(j + 1) % 8], t[j]], shade[j], LEAD(2.5))
    s += poly(t, c[0], LEAD(3)) + poly([[46, 36], [60, 36], [44, 62], [36, 54]], "#FFFFFF", 'fill-opacity="0.55"') + poly(o, "none", LEAD(7))
    return SV(120, 120, s)


A["gem_off"] = gem("slate")
A["gem_lit"] = gem("amber")

# Four-point sparkle for Day 7 (animate later: twinkle scale/rotation).
A["sparkle"] = SV(64, 64, '<defs><filter id="b"><feGaussianBlur stdDeviation="3"/></filter></defs>'
                  '<circle cx="32" cy="32" r="14" fill="%s" fill-opacity="0.8" filter="url(#b)"/>' % P["amber"][1]
                  + '<path d="M32 3 C34 24 40 30 61 32 C40 34 34 40 32 61 C30 40 24 34 3 32 C24 30 30 24 32 3 Z" fill="#FFFFFF" stroke="%s" stroke-width="2" stroke-linejoin="round"/>' % P["amber"][1])

# Timer plaque (460x50, the timer row's aspect): milk glass with pointed ends, like the HUD plaques.
A["timer_plaque"] = SV(460, 50, poly([[16, 3], [444, 3], [457, 25], [444, 47], [16, 47], [3, 25]], P["milk"][0], LEAD(5))
                       + poly([[18, 7], [440, 7], [445, 17], [13, 17]], "#FFFFFF", 'fill-opacity="0.6"'))

# Clock for the timer plaque: amber octagon rim, milk face, lead hands (the screen's accent; overlaps the plaque's
# left end like the coin on the HUD currency plaque).
O = [[30, 4], [66, 4], [92, 30], [92, 66], [66, 92], [30, 92], [4, 66], [4, 30]]
F = shrink(O, 0.74)
ticks = "".join('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="4" stroke-linecap="round"/>'
                % (48 + 24 * math.sin(a), 48 - 24 * math.cos(a), 48 + 29 * math.sin(a), 48 - 29 * math.cos(a), P["lead"])
                for a in [i * math.pi / 2 for i in range(4)])
A["icon_clock"] = SV(96, 96, poly(O, P["amber"][0], LEAD(6)) + poly([O[7], O[0], O[1], O[2], F[2], F[1], F[0], F[7]], P["amber"][1], 'fill-opacity="0.7"')
                     + poly(F, P["milk"][0], LEAD(4)) + ticks
                     + '<path d="M48 48 V27 M48 48 L62 55" fill="none" stroke="%s" stroke-width="6" stroke-linecap="round"/>' % P["lead"]
                     + '<circle cx="48" cy="48" r="5" fill="%s"/>' % P["ruby"][0] + poly(O, "none", LEAD(6)))


def size_of(svg):
    m = re.search(r'width="(\d+)" height="(\d+)"', svg)
    w, h = int(m.group(1)), int(m.group(2))
    k = min(2.0, 1024 / max(w, h))
    return round(w * k), round(h * k)


def render(assets):
    jobs = [{"name": n, "w": size_of(s)[0], "h": size_of(s)[1], "src": "data:image/svg+xml;base64," + base64.b64encode(s.encode()).decode()}
            for n, s in assets.items()]
    page = """<html><body><pre id="o"></pre><script>
const jobs = %s; const out = [];
Promise.all(jobs.map(j => new Promise(res => { const i = new Image(); i.onload = () => {
  const c = document.createElement("canvas"); c.width = j.w; c.height = j.h;
  const g = c.getContext("2d"); g.imageSmoothingQuality = "high"; g.drawImage(i, 0, 0, j.w, j.h);
  out.push(j.name + "=" + c.toDataURL("image/png").split(",")[1]); res(); }; i.src = j.src; })))
 .then(() => { document.getElementById("o").textContent = "BEGIN\\n" + out.join("\\n") + "\\nEND"; });
</script></body></html>""" % json.dumps(jobs)
    tmp = tempfile.mkdtemp(prefix="daily_art_")
    html, dump = os.path.join(tmp, "render.html"), os.path.join(tmp, "dump.txt")
    open(html, "w").write(page)
    with open(dump, "w") as f:
        proc = subprocess.Popen([CHROME, "--headless=new", "--user-data-dir=" + os.path.join(tmp, "profile"), "--no-first-run",
                                 "--disable-gpu", "--virtual-time-budget=20000", "--dump-dom", "file://" + html],
                                stdout=f, stderr=subprocess.DEVNULL)
        # Chrome prints the DOM promptly but can hang on teardown: stop it once the dump is complete.
        for _ in range(240):
            time.sleep(0.5)
            if "\nEND" in open(dump).read() or proc.poll() is not None:
                break
        proc.kill()
    subprocess.run(["pkill", "-f", tmp])  # helper processes outlive the main one
    text = open(dump).read()
    body = text[text.index("BEGIN\n") + 6:text.index("\nEND")]
    return {line.split("=", 1)[0]: base64.b64decode(line.split("=", 1)[1]) for line in body.split("\n")}


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
