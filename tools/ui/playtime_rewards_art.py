"""Playtime Rewards screen artwork (Stained Glass). Writes editable SVGs and transparent PNGs into
assets/ui/screens/playtime_rewards/{svg,png}. Same shapes and palette as tools/ui/stained_glass.mjs (windowSvg is
ported here so that file stays untouched); the accent is aqua so the screen reads apart from Daily Rewards (amber).

    python3 tools/ui/playtime_rewards_art.py

PNGs are 2x the SVG size, capped at 1024 px on the long side so Roblox never resamples them. Rendering uses headless
Google Chrome (this Mac has no Node/resvg): every SVG is drawn to a canvas in one page and read back as PNG data.
"""
import base64
import json
import math
import os
import subprocess
import tempfile
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "ui", "screens", "playtime_rewards")
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


def LEAD(w, op=None):
    return 'stroke="%s" stroke-width="%s" stroke-linejoin="round"%s' % (P["lead"], w, ' stroke-opacity="%s"' % op if op else "")


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
        ti = L[i] / T
        if t0 < ti < t1:
            o.append(pl[i % len(pl)])
    o.append(at(pl, L, t1))
    return o


def shrink(a, f):
    cx, cy = sum(p[0] for p in a) / len(a), sum(p[1] for p in a) / len(a)
    return [[cx + (p[0] - cx) * f, cy + (p[1] - cy) * f] for p in a]


def window_svg(w, h, band=26, cut=(34, 16, 38, 18), colors=("ruby", "amber", "emerald", "sapphire", "amethyst", "aqua"),
               pieces=None, pane=None, facets=3):
    """Stained-glass window: mosaic border band of jewel pieces around a smoky pane (port of windowSvg)."""
    outer = chamfer(4, 4, w - 8, h - 8, cut)
    ic = [max(6, v - band * 0.45) for v in cut]
    inner = chamfer(4 + band, 4 + band, w - 8 - 2 * band, h - 8 - 2 * band, ic)
    Lo, Li = along(outer), along(inner)
    n = pieces or max(6, round((w + h) / 75))
    ts = [0] + [i / n + (rnd() - 0.5) * 0.55 / n for i in range(1, n)] + [1]
    s = poly(outer, P["lead"])
    for i in range(n):
        a, b = arc(outer, Lo, ts[i], ts[i + 1]), list(reversed(arc(inner, Li, ts[i], ts[i + 1])))
        pc, col = a + b, P[colors[int(rnd() * len(colors))]]
        s += poly(pc, col[0], LEAD(5)) + poly(shrink(pc, 0.45), col[1], 'fill-opacity="0.35"')
    s += poly(inner, pane or P["smoke"], LEAD(6))
    for _ in range(facets):
        t = rnd()
        p1, p2 = at(inner, Li, t), at(inner, Li, (t + 0.3 + rnd() * 0.35) % 1)
        s += '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="4"/>' % (p1[0], p1[1], p2[0], p2[1], P["smoke2"])
    return SV(w, h, s + poly(outer, "none", LEAD(8)))


def octagon(cx, cy, r, k=0.42):
    c = r * k
    return [[cx - r + c, cy - r], [cx + r - c, cy - r], [cx + r, cy - r + c], [cx + r, cy + r - c],
            [cx + r - c, cy + r], [cx - r + c, cy + r], [cx - r, cy + r - c], [cx - r, cy - r + c]]


def brilliant(key, size=100, dim=False):
    """Round-cut (octagon) milestone gem: crown facets around a table, lead lines between them."""
    c, h = P[key], size / 2
    o = octagon(h, h, h - 4)
    t = shrink(o, 0.56)
    shades = [c[1], c[1], c[0], c[2], c[2], c[2], c[0], c[1]]
    s = poly(o, c[0], LEAD(5))
    for j in range(8):
        s += poly([o[j], o[(j + 1) % 8], t[(j + 1) % 8], t[j]], shades[j], LEAD(2.5))
    s += poly(t, c[0], LEAD(3))
    if not dim:
        s += poly([[t[0][0] + 2, t[0][1] + 4], [t[1][0] - 8, t[1][1] + 4], [t[7][0] + 6, t[7][1] + 2]], "#FFFFFF", 'fill-opacity="0.55"')
        s += poly([[o[0][0] + 4, o[0][1] + 5], [o[0][0] + 16, o[0][1] + 5], [o[7][0] + 6, o[7][1] + 14]], "#FFFFFF", 'fill-opacity="0.5"')
    return SV(size, size, s + poly(o, "none", LEAD(6)))


def star(key, size=110, dim=False):
    """Five-point star gem for the 60-minute milestone: each point split into a light and a dark facet."""
    c, h = P[key], size / 2
    R, r = h - 5, (h - 5) * 0.5
    outer = [[h + R * math.sin(i * 2 * math.pi / 5), h + 4 - R * math.cos(i * 2 * math.pi / 5)] for i in range(5)]
    inner = [[h + r * math.sin((i + 0.5) * 2 * math.pi / 5), h + 4 - r * math.cos((i + 0.5) * 2 * math.pi / 5)] for i in range(5)]
    ctr = [h, h + 4]
    shape = [p for i in range(5) for p in (outer[i], inner[i])]
    s = poly(shape, c[0], LEAD(5))
    for i in range(5):
        s += poly([ctr, inner[i - 1], outer[i]], c[1] if i in (0, 4) else c[0], LEAD(2))
        s += poly([ctr, outer[i], inner[i]], c[2] if i in (1, 2) else c[0], LEAD(2))
    if not dim:
        s += poly([[h - 3, 14], [h + 3, 14], [h - 4, h - 2]], "#FFFFFF", 'fill-opacity="0.6"')
    return SV(size, size, s + poly(shape, "none", LEAD(6)))


def plaque_pts(x0, y0, x1, y1):
    m, k = (y0 + y1) / 2, (y1 - y0) * 0.3
    return [[x0 + k, y0], [x1 - k, y0], [x1, m], [x1 - k, y1], [x0 + k, y1], [x0, m]]


A = {}
CELL_W, CELL_H, CELL_CUT = 200, 310, (24, 10, 26, 10)

# Window: wide (aspect 2.4), aqua-led cool mosaic so it is the same family as the other menus but its own colour.
seed(23 * 7)
A["window"] = window_svg(1680, 700, band=28, pieces=44,
                         colors=("aqua", "aqua", "sapphire", "aqua", "amethyst", "emerald", "sapphire"))
# Reward cells, one frame per state (claimed/next share cell_open; claimed adds cell_dim + check on top).
seed(61); A["cell_open"] = window_svg(CELL_W, CELL_H, band=13, cut=CELL_CUT, colors=("aqua", "sapphire"), pieces=11, facets=2)
seed(61); A["cell_ready"] = window_svg(CELL_W, CELL_H, band=13, cut=CELL_CUT, colors=("aqua", "emerald"), pieces=11, facets=2, pane="#1C4152")
seed(61); A["cell_locked"] = window_svg(CELL_W, CELL_H, band=13, cut=CELL_CUT, colors=("slate",), pieces=11, facets=2, pane="#211A33")
seed(83); A["cell_best"] = window_svg(CELL_W, CELL_H, band=13, cut=CELL_CUT,
                                      colors=("ruby", "amber", "emerald", "sapphire", "amethyst", "aqua"), pieces=16, facets=2, pane="#2A1F42")
A["cell_dim"] = SV(CELL_W, CELL_H, poly(chamfer(4, 4, CELL_W - 8, CELL_H - 8, CELL_CUT), P["lead"]))
A["cell_outline"] = SV(CELL_W + 16, CELL_H + 16, poly(chamfer(4, 4, CELL_W + 8, CELL_H + 8, [c + 3 for c in CELL_CUT]), "none",
                                                      'stroke="#FFFFFF" stroke-width="6" stroke-linejoin="round"'))
# Progress bar: a lead channel (Slice) and an aqua glass fill (Slice, width = progress).
A["bar_track"] = SV(900, 40, poly(plaque_pts(3, 3, 897, 37), P["lead"], LEAD(4)) + poly(plaque_pts(10, 9, 890, 31), "#140F22"))
A["bar_fill"] = SV(900, 40, poly(plaque_pts(6, 6, 894, 34), P["aqua"][0], LEAD(3))
                   + poly([[14, 9], [886, 9], [882, 17], [18, 17]], P["aqua"][1], 'fill-opacity="0.75"')
                   + poly([[18, 27], [882, 27], [886, 31], [14, 31]], P["aqua"][2], 'fill-opacity="0.6"'))
# Milestone gems: lit when reached (aqua / amber star), dark slate before.
A["gem_on"] = brilliant("aqua")
A["gem_off"] = brilliant("slate", dim=True)
A["gem_best_on"] = star("amber")
A["gem_best_off"] = star("slate", dim=True)
A["glow"] = SV(300, 300, '<defs><radialGradient id="g"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.95"/>'
                         '<stop offset="0.35" stop-color="#9BF3F8" stop-opacity="0.75"/><stop offset="0.7" stop-color="#1FC2D3" stop-opacity="0.3"/>'
                         '<stop offset="1" stop-color="#1FC2D3" stop-opacity="0"/></radialGradient></defs><rect width="300" height="300" fill="url(#g)"/>')
# Icons.
o = octagon(48, 48, 44)
A["icon_check"] = SV(96, 96, poly(o, P["emerald"][0], LEAD(6)) + poly(shrink(o, 0.78), P["emerald"][1], 'fill-opacity="0.45"')
                     + '<path d="M26 50 L41 64 L70 32" fill="none" stroke="%s" stroke-width="17" stroke-linecap="round" stroke-linejoin="round"/>' % P["lead"]
                     + '<path d="M26 50 L41 64 L70 32" fill="none" stroke="#FFFFFF" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>')
A["icon_lock"] = SV(80, 96, '<path d="M22 46 V30 a18 18 0 0 1 36 0 V46" fill="none" stroke="%s" stroke-width="16"/>' % P["lead"]
                    + '<path d="M22 46 V30 a18 18 0 0 1 36 0 V46" fill="none" stroke="%s" stroke-width="7"/>' % P["slate"][1]
                    + poly(chamfer(8, 42, 64, 48, [8, 8, 8, 8]), P["slate"][0], LEAD(5))
                    + poly([[16, 47], [64, 47], [62, 56], [14, 56]], P["slate"][1], 'fill-opacity="0.6"')
                    + '<circle cx="40" cy="62" r="6" fill="%s"/>' % P["lead"] + poly([[37, 64], [43, 64], [45, 78], [35, 78]], P["lead"]))
ticks = "".join('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="4" stroke-linecap="round"/>'
                % (48 + 26 * math.sin(a), 48 - 26 * math.cos(a), 48 + 31 * math.sin(a), 48 - 31 * math.cos(a), P["lead"])
                for a in [i * math.pi / 2 for i in range(4)])
A["icon_clock"] = SV(96, 96, poly(o, P["aqua"][0], LEAD(6)) + poly([o[0], o[1], o[2], o[7]], P["aqua"][1], 'fill-opacity="0.6"')
                     + poly(octagon(48, 48, 35), P["milk"][0], LEAD(4)) + ticks
                     + '<path d="M48 48 V25 M48 48 L63 56" fill="none" stroke="%s" stroke-width="6" stroke-linecap="round"/>' % P["lead"]
                     + '<circle cx="48" cy="48" r="5" fill="%s"/>' % P["ruby"][0])
# Time readout tag that rides above the fill's head, pointing down at it.
body = plaque_pts(4, 4, 216, 62)
tag = body[:3] + [body[3], [124, 62], [110, 80], [96, 62]] + body[4:]
A["time_tag"] = SV(220, 84, poly(tag, P["aqua"][0], LEAD(5)) + poly([[24, 9], [196, 9], [188, 22], [32, 22]], P["aqua"][1], 'fill-opacity="0.7"')
                   + poly(tag, "none", LEAD(6)))


def size_of(svg):
    import re
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
    tmp = tempfile.mkdtemp(prefix="playtime_art_")
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
