"""Glass Clash map layout: Kilnport (glassblower village) + Route 1 Cullet Yard.

Single source of truth for the map blueprint. Used by:
  - tools/map/make_blueprints.py   -> docs/art/blueprint_*.svg (labelled top-down plans)
  - tools/blender/blockout_village.py -> grey-box blockout in Blender at stud scale

Coordinates are studs. X = east, Y = north, Z = up (Blender axes).
In Roblox: X = X, Roblox Z = -Y, Roblox Y = Z.
Ground levels: village plateau Z = 0, Cullet Yard terrace Z = -20, beach Z = -56, sea Z = -60.
See docs/art/MAP_BLUEPRINT.md for the design reasoning.
"""

import math

VILLAGE_Z = 0
YARD_Z = -20
SEA_Z = -60

# Land masses (polygons, clockwise from south-west). Edges facing the sea are cliffs.
LAND = [
    {
        "id": "plateau",
        "label": "Kilnport plateau (Z 0)",
        "top": VILLAGE_Z,
        "bottom": SEA_Z,
        "color": "#E8D9B5",
        "points": [(-190, -190), (-195, 60), (-150, 140), (-60, 188), (60, 188), (140, 168),
                   (180, 100), (182, -60), (150, -150), (90, -195)],
    },
    {
        "id": "yard_terrace",
        "label": "Cullet Yard terrace (Z -20)",
        "top": YARD_Z,
        "bottom": SEA_Z,
        "color": "#C9C2A8",
        "points": [(-150, -395), (-300, -405), (-460, -365), (-490, -150), (-485, 60), (-425, 165),
                   (-300, 180), (-205, 150), (-195, 60), (-190, -190), (90, -195), (160, -300),
                   (140, -390), (20, -400)],
    },
    {
        "id": "beach",
        "label": "Sunny Beach (Zone 2, locked)",
        "top": SEA_Z + 4,
        "bottom": SEA_Z,
        "color": "#F2DFA6",
        "points": [(-120, -470), (-140, -400), (140, -390), (200, -430), (220, -480)],
    },
]

# Walkable paths: polylines with a width. z is the surface height.
PATHS = [
    {"id": "main_street", "label": "Main Street", "z": VILLAGE_Z, "width": 26,
     "points": [(0, -150), (0, -72)]},
    {"id": "west_lane", "label": "West Lane", "z": VILLAGE_Z, "width": 20,
     "points": [(-70, -28), (-120, -40), (-170, -40)]},
    {"id": "terrace_walk", "label": "Seaview Walk", "z": VILLAGE_Z, "width": 18,
     "points": [(72, -20), (110, -10), (125, 20)]},
    {"id": "furnace_walk", "label": "Furnace Walk", "z": VILLAGE_Z, "width": 22,
     "points": [(0, 72), (0, 100)]},
    {"id": "harbor_lane", "label": "Harbor Lane", "z": VILLAGE_Z, "width": 14,
     "points": [(50, 60), (110, 110), (150, 148)]},
    # Route 1: gate -> Rusty. Starts on the plateau and ramps down to the terrace.
    {"id": "route1", "label": "Route 1", "z": YARD_Z, "width": 20,
     "points": [(-175, -40), (-215, -40), (-262, -45), (-318, -82), (-335, -140), (-332, -205),
                (-300, -262), (-245, -300), (-178, -318), (-110, -322), (-48, -318), (8, -326)]},
    {"id": "lift_path", "label": "Lift path", "z": YARD_Z, "width": 14,
     "points": [(42, -310), (72, -268)]},
]

# Flat round areas (plazas, platforms, wild-spawn zones). kind controls colour + Blender look.
DISKS = [
    {"id": "square", "label": "Village Square", "kind": "plaza", "center": (0, 0), "radius": 74, "z": VILLAGE_Z},
    {"id": "spawn", "label": "Arrival Steps (spawn)", "kind": "plaza", "center": (0, -150), "radius": 24, "z": VILLAGE_Z},
    {"id": "terrace", "label": "Seaview Terrace", "kind": "plaza", "center": (132, 15), "radius": 46, "z": VILLAGE_Z},
    {"id": "wild_a", "label": "Wild A: Bottle Meadow", "kind": "wild", "center": (-338, -95), "radius": 34, "z": YARD_Z},
    {"id": "wild_b", "label": "Wild B: Crate Stacks", "kind": "wild", "center": (-205, -345), "radius": 30, "z": YARD_Z},
    {"id": "cullet_pit", "label": "The Cullet Pit (Rusty)", "kind": "platform", "center": (45, -335), "radius": 34, "z": YARD_Z + 2},
]

# Buildings: centre, footprint (w along facing-right, d along facing), wall height, facing (deg,
# 0 = front faces south toward the square/spawn, 90 = faces west, -90 = faces east).
BUILDINGS = [
    {"id": "furnace", "label": "The Great Furnace", "center": (0, 125), "size": (62, 38, 30), "facing": 0,
     "wall": "#B5654A", "roof": "#6E3B2E", "role": "Landmark. Glowing mouth faces the square. Leaderboards on the facade. Kiln (evolutions) inside later."},
    {"id": "bazaar", "label": "Bottle Bazaar (crates)", "center": (-102, 18), "size": (30, 22, 16), "facing": -90,
     "wall": "#E7C9A0", "roof": "#C2553D", "role": "Crate shop with odds board."},
    {"id": "studio", "label": "Sparkle Studio (Shatter FX & Fills)", "center": (68, 92), "size": (28, 20, 15), "facing": 30,
     "wall": "#E7C9A0", "roof": "#3F6FB5", "role": "Cosmetics shop with a test stand outside."},
    {"id": "repair", "label": "Glue & Glaze (Repair Bench)", "center": (-62, 92), "size": (18, 14, 10), "facing": -30,
     "wall": "#E7C9A0", "roof": "#3FA874", "role": "Free repair, reverse-shatter animation."},
    {"id": "notice", "label": "Notice Board (quests, daily, codes)", "center": (-46, -112), "size": (14, 6, 10), "facing": -60,
     "wall": "#D9A066", "roof": "#8C5A2B", "role": "Quests, daily rewards, codes."},
    {"id": "starter_hall", "label": "Starter Hall", "center": (48, -112), "size": (22, 16, 13), "facing": 60,
     "wall": "#E7C9A0", "roof": "#7A5CFF", "role": "New players pick Pop, Jam or Prism here (M2)."},
    {"id": "house_1", "label": "Cottage", "center": (-120, -100), "size": (18, 16, 12), "facing": -45, "wall": "#EADBC0", "roof": "#C2553D", "role": "Decor"},
    {"id": "house_2", "label": "Cottage", "center": (-140, 70), "size": (20, 16, 13), "facing": -100, "wall": "#EADBC0", "roof": "#3F6FB5", "role": "Decor"},
    {"id": "house_3", "label": "Cottage", "center": (-95, 140), "size": (18, 14, 12), "facing": -150, "wall": "#EADBC0", "roof": "#C2553D", "role": "Decor"},
    {"id": "house_4", "label": "Workshop", "center": (115, -105), "size": (20, 16, 12), "facing": 45, "wall": "#EADBC0", "roof": "#3FA874", "role": "Decor (glassblower at work)"},
    {"id": "house_5", "label": "Cottage", "center": (-75, -150), "size": (16, 14, 11), "facing": -20, "wall": "#EADBC0", "roof": "#3F6FB5", "role": "Decor"},
    {"id": "house_6", "label": "Cottage", "center": (85, -150), "size": (16, 14, 11), "facing": 20, "wall": "#EADBC0", "roof": "#C2553D", "role": "Decor"},
    {"id": "hut", "label": "Halfway Hut (repair)", "center": (-272, -300), "size": (14, 12, 9), "facing": 60, "wall": "#D9A066", "roof": "#3FA874", "role": "Repair Bench on Route 1."},
    {"id": "crusher", "label": "The Crusher", "center": (100, -318), "size": (24, 18, 20), "facing": 90, "wall": "#7A8396", "roof": "#4A4F6B", "role": "Zone 1 landmark machine. Feeds cullet to the conveyor."},
]

# Glass furnace tower (the landmark): base centre, radii, height, glass bottle on top.
TOWER = {"id": "tower", "label": "Furnace Tower (130 studs + glass bottle)", "center": (0, 132),
         "radius_base": 12, "radius_top": 8.5, "height": 130, "bottle_height": 30}

# Clash Stands: centre, facing (deg). Arena uses the octagon pen; others are standard stands.
STANDS = [
    {"id": "arena", "label": "Octagon Arena (tournaments)", "center": (0, 0), "facing": 0, "kind": "arena"},
    {"id": "pvp_1", "label": "PvP stand", "center": (128, -18), "facing": 90, "kind": "pvp"},
    {"id": "pvp_2", "label": "PvP stand", "center": (148, 8), "facing": 90, "kind": "pvp"},
    {"id": "pvp_3", "label": "PvP stand", "center": (148, 38), "facing": 90, "kind": "pvp"},
    {"id": "pvp_4", "label": "PvP stand", "center": (128, 58), "facing": 90, "kind": "pvp"},
    {"id": "fx_test", "label": "FX test stand", "center": (52, 66), "facing": 30, "kind": "small"},
    {"id": "t_kevin", "label": "Kevin (Lv 2)", "center": (-240, -20), "facing": 0, "kind": "trainer"},
    {"id": "t_sam", "label": "Sam (Lv 4)", "center": (-362, -170), "facing": -90, "kind": "trainer"},
    {"id": "t_cora", "label": "Cora (Lv 5)", "center": (-300, -228), "facing": 45, "kind": "trainer"},
    {"id": "t_jo", "label": "Jo (Lv 7)", "center": (-140, -298), "facing": 180, "kind": "trainer"},
    {"id": "t_bo", "label": "Bo (Lv 9)", "center": (-60, -345), "facing": 0, "kind": "trainer"},
    {"id": "t_rusty", "label": "Rusty, Shelf Champion (Lv 14)", "center": (45, -335), "facing": 0, "kind": "boss"},
]

# Single points of interest.
POINTS = [
    {"id": "spawn_point", "label": "SPAWN (faces north)", "pos": (0, -150), "kind": "spawn"},
    {"id": "pedestal", "label": "Champion Pedestal (off-axis, never blocks the arena)", "pos": (30, -84), "kind": "pedestal"},
    {"id": "bracket", "label": "Bracket Board (on the furnace facade, above the mouth)", "pos": (0, 104), "kind": "board"},
    {"id": "leaders", "label": "Leaderboards (flank the square entrance)", "pos": (-30, -84), "kind": "board_small"},
    {"id": "kiln_gate", "label": "Kiln Gate -> Route 1", "pos": (-175, -40), "kind": "gate"},
    {"id": "harbor_gate", "label": "Harbor Stairs (boats to later zones, locked)", "pos": (152, 150), "kind": "gate_locked"},
    {"id": "beach_gate", "label": "Beach Gate -> Zone 2 (badge)", "pos": (95, -385), "kind": "gate_locked"},
    {"id": "lift", "label": "Cullet Lift (shortcut home)", "pos": (75, -262), "kind": "lift"},
    {"id": "lift_top", "label": "Lift top", "pos": (75, -200), "kind": "lift"},
]

# Decorative scatter: (centre, radius, count, kind). Trees and hills frame every edge that
# isn't a cliff, so the world feels enclosed rather than a slab in the void.
SCATTER = [
    {"center": (-165, -165), "radius": 22, "count": 7, "kind": "pine", "z": VILLAGE_Z},
    {"center": (-170, 110), "radius": 30, "count": 9, "kind": "pine", "z": VILLAGE_Z},
    {"center": (-110, 175), "radius": 24, "count": 6, "kind": "round", "z": VILLAGE_Z},
    {"center": (120, -170), "radius": 22, "count": 6, "kind": "round", "z": VILLAGE_Z},
    {"center": (-60, -175), "radius": 18, "count": 5, "kind": "round", "z": VILLAGE_Z},
    {"center": (-260, 5), "radius": 30, "count": 9, "kind": "pine", "z": YARD_Z},
    {"center": (-375, -40), "radius": 25, "count": 8, "kind": "pine", "z": YARD_Z},
    {"center": (-380, -300), "radius": 25, "count": 8, "kind": "pine", "z": YARD_Z},
    {"center": (-250, -230), "radius": 30, "count": 8, "kind": "round", "z": YARD_Z},
    {"center": (-120, -250), "radius": 35, "count": 10, "kind": "round", "z": YARD_Z},
    {"center": (-10, -250), "radius": 25, "count": 6, "kind": "pine", "z": YARD_Z},
    {"center": (-160, -385), "radius": 20, "count": 5, "kind": "pine", "z": YARD_Z},
    # Cullet mountains: piles of crushed coloured glass around Rusty's pit
    {"center": (45, -335), "radius": 62, "count": 16, "kind": "cullet", "z": YARD_Z,
     "clear_inside": 38, "clear_angles": [(140, 215), (25, 95)]},  # entrance (west) and lift (north-east) stay open
    # Sorting Lane props: colour-sorted bins along the path
    {"center": (-345, -200), "radius": 20, "count": 8, "kind": "bin", "z": YARD_Z},
    {"center": (-200, -300), "radius": 16, "count": 6, "kind": "crate", "z": YARD_Z},
]

# Market stalls around the square edge (angle in degrees, 0 = east, counter-clockwise), radius 62.
# They fill the gaps between the four entrances so the big square never feels empty.
STALLS = [
    {"angle": 35, "roof": "#C2553D"}, {"angle": 58, "roof": "#3F6FB5"}, {"angle": 122, "roof": "#3FA874"},
    {"angle": 145, "roof": "#FFC93C"}, {"angle": 225, "roof": "#3F6FB5"}, {"angle": 245, "roof": "#C2553D"},
    {"angle": 295, "roof": "#3FA874"}, {"angle": 318, "roof": "#FFC93C"},
]
STALL_RADIUS = 62

# Lamp posts with glowing glass globes (warm light at golden hour).
LAMPS = [(x, y) for y in (-132, -112) for x in (-17, 17)] + [
    (round(66 * math.cos(math.radians(a)), 1), round(66 * math.sin(math.radians(a)), 1)) for a in (10, 80, 100, 170, 190, 260, 280, 350)
] + [(-150, -30), (-150, -52), (14, 85), (-14, 85)]

def scatter_allowed(entry, x, y):
    """False if a scattered prop would land in a keep-clear zone of its scatter entry."""
    cx, cy = entry["center"]
    dx, dy = x - cx, y - cy
    if math.hypot(dx, dy) < entry.get("clear_inside", 0):
        return False
    ang = math.degrees(math.atan2(dy, dx)) % 360
    return not any(lo <= ang <= hi for lo, hi in entry.get("clear_angles", []))


# Big hills behind the yard (outer boundary). (x, y, radius, height)
HILLS = [(-440, 60, 70, 70), (-450, -120, 80, 90), (-440, -300, 75, 80), (-330, -440, 70, 60),
         (-250, 90, 60, 55), (-300, 120, 55, 65)]

# Harbour props below the north-east cliff (sea level): docks and boats.
HARBOR = {"center": (195, 175), "dock_length": 60}

LIGHTING = {
    "ClockTime": 16.6,
    "GeographicLatitude": 35,
    "note": "Sun from the west-south-west: the furnace is side-lit from spawn, glass glints toward the camera, the sea catches warm light.",
}
