"""Draws the labelled top-down blueprints from tools/map/village_layout.py.

    python tools/map/make_blueprints.py

Writes docs/art/blueprint_overview.svg and docs/art/blueprint_lobby.svg.
"""

import importlib.util
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))

spec = importlib.util.spec_from_file_location("village_layout", os.path.join(HERE, "village_layout.py"))
L = importlib.util.module_from_spec(spec)
spec.loader.exec_module(L)

INK = "#1A1E4A"
SEA = "#7FC4E8"
SEA_DEEP = "#5AA9D6"
GRASS_V = "#BFE3A0"
GRASS_Y = "#A9CF8C"
PATH = "#F3E6C4"
PLAZA = "#EFE3C8"

KIND_STYLE = {
    "plaza": (PLAZA, INK),
    "wild": ("#7CDB8A", "#2E8B4A"),
    "platform": ("#D8C7F2", "#6A2BD1"),
}
STAND_COLOR = {"arena": "#C98B4E", "pvp": "#4FA8FF", "small": "#FF9BE0", "trainer": "#E5263F", "boss": "#7A1FA2"}
POINT_STYLE = {
    "spawn": ("#FFE45C", "S"), "pedestal": ("#FFD54A", "P"), "board": ("#FFFFFF", "B"),
    "board_small": ("#C9D2F5", "b"), "gate": ("#2FCB3A", "G"), "gate_locked": ("#9AA5B8", "L"), "lift": ("#4FA8FF", "^"),
}


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


class Canvas:
    def __init__(self, xmin, xmax, ymin, ymax, scale, title, subtitle):
        self.xmin, self.xmax, self.ymin, self.ymax, self.s = xmin, xmax, ymin, ymax, scale
        self.w = (xmax - xmin) * scale
        self.h = (ymax - ymin) * scale
        self.legend_w = 470
        self.items = []
        self.legend = []
        self.title, self.subtitle = title, subtitle

    def p(self, x, y):
        return ((x - self.xmin) * self.s, (self.ymax - y) * self.s)

    def add(self, svg):
        self.items.append(svg)

    def num(self, label, color):
        self.legend.append((label, color))
        return len(self.legend)

    def svg(self):
        W, H = self.w + self.legend_w, max(self.h, 200 + 26 * len(self.legend))
        out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W:.0f}" height="{H:.0f}" viewBox="0 0 {W:.0f} {H:.0f}" font-family="Montserrat, Arial, sans-serif">']
        out.append(f'<defs><pattern id="waves" width="40" height="20" patternUnits="userSpaceOnUse"><path d="M0 10 Q10 4 20 10 T40 10" fill="none" stroke="#FFFFFF" stroke-opacity="0.25" stroke-width="2"/></pattern>'
                   f'<pattern id="grid" width="{20*self.s}" height="{20*self.s}" patternUnits="userSpaceOnUse"><path d="M {20*self.s} 0 L 0 0 0 {20*self.s}" fill="none" stroke="{INK}" stroke-opacity="0.06" stroke-width="1"/></pattern></defs>')
        out.append(f'<rect width="{self.w:.0f}" height="{H:.0f}" fill="{SEA}"/><rect width="{self.w:.0f}" height="{H:.0f}" fill="url(#waves)"/>')
        out.extend(self.items)
        out.append(f'<rect width="{self.w:.0f}" height="{self.h:.0f}" fill="url(#grid)"/>')
        # scale bar + compass
        bar = 100 * self.s
        out.append(f'<g transform="translate(20,{self.h-30:.0f})"><rect x="-8" y="-24" width="{bar+70:.0f}" height="40" rx="8" fill="#FFFFFF" fill-opacity="0.85"/>'
                   f'<rect x="0" y="0" width="{bar:.0f}" height="6" fill="{INK}"/><text x="{bar+8:.0f}" y="7" font-size="13" fill="{INK}" font-weight="700">100 studs</text>'
                   f'<text x="0" y="-8" font-size="11" fill="{INK}">≈ 6 s walk</text></g>')
        out.append(f'<g transform="translate({self.w-50:.0f},{self.h-50:.0f})"><circle r="30" fill="#FFFFFF" fill-opacity="0.85"/><path d="M0 -24 L8 4 L0 -2 L-8 4 Z" fill="{INK}"/><text y="20" text-anchor="middle" font-size="14" font-weight="800" fill="{INK}">N</text></g>')
        # legend panel
        lx = self.w
        out.append(f'<rect x="{lx:.0f}" y="0" width="{self.legend_w}" height="{H:.0f}" fill="#141344"/>')
        out.append(f'<text x="{lx+20:.0f}" y="38" font-size="22" font-weight="800" fill="#FFFFFF">{esc(self.title)}</text>')
        out.append(f'<text x="{lx+20:.0f}" y="62" font-size="13" fill="#C9D2F5">{esc(self.subtitle)}</text>')
        for i, (label, color) in enumerate(self.legend, start=1):
            y = 96 + (i - 1) * 26
            out.append(f'<circle cx="{lx+32:.0f}" cy="{y-5}" r="10" fill="{color}" stroke="#FFFFFF" stroke-width="1.5"/>'
                       f'<text x="{lx+32:.0f}" y="{y-1}" text-anchor="middle" font-size="11" font-weight="800" fill="{INK}">{i}</text>'
                       f'<text x="{lx+52:.0f}" y="{y}" font-size="13" fill="#FFFFFF">{esc(label)}</text>')
        out.append("</svg>")
        return "\n".join(out)


def pts(c, points):
    return " ".join(f"{c.p(x, y)[0]:.1f},{c.p(x, y)[1]:.1f}" for x, y in points)


def marker(c, x, y, color, n, r=11):
    px, py = c.p(x, y)
    c.add(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="{r}" fill="{color}" stroke="{INK}" stroke-width="2"/>'
          f'<text x="{px:.1f}" y="{py+4:.1f}" text-anchor="middle" font-size="{r+1}" font-weight="800" fill="{INK}">{n}</text>')


def rect_poly(cx, cy, w, d, facing):
    a = math.radians(facing)
    ca, sa = math.cos(a), math.sin(a)
    corners = [(-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2)]
    return [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in corners]


def draw(c, in_view):
    # land
    for land in L.LAND:
        fill = GRASS_Y if land["id"] == "yard_terrace" else (GRASS_V if land["id"] == "plateau" else land["color"])
        c.add(f'<polygon points="{pts(c, land["points"])}" fill="{fill}" stroke="#6B5B3E" stroke-width="{3 if land["id"] != "beach" else 1.5}" stroke-linejoin="round"/>')
    c.add(f'<polygon points="{pts(c, L.LAND[0]["points"])}" fill="none" stroke="#3D2E1E" stroke-width="5" stroke-dasharray="2 6" stroke-linecap="round"/>')
    # hills
    for x, y, r, h in L.HILLS:
        px, py = c.p(x, y)
        c.add(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="{r*c.s:.1f}" fill="#7DBB6A" stroke="#4E8A43" stroke-width="2"/>'
              f'<circle cx="{px:.1f}" cy="{py:.1f}" r="{r*c.s*0.55:.1f}" fill="#93CC7E"/>')
    # paths
    for path in L.PATHS:
        c.add(f'<polyline points="{pts(c, path["points"])}" fill="none" stroke="#B9A57A" stroke-width="{path["width"]*c.s+4:.1f}" stroke-linecap="round" stroke-linejoin="round"/>'
              f'<polyline points="{pts(c, path["points"])}" fill="none" stroke="{PATH}" stroke-width="{path["width"]*c.s:.1f}" stroke-linecap="round" stroke-linejoin="round"/>')
    # disks
    for d in L.DISKS:
        if not in_view(*d["center"]):
            continue
        fill, stroke = KIND_STYLE[d["kind"]]
        px, py = c.p(*d["center"])
        dash = ' stroke-dasharray="8 6"' if d["kind"] == "wild" else ""
        op = ' fill-opacity="0.55"' if d["kind"] == "wild" else ""
        c.add(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="{d["radius"]*c.s:.1f}" fill="{fill}"{op} stroke="{stroke}" stroke-width="2.5"{dash}/>')
    # scatter
    import random
    rng = random.Random(7)
    for s in L.SCATTER:
        cx, cy = s["center"]
        for _ in range(s["count"]):
            a, r = rng.uniform(0, math.tau), s["radius"] * math.sqrt(rng.random())
            x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
            if not in_view(x, y) or not L.scatter_allowed(s, x, y):
                continue
            px, py = c.p(x, y)
            kind = s["kind"]
            if kind in ("pine", "round"):
                rr = (5 if kind == "pine" else 6.5) * c.s
                c.add(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="{rr:.1f}" fill="{"#3FA874" if kind == "pine" else "#62CF9C"}" stroke="#2E7A52" stroke-width="1"/>')
            elif kind == "cullet":
                col = rng.choice(["#3FB86B", "#D98A2B", "#CFE8FF", "#4FA8FF"])
                rr = rng.uniform(7, 12) * c.s
                c.add(f'<polygon points="{px:.1f},{py-rr:.1f} {px+rr:.1f},{py+rr*0.7:.1f} {px-rr:.1f},{py+rr*0.7:.1f}" fill="{col}" stroke="{INK}" stroke-width="1"/>')
            else:
                col = rng.choice(["#3D7BF2", "#3FB86B", "#FFC93C"]) if kind == "bin" else "#D9A066"
                rr = 3 * c.s
                c.add(f'<rect x="{px-rr:.1f}" y="{py-rr:.1f}" width="{2*rr:.1f}" height="{2*rr:.1f}" fill="{col}" stroke="{INK}" stroke-width="1"/>')
    # market stalls + lamps
    for st in L.STALLS:
        a = math.radians(st["angle"])
        x, y = math.cos(a) * L.STALL_RADIUS, math.sin(a) * L.STALL_RADIUS
        if in_view(x, y):
            poly = rect_poly(x, y, 9, 7, st["angle"] - 90)
            c.add(f'<polygon points="{pts(c, poly)}" fill="{st["roof"]}" stroke="{INK}" stroke-width="1.5"/>')
    if any(in_view(math.cos(math.radians(st["angle"])) * L.STALL_RADIUS, 0) for st in L.STALLS):
        c.num("Market stalls (ring the square)", "#FFC93C")
    for x, y in L.LAMPS:
        if in_view(x, y):
            px, py = c.p(x, y)
            c.add(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="{max(2.5, 1.6*c.s):.1f}" fill="#FFE45C" stroke="{INK}" stroke-width="1"/>')
    # buildings
    for b in L.BUILDINGS:
        if not in_view(*b["center"]):
            continue
        w, d, _ = b["size"]
        poly = rect_poly(*b["center"], w, d, b["facing"])
        n = c.num(b["label"], b["roof"])
        c.add(f'<polygon points="{pts(c, poly)}" fill="{b["roof"]}" stroke="{INK}" stroke-width="2"/>')
        # front edge marker (door side) = the side at -d/2 in local coords rotated so 0 faces south
        fx, fy = rect_poly(*b["center"], w * 0.5, d, b["facing"])[0:2]
        c.add(f'<line x1="{c.p(*fx)[0]:.1f}" y1="{c.p(*fx)[1]:.1f}" x2="{c.p(*fy)[0]:.1f}" y2="{c.p(*fy)[1]:.1f}" stroke="#FFE45C" stroke-width="4"/>')
        marker(c, *b["center"], "#FFFFFF", n, 10)
    # tower
    t = L.TOWER
    if in_view(*t["center"]):
        px, py = c.p(*t["center"])
        n = c.num(t["label"], "#FF9A2E")
        c.add(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="{t["radius_base"]*c.s*1.4:.1f}" fill="#FF9A2E" fill-opacity="0.35"/>'
              f'<circle cx="{px:.1f}" cy="{py:.1f}" r="{t["radius_base"]*c.s:.1f}" fill="#8C4A35" stroke="{INK}" stroke-width="2"/>'
              f'<circle cx="{px:.1f}" cy="{py:.1f}" r="{t["radius_top"]*c.s*0.7:.1f}" fill="#8FE3FF" stroke="#FFFFFF" stroke-width="2"/>')
        marker(c, t["center"][0] + 16, t["center"][1] + 10, "#FF9A2E", n, 10)
    # stands
    for s in L.STANDS:
        if not in_view(*s["center"]):
            continue
        color = STAND_COLOR[s["kind"]]
        px, py = c.p(*s["center"])
        if s["kind"] in ("arena", "boss"):
            r = 15 * c.s
            octo = " ".join(f"{px + r*math.cos(math.pi/8 + i*math.tau/8):.1f},{py + r*math.sin(math.pi/8 + i*math.tau/8):.1f}" for i in range(8))
            if s["kind"] == "arena":
                c.add(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="{32*c.s:.1f}" fill="#D8CDB4" stroke="#9C8B6A" stroke-width="2"/>'
                      f'<circle cx="{px:.1f}" cy="{py:.1f}" r="{24*c.s:.1f}" fill="#E5DAC0" stroke="#9C8B6A" stroke-width="1.5"/>')
            c.add(f'<polygon points="{octo}" fill="{color}" stroke="{INK}" stroke-width="2"/>')
        else:
            poly = rect_poly(*s["center"], 22, 10, s["facing"])
            c.add(f'<polygon points="{pts(c, poly)}" fill="{color}" stroke="{INK}" stroke-width="1.5" fill-opacity="0.9"/>')
        n = c.num(s["label"], color)
        marker(c, s["center"][0], s["center"][1] - (20 if s["kind"] in ("arena", "boss") else 0), color, n, 10)
    # wild + platform labels
    for d in L.DISKS:
        if d["kind"] in ("wild", "platform") and in_view(*d["center"]) and d["id"] != "cullet_pit":
            n = c.num(d["label"], KIND_STYLE[d["kind"]][0])
            marker(c, *d["center"], KIND_STYLE[d["kind"]][0], n, 10)
    for d in L.DISKS:
        if d["id"] in ("square", "terrace") and in_view(*d["center"]):
            px, py = c.p(d["center"][0], d["center"][1] - d["radius"] + 8)
            if d["id"] == "terrace":
                px, py = c.p(d["center"][0] + 4, d["center"][1] - d["radius"] - 6)
            c.add(f'<text x="{px:.1f}" y="{py:.1f}" text-anchor="middle" font-size="13" font-weight="800" fill="{INK}" fill-opacity="0.7">{esc(d["label"].upper())}</text>')
    # points
    for pnt in L.POINTS:
        if not in_view(*pnt["pos"]) or pnt["id"] == "lift_top":
            continue
        color, _ = POINT_STYLE[pnt["kind"]]
        n = c.num(pnt["label"], color)
        marker(c, *pnt["pos"], color, n, 11 if pnt["kind"] == "spawn" else 10)
    # route arrows and lift line
    lt, lb = [p["pos"] for p in L.POINTS if p["id"] in ("lift", "lift_top")]
    if in_view(*lt):
        c.add(f'<line x1="{c.p(*lt)[0]:.1f}" y1="{c.p(*lt)[1]:.1f}" x2="{c.p(*lb)[0]:.1f}" y2="{c.p(*lb)[1]:.1f}" stroke="#4FA8FF" stroke-width="4" stroke-dasharray="6 5"/>')
    # sight line from spawn
    sp, tw = c.p(0, -150), c.p(*L.TOWER["center"])
    c.add(f'<line x1="{sp[0]:.1f}" y1="{sp[1]-14:.1f}" x2="{tw[0]:.1f}" y2="{tw[1]+18:.1f}" stroke="#FF9A2E" stroke-width="2" stroke-dasharray="3 7" stroke-opacity="0.8"/>')
    # sea / cliff labels
    for x, y, text, size in [(150, 210, "SEA — cliffs drop 60 studs", 15), (250, -40, "SEA", 18), (205, 205, "Harbor below", 13),
                             (60, -455, "Sunny Beach — Zone 2", 14), (-440, -200, "HILLS (map edge)", 14)]:
        if in_view(x, y):
            px, py = c.p(x, y)
            c.add(f'<text x="{px:.1f}" y="{py:.1f}" text-anchor="middle" font-size="{size}" font-weight="800" fill="{INK}" fill-opacity="0.55">{esc(text)}</text>')


def build(name, bounds, scale, title, subtitle):
    xmin, xmax, ymin, ymax = bounds
    c = Canvas(xmin, xmax, ymin, ymax, scale, title, subtitle)

    def in_view(x, y):
        return xmin <= x <= xmax and ymin <= y <= ymax

    draw(c, in_view)
    path = os.path.join(REPO, "docs", "art", name)
    with open(path, "w", encoding="utf-8") as f:
        f.write(c.svg())
    return path


if __name__ == "__main__":
    print(build("blueprint_lobby.svg", (-210, 230, -210, 230), 2.2, "Kilnport — Lobby", "Compact glassblower village on a sea cliff. 1 grid square = 20 studs."))
    print(build("blueprint_overview.svg", (-500, 260, -500, 240), 1.15, "Kilnport + Route 1", "Village (Z 0) and Cullet Yard terrace (Z -20). 1 grid square = 20 studs."))
