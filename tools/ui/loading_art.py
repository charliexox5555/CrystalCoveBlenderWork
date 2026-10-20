"""Loading screen artwork (Stained Glass, flat vector). Writes editable SVGs and transparent PNGs into
assets/ui/loading/{svg,png}, plus a full-screen mockup (mockup.png) of the composed screen.

    python3 tools/ui/loading_art.py

Pieces (the client animates them; no ViewportFrames):
  glassy_pop / glassy_jam / glassy_prism / glassy_flask   glass toys hanging from a ring at the top centre
  shard_a / shard_b / shard_c                              white glass shards (tinted in game with ImageColor3)
  burst                                                    the clash star (white, tinted gold in game)
  glow                                                     soft round glow behind the clash
  swing_frame                                              the wooden swing beam and legs
  backdrop                                                 a dim rose window behind everything
Every glassy hangs from the point (0.5, 0.03) of its image: the string ties on there.
Rendering reuses the headless-Chrome helper in daily_rewards_art.py.
"""
import base64
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from daily_rewards_art import P, render, mix, rnd, seed  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "ui", "loading")
LEAD = P["lead"]


def svg(w, h, body):
    return '<svg width="%d" height="%d" viewBox="0 0 %d %d" xmlns="http://www.w3.org/2000/svg">%s</svg>' % (w, h, w, h, body)


def ring(cx, cy=16):
    # The hang ring the string ties to.
    return ('<circle cx="%s" cy="%s" r="10" fill="none" stroke="%s" stroke-width="7"/>'
            '<circle cx="%s" cy="%s" r="10" fill="none" stroke="#FFFFFF" stroke-opacity="0.55" stroke-width="2"/>'
            % (cx, cy, LEAD, cx, cy))


def shine(*strokes):
    out = ""
    for d, w, op in strokes:
        out += '<path d="%s" fill="none" stroke="#FFFFFF" stroke-opacity="%s" stroke-width="%s" stroke-linecap="round"/>' % (d, op, w)
    return out


def body_svg(w, h, path, tint, light, dark, extra_back="", extra_front="", top=48):
    clip = '<defs><clipPath id="clip"><path d="%s"/></clipPath></defs>' % path
    inner = ('<g clip-path="url(#clip)"><path d="%s" fill="none" stroke="%s" stroke-opacity="0.6" stroke-width="22"/>'
             '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s" fill-opacity="0.55"/></g>'
             % (path, dark, w * 0.42, h * 0.62, w * 0.22, h * 0.2, light))
    return svg(w, h, clip + ring(w / 2) + '<line x1="%s" y1="26" x2="%s" y2="%s" stroke="%s" stroke-width="6"/>'
               % (w / 2, w / 2, top, LEAD) + extra_back
               + '<path d="%s" fill="%s" fill-opacity="0.93"/>' % (path, tint) + inner
               + '<path d="%s" fill="none" stroke="%s" stroke-width="9" stroke-linejoin="round"/>' % (path, LEAD)
               + extra_front)


def pop():
    # Soda bottle (Pop, aqua): cap, long neck, round shoulders, a pinch at the waist, bubbles.
    w, h = 220, 340
    d = ("M92 70 L128 70 L130 112 C132 130 170 142 172 178 C174 204 160 214 160 228 C160 242 176 252 176 282 "
         "C176 316 156 330 110 330 C64 330 44 316 44 282 C44 252 60 242 60 228 C60 214 46 204 48 178 "
         "C50 142 88 130 90 112 Z")
    cap = ('<rect x="84" y="46" width="52" height="28" rx="7" fill="%s" stroke="%s" stroke-width="8"/>'
           '<rect x="92" y="52" width="16" height="10" rx="4" fill="#FFFFFF" fill-opacity="0.45"/>' % (P["ruby"][0], LEAD))
    bubbles = "".join('<circle cx="%s" cy="%s" r="%s" fill="#FFFFFF" fill-opacity="0.55"/>' % b
                      for b in [(130, 262, 7), (144, 236, 5), (122, 214, 4), (150, 292, 5), (136, 190, 3.5)])
    front = bubbles + shine(("M70 196 C64 222 66 250 72 270", 10, 0.85), ("M74 290 L76 300", 10, 0.85),
                            ("M104 92 L104 118", 6, 0.6)) + cap
    return body_svg(w, h, d, "#8FE3FF", "#E6FBFF", "#2AA6C8", extra_front=front, top=48)


def jam():
    # Jam jar (Jam, pink): screw lid, chunky jar, seeds, a little label heart.
    w, h = 240, 340
    d = "M58 104 L182 104 C198 104 206 118 206 136 L206 292 C206 316 190 330 166 330 L74 330 C50 330 34 316 34 292 L34 136 C34 118 42 104 58 104 Z"
    lid = ('<rect x="44" y="52" width="152" height="50" rx="12" fill="%s" stroke="%s" stroke-width="8"/>'
           '<path d="M62 64 L62 92 M86 64 L86 92 M110 64 L110 92 M134 64 L134 92 M158 64 L158 92 M178 64 L178 92" '
           'stroke="%s" stroke-opacity="0.35" stroke-width="5"/>'
           '<rect x="54" y="58" width="60" height="10" rx="5" fill="#FFFFFF" fill-opacity="0.5"/>'
           % (P["amber"][0], LEAD, P["amber"][2]))
    seeds = "".join('<ellipse cx="%s" cy="%s" rx="4" ry="6" fill="%s" fill-opacity="0.6" transform="rotate(%s %s %s)"/>'
                    % (x, y, P["ruby"][2], r, x, y) for x, y, r in
                    [(92, 280, 20), (150, 298, -15), (170, 250, 30), (70, 238, -25), (128, 262, 5), (176, 300, 40)])
    label = ('<rect x="70" y="160" width="100" height="62" rx="12" fill="%s" stroke="%s" stroke-width="6"/>'
             '<path d="M120 208 C104 196 96 188 96 180 C96 172 104 168 110 168 C115 168 118 171 120 175 '
             'C122 171 125 168 130 168 C136 168 144 172 144 180 C144 188 136 196 120 208 Z" fill="%s" stroke="%s" stroke-width="4"/>'
             % (P["milk"][0], LEAD, P["ruby"][0], LEAD))
    front = seeds + label + shine(("M54 140 L54 290", 11, 0.8), ("M188 140 L188 170", 8, 0.5)) + lid
    return body_svg(w, h, d, "#FF6B8B", "#FFD3DD", "#C7375A", extra_front=front, top=52)


def prism():
    # Prism (purple crystal): a cut gem hanging point-down, facets catching light.
    w, h = 230, 340
    d = "M115 52 L196 126 L170 286 L115 330 L60 286 L34 126 Z"
    facets = ('<path d="M115 52 L115 330 M34 126 L115 168 L196 126 M60 286 L115 168 L170 286" fill="none" '
              'stroke="%s" stroke-width="5" stroke-linejoin="round" stroke-opacity="0.85"/>'
              '<path d="M115 52 L34 126 L115 168 Z" fill="#FFFFFF" fill-opacity="0.35"/>'
              '<path d="M115 168 L196 126 L170 286 Z" fill="%s" fill-opacity="0.35"/>'
              '<path d="M60 286 L115 168 L115 330 Z" fill="#FFFFFF" fill-opacity="0.15"/>' % (LEAD, P["amethyst"][2]))
    sparkle = ('<path d="M150 92 L156 106 L170 112 L156 118 L150 132 L144 118 L130 112 L144 106 Z" fill="#FFFFFF"/>'
               '<circle cx="78" cy="220" r="5" fill="#FFFFFF" fill-opacity="0.8"/>')
    return body_svg(w, h, d, "#C9A8FF", "#F1E8FF", "#7A4FD0", extra_front=facets + sparkle, top=52)


def flask():
    # Round potion flask (green): cork, neck, round belly with a liquid line.
    w, h = 230, 340
    d = ("M96 72 L134 72 L134 132 C182 146 208 186 208 236 C208 292 166 330 115 330 C64 330 22 292 22 236 "
         "C22 186 48 146 96 132 Z")
    cork = ('<rect x="88" y="44" width="54" height="32" rx="8" fill="%s" stroke="%s" stroke-width="8"/>'
            '<path d="M98 54 L130 54" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="5" stroke-linecap="round"/>'
            % ("#C98B4A", LEAD))
    liquid = ('<path d="M30 238 C70 222 100 252 130 236 C160 222 186 232 202 240 C200 290 162 324 115 324 '
              'C68 324 32 290 30 238 Z" fill="%s" fill-opacity="0.75"/>'
              '<path d="M30 238 C70 222 100 252 130 236 C160 222 186 232 202 240" fill="none" stroke="#FFFFFF" '
              'stroke-opacity="0.7" stroke-width="5"/>' % P["emerald"][0])
    bubbles = "".join('<circle cx="%s" cy="%s" r="%s" fill="#FFFFFF" fill-opacity="0.6"/>' % b
                      for b in [(90, 286, 7), (140, 270, 5), (118, 300, 4)])
    front = liquid + bubbles + shine(("M50 206 C44 226 46 246 52 262", 11, 0.85), ("M106 92 L106 126", 6, 0.6)) + cork
    return body_svg(w, h, d, "#B9F5D6", "#F0FFF7", "#22B573", extra_front=front, top=48)


def shard(points, w=110, h=110):
    pts = " ".join("%s,%s" % p for p in points)
    cx = sum(p[0] for p in points) / len(points)
    cy = sum(p[1] for p in points) / len(points)
    inner = " ".join("%.1f,%.1f" % (cx + (x - cx) * 0.5 - 6, cy + (y - cy) * 0.5 - 6) for x, y in points)
    return svg(w, h, '<polygon points="%s" fill="#FFFFFF" fill-opacity="0.9" stroke="%s" stroke-width="7" stroke-linejoin="round"/>'
               '<polygon points="%s" fill="#FFFFFF"/>' % (pts, LEAD, inner))


def burst():
    w = h = 300
    cx = cy = 150
    spikes, outer, inner = 12, 140, 70
    pts = []
    for i in range(spikes * 2):
        r = outer if i % 2 == 0 else inner
        r *= 1 if i % 4 else 0.86
        a = math.pi * i / spikes - math.pi / 2
        pts.append("%.1f,%.1f" % (cx + math.cos(a) * r, cy + math.sin(a) * r))
    star = " ".join(pts)
    core = []
    for i in range(spikes * 2):
        r = 74 if i % 2 == 0 else 40
        a = math.pi * i / spikes - math.pi / 2 + 0.13
        core.append("%.1f,%.1f" % (cx + math.cos(a) * r, cy + math.sin(a) * r))
    return svg(w, h, '<polygon points="%s" fill="#FFFFFF" fill-opacity="0.9" stroke="%s" stroke-width="9" stroke-linejoin="round"/>'
               '<polygon points="%s" fill="#FFFFFF"/>' % (star, LEAD, " ".join(core)))


def glow():
    return svg(256, 256, '<defs><radialGradient id="g"><stop offset="0" stop-color="#FFFFFF" stop-opacity="1"/>'
               '<stop offset="0.35" stop-color="#FFFFFF" stop-opacity="0.55"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>'
               '</radialGradient></defs><circle cx="128" cy="128" r="128" fill="url(#g)"/>')


def swing_frame():
    # Front view of the arena swing: a chunky beam on two A-legs (flat low-poly wood, lead outline).
    w, h = 1000, 560
    wood, side, dark = "#D9A15B", "#B07A3C", "#7E5427"

    def leg(x0, x1, xb0, xb1):
        return ('<polygon points="%s,70 %s,70 %s,548 %s,548" fill="%s" stroke="%s" stroke-width="9" stroke-linejoin="round"/>'
                '<polygon points="%s,70 %s,70 %s,548 %s,548" fill="%s" fill-opacity="0.9"/>'
                % (x0, x1, xb1, xb0, wood, LEAD, x0 + (x1 - x0) * 0.62, x1, xb1, xb0 + (xb1 - xb0) * 0.62, side))
    legs = leg(150, 196, 40, 86) + leg(196, 242, 250, 296) + leg(758, 804, 704, 750) + leg(804, 850, 914, 960)
    beam = ('<rect x="96" y="34" width="808" height="62" rx="10" fill="%s" stroke="%s" stroke-width="9"/>'
            '<rect x="104" y="72" width="792" height="18" fill="%s" fill-opacity="0.9"/>'
            '<rect x="120" y="44" width="300" height="10" rx="5" fill="#FFFFFF" fill-opacity="0.35"/>' % (wood, LEAD, side))
    bolts = "".join('<circle cx="%s" cy="64" r="9" fill="%s" stroke="%s" stroke-width="5"/>' % (x, dark, LEAD) for x in (196, 804))
    braces = ('<polygon points="70,410 266,410 276,436 60,436" fill="%s" stroke="%s" stroke-width="8"/>'
              '<polygon points="734,410 930,410 940,436 724,436" fill="%s" stroke="%s" stroke-width="8"/>' % (side, LEAD, side, LEAD))
    return svg(w, h, legs + braces + beam + bolts)


def backdrop():
    # A dim rose window filling the screen: rings of panes in jewel colours mixed far toward smoke, lead lines.
    w, h = 1024, 576
    cx, cy = 512, 250
    seed(23)
    jewels = ["ruby", "amber", "emerald", "aqua", "sapphire", "amethyst"]
    out = '<rect width="%d" height="%d" fill="%s"/>' % (w, h, P["smoke"])
    # Background panes: a loose grid of quads in smoke tones.
    for gy in range(-1, 7):
        for gx in range(-1, 11):
            x, y = gx * 104 + (gy % 2) * 52, gy * 96
            jit = lambda: (rnd() - 0.5) * 26
            quad = [(x + jit(), y + jit()), (x + 104 + jit(), y + jit()), (x + 104 + jit(), y + 96 + jit()), (x + jit(), y + 96 + jit())]
            col = mix(P[jewels[int(rnd() * 6)]][0], P["smoke"], 0.86 + rnd() * 0.08)
            out += '<polygon points="%s" fill="%s" stroke="%s" stroke-width="6" stroke-linejoin="round"/>' % (
                " ".join("%.1f,%.1f" % q for q in quad), col, LEAD)
    # The rose window.
    rings = [(46, 120, 8), (120, 210, 16), (210, 300, 24)]
    out += '<circle cx="%d" cy="%d" r="312" fill="%s"/>' % (cx, cy, LEAD)
    out += '<circle cx="%d" cy="%d" r="42" fill="%s" stroke="%s" stroke-width="7"/>' % (cx, cy, mix(P["amber"][0], P["smoke"], 0.55), LEAD)
    for r0, r1, n in rings:
        for i in range(n):
            a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
            steps = 6
            pts = [(cx + math.cos(a0 + (a1 - a0) * k / steps) * r1, cy + math.sin(a0 + (a1 - a0) * k / steps) * r1) for k in range(steps + 1)]
            pts += [(cx + math.cos(a1 - (a1 - a0) * k / steps) * r0, cy + math.sin(a1 - (a1 - a0) * k / steps) * r0) for k in range(steps + 1)]
            j = jewels[(i + r0 // 40) % 6]
            col = mix(P[j][0], P["smoke"], 0.74 if r0 < 200 else 0.8)
            out += '<polygon points="%s" fill="%s" stroke="%s" stroke-width="7" stroke-linejoin="round"/>' % (
                " ".join("%.1f,%.1f" % p for p in pts), col, LEAD)
    # Vignette and a soft light from the window.
    out += ('<defs><radialGradient id="v" cx="0.5" cy="0.43" r="0.75"><stop offset="0.45" stop-color="%s" stop-opacity="0"/>'
            '<stop offset="1" stop-color="%s" stop-opacity="0.92"/></radialGradient>'
            '<radialGradient id="l" cx="0.5" cy="0.43" r="0.35"><stop offset="0" stop-color="#FFE7B0" stop-opacity="0.22"/>'
            '<stop offset="1" stop-color="#FFE7B0" stop-opacity="0"/></radialGradient></defs>'
            '<rect width="%d" height="%d" fill="url(#l)"/><rect width="%d" height="%d" fill="url(#v)"/>' % (LEAD, LEAD, w, h, w, h))
    return svg(w, h, out)


A = {
    "glassy_pop": pop(),
    "glassy_jam": jam(),
    "glassy_prism": prism(),
    "glassy_flask": flask(),
    "shard_a": shard([(10, 30), (100, 12), (56, 100)]),
    "shard_b": shard([(20, 10), (96, 54), (40, 102), (8, 60)]),
    "shard_c": shard([(54, 6), (100, 90), (14, 80)]),
    "burst": burst(),
    "glow": glow(),
    "swing_frame": swing_frame(),
    "backdrop": backdrop(),
}


def inner(s):
    return s[s.index(">") + 1:s.rindex("</svg>")]


def nested(key, x, y, scale, rot=0, pivot=None, tint=None, opacity=1):
    s = A[key]
    import re
    m = re.search(r'width="(\d+)" height="(\d+)"', s)
    w, h = int(m.group(1)), int(m.group(2))
    px, py = pivot or (w / 2, h / 2)
    body = inner(s).replace('id="clip"', 'id="clip_%s_%d"' % (key, int(x))).replace("url(#clip)", "url(#clip_%s_%d)" % (key, int(x)))
    return ('<g transform="translate(%s %s) rotate(%s) scale(%s) translate(%s %s)" opacity="%s">%s</g>'
            % (x, y, rot, scale, -px, -py, opacity, body))


def mockup():
    """The composed screen at 1920x1080: one frame of the clash, for the creator to approve."""
    W, H = 1920, 1080
    s = nested("backdrop", W / 2, H / 2, W / 1024 * 1.0, 0)
    # Title
    s += ('<text x="960" y="150" text-anchor="middle" font-family="Denk One, Impact, Arial Black, sans-serif" '
          'font-size="118" font-weight="900" fill="%s" stroke="%s" stroke-width="22" paint-order="stroke" '
          'letter-spacing="4">GLASS CLASH</text>' % (P["amber"][1], LEAD))
    s += ('<text x="960" y="150" text-anchor="middle" font-family="Denk One, Impact, Arial Black, sans-serif" '
          'font-size="118" font-weight="900" fill="url(#tg)" letter-spacing="4">GLASS CLASH</text>'
          '<defs><linearGradient id="tg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFF4D6"/>'
          '<stop offset="0.55" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient></defs>' % (P["amber"][1], P["amber"][0]))
    # Swing frame (scale 0.9 around y 500): the beam's hang line sits at y = 500 + (64 - 280) * 0.9.
    fs = 0.9
    s += nested("swing_frame", 960, 500, fs)
    beam_y = 500 + (64 - 280) * fs
    pl, pr = (840, beam_y), (1080, beam_y)
    L, gs = 250, 0.85
    al, ar = -5, 5  # mid-clash: each swung in toward the middle
    for (px, py), a, key in [(pl, al, "glassy_pop"), (pr, ar, "glassy_jam")]:
        ex = px - math.sin(math.radians(a)) * L
        ey = py + math.cos(math.radians(a)) * L
        s += '<line x1="%s" y1="%s" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="6"/>' % (px, py, ex, ey, LEAD)
        s += '<line x1="%s" y1="%s" x2="%.1f" y2="%.1f" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="2"/>' % (px, py, ex, ey)
        s += nested(key, ex, ey, gs, a, pivot=(110 if key != "glassy_jam" else 120, 16))
    # Clash burst where they meet
    cx, cy = 960, beam_y + L + 140
    s += nested("glow", cx, cy, 2.2, opacity=0.6)
    s += '<g>%s</g>' % nested("burst", cx, cy, 0.7, 12).replace('fill="#FFFFFF" fill-opacity="0.9"', 'fill="%s"' % P["amber"][1])
    for k, (dx, dy, r, sc) in enumerate([(-200, -120, 25, 0.85), (210, -100, -40, 0.75), (-180, 120, 70, 0.7),
                                         (190, 140, 15, 0.8), (30, -200, -10, 0.6), (-290, 0, 50, 0.55), (300, 20, -60, 0.6)]):
        key = ["shard_a", "shard_b", "shard_c"][k % 3]
        tint = ["#8FE3FF", "#FF6B8B", "#FFFFFF"][k % 3]
        s += nested(key, cx + dx, cy + dy, sc, r).replace('fill="#FFFFFF" fill-opacity="0.9"', 'fill="%s" fill-opacity="0.9"' % tint)
    # "CLASH!" pop text
    s += ('<text x="%d" y="%d" text-anchor="middle" font-family="Denk One, Impact, Arial Black, sans-serif" font-size="64" '
          'font-weight="900" fill="#FFFFFF" stroke="%s" stroke-width="14" paint-order="stroke" transform="rotate(-8 %d %d)">CLASH!</text>'
          % (cx + 4, cy - 170, LEAD, cx, cy - 170))
    # Progress bar: lead frame, segmented amber glass fill, percent
    bx, by, bw, bh = 560, 968, 800, 46
    s += '<rect x="%d" y="%d" width="%d" height="%d" rx="23" fill="%s" stroke="%s" stroke-width="8"/>' % (bx, by, bw, bh, P["smoke2"], LEAD)
    fill = 0.62
    s += ('<defs><linearGradient id="bar" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="%s"/>'
          '<stop offset="1" stop-color="%s"/></linearGradient><clipPath id="bc"><rect x="%d" y="%d" width="%d" height="%d" rx="17"/></clipPath></defs>'
          % (P["amber"][1], P["amber"][0], bx + 6, by + 6, bw - 12, bh - 12))
    s += '<g clip-path="url(#bc)"><rect x="%d" y="%d" width="%d" height="%d" fill="url(#bar)"/>' % (bx + 6, by + 6, (bw - 12) * fill, bh - 12)
    s += '<rect x="%d" y="%d" width="%d" height="8" fill="#FFFFFF" fill-opacity="0.45"/>' % (bx + 6, by + 10, (bw - 12) * fill)
    for i in range(1, 10):
        x = bx + 6 + (bw - 12) * i / 10
        s += '<line x1="%s" y1="%d" x2="%s" y2="%d" stroke="%s" stroke-width="5" stroke-opacity="0.9"/>' % (x, by, x, by + bh, LEAD)
    s += '</g>'
    s += ('<text x="960" y="948" text-anchor="middle" font-family="Denk One, Arial Black, sans-serif" font-size="34" '
          'fill="#FFFFFF" stroke="%s" stroke-width="8" paint-order="stroke">Heating the Kiln...</text>' % LEAD)
    s += ('<text x="960" y="1062" text-anchor="middle" font-family="Denk One, Arial Black, sans-serif" font-size="30" '
          'fill="%s" stroke="%s" stroke-width="7" paint-order="stroke">62%%</text>' % (P["amber"][1], LEAD))
    return svg(W, H, s)


if __name__ == "__main__":
    os.makedirs(os.path.join(OUT, "svg"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "png"), exist_ok=True)
    jobs = dict(A)
    jobs["mockup"] = mockup()
    for name, s in jobs.items():
        open(os.path.join(OUT, "svg", name + ".svg"), "w").write(s)
    for name, data in render(jobs).items():
        path = os.path.join(OUT, "mockup.png") if name == "mockup" else os.path.join(OUT, "png", name + ".png")
        open(path, "wb").write(data)
        print(name, "written")
