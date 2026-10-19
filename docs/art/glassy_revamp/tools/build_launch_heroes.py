"""Hero launch glassies (Roster V2 items 10-12), built by workstream C in the Blender MCP window:
Grizzly Guardian, Glass Unicorn, Glass Phoenix.

    R = "<repo>"
    __file__ = R + "/docs/art/launch_glassies/tools/build_launch.py"     # F's file locates the repo from this
    exec(open(__file__).read())                                          # F's packaging (build/validate/LAUNCH)
    exec(open(R + "/docs/art/glassy_revamp/tools/build_launch_heroes.py").read())
    build("grizzly_guardian"); validate("grizzly_guardian")

Loads workstream F's build_launch.py as a library (its CLI only runs as __main__), which itself loads
build_glassy_v4.py, and replaces LAUNCH_BUILDERS for the three hero ids. Output, manifest format,
release_geometry and checks are therefore identical to the other launch glassies
(assets/blender/glassies/<id>/v4/, collected by docs/art/launch_glassies/tools/collect_launch.py).
Uses the v4 bar: glass4 two-layer glass, face(), organic(), weighted normals, rig4 icons.
"""


# F's library defines its own face(); the heroes use the v4 shared face language (face4).
_v4ns = dict(globals())
exec(open(repo_path("docs", "art", "glassy_revamp", "tools", "build_glassy_v4.py"), encoding="utf-8").read(), _v4ns)
face4 = _v4ns["face"]


def gem_body(name, build, tris=240, fit=None, voxel=0.03, bevel=0.014):
    """Crystal-cut body: union -> voxel -> decimate to `tris` flat facets -> every edge bevelled
    (each facet edge catches a highlight). Closed, manifold, flat-shaded with weighted normals."""
    bm = bmesh.new()
    build(bm)
    tmp = _obj("_gem_src", bm)
    rm = tmp.modifiers.new("Remesh", "REMESH")
    rm.mode, rm.voxel_size = "VOXEL", voxel
    sm = tmp.modifiers.new("Smooth", "SMOOTH")
    sm.factor, sm.iterations = 0.5, 4
    dec = tmp.modifiers.new("Decimate", "DECIMATE")
    dg = bpy.context.evaluated_depsgraph_get()
    probe = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    dec.ratio = min(1.0, tris / max(1, sum(len(p.vertices) - 2 for p in probe.polygons)))
    bpy.data.meshes.remove(probe)
    dg = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bpy.data.objects.remove(tmp, do_unlink=True)
    obj = bpy.data.objects.new(name, mesh)
    _link(obj)
    bm = _bm_from_object(obj)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    if fit:
        lo, hi = Vector(fit[0]), Vector(fit[1])
        xs = [v.co for v in bm.verts]
        a = Vector((min(p.x for p in xs), min(p.y for p in xs), min(p.z for p in xs)))
        b = Vector((max(p.x for p in xs), max(p.y for p in xs), max(p.z for p in xs)))
        for v in bm.verts:
            v.co = Vector(tuple(lo[k] + (v.co[k] - a[k]) * (hi[k] - lo[k]) / (b[k] - a[k]) for k in range(3)))
    # Merge near-coplanar neighbours into bigger gem facets before bevelling.
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(7), verts=bm.verts, edges=bm.edges)
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect="EDGES", profile=0.5, clamp_overlap=True)
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method="BEAUTY", ngon_method="BEAUTY")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bad = [e for e in bm.edges if not e.is_manifold]
    if bad:
        raise AssertionError((name, "gem body not closed", len(bad)))
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.name = name
    obj["source_name"] = name
    set_shading(obj, True)
    obj.data.set_sharp_from_angle(angle=math.radians(25))
    mod = obj.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
    mod.mode, mod.weight, mod.keep_sharp = "FACE_AREA", 50, True
    return obj


_glass4_base = glass4


def glass4(obj, color, layer="shell", role="Detail"):
    """Adds a 'frost' layer (frosted crystal: low transmission, near-white) for crystal plates."""
    if layer != "frost":
        return _glass4_base(obj, color, layer, role)
    _glass4_base(obj, color, "detail", role)
    node = next(n for n in obj.data.materials[0].node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    _set_input(node, "Transmission Weight", 0.25)
    _set_input(node, "Base Color", (0.95, 0.98, 1.0, 1))
    obj["glass_layer"] = "frost"
    return obj


def inner_layer(*objs):
    """F's finish_v4 keeps the clear-shell look only when inner parts are tagged."""
    for o in objs:
        o["glass_layer"] = "inner"
    return objs


def gem_detail(name, obj, offset=0.01):
    """Bevel a faceted detail's hard edges the same way as the gem body."""
    bevel_edges(obj, offset, 1, 20)
    return obj


@launch("grizzly_guardian")
def h_grizzly_guardian(gid):
    tint, amber, ice, cream, dark, gold = "#FFC96B", "#E8962A", "#EAF6FF", "#FFE6B8", "#3A2618", "#FFE08A"
    head = Vector((0, -0.12, -0.62))
    lo, hi = Vector((-1.0, -0.98, -2.6)), Vector((1.0, 0.86, -0.14))

    def shape(bm):
        ellipsoid_bm(bm, head, (0.56, 0.5, 0.48), 20, 12)
        ellipsoid_bm(bm, (0, -0.02, -1.12), (0.6, 0.5, 0.32), 16, 10)
        ellipsoid_bm(bm, (0, 0.04, -1.64), (0.92, 0.8, 0.82), 24, 14)
        for s in (-1, 1):
            ellipsoid_bm(bm, (s * 0.76, -0.24, -1.52), (0.24, 0.26, 0.46), 12, 8, Quaternion((0, 1, 0), s * 0.3))
            ellipsoid_bm(bm, (s * 0.6, -0.5, -1.95), (0.23, 0.24, 0.21), 10, 7)
            ellipsoid_bm(bm, (s * 0.5, -0.5, -2.34), (0.3, 0.45, 0.27), 12, 8)
        ellipsoid_bm(bm, (0, 0.8, -2.2), (0.16, 0.14, 0.14), 8, 6)
    body = gem_body("Body", shape, 250, fit=(lo, hi))
    glass4(body, tint, "shell", role="Body")
    ds = []
    inner = blob("InnerAmber", (0, 0.02, -1.6), (0.7, 0.6, 0.66), 8, 5)
    glass4(inner, amber, "inner")
    head_in = blob("InnerAmberHead", head + Vector((0, 0.04, 0)), (0.4, 0.36, 0.34), 8, 5)
    glass4(head_in, amber, "inner")
    core = paint(blob("HeartCore", (0, -0.2, -1.5), (0.17, 0.15, 0.19), 10, 6), "#FFC24A", "Neon")
    anim(core, (0, -0.2, -1.5), (0, 0, 1), pulse(0.07, 3.0), flash(0.25), lod_keep=False, note="guardian heart: brightens with each received clash, flares at Ready")
    inner_layer(inner, head_in)
    ds += [inner, head_in, core]
    mp, mn = surface_point(body, 0, head.z - 0.14)
    muzzle = smooth_normals(blob("Muzzle", mp + mn * 0.06, (0.26, 0.17, 0.18), 10, 6))
    glass4(muzzle, cream, "detail")
    np_, nn = surface_point(muzzle, 0, mp.z + 0.05)
    nose = paint(smooth_normals(blob("Nose", np_ + nn * 0.02, (0.1, 0.07, 0.07), 10, 6)), dark, "SmoothPlastic")
    ds += [muzzle, nose]
    ds += face4(body, [(-0.22, head.z + 0.08), (0.22, head.z + 0.08)], (0.085, 0.11), cheeks=True, cheek_target=muzzle,
               smile=(0, mp.z - 0.1, 0.07), eye_segs=(8, 5))
    eyes = next(d for d in ds if d.name == "Eyes")
    m = json.loads(eyes["motion_json"])
    m["note"] = "eyes glow gold (#FFE08A Neon) at Ready"
    eyes["motion_json"] = json.dumps(m)
    for s, label in ((-1, "L"), (1, "R")):
        ep = Vector((s * 0.4, -0.02, head.z + 0.38))
        eb = bmesh.new()
        ellipsoid_bm(eb, ep, (0.17, 0.1, 0.16), 8, 5, Quaternion((0, 1, 0), s * 0.35))
        ellipsoid_bm(eb, ep + Vector((0, -0.05, -0.01)), (0.1, 0.05, 0.09), 6, 4, Quaternion((0, 1, 0), s * 0.35))
        ear = glass4(smooth_normals(_obj("Ear_" + label, eb)), tint, "detail")
        anim(ear, ep + Vector((0, 0, -0.1)), (0, 0, 1), sway(10, 3.2, 0.8 if s > 0 else 0.0), kick(18), lod_keep=(s < 0),
             note="ears swivel (idle) and flick back on a hit")
        ds.append(ear)
    pb = bmesh.new()
    for k, (x, z, r) in enumerate(((0, -1.4, 0.26), (-0.3, -1.66, 0.22), (0.3, -1.66, 0.22), (0, -1.92, 0.2))):
        p, n = surface_point(body, x, z)
        q = n.to_track_quat("-Y", "Z").to_matrix().to_4x4()
        gem_bm(pb, (0, 0, 0), r, 0.08, 6, Matrix.Translation(p + n * 0.02) @ q @ Matrix.Rotation(math.pi / 2, 4, "X"))
    plates = glass4(gem_detail("ChestPlates", _obj("ChestPlates", pb, smooth=False), 0.008), ice, "frost")
    anim(plates, (0, -0.6, -1.66), (0, 1, 0), pulse(0.03, 3.0), flash(0.25), lod_keep=True,
         note="breathing chest; at Ready the plates fold across the chest as the crystal guard and light up")
    ds.append(plates)
    cb = bmesh.new()
    for s in (-1, 1):
        for k in (-1, 0, 1):
            base, fwd = Vector((s * 0.5 + k * 0.1, -0.94, -2.42)), Vector((0, -0.12, 0.02))
            tube_bm(cb, [base, base + fwd * 0.6, base + fwd], [0.032, 0.02, 0.004], 4)
    claws = glass4(_obj("Claws", cb), ice, "detail")
    ds.append(claws)
    rb = bmesh.new()
    torus_bm(rb, (0, 0.12, -0.08), 0.11, 0.035, 12, 4, Matrix.Rotation(math.pi / 2, 4, "X"))
    ring = paint(smooth_normals(_obj("HangRing", rb)), gold, "Metal")
    bg = bmesh.new()
    p, n = surface_point(body, 0, head.z + 0.32)
    gem_bm(bg, (0, 0, 0), 0.07, 0.12, 6, Matrix.Translation(p + n * 0.01) @ n.to_track_quat("-Y", "Z").to_matrix().to_4x4() @ Matrix.Rotation(math.pi / 2, 4, "X"))
    brow = paint(_obj("BrowGem", bg, smooth=False), "#FFE08A", "Neon")
    anim(brow, p, (0, 1, 0), pulse(0.1, 3.0, 0.5), flash(0.3))
    sp = bubbles("Sparkles", (0, 0, -1.7), 0.55, 5, (0.03, 0.05), seed=51, color="#FFF6D6", neon=True, height=0.5)
    anim(sp, (0, 0, -1.7), (0, 0, 1), spin(12), spin_boost(160))
    ds += [ring, brow, sp]
    return body, ds
