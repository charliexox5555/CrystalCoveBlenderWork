"""Glassy revamp v4: the higher quality bar (smooth glass, depth, faces, hero detail).

    R = "<repo>"
    exec(open(R + "/tools/blender/glassclash_blender.py").read()); set_repo(R)
    exec(open(R + "/docs/art/glassy_revamp/tools/build_glassy_v4.py").read())
    build_v4("glass_dragon"); validate_v4("glass_dragon")

Loads build_glassy_v3.py unchanged (its primitives, motion tags and manifest format stay the
shared contract) and adds:
- round_profile(): small radius on every rim/corner of a lathe profile (real highlights).
- smooth_normals(): weighted normals (exported in the FBX) so bodies read as one smooth glass.
- organic(): union -> voxel -> Quadriflow quads -> one clean, evenly smooth closed body.
- face(): the shared face language (tall eyes, two highlights, cheeks, optional smile),
  placed by ray-casting onto the head so it sits on any surface.
- rig4(): the release icon camera and key/rim/fill plus a soft sky and two reflection cards,
  so glass shows proper gloss in icons. Use it for every v4 icon.
Writes only assets/blender/glassies/<id>/v4/ and docs/art/glassy_revamp/previews/*_v4_*.png.
"""
from mathutils.bvhtree import BVHTree

exec(open(repo_path("docs", "art", "glassy_revamp", "tools", "build_glassy_v3.py"), encoding="utf-8").read())

V4 = "v4"
BUILDERS4 = {}
FACE_DARK, FACE_SHINE, FACE_BLUSH = "#1B2440", "#FFFFFF", "#FF8FB0"


def builder4(gid):
    def wrap(fn):
        BUILDERS4[gid] = fn
        return fn
    return wrap


def v4_folder(gid):
    return repo_path("assets", "blender", "glassies", gid, V4)


# ------------------------------------------------------------------------------------------
# Shape quality
# ------------------------------------------------------------------------------------------

def round_profile(points, r=0.035, steps=2, min_deg=18, keep=()):
    """Replaces every interior corner sharper than min_deg with a small arc of radius ~r."""
    out = [points[0]]
    for i in range(1, len(points) - 1):
        p, a, b = Vector(points[i]), Vector(points[i - 1]), Vector(points[i + 1])
        if i in keep or p.x <= 1e-6:
            out.append(points[i])
            continue
        da, db = (p - a), (b - p)
        if da.length < 1e-6 or db.length < 1e-6 or math.degrees(da.angle(db)) < min_deg:
            out.append(points[i])
            continue
        d = min(r, da.length * 0.45, db.length * 0.45)
        p0, p2 = p - da.normalized() * d, p + db.normalized() * d
        for s in range(steps + 1):
            t = s / steps
            q = p0 * (1 - t) ** 2 + p * 2 * t * (1 - t) + p2 * t * t
            out.append((q.x, q.y))
    out.append(points[-1])
    return out


def smooth_normals(obj, sharp_deg=None, weight=50):
    """Smooth shading + weighted normals (applied on FBX export). Optional sharp-by-angle first."""
    set_shading(obj, True)
    if sharp_deg:
        obj.data.set_sharp_from_angle(angle=math.radians(sharp_deg))
    mod = obj.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
    mod.mode, mod.weight, mod.keep_sharp = "FACE_AREA", weight, True
    return obj


def body_lathe(name, profile, h, segments=32, r=0.035, sharp_deg=None, flat=False, steps=2):
    prof = round_profile(profile, r, steps) if r else profile
    obj = lathe3(name, prof, h, segments, sharp_deg=None, flat=flat)
    return smooth_normals(obj, sharp_deg if not flat else 1)


def organic(name, build, target_faces=600, fit=None, voxel=0.03, max_tris=None):
    """Overlapping volumes -> voxel union -> Quadriflow (even quads, mirror X) -> triangles."""
    bm = bmesh.new()
    build(bm)
    tmp = _obj("_organic_src", bm)
    rm = tmp.modifiers.new("Remesh", "REMESH")
    rm.mode, rm.voxel_size = "VOXEL", voxel
    sm = tmp.modifiers.new("Smooth", "SMOOTH")
    sm.factor, sm.iterations = 0.5, 3
    dg = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bpy.data.objects.remove(tmp, do_unlink=True)
    obj = bpy.data.objects.new(name, mesh)
    _link(obj)
    mesh.use_mirror_x = True
    vl = bpy.context.scene.view_layers[0]
    for o in list(vl.objects):
        if o is not None and o != obj:
            o.select_set(False, view_layer=vl)
    obj.select_set(True, view_layer=vl)
    vl.objects.active = obj
    with bpy.context.temp_override(active_object=obj, object=obj, selected_objects=[obj], selected_editable_objects=[obj]):
        bpy.ops.object.quadriflow_remesh(target_faces=target_faces, use_mesh_symmetry=True, use_preserve_sharp=False,
                                         use_preserve_boundary=False, preserve_attributes=False, smooth_normals=False, seed=7)
    obj.select_set(False, view_layer=vl)
    bm = _bm_from_object(obj)
    holes = [e for e in bm.edges if e.is_boundary]
    if holes:
        bmesh.ops.holes_fill(bm, edges=holes, sides=0)
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method="BEAUTY")
    if max_tris and len(bm.faces) > max_tris:
        # Quadriflow's face count varies run to run; collapse down to a hard cap.
        bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=1e-6)
        bm.to_mesh(obj.data)
        bm.free()
        dec = obj.modifiers.new("Cap", "DECIMATE")
        dec.ratio = max_tris / len(obj.data.polygons)
        dg = bpy.context.evaluated_depsgraph_get()
        capped = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
        obj.modifiers.clear()
        old = obj.data
        obj.data = capped
        bpy.data.meshes.remove(old)
        bm = _bm_from_object(obj)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bad = [e for e in bm.edges if not e.is_manifold]
    if bad:
        raise AssertionError((name, "organic body not closed", len(bad)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if fit:
        lo, hi = Vector(fit[0]), Vector(fit[1])
        xs = [v.co for v in bm.verts]
        a = Vector((min(p.x for p in xs), min(p.y for p in xs), min(p.z for p in xs)))
        b = Vector((max(p.x for p in xs), max(p.y for p in xs), max(p.z for p in xs)))
        for v in bm.verts:
            v.co = Vector(tuple(lo[k] + (v.co[k] - a[k]) * (hi[k] - lo[k]) / (b[k] - a[k]) for k in range(3)))
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.name = name
    obj["source_name"] = name
    return smooth_normals(obj)


def surface_point(obj, x, z, from_y=-6.0, direction=(0, 1, 0)):
    """Ray-cast onto obj from the front: returns (point, normal) or None."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = ev.to_mesh()
    tree = BVHTree.FromPolygons([v.co.copy() for v in me.vertices], [list(p.vertices) for p in me.polygons])
    ev.to_mesh_clear()
    hit = tree.ray_cast(Vector((x, from_y, z)), Vector(direction))
    if hit[0] is None:
        return None
    n = hit[1].normalized()
    if n.dot(Vector(direction)) > 0:
        n = -n
    return hit[0], n


def face(target, eyes, eye_size=(0.1, 0.13), cheeks=True, smile=None, prefix="", cheek_target=None, eye_segs=(10, 6)):
    """Shared face language. eyes = [(x, z), (x, z)] on `target` seen from the front.
    Eyes: tall dark ovals, slightly embedded. Shine: big dot upper-left + small dot lower-right
    (same light direction on every glassy). Cheeks: soft blush below-outside. Smile: optional
    (x, z, width) small curved mouth. Returns detail objects with blink motion on eyes/shine."""
    sx, sz = eye_size
    eb, sb, cb = bmesh.new(), bmesh.new(), bmesh.new()
    centre = Vector((0, 0, 0))
    for x, z in eyes:
        p, n = surface_point(target, x, z)
        q = n.to_track_quat("-Y", "Z")
        c = p - n * sx * 0.25
        centre += c / len(eyes)
        ellipsoid_bm(eb, c, (sx, sx * 0.5, sz), *eye_segs, q)
        m = q.to_matrix()
        for (u, w, r) in ((-0.36, 0.38, 0.34), (0.32, -0.34, 0.16)):
            ellipsoid_bm(sb, c + m @ Vector((u * sx, -sx * 0.42, w * sz)), (r * sx, r * sx * 0.45, r * sx), 5, 3, q)
        if cheeks:
            side = 1 if x > 0 else -1
            hit = surface_point(cheek_target or target, x + side * sx * 1.2, z - sz * 1.25) or surface_point(target, x + side * sx * 1.2, z - sz * 1.25)
            if hit:
                cp, cn = hit
                ellipsoid_bm(cb, cp - cn * 0.01, (sx * 0.95, sx * 0.22, sx * 0.55), 6, 3, cn.to_track_quat("-Y", "Z"))
    out = []
    e = paint(_obj(prefix + "Eyes", eb), FACE_DARK, "SmoothPlastic")
    anim(e, centre, (0, 0, 1), blink(3.6, 0.12))
    s = paint(_obj(prefix + "EyeShine", sb), FACE_SHINE, "SmoothPlastic")
    anim(s, centre, (0, 0, 1), blink(3.6, 0.12), note="blinks with Eyes")
    out += [e, s]
    if cheeks:
        c = paint(_obj(prefix + "Cheeks", cb), FACE_BLUSH, "SmoothPlastic")
        c["studio_transparency"] = 0.35
        out.append(c)
    if smile:
        x0, z0, w = smile
        pts = []
        for k in range(7):
            t = -1 + 2 * k / 6
            hit = surface_point(target, x0 + t * w, z0 - (1 - t * t) * w * 0.35)
            if hit:
                pts.append(hit[0] - hit[1] * 0.005)
        mb = bmesh.new()
        tube_bm(mb, pts, [0.018 + 0.006 * (1 - abs(-1 + 2 * k / 6)) for k in range(len(pts))], 5)
        out.append(paint(_obj(prefix + "Mouth", mb), FACE_DARK, "SmoothPlastic"))
    return out


def bubbles(name, centre, radius, count, size=(0.03, 0.07), seed=1, color="#EAFBFF", height=None, neon=False, segs=(6, 4)):
    """Floating bubbles (or Neon sparkles) inside a volume; one mesh."""
    rng = random.Random(seed)
    bm = bmesh.new()
    c = Vector(centre)
    for _ in range(count):
        while True:
            p = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)))
            if p.length < 1:
                break
        if height:
            p.z *= height / radius
        r = rng.uniform(*size)
        if neon:
            gem_bm(bm, c + p * radius, r, r * 2.2, 4)
        else:
            ellipsoid_bm(bm, c + p * radius, (r, r, r), *segs)
    o = _obj(name, bm, smooth=not neon)
    return paint(o, color, "Neon" if neon else "Glass")


def rcut4(bm, co, no, inner):
    """rcut (triangle fill of the cut) with a per-loop fallback when triangle fill leaves holes."""
    piece = rcut(bm, co, no, inner)
    if all(e.is_manifold for e in piece.edges):
        return piece
    piece.free()
    piece = bm.copy()
    bmesh.ops.bisect_plane(piece, geom=piece.verts[:] + piece.edges[:] + piece.faces[:], plane_co=co, plane_no=no, clear_outer=inner, clear_inner=not inner)
    edges = [e for e in piece.edges if e.is_boundary]
    if edges:
        res = bmesh.ops.holes_fill(piece, edges=edges, sides=0)
        bmesh.ops.triangulate(piece, faces=res["faces"])
    wires = [e for e in piece.edges if not e.link_faces]
    if wires:
        bmesh.ops.delete(piece, geom=wires, context="EDGES")
    bmesh.ops.recalc_face_normals(piece, faces=piece.faces)
    return piece


# ------------------------------------------------------------------------------------------
# Preview materials: two-layer glass reads as a clear shell around a tinted inside
# ------------------------------------------------------------------------------------------

def neon_material(color):
    """v4 Neon preview: brighter than v3 so emissive cores read through two glass layers."""
    mat = bpy.data.materials.get("V4Neon_" + color) or bpy.data.materials.new("V4Neon_" + color)
    mat.use_nodes = True
    node = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    rgb = hex_to_rgb(color)
    _set_input(node, "Base Color", (*rgb, 1))
    _set_input(node, ["Emission Color", "Emission"], (*rgb, 1))
    _set_input(node, "Emission Strength", 3.0)
    _set_input(node, "Roughness", 0.3)
    return mat


def glass4(obj, color, layer="shell", role="Detail"):
    """layer: 'shell' (clear, light tint, glossy), 'inner' (saturated tinted volume), 'detail'."""
    rmaterial(obj, color, "Glass", role)
    mat = obj.data.materials[0].copy()
    mat.name = "V4_%s_%s_%s" % (layer, color, obj.name)
    obj.data.materials[0] = mat
    node = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    rgb = hex_to_rgb(color)
    if layer == "shell":
        light = tuple(c * 0.7 + 0.3 for c in rgb)
        _set_input(node, "Base Color", (*light, 1))
        _set_input(node, "Transmission Weight", 0.92)
        _set_input(node, "Roughness", 0.05)
        _set_input(node, "IOR", 1.22)
        _set_input(node, ["Coat Weight", "Clearcoat"], 1.0)
        _set_input(node, ["Coat Roughness", "Clearcoat Roughness"], 0.02)
        _set_input(node, "Alpha", 0.8)
        obj["studio_transparency"] = 0.38
    elif layer == "inner":
        _set_input(node, "Transmission Weight", 0.5)
        _set_input(node, "Roughness", 0.15)
        _set_input(node, "IOR", 1.2)
        _set_input(node, "Alpha", 0.9)
        obj["studio_transparency"] = 0.15
    else:
        _set_input(node, "Transmission Weight", 0.7)
        _set_input(node, "Roughness", 0.06)
        _set_input(node, "IOR", 1.25)
        _set_input(node, ["Coat Weight", "Clearcoat"], 0.8)
        _set_input(node, "Alpha", 0.92)
    return obj


# ------------------------------------------------------------------------------------------
# Icon rig v4 = release rig + soft sky + reflection cards
# ------------------------------------------------------------------------------------------

def rig4(scene, objs):
    release_rig(scene, objs)
    lo, hi = _world_bounds(objs)
    centre, size = (lo + hi) / 2, max((hi - lo).length, 1.0)
    world = bpy.data.worlds.new("V4World")
    world.use_nodes = True
    nt = world.node_tree
    bg = nt.nodes["Background"]
    tc, sep, ramp = nt.nodes.new("ShaderNodeTexCoord"), nt.nodes.new("ShaderNodeSeparateXYZ"), nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], ramp.inputs[0])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    ramp.color_ramp.elements[0].position, ramp.color_ramp.elements[0].color = 0.35, (0.05, 0.07, 0.12, 1)
    ramp.color_ramp.elements[1].position, ramp.color_ramp.elements[1].color = 0.7, (0.55, 0.68, 0.85, 1)
    bg.inputs["Strength"].default_value = 0.8
    scene.world = world
    for name, offset, scale, energy in (("V4CardL", (-1.4, -1.6, 1.1), (0.35, 1.6), 6.0), ("V4CardR", (1.6, -0.9, 0.5), (0.25, 1.2), 3.5)):
        bpy.ops.mesh.primitive_plane_add(size=1, location=centre + Vector(offset) * size * 0.8)
        card = bpy.context.active_object
        card.name = name
        card.scale = (scale[0] * size, scale[1] * size, 1)
        card.rotation_euler = (centre - card.location).to_track_quat("Z", "Y").to_euler()
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        em = mat.node_tree.nodes.new("ShaderNodeEmission")
        em.inputs["Strength"].default_value = energy
        mat.node_tree.links.new(em.outputs[0], mat.node_tree.nodes["Material Output"].inputs["Surface"])
        card.data.materials.append(mat)
        card.visible_camera = False
        card.visible_shadow = False
        card.visible_diffuse = False
        card["rig_only"] = True
    scene.cycles.samples = 96
    scene.cycles.max_bounces, scene.cycles.transmission_bounces, scene.cycles.glossy_bounces = 10, 8, 6
    scene.cycles.transparent_max_bounces = 10
    _gpu(scene)


def render_views4(scene, objs, icon_path, preview_path, samples=96):
    rig4(scene, objs)
    scene.cycles.samples = samples
    scene.render.filepath = icon_path
    bpy.ops.render.render(write_still=True)
    cam = scene.camera
    lo, hi = _world_bounds(objs)
    centre = (lo + hi) / 2
    direction = Vector((1.0, -1.35, 0.75)).normalized()
    cam.location = centre + direction * 12
    cam.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
    cam.data.ortho_scale = max((hi - lo).length * 0.86, 1)
    scene.render.filepath = preview_path
    bpy.ops.render.render(write_still=True)


# ------------------------------------------------------------------------------------------
# Package (same contract as v3; before = v3)
# ------------------------------------------------------------------------------------------

def build_v4(gid, force=False, render=True, samples=96):
    global COLLECTION
    folder = v4_folder(gid)
    manifest_path = os.path.join(folder, "manifest.json")
    if os.path.exists(manifest_path) and not force:
        return {"id": gid, "status": "existing v4 preserved (force=True to rebuild)"}
    os.makedirs(folder, exist_ok=True)
    rarity = RARITY[gid]
    previous, old_col = bpy.context.window.scene, COLLECTION
    scene = bpy.data.scenes.new("V4_" + gid)
    scene.unit_settings.system, scene.unit_settings.scale_length = "NONE", 1
    bpy.context.window.scene = scene
    COLLECTION = scene.name
    try:
        with bpy.context.temp_override(scene=scene, view_layer=scene.view_layers[0]):
            body, details = BUILDERS4[gid](gid)
            body["glassy_id"], body["asset_role"], body["source_name"] = gid, "Body", "Body"
            for d in details:
                d["glassy_id"] = gid
            for o in [body, *details]:
                assert o.name == o["source_name"], ("name clash", o.name, o["source_name"])
            tris = sum(_tris(o) for o in [body, *details])
            budget = BUDGET.get(rarity, 1500)
            assert tris <= budget, (gid, "intact budget", tris, budget)
            count = SHARD_COUNT.get(rarity, 16)
            for attempt in range(16):
                shards = make_shards(body, count, seed=4040 + sum(map(ord, gid)) + attempt * 7919, cut=rcut4, min_volume_ratio=0.3 / count)
                if len(shards) == count and all(rclosed(s)["nonmanifold_edges"] == 0 and rclosed(s)["volume"] > 1e-7 for s in shards) \
                        and abs(sum(rclosed(s)["volume"] for s in shards) / rclosed(body)["volume"] - 1) < 0.001:
                    break
                for s in shards:
                    bpy.data.objects.remove(s, do_unlink=True)
            else:
                raise AssertionError((gid, "no valid fracture seed"))
            checks = {o.name: rclosed(o) for o in [body, *shards]}
            assert all(c["nonmanifold_edges"] == 0 and c["boundary_edges"] == 0 for c in checks.values()), checks
            ratio = sum(rclosed(s)["volume"] for s in shards) / rclosed(body)["volume"]
            assert abs(ratio - 1) < 0.001, (gid, "volume ratio", ratio)
            for i, s in enumerate(shards):
                s["source_name"], s["asset_role"], s["glassy_id"] = f"Shard_{i + 1:02d}", "Shard", gid
                assert s.name == s["source_name"]
                paint(s, body["studio_color"], role="Shard")
            cracks = rcracks(body)
            assert len(cracks) > 20, (gid, "cracks", len(cracks))
            files = {}
            for role, objs in (("body", [body]), ("details", details), ("shards", shards), ("bundle", [body, *details, *shards])):
                files[role] = export_fbx(objs, os.path.join(folder, f"{gid}_{role}.fbx"))
            for s in shards:
                s.hide_render = True
            icon = os.path.join(folder, f"{gid}_icon.png")
            preview = repo_path("docs", "art", "glassy_revamp", "previews", f"{gid}_v4_34.png")
            os.makedirs(os.path.dirname(preview), exist_ok=True)
            if render:
                render_views4(scene, [body, *details], icon, preview, samples)
                files["icon"] = icon
            for o in list(scene.objects):
                if o.get("rig_only"):
                    bpy.data.objects.remove(o, do_unlink=True)
            for s in shards:
                s.hide_set(True)
            files["blend"] = save_blend_copy(os.path.join(folder, f"{gid}.blend"))
            crack_path = os.path.join(folder, "cracks.json")
            with open(crack_path, "w", newline="\n") as fh:
                json.dump(cracks, fh, indent=2)
            files["cracks"] = crack_path
            meshes = []
            for o in [body, *details, *shards]:
                lo, hi = _world_bounds([o])
                entry = {"name": o.name, "source_name": o["source_name"], "role": o["asset_role"], "triangles": _tris(o),
                         "bounds_blender": [list(lo), list(hi)], "origin": [0, 0, 0], "color": o["studio_color"],
                         "material": o["studio_material"], "transparency": o.get("studio_transparency", 0),
                         "animation_pivot": list(o.get("animation_pivot", [0, 0, 0])), "effect_only": bool(o.get("effect_only", False))}
                if "motion_json" in o:
                    entry["motion"] = json.loads(o["motion_json"])
                    entry["pivot_empty"] = "Pivot_" + o["source_name"]
                meshes.append(entry)
            blo, bhi = _world_bounds([body])
            vlo, vhi = v2_body_bounds(gid)
            dims, v2dims = bhi - blo, vhi - vlo
            v3m = json.load(open(os.path.join(v3_folder(gid), "manifest.json")))
            v3_blend = os.path.join(v3_folder(gid), gid + ".blend")
            report = {
                "id": gid, "version": V4, "rarity": rarity, "base_version": "v3",
                "status": {"exported": True, "blender_validated": True, "studio_imported": False, "uploaded": False, "playtested": False},
                "units": "1 Blender unit = 1 stud", "axis_conversion": "Blender (x,y,z) -> Roblox (x,z,-y)", "hang_origin": [0, 0, 0],
                "intact_triangles": tris, "triangle_budget": budget, "shard_count": len(shards), "fracture_volume_ratio": ratio,
                "checks": checks, "crack_segments": len(cracks), "meshes": meshes,
                "files": {k: _rel(v) for k, v in files.items()}, "hashes": {k: _sha(v) for k, v in files.items()},
                "before": {"source": _rel(v3_blend), "sha256": _sha(v3_blend), "icon": v3m["files"].get("icon"),
                           "intact_triangles": v3m["intact_triangles"], "version": "v3"},
                "release_v2": v3m["before"],
                "collision": {"config_radius_unchanged": True,
                              "body_dimensions_roblox_v2": [v2dims.x, v2dims.z, v2dims.y], "body_dimensions_roblox_v4": [dims.x, dims.z, dims.y],
                              "max_dimension_change_pct": round(max(abs(dims[k] / v2dims[k] - 1) for k in range(3)) * 100, 2)},
                "measured_body_dimensions_roblox": [dims.x, dims.z, dims.y],
                "preview": _rel(preview) if render else None,
                "normals": "weighted normals on Body (applied in the FBX); smooth shading on rounded details",
                "remaining_checks": ["Roblox FBX import scale/orientation/pivot", "Glass/Neon material against live sky",
                                     "idle motion implementation in Studio", "phone performance with all details animated"],
            }
            with open(manifest_path, "w") as fh:
                json.dump(report, fh, indent=2)
            return {"id": gid, "tris": tris, "budget": budget, "shards": len(shards), "ratio": round(ratio, 8),
                    "dims_v4": [round(x, 3) for x in dims], "dims_v2": [round(x, 3) for x in v2dims],
                    "change_pct": report["collision"]["max_dimension_change_pct"], "details": len(details)}
    finally:
        bpy.context.window.scene = previous
        COLLECTION = old_col
        _drop_scene(scene)


def validate_v4(gid):
    global v3_folder
    keep = v3_folder
    v3_folder = v4_folder
    try:
        return validate_v3(gid)
    finally:
        v3_folder = keep


def preview_v4(gid, out_dir, samples=32):
    global COLLECTION
    previous, old_col = bpy.context.window.scene, COLLECTION
    scene = bpy.data.scenes.new("V4Preview_" + gid)
    bpy.context.window.scene = scene
    COLLECTION = scene.name
    try:
        with bpy.context.temp_override(scene=scene, view_layer=scene.view_layers[0]):
            body, details = BUILDERS4[gid](gid)
            tris = {o.name: _tris(o) for o in [body, *details]}
            blo, bhi = _world_bounds([body])
            os.makedirs(out_dir, exist_ok=True)
            render_views4(scene, [body, *details], os.path.join(out_dir, gid + "_v4_front.png"), os.path.join(out_dir, gid + "_v4_34.png"), samples)
            return {"tris_total": sum(tris.values()), "tris": tris, "body_dims": [round(x, 3) for x in (bhi - blo)],
                    "v2_dims": [round(x, 3) for x in (v2_body_bounds(gid)[1] - v2_body_bounds(gid)[0])], "body_closed": rclosed(body)}
    finally:
        bpy.context.window.scene = previous
        COLLECTION = old_col
        _drop_scene(scene)


def before_after4(gids, out, title):
    entries = []
    for g in gids:
        name = ROWS[g]["name"]
        entries.append((f"{name}  ({RARITY[g]})  v3  |  v4  |  v4 3/4", [
            os.path.join(v3_folder(g), g + "_icon.png"),
            os.path.join(v4_folder(g), g + "_icon.png"),
            repo_path("docs", "art", "glassy_revamp", "previews", g + "_v4_34.png")]))
    return labeled_sheet(entries, out, title)


# ------------------------------------------------------------------------------------------
# v4 builders: batch 1 (heroes)
# ------------------------------------------------------------------------------------------

def spikes_bm(bm, base_points, normals, heights, radii, sides=5):
    for p, n, h, r in zip(base_points, normals, heights, radii):
        p, n = Vector(p), Vector(n).normalized()
        tube_bm(bm, [p - n * r * 0.6, p + n * h * 0.55, p + n * h], [r, r * 0.45, 0.004], sides)
    return bm


def wing_bm(side, shoulder, sweep, lift, scale=1.0, membrane_depth=0.035):
    """Bat-style wing: membrane outline + rib tubes, both in the same local frame."""
    outline = [(0, 0), (0.25, 0.45), (0.55, 0.75), (0.38, 1.25), (0.66, 0.98), (0.98, 1.08), (0.9, 0.74), (1.2, 0.54), (0.84, 0.36), (0.32, -0.1)]
    wrist, tips = (0.55, 0.75), [(0.38, 1.25), (0.98, 1.08), (1.2, 0.54)]
    pts = [(side * u * scale, v * scale) for u, v in outline]
    if side < 0:
        pts = list(reversed(pts))
    rot = Matrix.Rotation(side * -sweep, 4, "Z") @ Matrix.Rotation(side * -lift, 4, "Y")
    m = Matrix.Translation(shoulder) @ rot
    mem = bmesh.new()
    slab_bm(mem, pts, membrane_depth, 0.014, 1, m)
    ribs = bmesh.new()
    loc = lambda u, v: m @ Vector((side * u * scale, 0, v * scale))
    tube_bm(ribs, [loc(0, 0), loc(0.27, 0.38), loc(*wrist)], [0.06, 0.05, 0.042], 6)
    for t in tips:
        tube_bm(ribs, [loc(*wrist), loc((wrist[0] + t[0]) / 2, (wrist[1] + t[1]) / 2), loc(*t)], [0.036, 0.025, 0.01], 4)
    ellipsoid_bm(ribs, loc(*wrist), (0.05, 0.05, 0.05), 6, 4)
    return mem, ribs, rot.to_3x3() @ Vector((0, side, 0))


@builder4("glass_dragon")
def v4_glass_dragon(gid):
    tint, pale, wing_c, rib_c = "#7CF0C4", "#F2FFF8", "#A6F5D8", "#2FB585"
    lo, hi = v2_body_bounds(gid)

    def shape(bm):
        ellipsoid_bm(bm, (0, -0.06, -0.6), (0.64, 0.6, 0.58), 24, 14)
        ellipsoid_bm(bm, (0, 0.02, -1.18), (0.36, 0.34, 0.3), 16, 10)
        ellipsoid_bm(bm, (0, -0.1, -1.6), (0.52, 0.5, 0.44), 20, 12)
        ellipsoid_bm(bm, (0, 0.02, -2.12), (0.66, 0.62, 0.68), 24, 14)
        for x in (-0.4, 0.4):
            ellipsoid_bm(bm, (x, 0.1, -2.42), (0.3, 0.34, 0.32), 14, 8)
            ellipsoid_bm(bm, (x * 0.85, -0.2, -2.84), (0.22, 0.28, 0.16), 12, 8)
    body = organic("Body", shape, 360, fit=(lo, hi), max_tris=860)
    glass4(body, tint, "shell", role="Body")
    ds = []
    muzzle = blob("Muzzle", (0, -0.5, -0.8), (0.4, 0.3, 0.24), 12, 7, Quaternion((1, 0, 0), -0.12))
    glass4(smooth_normals(muzzle), "#93ECC6", "detail")
    nb = bmesh.new()
    for x in (-0.12, 0.12):
        p, n = surface_point(muzzle, x, -0.72)
        ellipsoid_bm(nb, p - n * 0.01, (0.045, 0.02, 0.03), 5, 3, n.to_track_quat("-Y", "Z"))
    nostrils = paint(_obj("Nostrils", nb), "#2F5A4C", "SmoothPlastic")
    jaw = glass4(blob("Jaw", (0, -0.47, -1.0), (0.33, 0.27, 0.1), 10, 5), pale, "detail")
    anim(jaw, (0, -0.24, -0.94), (1, 0, 0), sway(4, 2.6), kick(18, 4, 0.35))
    fb = bmesh.new()
    for x in (-0.15, 0.15):
        gem_bm(fb, (x, -0.66, -0.93), 0.028, 0.1, 4)
    fangs = paint(_obj("Fangs", fb, smooth=False), "#FFFFFF", "SmoothPlastic")
    anim(fangs, (0, -0.24, -0.94), (1, 0, 0), sway(4, 2.6), kick(18, 4, 0.35), note="moves with Jaw")
    ds += [muzzle, nostrils, jaw, fangs]
    ds += face(body, [(-0.26, -0.47), (0.26, -0.47)], (0.11, 0.15), cheeks=True, cheek_target=muzzle, eye_segs=(8, 6))
    hb = bmesh.new()
    for s_ in (-1, 1):
        path = spline([(s_ * 0.3, 0.06, -0.24), (s_ * 0.4, 0.28, -0.08), (s_ * 0.46, 0.52, -0.05), (s_ * 0.47, 0.72, -0.16)], 10)
        path = path[:]
        rs = [(0.11 * (1 - k / (len(path) - 1)) + 0.012) * (1.12 if k % 2 == 0 and k < len(path) - 2 else 1.0) for k in range(len(path))]
        tube_bm(hb, path, rs, 4)
    horns = glass4(_obj("Horns", hb), "#FFF1C6", "detail")
    ds.append(horns)
    for s_, label in ((-1, "L"), (1, "R")):
        fin = glass4(slab("EarFin_" + label, [(0, -0.12), (s_ * 0.22, -0.02), (s_ * 0.3, 0.14), (s_ * 0.12, 0.08), (0, 0.12)][::s_], 0.03,
                          Matrix.Translation((s_ * 0.6, 0.08, -0.64)) @ Matrix.Rotation(s_ * -0.5, 4, "Z"), bevel=0.012, segments=1), wing_c, "detail")
        anim(fin, (s_ * 0.6, 0.08, -0.64), (0, 0, 1), sway(8, 1.7, 0.5 if s_ > 0 else 0), kick(18))
        ds.append(fin)
    for s_, label in ((-1, "L"), (1, "R")):
        shoulder = Vector((s_ * 0.3, 0.4, -1.5))
        mem, ribs, axis = wing_bm(s_, shoulder, 0.3, 0.45, 1.08)
        w = glass4(_obj("Wing_" + label, mem, sharp_deg=60), wing_c, "detail")
        anim(w, shoulder, axis, sway(14, 1.4), flare(28), lod_keep=True)
        r = glass4(_obj("WingRibs_" + label, ribs), rib_c, "detail")
        anim(r, shoulder, axis, sway(14, 1.4), flare(28), note="moves with Wing_" + label)
        ds += [w, r]
    ab = bmesh.new()
    for s_ in (-1, 1):
        tube_bm(ab, [(s_ * 0.38, -0.28, -1.48), (s_ * 0.44, -0.46, -1.66), (s_ * 0.32, -0.6, -1.74)], [0.1, 0.085, 0.07], 5)
        ellipsoid_bm(ab, (s_ * 0.3, -0.63, -1.75), (0.09, 0.08, 0.08), 6, 4)
    arms = glass4(_obj("Arms", ab), "#86EDC4", "detail")
    anim(arms, (0, -0.3, -1.5), (1, 0, 0), sway(3, 1.9), kick(8))
    pb = bmesh.new()
    for k, z in enumerate((-1.95, -2.2, -2.45)):
        hit = surface_point(body, 0, z)
        if hit:
            p, n = hit
            ellipsoid_bm(pb, p + n * 0.005, (0.33 - 0.05 * abs(k - 1), 0.07, 0.115), 8, 4, n.to_track_quat("-Y", "Z"))
    plates = glass4(_obj("BellyPlates", pb), pale, "detail")
    sp = bmesh.new()
    pts, nrm = [], []
    for z in (-0.45, -1.0, -1.55, -2.1):
        hit = surface_point(body, 0, z, from_y=6.0, direction=(0, -1, 0))
        if hit:
            pts.append(hit[0])
            nrm.append(hit[1])
    spikes_bm(sp, pts, nrm, [0.18, 0.24, 0.24, 0.18][:len(pts)], [0.08, 0.1, 0.1, 0.08][:len(pts)], 4)
    spines = glass4(_obj("Spines", sp), rib_c, "detail")
    path = spline([(0, 0.45, -2.5), (0, 0.85, -2.72), (0.1, 1.15, -2.55), (0.2, 1.28, -2.2), (0.16, 1.15, -1.9), (0.06, 0.98, -1.86)], 12)
    tb = bmesh.new()
    rads = [0.26 - 0.19 * k / (len(path) - 1) for k in range(len(path))]
    tube_bm(tb, path, rads, 6)
    tpts, tn = [], []
    for k in range(2, len(path) - 2, 3):
        t = (path[k + 1] - path[k - 1]).normalized()
        side = t.cross(Vector((1, 0, 0))).normalized()
        if side.z < 0:
            side = -side
        tpts.append(path[k] + side * rads[k] * 0.8)
        tn.append(side)
    spikes_bm(tb, tpts, tn, [0.12] * len(tpts), [0.045] * len(tpts), 4)
    end, d = path[-1], (path[-1] - path[-2]).normalized()
    m = Matrix.Translation(end + d * 0.06) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4() @ Matrix.Rotation(math.pi / 2, 4, "X")
    slab_bm(tb, [(0, -0.05), (0.18, 0.1), (0.0, 0.3), (-0.18, 0.1)], 0.06, 0.02, 1, m)
    tail = glass4(_obj("Tail", tb, sharp_deg=70), "#74E6B9", "detail")
    anim(tail, (0, 0.42, -2.45), (0, 0, 1), sway(12, 1.9), kick(20))
    core = paint(blob("BreathCore", (0, -0.14, -1.6), (0.2, 0.2, 0.2), 10, 6), "#FFF2B3", "Neon")
    anim(core, (0, -0.14, -1.6), (0, 0, 1), pulse(0.08, 1.6), flash(0.2), lod_keep=True)
    inner = glass4(blob("InnerGlow", (0, -0.05, -1.95), (0.46, 0.42, 0.62), 10, 6), "#2FD39A", "inner")
    spk = bubbles("Sparkles", (0, 0.0, -2.1), 0.42, 4, (0.03, 0.05), seed=3, color="#FFF7D6", neon=True)
    anim(spk, (0, 0, -2.1), (0, 0, 1), spin(20), spin_boost(200))
    ds += [arms, plates, spines, tail, inner, core, spk]
    return body, ds


def bevel_edges(obj, offset=0.02, segments=2, min_deg=25):
    """Chamfers hard edges (faceted crystal parts) so every facet edge catches a highlight."""
    bm = _bm_from_object(obj)
    edges = [e for e in bm.edges if len(e.link_faces) == 2 and math.degrees(e.calc_face_angle(0)) > min_deg]
    if edges:
        bmesh.ops.bevel(bm, geom=edges, offset=offset, segments=segments, affect="EDGES", profile=0.5, clamp_overlap=True)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    return smooth_normals(obj, sharp_deg=40)


@builder4("galaxy_orb")
def v4_galaxy_orb(gid):
    h, r = 2.40, 0.96
    prof = circle_profile(r, r, -90, 74, 13) + [(0.3, 2.06), (0.27, 2.16), (0.31, 2.2), (0.31, 2.27), (0, 2.27)]
    prof[0] = (0, 0)
    body = glass4(body_lathe("Body", prof, h, 28, r=0.02, steps=1), "#7A5CFF", "shell", role="Body")
    c = Vector((0, 0, r - h))
    ds = []
    cb = bmesh.new()
    lathe_bm(cb, [(0, 2.22), (0.21, 2.22), (0.24, 2.27), (0.19, 2.34), (0.12, 2.36), (0.12, 2.4), (0, 2.4)], h, 12)
    for k in range(4):
        a = k * math.tau / 4 + math.pi / 4
        gem_bm(cb, (0.2 * math.cos(a), 0.2 * math.sin(a), 2.33 - h), 0.035, 0.1, 4)
    crown = paint(smooth_normals(_obj("HangCrown", cb)), "#E4D6FF", "Metal")
    anim(crown, (0, 0, 0), (1, 0, 0), None, kick(10))
    nebula = glass4(blob("Nebula", c, (0.7, 0.7, 0.7), 12, 8), "#9B45FF", "inner")
    nmat = nebula.data.materials[0]
    _set_input(next(n for n in nmat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), "Alpha", 0.45)
    nebula["studio_transparency"] = 0.55
    sw = bmesh.new()
    tilt = Matrix.Translation(c) @ Matrix.Rotation(0.42, 4, "X")
    for arm in range(3):
        pts = []
        for i in range(11):
            t = i / 10
            a = arm * math.tau / 3 + t * 3.2
            rr = 0.07 + 0.52 * t
            pts.append(tilt @ Vector((rr * math.cos(a), rr * math.sin(a), 0.03 * math.sin(t * 6))))
        tube_bm(sw, pts, [0.085 * (1 - 0.85 * i / 10) + 0.008 for i in range(11)], 5)
    swirl = paint(_obj("GalaxySwirl", sw), "#F2A8FF", "Neon")
    anim(swirl, c, tilt.to_3x3() @ Vector((0, 0, 1)), spin(25), flash(0.2), lod_keep=True)
    core = paint(blob("StarCore", c, (0.14, 0.14, 0.14), 10, 6), "#FFF1B8", "Neon")
    anim(core, c, (0, 0, 1), pulse(0.12, 1.2), flash(0.25))
    halo = glass4(blob("CoreHalo", c, (0.27, 0.27, 0.27), 10, 6), "#FFD8F4", "detail")
    anim(halo, c, (0, 0, 1), pulse(0.06, 1.2, 0.4))
    dust = bubbles("Stardust", c, 0.72, 14, (0.03, 0.05), seed=7, color="#FFFFFF", neon=True)
    anim(dust, c, (0, 0, 1), spin(-12))
    for i, (angle, speed) in enumerate(((0.5, 40), (-0.6, -55))):
        rot = Matrix.Rotation(angle, 4, "X") @ Matrix.Rotation(i * 0.9, 4, "Z")
        rb = bmesh.new()
        torus_bm(rb, c, 1.16, 0.042, 28, 4, rot)
        band = paint(smooth_normals(_obj(f"OrbitBand_{i + 1}", rb)), "#E2D6FF", "Metal" if i == 0 else "Glass")
        axis = rot.to_3x3() @ Vector((0, 0, 1))
        anim(band, c, axis, spin(speed), spin_boost(240), lod_keep=(i == 0))
        mb = bmesh.new()
        for s_ in (-1, 1):
            ellipsoid_bm(mb, c + rot.to_3x3() @ Vector((s_ * 1.16, 0, 0)), (0.1, 0.1, 0.1), 8, 5)
        moons = paint(_obj(f"OrbitBand_{i + 1}_Moons", mb), ("#FFD27A", "#8FE3FF")[i], "SmoothPlastic")
        anim(moons, c, axis, spin(speed), spin_boost(240), note=f"rides OrbitBand_{i + 1}")
        ds += [band, moons]
    ds += [crown, nebula, swirl, core, halo, dust]
    return body, ds


@builder4("comet")
def v4_comet(gid):
    h = 2.45
    prof = chaikin([(0, 0.10), (0.5, 0.12), (0.75, 0.32), (0.84, 0.66), (0.82, 1.04), (0.66, 1.38), (0.44, 1.64), (0.27, 1.86), (0.15, 2.1), (0.06, 2.34), (0, 2.45)], iterations=1)
    body = glass4(body_lathe("Body", prof, h, 32, r=0), "#B8F1FF", "shell", role="Body")
    head = Vector((0, 0, 0.72 - h))
    ds = []
    inner = glass4(blob("InnerGlow", head + Vector((0, 0.05, 0.02)), (0.6, 0.6, 0.55), 12, 8), "#9FDCFF", "inner")
    star = paint(slab("StarCore", star_points(5, 0.3, 0.14), 0.14, Matrix.Translation(head + Vector((0, 0.12, -0.08))), bevel=0.045, segments=2), "#FFD57D", "Neon")
    anim(star, head + Vector((0, 0.12, -0.08)), (0, 1, 0), pulse(0.08, 1.3), flash(0.25), lod_keep=True)
    ds += [inner, star]
    ds += face(body, [(-0.25, 0.86 - h), (0.25, 0.86 - h)], (0.1, 0.14), cheeks=True, smile=(0, 0.6 - h, 0.12), eye_segs=(8, 6))
    fin_shape = [(-0.2, 0.0), (-0.3, 0.28), (-0.27, 0.58), (-0.14, 0.88), (0.04, 1.16), (0.08, 0.86), (0.13, 0.56), (0.19, 0.26), (0.18, 0.0)]
    root = Vector((0, 0.32, 1.45 - h))
    for i, (yaw, size, tint) in enumerate(((-1.38, 1.55, "#B9EBFF"), (-1.02, 1.26, "#D3C6FF"), (-0.68, 0.98, "#FFE9A8"))):
        pts = [(u * size, v * size) for u, v in fin_shape]
        rot = Matrix.Rotation(yaw, 4, "Y") @ Matrix.Rotation(-0.3, 4, "X")
        fb = bmesh.new()
        slab_bm(fb, pts, 0.1 - i * 0.015, 0.04, 2, None)
        for v in fb.verts:
            v.co.y += 0.12 * (v.co.z / size) ** 2
        bmesh.ops.transform(fb, matrix=Matrix.Translation(root + Vector((0, i * 0.06, 0))) @ rot, verts=fb.verts)
        fin = glass4(smooth_normals(_obj(f"TailFin_{i + 1}", fb), 60), tint, "detail")
        anim(fin, root, rot.to_3x3() @ Vector((0, 1, 0)), sway(8, 1.1, i * 0.9), kick(16))
        ds.append(fin)
    for i, (ang, z, rr) in enumerate(((0.6, -1.25, 1.02), (2.6, -1.85, 0.98), (4.4, -0.85, 0.82))):
        p = Vector((rr * math.cos(ang), rr * math.sin(ang), z))
        m = Matrix.Translation(p) @ Matrix.Rotation(ang + math.pi / 2, 4, "Z")
        sp = paint(slab(f"Sparkle_{i + 1}", star_points(4, 0.14, 0.04), 0.04, m, bevel=0.012, segments=1), "#FFFFFF", "Neon")
        anim(sp, (0, 0, z), (0, 0, 1), spin(60 + i * 15), spin_boost(300))
        ds.append(sp)
    return body, ds


@builder4("prism_blade")
def v4_prism_blade(gid):
    def hexs(w, t, k=0.5):
        return [(w, 0), (w * k, t), (-w * k, t), (-w, 0), (-w * k, -t), (w * k, -t)]
    secs = [(-0.48, hexs(0.1, 0.07)), (-0.56, hexs(0.3, 0.13)), (-0.7, hexs(0.36, 0.15)), (-1.6, hexs(0.33, 0.145)),
            (-2.3, hexs(0.3, 0.13)), (-2.62, hexs(0.22, 0.1)), (-2.86, hexs(0.1, 0.05)), (-2.99, [(0, 0)])]
    body = loft("Body", secs)
    bevel_edges(body, 0.018, 2, 20)
    glass4(body, "#9BE7FF", "shell", role="Body")
    ds = []
    core = paint(loft("RainbowCore", [(-0.8, hexs(0.03, 0.02)), (-0.95, hexs(0.09, 0.04)), (-2.35, hexs(0.07, 0.035)), (-2.6, [(0, 0)])]), "#E6B8FF", "Neon")
    anim(core, (0, 0, -1.7), (0, 0, 1), pulse(0.04, 2.0), flash(0.15), lod_keep=True)
    guard_pts = [(-0.7, 0.16), (-0.54, 0.08), (-0.36, 0.0), (-0.14, 0.07), (0.14, 0.07), (0.36, 0.0), (0.54, 0.08), (0.7, 0.16),
                 (0.62, -0.06), (0.44, -0.16), (0.22, -0.18), (0.0, -0.3), (-0.22, -0.18), (-0.44, -0.16), (-0.62, -0.06)]
    guard = glass4(smooth_normals(slab("Crossguard", guard_pts, 0.22, Matrix.Translation((0, 0, -0.33)), bevel=0.05, segments=1), 55), "#B9E4FA", "detail")
    anim(guard, (0, 0, -0.4), (0, 1, 0), None, kick(4))
    gb = bmesh.new()
    gem_bm(gb, (0, -0.12, -0.42), 0.09, 0.11, 6, Matrix.Rotation(math.pi / 2, 4, "X"))
    for s_ in (-1, 1):
        gem_bm(gb, (s_ * 0.5, -0.11, -0.32), 0.045, 0.06, 4, Matrix.Rotation(math.pi / 2, 4, "X"))
    ggem = paint(_obj("GuardGem", gb, smooth=False), "#FF8FD8", "Neon")
    anim(ggem, (0, -0.12, -0.42), (0, 1, 0), pulse(0.1, 1.4), flash(0.25))
    hprof = [(0, 0.0), (0.075, 0.0), (0.09, 0.03), (0.075, 0.06), (0.09, 0.09), (0.075, 0.12), (0.09, 0.15), (0.075, 0.18), (0.11, 0.2),
             (0.15, 0.24), (0.16, 0.3), (0.13, 0.35), (0.06, 0.37), (0, 0.37)]
    hilt = glass4(smooth_normals(lathe3("Hilt", [(r_, z - 0.37) for r_, z in hprof], 0.0, 12, sharp_deg=None)), "#B9E4FA", "detail")
    pb = bmesh.new()
    gem_bm(pb, (0, -0.15, -0.07), 0.055, 0.07, 6, Matrix.Rotation(math.pi / 2, 4, "X"))
    pgem = paint(_obj("PommelGem", pb, smooth=False), "#8FE3FF", "Neon")
    anim(pgem, (0, -0.15, -0.07), (0, 1, 0), None, flash(0.2))
    for i, (ang, z) in enumerate(((0.3, -1.35), (math.pi + 0.3, -2.15), (math.pi / 2 + 0.3, -1.75))):
        sb = bmesh.new()
        p = Vector((0.55 * math.cos(ang), 0.55 * math.sin(ang), z))
        gem_bm(sb, p, 0.1 - i * 0.02, 0.42 - i * 0.1, 5, Matrix.Rotation(0.3, 4, "Y"))
        shard = paint(_obj(f"PrismShard_{i + 1}", sb, smooth=False), ("#C9A8FF", "#9BE7FF", "#FFB8E6")[i])
        anim(shard, (0, 0, -1.75), (0, 0, 1), spin(70), spin_boost(300), extra_idle=[bob(0.06, 1.6, i * 2.1)])
        ds.append(shard)
    glint = bubbles("BladeGlints", (0, 0, -1.7), 0.3, 5, (0.025, 0.04), seed=9, color="#FFFFFF", neon=True, height=0.9)
    anim(glint, (0, 0, -1.7), (0, 0, 1), pulse(0.3, 0.9), flash(0.15))
    ds = [guard, ggem, hilt, pgem, core, glint] + ds
    return body, ds


@builder4("rocket_pop")
def v4_rocket_pop(gid):
    h = 2.70
    ctrl = [(0, 0), (0.42, 0), (0.58, 0.12), (0.61, 0.32), (0.61, 1.3), (0.54, 1.6), (0.36, 1.88), (0.25, 2.06), (0.25, 2.18), (0.3, 2.22), (0.3, 2.3), (0.25, 2.34), (0.25, 2.49), (0, 2.49)]
    prof = round_profile(ctrl, 0.03, steps=1)
    body = glass4(body_lathe("Body", prof, h, 16, r=0), "#8FE3FF", "shell", role="Body")
    ds = []
    cap = lathe3("Cap", [(0, 2.49), (0.31, 2.49), (0.34, 2.54), (0.34, 2.63), (0.27, 2.69), (0, 2.70)], h, 10, sharp_deg=None)
    paint(smooth_normals(crimp(cap, 5, 0.05, -0.06)), "#ED5367", "SmoothPlastic")
    anim(cap, (0, 0, -0.2), (0, 0, 1), None, hop(0.08))
    fill = glass4(lathe3("SodaFill", inset(ctrl, 0.07, 0.12, 1.5), h, 8, sharp_deg=None), "#3FB8F0", "inner")
    anim(fill, (0, 0, 1.5 - h), (1, 0, 0), slosh(12))
    fizz = bubbles("Fizz", (0, -0.1, 0.85 - h), 0.32, 3, (0.04, 0.07), seed=4, height=0.5, segs=(4, 3))
    anim(fizz, (0, -0.1, 0.85 - h), (0, 0, 1), bob(0.05, 1.1), squash(1.15))
    fin_pts = [(0.0, -0.05), (0.0, 0.9), (0.14, 0.78), (0.46, 0.22), (0.58, -0.22), (0.42, -0.2), (0.2, -0.08)]
    for i in range(3):
        rot = Matrix.Rotation(i * math.tau / 3 + math.pi / 2, 4, "Z")
        fb = bmesh.new()
        slab_bm(fb, fin_pts, 0.12, 0.04, 1, rot @ Matrix.Translation((0.5, 0, -2.45)))
        fin = paint(smooth_normals(_obj(f"RocketFin_{i + 1}", fb), 55), "#ED5367", "SmoothPlastic")
        anim(fin, rot.to_3x3() @ Vector((0.55, 0, -2.0)), rot.to_3x3() @ Vector((0, 1, 0)), None, kick(6))
        ds.append(fin)
    nozzle = paint(smooth_normals(lathe3("BoosterNozzle", [(0, -0.12), (0.42, -0.12), (0.37, 0.06), (0.3, 0.16), (0.32, 0.22), (0, 0.22)], h, 10, sharp_deg=None)), "#C0D9EF", "Metal")
    flame = paint(lathe3("BoosterFlame", [(0, -1.0), (0.17, -0.62), (0.34, -0.26), (0, -0.1)], h, 8, sharp_deg=None), "#FF6A00", "Neon")
    anim(flame, (0, 0, -0.1 - h), (0, 0, 1), flicker(0.12, 14), squash(1.5), lod_keep=True)
    flame2 = paint(lathe3("BoosterFlameCore", [(0, -0.66), (0.11, -0.4), (0.2, -0.2), (0, -0.14)], h, 6, sharp_deg=None), "#FFF0A8", "Neon")
    anim(flame2, (0, 0, -0.1 - h), (0, 0, 1), flicker(0.18, 18), squash(1.6), note="inner flame; flickers faster")
    pr = bmesh.new()
    torus_bm(pr, (0, -0.6, 1.02 - h), 0.2, 0.05, 10, 4, Matrix.Rotation(math.pi / 2, 4, "X"))
    port = paint(smooth_normals(_obj("Porthole", pr)), "#C0D9EF", "Metal")
    win = glass4(blob("PortholeGlass", (0, -0.6, 1.02 - h), (0.16, 0.03, 0.16), 8, 3), "#2B6FD6", "inner")
    anim(win, (0, -0.6, 1.02 - h), (0, 1, 0), None, flash(0.15))
    sb = bmesh.new()
    torus_bm(sb, (0, 0, 0.5 - h), 0.615, 0.04, 16, 3)
    stripe = paint(_obj("RaceStripe", sb), "#FFFFFF", "SmoothPlastic")
    ds = [cap, fill, fizz] + ds + [nozzle, flame, flame2, port, win, stripe]
    return body, ds


@builder4("glass_duck")
def v4_glass_duck(gid):
    lo, hi = v2_body_bounds(gid)

    def shape(bm):
        ellipsoid_bm(bm, (0, -0.14, -0.5), (0.5, 0.48, 0.5), 20, 12)
        ellipsoid_bm(bm, (0, -0.06, -0.98), (0.34, 0.32, 0.3), 14, 8)
        ellipsoid_bm(bm, (0, 0.12, -1.62), (0.86, 0.9, 0.68), 24, 14)
        ellipsoid_bm(bm, (0, -0.4, -1.46), (0.6, 0.5, 0.56), 18, 10)
        ellipsoid_bm(bm, (0, 0.74, -1.28), (0.34, 0.3, 0.32), 12, 8, Quaternion((1, 0, 0), -0.6))
    body = organic("Body", shape, 300, fit=(lo, hi), max_tris=620)
    glass4(body, "#FFE45C", "shell", role="Body")
    _set_input(next(n for n in body.data.materials[0].node_tree.nodes if n.type == "BSDF_PRINCIPLED"), "Base Color", (*hex_to_rgb("#FFE45C"), 1))
    ds = []
    upper = bmesh.new()
    ellipsoid_bm(upper, (0, -0.6, -0.62), (0.3, 0.27, 0.085), 10, 5)
    beak = paint(smooth_normals(_obj("Beak", upper)), "#FF9E3D", "SmoothPlastic")
    anim(beak, (0, -0.4, -0.66), (1, 0, 0), None, kick(6))
    lower = paint(smooth_normals(blob("BeakLower", (0, -0.54, -0.72), (0.23, 0.2, 0.06), 8, 4)), "#F98A2B", "SmoothPlastic")
    anim(lower, (0, -0.38, -0.7), (1, 0, 0), sway(3, 2.4), kick(22, 5, 0.4), note="opens on hit: a quack")
    ds += [beak, lower]
    ds += face(body, [(-0.2, -0.38), (0.2, -0.38)], (0.085, 0.115), cheeks=True, eye_segs=(8, 5))
    feather = [(0.0, 0.0), (0.16, 0.22), (0.42, 0.26), (0.62, 0.08), (0.54, -0.04), (0.58, -0.16), (0.4, -0.12), (0.34, -0.26), (0.14, -0.14)]
    for side, label in ((-1, "L"), (1, "R")):
        m = Matrix.Translation((side * 0.8, -0.32, -1.42)) @ Matrix.Rotation(side * -0.3, 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "Z") @ Matrix.Rotation(-0.3, 4, "Y")
        wb = bmesh.new()
        slab_bm(wb, [(u * 1.15, v * 1.15) for u, v in feather], 0.15, 0.06, 1, m)
        w = glass4(smooth_normals(_obj("Wing_" + label, wb), 60), "#FFD23C", "detail")
        anim(w, (side * 0.8, -0.32, -1.42), (0, side, 0), sway(6, 1.8), flare(30), lod_keep=True)
        ds.append(w)
    tb = bmesh.new()
    for k, ang in enumerate((-0.3, 0.3)):
        m = Matrix.Translation((0, 0.86, -1.18)) @ Matrix.Rotation(math.pi / 2, 4, "Z") @ Matrix.Rotation(ang, 4, "X") @ Matrix.Rotation(-0.9, 4, "Y")
        slab_bm(tb, [(0, -0.07), (0.3, -0.04), (0.36, 0.0), (0.3, 0.04), (0, 0.07)], 0.05, 0, 1, m)
    tail = glass4(smooth_normals(_obj("TailFeather", tb), 60), "#FFD23C", "detail")
    anim(tail, (0, 0.78, -1.28), (0, 0, 1), sway(10, 1.2), kick(14))
    tf = bmesh.new()
    tube_bm(tf, spline([(0, -0.16, -0.06), (0, -0.2, 0.06), (0, -0.32, 0.12), (0, -0.4, 0.06), (0, -0.34, 0.0)], 10), [0.07, 0.06, 0.05, 0.04, 0.03, 0.025, 0.02, 0.016, 0.012, 0.01, 0.008], 5)
    tuft = glass4(_obj("HeadTuft", tf), "#FFD23C", "detail")
    anim(tuft, (0, -0.16, -0.06), (1, 0, 0), sway(3, 2.2), kick(25))
    bubble = glass4(blob("CrownBubble", (0, 0.04, 0.0), (0.13, 0.13, 0.13), 6, 5), "#EAFBFF", "detail")
    anim(bubble, (0, 0.04, 0.0), (0, 0, 1), bob(0.05, 1.5), hop(0.08))
    heart = [(0.0, -0.22), (0.2, -0.02), (0.22, 0.1), (0.14, 0.18), (0.05, 0.16), (0.0, 0.1), (-0.05, 0.16), (-0.14, 0.18), (-0.22, 0.1), (-0.2, -0.02)]
    hc = paint(slab("HeartCore", heart, 0.1, Matrix.Translation((0, -0.1, -1.55)) @ Matrix.Diagonal((0.8, 1, 0.8, 1)), bevel=0, segments=1), "#FF7A9C", "Neon")
    anim(hc, (0, -0.1, -1.55), (0, 1, 0), pulse(0.1, 1.1), flash(0.2))
    inner = glass4(blob("InnerGlow", (0, 0.05, -1.62), (0.5, 0.52, 0.38), 8, 5), "#FFD23C", "inner")
    ds += [tail, tuft, bubble, hc, inner]
    return body, ds


# ------------------------------------------------------------------------------------------
# v4 batch 2: starters and first Rares
# ------------------------------------------------------------------------------------------

def bottle(ctrl, h, segments=20, r=0.03, tint="#FFFFFF"):
    """Rounded-rim bottle body: one rounding step per corner keeps the ring count low."""
    prof = round_profile(ctrl, r, steps=1)
    body = glass4(body_lathe("Body", prof, h, segments, r=0), tint, "shell", role="Body")
    return body, prof


def fill(name, ctrl, h, d, z_lo, z_hi, color, segments=10, max_deg=12, gain=0.3):
    obj = glass4(smooth_normals(lathe3(name, inset(ctrl, d, z_lo, z_hi), h, segments, sharp_deg=None)), color, "inner")
    anim(obj, (0, 0, z_hi - h), (1, 0, 0), slosh(max_deg, gain))
    return obj


@builder4("pop")
def v4_pop(gid):
    h = 2.55
    ctrl = [(0, 0), (0.44, 0), (0.6, 0.08), (0.65, 0.22), (0.65, 0.4), (0.57, 0.58), (0.58, 0.72), (0.62, 0.84), (0.62, 1.3),
            (0.5, 1.62), (0.3, 1.88), (0.245, 2.02), (0.245, 2.22), (0.3, 2.26), (0.3, 2.35), (0, 2.35)]
    body, prof = bottle(ctrl, h, 18, 0.03, "#8FE3FF")
    cap = lathe3("Cap", [(0, 2.35), (0.31, 2.35), (0.34, 2.4), (0.34, 2.48), (0.27, 2.54), (0, 2.55)], h, 12, sharp_deg=None)
    paint(smooth_normals(crimp(cap, 6, 0.06, -0.06)), "#ED5367", "SmoothPlastic")
    anim(cap, (0, 0, -0.2), (0, 0, 1), None, hop(0.08), lod_keep=True)
    soda = fill("SodaFill", ctrl, h, 0.07, 0.08, 1.42, "#3FB8F0")
    ds = [cap, soda]
    for i, (x, z, r) in enumerate(((-0.22, 0.66, 0.17), (0.2, 1.02, 0.2), (-0.1, 1.36, 0.16))):
        ds.append(glass4(smooth_normals(blob(f"ChargeBubble_{i + 1}", (x, -0.42, z - h), (r, 0.12, r), 8, 5)), "#EAFBFF", "detail"))
    fizz = bubbles("Fizz", (0.05, 0.1, 0.95 - h), 0.34, 5, (0.025, 0.05), seed=12, height=0.5, segs=(4, 3))
    anim(fizz, (0.05, 0.1, 0.95 - h), (0, 0, 1), bob(0.05, 1.0), squash(1.15))
    ds.append(fizz)
    return body, ds


@builder4("jam")
def v4_jam(gid):
    h = 2.05
    ctrl = [(0, 0), (0.67, 0), (0.86, 0.08), (0.95, 0.24), (0.95, 1.26), (0.91, 1.46), (0.79, 1.6), (0.79, 1.69), (0.9, 1.72), (0.9, 1.8), (0, 1.8)]
    body, prof = bottle(ctrl, h, 20, 0.035, "#FF6B8B")
    cap = paint(smooth_normals(lathe3("Cap", [(0, 1.8), (0.93, 1.8), (0.98, 1.85), (0.98, 1.98), (0.92, 2.05), (0, 2.05)], h, 16, sharp_deg=None)), "#F5C860", "Metal")
    cloth = lathe3("CapCloth", [(0, 2.08), (0.7, 2.08), (0.96, 2.04), (1.04, 1.96), (1.07, 1.8), (1.06, 1.68), (1.0, 1.68), (1.0, 1.8), (0.97, 1.92), (0.9, 2.0), (0.6, 2.03), (0, 2.03)], h, 16, sharp_deg=None)
    for v in cloth.data.vertices:
        a = math.atan2(v.co.y, v.co.x)
        if v.co.z < -0.18:
            v.co.z += 0.06 * (1 + math.cos(8 * a))
            k = 1 + 0.03 * math.cos(8 * a)
            v.co.x *= k
            v.co.y *= k
    paint(smooth_normals(cloth), "#FF9DB8", "SmoothPlastic")
    anim(cloth, (0, 0, 0), (1, 0, 0), sway(3, 2.4), hop(0.06), lod_keep=True)
    tb = bmesh.new()
    torus_bm(tb, (0, 0, 1.79 - h), 1.035, 0.035, 16, 4)
    tie = paint(smooth_normals(_obj("CapTie", tb)), "#FFFFFF", "SmoothPlastic")
    anim(tie, (0, 0, 0), (1, 0, 0), sway(3, 2.4), hop(0.06), note="moves with CapCloth; both names contain 'Cap' so the Lid Guard power lifts them with the lid")
    jam = fill("JamInsert", ctrl, h, 0.08, 0.08, 1.18, "#E0325A", 12, 10, 0.25)
    berries = paint(smooth_normals(blobs("Berries", [((0.32, -0.45, 0.62 - h), (0.17, 0.15, 0.2)), ((-0.36, -0.38, 0.42 - h), (0.15, 0.13, 0.17)), ((0.0, 0.3, 0.5 - h), (0.14, 0.12, 0.16))], 6, 4)), "#FF4D6D", "SmoothPlastic")
    anim(berries, (0, 0, 1.18 - h), (1, 0, 0), slosh(10, 0.25), note="moves with JamInsert")
    seeds = bubbles("JamBubbles", (0, -0.1, 0.8 - h), 0.5, 4, (0.03, 0.05), seed=21, height=0.3, segs=(4, 3))
    anim(seeds, (0, -0.1, 0.8 - h), (0, 0, 1), bob(0.03, 1.6))
    return body, [cap, cloth, tie, jam, berries, seeds]


@builder4("prism")
def v4_prism(gid):
    h = 2.60
    prof = [(0, 0), (0.48, 0), (0.62, 0.06), (0.74, 0.2), (0.81, 0.42), (0.81, 1.16), (0.74, 1.3), (0.44, 1.56), (0.26, 1.72), (0.24, 1.9), (0.31, 1.93), (0.31, 1.96), (0, 1.96)]
    body = lathe3("Body", prof, h, 8, flat=True)
    bevel_edges(body, 0.02, 1, 20)
    glass4(body, "#C9A8FF", "shell", role="Body")
    stopper = lathe3("GemStopper", [(0, 1.94), (0.18, 1.94), (0.4, 2.12), (0.44, 2.22), (0.3, 2.42), (0.1, 2.56), (0, 2.6)], h, 8, flat=True)
    bevel_edges(stopper, 0.015, 1, 20)
    glass4(stopper, "#E2CCFF", "detail")
    anim(stopper, (0, 0, 1.95 - h), (1, 0, 0), sway(3, 2.2), kick(12), lod_keep=True)
    lens = glass4(smooth_normals(blob("RayLens", (0, -0.79, 0.86 - h), (0.27, 0.06, 0.29), 12, 6)), "#B9F4FF", "detail")
    sp = paint(slab("Sparkle", star_points(4, 0.13, 0.035), 0.04, Matrix.Translation((0.5, -0.2, 2.25 - h)), bevel=0.012, segments=1), "#FFFFFF", "Neon")
    anim(sp, (0, 0, 2.25 - h), (0, 0, 1), spin(70), spin_boost(300))
    core = lathe3("FacetCore", [(0, 0.3), (0.34, 0.42), (0.42, 0.8), (0.34, 1.18), (0, 1.3)], h, 8, flat=True)
    glass4(core, "#B88CFF", "inner")
    anim(core, (0, 0, 0.8 - h), (0, 0, 1), spin(10))
    glints = bubbles("Glints", (0, 0, 0.8 - h), 0.5, 4, (0.025, 0.04), seed=5, color="#FFFFFF", neon=True, height=0.5)
    anim(glints, (0, 0, 0.8 - h), (0, 0, 1), pulse(0.3, 1.1))
    return body, [stopper, lens, sp, core, glints]


def crescent_pts(R, w, n=7, tip_deg=60):
    t = math.radians(tip_deg)
    p1 = (R * math.cos(t), R * math.sin(t))
    a = -R + w
    k = a - p1[0]
    rho = -(k * k + p1[1] ** 2) / (2 * k)
    cx = a + rho
    outer = [(R * math.cos(t + (math.tau - 2 * t) * i / n), R * math.sin(t + (math.tau - 2 * t) * i / n)) for i in range(n + 1)]
    f1 = math.atan2(p1[1], p1[0] - cx)
    inner = [(cx + rho * math.cos(-f1 - (math.tau - 2 * f1) * i / n), rho * math.sin(-f1 - (math.tau - 2 * f1) * i / n)) for i in range(1, n)]
    return outer + inner


@builder4("crescent_axe")
def v4_crescent_axe(gid):
    h = 2.40
    ctrl = [(0, 0), (0.54, 0), (0.78, 0.13), (0.89, 0.43), (0.85, 1.08), (0.65, 1.39), (0.3, 1.61), (0.27, 1.9), (0.36, 1.93), (0.36, 1.96), (0, 1.96)]
    body, prof = bottle(ctrl, h, 20, 0.035, "#B69BFF")
    sb = bmesh.new()
    lathe_bm(sb, [(0, 1.84), (0.24, 1.84), (0.26, 2.02), (0.2, 2.06), (0, 2.06)], h, 10)
    slab_bm(sb, crescent_pts(0.28, 0.12, 7, 70), 0.14, 0.03, 1, Matrix.Translation((-0.06, 0, 2.27 - h)), clamp=True)
    stopper = glass4(smooth_normals(_obj("CrescentStopper", sb), 55), "#E2DBFF", "detail")
    anim(stopper, (0, 0, 1.9 - h), (0, 1, 0), sway(5, 2.0), kick(15), lod_keep=True)
    tb = bmesh.new()
    torus_bm(tb, (0, 0, 1.45 - h), 0.62, 0.06, 16, 3)
    band = paint(smooth_normals(_obj("ShoulderBand", tb)), "#C9DDF2", "Metal")
    emblem = paint(slab("CrescentEmblem", crescent_pts(0.24, 0.09, 6, 70), 0.05, Matrix.Translation((0, -0.83, 0.82 - h)) @ Matrix.Rotation(-0.3, 4, "Y"), bevel=0.015, segments=1, clamp=True), "#F1E8FF", "Neon")
    anim(emblem, (0, -0.83, 0.82 - h), (0, 1, 0), pulse(0.06, 1.8), flash(0.2))
    mist = fill("MoonMist", ctrl, h, 0.08, 0.06, 1.0, "#7E5CE8", 10, 10, 0.3)
    stars = bubbles("MistStars", (0, 0, 0.55 - h), 0.5, 3, (0.025, 0.04), seed=8, color="#FFFFFF", neon=True, height=0.3)
    anim(stars, (0, 0, 0.55 - h), (0, 0, 1), spin(14))
    handle = paint(tube("AxeHandle", [(0.96, 0, -1.9), (0.97, 0, -1.3), (0.96, 0, -0.62)], [0.07, 0.065, 0.06], 8), "#9BCDEB")
    head = paint(slab("AxeHead", [(-u, v) for u, v in crescent_pts(0.44, 0.17, 8, 62)], 0.14, Matrix.Translation((1.27, 0, -0.84)), bevel=0.04, segments=1, clamp=True), "#D2CBFF")
    for o in (handle, head):
        o["effect_only"] = True
        anim(o, (0.96, 0, -1.7), (0, 1, 0), None, None, note="effect-only; the Crescent Sweep kit swings it about this pivot")
    return body, [stopper, band, emblem, mist, stars, handle, head]


@builder4("briar_flask")
def v4_briar_flask(gid):
    h = 2.65
    ctrl = [(0, 0), (0.36, 0.03), (0.6, 0.21), (0.79, 0.56), (0.8, 0.82), (0.69, 1.2), (0.48, 1.56), (0.24, 1.91), (0.21, 2.12), (0.28, 2.16), (0.28, 2.23), (0, 2.23)]
    body, prof = bottle(ctrl, h, 18, 0.03, "#35CB97")
    ds = []
    plug = bmesh.new()
    lathe_bm(plug, [(0, 2.1), (0.2, 2.1), (0.22, 2.28), (0, 2.3)], h, 8)
    slab_bm(plug, [(0.0, 0.0), (-0.16, 0.12), (-0.2, 0.3), (-0.08, 0.46), (0.06, 0.5), (0.14, 0.34), (0.12, 0.14)], 0.07, 0.025, 1, Matrix.Translation((0, 0, 2.24 - h)) @ Matrix.Rotation(-0.35, 4, "Y"))
    stopper = glass4(smooth_normals(_obj("LeafStopper", plug), 55), "#8EEDB2", "detail")
    anim(stopper, (0, 0, 2.2 - h), (0, 1, 0), sway(4, 2.2), kick(12))
    for i in range(3):
        rot = Matrix.Rotation(i * math.tau / 3, 3, "Z")
        path = [rot @ Vector(p) for p in spline([(0.66, 0, -1.6), (0.9, 0, -1.5), (1.05, 0, -1.36), (1.12, 0, -1.2)], 6)]
        tb = bmesh.new()
        tube_bm(tb, path, [0.13 * (1 - k / (len(path) - 1)) + 0.012 for k in range(len(path))], 6)
        thorn = glass4(smooth_normals(_obj(f"Thorn_{i + 1}", tb)), "#A0F7CC", "detail")
        anim(thorn, rot @ Vector((0.64, 0, -1.5)), rot @ Vector((0, 1, 0)), None, kick(10), note="client grows it from AnimationPivot by charge")
        ds.append(thorn)
    vine = []
    for k in range(16):
        t = k / 15
        z = 0.35 + t * 1.25
        near = [rr for rr, zz in prof if abs(zz - z) < 0.12]
        r = (max(near) if near else 0.6) + 0.035
        a = t * math.tau * 1.15 + 0.4
        vine.append((r * math.cos(a), r * math.sin(a), z - h))
    vb = bmesh.new()
    tube_bm(vb, vine, 0.04, 4)
    vine_o = paint(smooth_normals(_obj("Vine", vb)), "#2FA86A", "SmoothPlastic")
    for i, k in enumerate((5, 12)):
        p = Vector(vine[k])
        a = math.atan2(p.y, p.x)
        m = Matrix.Translation(p) @ Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(0.5 if i else -0.4, 4, "Y")
        lf = glass4(smooth_normals(slab(f"Leaf_{i + 1}", [(0.0, 0.0), (0.1, 0.07), (0.2, 0.06), (0.28, 0.0), (0.2, -0.06), (0.1, -0.07)], 0.035, m, bevel=0.012, segments=1)), "#5FD38E", "detail")
        anim(lf, p, Matrix.Rotation(a, 3, "Z") @ Vector((0, 1, 0)), sway(6, 1.7, i * 1.3), kick(14))
        ds.append(lf)
    bud = bmesh.new()
    for j in range(4):
        a = j * math.tau / 4 + 0.4
        ellipsoid_bm(bud, (0.09 * math.cos(a), -0.1 + 0.09 * math.sin(a), 0.72 - h), (0.12, 0.1, 0.16), 6, 4)
    ellipsoid_bm(bud, (0, -0.1, 0.78 - h), (0.1, 0.1, 0.14), 6, 4)
    rose = paint(_obj("RoseSeed", bud), "#FF7AB6", "Neon")
    anim(rose, (0, -0.1, 0.72 - h), (0, 0, 1), pulse(0.07, 1.6), flash(0.2), lod_keep=True)
    nectar = fill("Nectar", ctrl, h, 0.08, 0.06, 0.62, "#1FA77A", 10, 10, 0.3)
    return body, [stopper] + ds[:3] + [vine_o] + ds[3:] + [rose, nectar]


@builder4("arc_coil")
def v4_arc_coil(gid):
    h = 2.30
    ctrl = [(0, 0), (0.5, 0), (0.71, 0.13), (0.87, 0.43), (0.91, 0.78), (0.83, 1.12), (0.61, 1.41), (0.33, 1.57), (0.3, 1.88), (0, 1.88)]
    body, prof = bottle(ctrl, h, 20, 0.03, "#6BE9FF")
    cap = paint(smooth_normals(lathe3("Cap", [(0, 1.84), (0.36, 1.84), (0.39, 1.9), (0.39, 2.06), (0.3, 2.12), (0.12, 2.14), (0.1, 2.2), (0, 2.2)], h, 12, sharp_deg=None)), "#D99561", "Metal")
    term = glass4(smooth_normals(blob("Terminal", (0, 0, 2.24 - h), (0.16, 0.16, 0.15), 10, 6)), "#EAFBFF", "detail")
    anim(term, (0, 0, 2.24 - h), (0, 0, 1), pulse(0.06, 0.8), flash(0.15))
    ds = [cap, term]
    for i in range(3):
        z0, r = 0.72 + i * 0.27, 0.95 - i * 0.07
        pts = [(r * math.cos(k / 16 * 5.4), r * math.sin(k / 16 * 5.4), z0 - h + 0.1 * k / 16) for k in range(17)]
        cb = bmesh.new()
        tube_bm(cb, pts, 0.06, 4)
        ds.append(glass4(smooth_normals(_obj(f"CoilSegment_{i + 1}", cb)), "#BBFAFF", "detail"))
    for i in range(2):
        a0 = i * math.pi + 0.5
        zig = [((0.22 + k * 0.11) * math.cos(a0), (0.22 + k * 0.11) * math.sin(a0), 2.18 - h + (0.06 if k % 2 else -0.06) - k * 0.04) for k in range(5)]
        sb = bmesh.new()
        tube_bm(sb, zig, [0.035, 0.03, 0.025, 0.02, 0.012], 5)
        spark = paint(_obj(f"Spark_{i + 1}", sb, smooth=False), "#9FF3FF", "Neon")
        anim(spark, (0, 0, 2.24 - h), (0, 0, 1), spin(140 if i == 0 else -110), flash(0.12), extra_idle=[flicker(0.25, 12)], lod_keep=(i == 0))
        ds.append(spark)
    charge = glass4(blob("ChargeCore", (0, 0, 0.9 - h), (0.42, 0.42, 0.5), 8, 5), "#29C8F0", "inner")
    anim(charge, (0, 0, 0.9 - h), (0, 0, 1), pulse(0.04, 0.9))
    bolt = bmesh.new()
    zz = [(0.0, -0.05, 1.32 - h), (0.08, -0.05, 1.12 - h), (-0.06, -0.05, 0.98 - h), (0.06, -0.05, 0.78 - h), (-0.02, -0.05, 0.6 - h)]
    tube_bm(bolt, zz, [0.04, 0.035, 0.03, 0.025, 0.012], 4)
    boltc = paint(_obj("InnerBolt", bolt, smooth=False), "#E6FFFF", "Neon")
    anim(boltc, (0, 0, 0.95 - h), (0, 0, 1), flicker(0.2, 10), flash(0.12))
    ds += [charge, boltc]
    return body, ds


# ------------------------------------------------------------------------------------------
# v4 batch 3: remaining Rares and Uncommons
# ------------------------------------------------------------------------------------------

@builder4("hourglass")
def v4_hourglass(gid):
    h = 2.65
    ctrl = [(0, 0.15), (0.68, 0.15), (0.75, 0.29), (0.66, 0.62), (0.43, 0.92), (0.19, 1.22), (0.17, 1.36), (0.39, 1.68), (0.66, 2.05), (0.75, 2.34), (0.68, 2.49), (0, 2.49)]
    prof = round_profile(ctrl, 0.03, steps=1, keep=(2, 9))
    body = glass4(body_lathe("Body", prof, h, 16, r=0), "#F8C16B", "shell", role="Body")
    frame = "#AD91DC"
    caps = []
    for label, z, flip in (("Bottom", 0.02, False), ("Top", 2.49, True)):
        p = [(0, 0), (0.7, 0), (0.8, 0.03), (0.84, 0.08), (0.8, 0.13), (0.72, 0.16), (0, 0.16)]
        p = [(r_, z + (0.16 - dz if flip else dz)) for r_, dz in p]
        if flip:
            p = list(reversed(p))
        cb = bmesh.new()
        lathe_bm(cb, p, h, 12)
        for k in range(3):
            a = k * math.tau / 3 + math.pi / 6
            ellipsoid_bm(cb, (0.6 * math.cos(a), 0.6 * math.sin(a), (z - 0.04 if not flip else z + 0.2) - h), (0.08, 0.08, 0.06), 6, 3)
        cap = paint(smooth_normals(_obj("FrameCap_" + label, cb)), frame, "SmoothPlastic")
        anim(cap, (0, 0, 1.33 - h), (0, 1, 0), None, kick(4), note="client flips the whole frame about the body centre (Hourglass kit)")
        caps.append(cap)
    posts = []
    for i, x in enumerate((-0.76, 0.76)):
        zs = [0.16 + k * (2.33 / 10) for k in range(11)]
        rs = [0.07 + 0.03 * math.sin(k / 10 * math.pi * 3) ** 2 for k in range(11)]
        pb = bmesh.new()
        tube_bm(pb, [(x, 0.0, z - h) for z in zs], rs, 5)
        post = paint(smooth_normals(_obj(f"FramePost_{i + 1}", pb)), frame, "SmoothPlastic")
        anim(post, (0, 0, 1.33 - h), (0, 1, 0), None, kick(4), note="flips with the frame")
        posts.append(post)
    sand = paint(smooth_normals(lathe3("SandInsert", chaikin([(0, 0.24), (0.6, 0.24), (0.62, 0.36), (0.42, 0.56), (0.12, 0.72), (0, 0.74)], iterations=1), h, 10, sharp_deg=None)), "#F6D36E", "SmoothPlastic")
    anim(sand, (0, 0, 0.24 - h), (0, 0, 1), None, squash(0.92), note="client scales it by charge")
    top = paint(smooth_normals(lathe3("SandTop", [(0, 1.5), (0.3, 1.74), (0.5, 1.92), (0.52, 1.98), (0, 1.98)], h, 10, sharp_deg=None)), "#F6D36E", "SmoothPlastic")
    anim(top, (0, 0, 1.4 - h), (0, 0, 1), pulse(0.02, 2.0))
    stream = paint(tube("SandStream", [(0, 0, 1.5 - h), (0, 0, 0.72 - h)], 0.03, 5), "#F6D36E", "SmoothPlastic")
    anim(stream, (0, 0, 1.5 - h), (0, 0, 1), flicker(0.15, 10), lod_keep=True)
    rb = bmesh.new()
    torus_bm(rb, (0, 0, 1.29 - h), 0.2, 0.03, 14, 4)
    waist = paint(_obj("TimeRing", rb), "#FFD27A", "Neon")
    anim(waist, (0, 0, 1.29 - h), (0, 0, 1), pulse(0.08, 1.4), flash(0.2))
    glints = bubbles("SandGlints", (0, 0, 0.45 - h), 0.4, 4, (0.02, 0.035), seed=13, color="#FFF6D0", neon=True, height=0.15)
    anim(glints, (0, 0, 0.45 - h), (0, 0, 1), pulse(0.3, 0.8))
    return body, caps + posts + [sand, top, stream, waist, glints]


@builder4("frostglobe")
def v4_frostglobe(gid):
    h = 2.40
    ctrl = [(0, 0.25), (0.48, 0.25), (0.73, 0.42), (0.91, 0.75), (0.95, 1.1), (0.88, 1.49), (0.66, 1.82), (0.34, 2.05), (0, 2.13)]
    prof = chaikin(ctrl, fixed=(1, 4), iterations=1)
    body = glass4(body_lathe("Body", prof, h, 22, r=0), "#9ECFFF", "shell", role="Body")
    collar = paint(smooth_normals(lathe3("SnowCollar", chaikin([(0, 0), (0.72, 0), (0.82, 0.08), (0.84, 0.18), (0.76, 0.28), (0.6, 0.32), (0, 0.32)], fixed=(1,), iterations=1), h, 16, sharp_deg=None)), "#EAFBFF", "SmoothPlastic")
    drift = paint(smooth_normals(blob("SnowDrift", (0, 0, 0.36 - h), (0.66, 0.66, 0.16), 12, 5)), "#FFFFFF", "SmoothPlastic")
    cb = bmesh.new()
    for x, y, z, r_, ht, tilt in ((0, 0, 0.98, 0.15, 0.95, 0.0), (-0.24, 0.05, 0.74, 0.1, 0.55, 0.35), (0.25, -0.04, 0.7, 0.09, 0.48, -0.4)):
        gem_bm(cb, (x, y, z - h), r_, ht, 6, Matrix.Rotation(tilt, 4, "Y"))
    sprout = _obj("CrystalSprout", cb, smooth=False)
    bevel_edges(sprout, 0.012, 1, 20)
    paint(sprout, "#C8F7FF", "Neon")
    anim(sprout, (0, 0, 0.5 - h), (0, 0, 1), pulse(0.05, 2.2), flash(0.2))
    rng = random.Random(11)
    fb = bmesh.new()
    for k in range(8):
        a = k * math.tau / 8 + rng.uniform(-0.2, 0.2)
        rr = rng.uniform(0.42, 0.72)
        z = rng.uniform(0.7, 1.75)
        m = Matrix.Translation((rr * math.cos(a), rr * math.sin(a), z - h)) @ Matrix.Rotation(a, 4, "Z")
        slab_bm(fb, star_points(3, 0.075, 0.025), 0.02, 0, 1, m)
    flakes = paint(_obj("SnowSwirl", fb, smooth=False), "#FFFFFF", "SmoothPlastic")
    anim(flakes, (0, 0, 1.2 - h), (0, 0, 1), spin(30), spin_boost(220), lod_keep=True)
    mist = glass4(blob("FrostMist", (0, 0, 1.15 - h), (0.78, 0.78, 0.72), 10, 6), "#CDEBFF", "inner")
    mist["studio_transparency"] = 0.6
    _set_input(next(n for n in mist.data.materials[0].node_tree.nodes if n.type == "BSDF_PRINCIPLED"), "Alpha", 0.35)
    pearl = glass4(smooth_normals(blob("HangPearl", (0, 0, -0.12), (0.13, 0.13, 0.12), 10, 6)), "#EAFBFF", "detail")
    anim(pearl, (0, 0, 0), (1, 0, 0), None, kick(10))
    return body, [collar, drift, sprout, flakes, mist, pearl]


@builder4("mason_jar")
def v4_mason_jar(gid):
    h = 2.25
    ctrl = [(0, 0), (0.63, 0), (0.84, 0.08), (0.91, 0.24), (0.88, 0.39), (0.85, 0.46), (0.85, 1.36), (0.89, 1.44), (0.85, 1.54), (0.76, 1.75), (0.76, 1.96), (0, 1.96)]
    body, prof = bottle(ctrl, h, 20, 0.03, "#BFEFFF")
    cap = paint(smooth_normals(lathe3("Cap", [(0, 1.96), (0.86, 1.96), (0.9, 2.0), (0.9, 2.18), (0.84, 2.25), (0, 2.25)], h, 16, sharp_deg=None)), "#F5C860", "Metal")
    anim(cap, (0, 0, 0), (0, 0, 1), None, kick(8), note="hit = a little quarter-turn twist")
    tpts = [(0.785 * math.cos(k / 20 * math.tau * 1.6), 0.785 * math.sin(k / 20 * math.tau * 1.6), 1.78 + 0.14 * k / 20 - h) for k in range(21)]
    th = bmesh.new()
    tube_bm(th, tpts, 0.03, 4)
    threads = glass4(smooth_normals(_obj("Threads", th)), "#D8F6FF", "detail")
    ds = [cap, threads]
    for i, z in enumerate((0.57, 1.19)):
        sb = bmesh.new()
        torus_bm(sb, (0, 0, z - h), 0.86, 0.035, 16, 4)
        ds.append(glass4(smooth_normals(_obj(f"StressBand_{i + 1}", sb)), "#C3F9ED", "detail"))
    for i, (a, z) in enumerate(((0.8, 0.9), (3.6, 1.3))):
        p = (0.42 * math.cos(a), 0.42 * math.sin(a), z - h)
        fb = bmesh.new()
        ellipsoid_bm(fb, p, (0.095, 0.095, 0.095), 8, 5)
        ff = paint(_obj(f"Firefly_{i + 1}", fb), "#FFF07A", "Neon")
        anim(ff, (0, 0, z - h), (0, 0, 1), spin((35, -28, 22)[i]), flash(0.2), extra_idle=[bob(0.08, 1.7, i * 2.0), pulse(0.25, 0.9, i)], lod_keep=(i == 0))
        ds.append(ff)
    ds.append(bubbles("JarBubbles", (0, 0.1, 0.9 - h), 0.5, 4, (0.025, 0.045), seed=29, height=0.5, segs=(4, 3)))
    anim(ds[-1], (0, 0.1, 0.9 - h), (0, 0, 1), bob(0.04, 1.7))
    return body, ds


@builder4("hot_sauce")
def v4_hot_sauce(gid):
    h = 2.66
    ctrl = [(0, 0), (0.34, 0), (0.48, 0.09), (0.53, 0.25), (0.51, 1.17), (0.45, 1.4), (0.28, 1.65), (0.19, 1.86), (0.19, 2.34), (0, 2.34)]
    body, prof = bottle(ctrl, h, 18, 0.03, "#FF5A4E")
    cap = lathe3("Cap", [(0, 2.34), (0.22, 2.34), (0.25, 2.38), (0.25, 2.54), (0.2, 2.58), (0.12, 2.6), (0.1, 2.66), (0, 2.66)], h, 12, sharp_deg=None)
    paint(smooth_normals(crimp(cap, 6, 0.05, -0.12)), "#354865", "SmoothPlastic")
    anim(cap, (0, 0, -0.32), (0, 0, 1), None, hop(0.06))
    bm2 = bmesh.new()
    lathe_bm(bm2, [(0, 0.62), (0.535, 0.62), (0.555, 0.64), (0.555, 0.98), (0.535, 1.0), (0, 1.0)], h, 18)
    for v in bm2.verts:
        if v.co.z > 0.9 - h and math.hypot(v.co.x, v.co.y) > 0.1:
            a = math.atan2(v.co.y, v.co.x)
            v.co.z += 0.14 * max(0.0, math.cos(3 * a + math.pi / 2)) ** 3
    band = paint(smooth_normals(_obj("FlameBand", bm2)), "#FFD36E", "SmoothPlastic")
    ds = [cap, band]
    for i, x in enumerate((-0.2, 0.0, 0.2)):
        eb = bmesh.new()
        slab_bm(eb, [(0, -0.09), (0.06, -0.03), (0.05, 0.04), (0.0, 0.11), (-0.05, 0.04), (-0.06, -0.03)], 0.04, 0.012, 1,
                Matrix.Translation((x, -0.53, 1.42 - h + (0.04 if i == 1 else 0))))
        ds.append(paint(smooth_normals(_obj(f"Ember_{i + 1}", eb)), "#FFBD62", "SmoothPlastic"))
    ch = bmesh.new()
    path = spline([(0.2, -0.12, 1.84 - h), (0.27, -0.2, 1.62 - h), (0.32, -0.26, 1.42 - h), (0.27, -0.27, 1.27 - h)], 8)
    tube_bm(ch, path, [0.06, 0.085, 0.09, 0.085, 0.075, 0.06, 0.045, 0.03, 0.015], 7)
    chili = paint(smooth_normals(_obj("ChiliCharm", ch)), "#E8242E", "SmoothPlastic")
    anim(chili, (0.2, -0.12, 1.86 - h), (0, 1, 0), sway(10, 1.5), kick(25), lod_keep=True)
    st = bmesh.new()
    tube_bm(st, [(0.19, -0.11, 1.95 - h), (0.2, -0.12, 1.84 - h), (0.23, -0.15, 1.8 - h)], [0.03, 0.035, 0.025], 5)
    stem = paint(_obj("ChiliStem", st), "#3FAE4C", "SmoothPlastic")
    anim(stem, (0.2, -0.12, 1.86 - h), (0, 1, 0), sway(10, 1.5), kick(25), note="moves with ChiliCharm")
    sauce = fill("Sauce", ctrl, h, 0.06, 0.06, 1.5, "#C8141E", 10, 10, 0.25)
    pops = bubbles("HeatBubbles", (0, -0.05, 1.15 - h), 0.3, 4, (0.025, 0.045), seed=17, color="#FFC08A", height=0.4, segs=(4, 3))
    anim(pops, (0, -0.05, 1.15 - h), (0, 0, 1), bob(0.06, 0.8))
    ds += [chili, stem, sauce, pops]
    return body, ds


@builder4("crystal_tumbler")
def v4_crystal_tumbler(gid):
    h = 2.05
    prof = [(0, 0), (0.56, 0), (0.74, 0.13), (0.77, 0.29), (0.69, 0.43), (0.7, 1.58), (0.79, 1.9), (0.79, 2.05), (0.66, 2.05), (0.6, 1.65), (0.56, 0.39), (0.48, 0.25), (0, 0.25)]
    body = lathe3("Body", prof, h, 12, flat=True)
    bevel_edges(body, 0.018, 1, 20)
    glass4(body, "#D7E9FF", "shell", role="Body")
    rb = bmesh.new()
    torus_bm(rb, (0, 0, -0.05), 0.72, 0.055, 24, 5)
    rim = glass4(smooth_normals(_obj("ThickRim", rb)), "#EAFBFF", "detail")
    mirror = glass4(smooth_normals(slab("MirrorFacet", [(-0.27, -1.54), (0.27, -1.54), (0.32, -0.45), (-0.32, -0.45)], 0.04, Matrix.Translation((0, -0.665, 0)), bevel=0.015, segments=1), 50), "#C4E9FF", "detail")
    water = glass4(lathe3("WaterFill", [(0, 0.28), (0.47, 0.28), (0.54, 0.4), (0.57, 1.25), (0, 1.25)], h, 12, sharp_deg=None), "#9FD8FF", "inner")
    anim(water, (0, 0, 1.25 - h), (1, 0, 0), slosh(10, 0.3))
    ice = glass4(rounded_box("IceCube", (0.44, 0.44, 0.42), (0.06, -0.04, 1.2 - h), 0.09, 2, Quaternion((0.3, 0.2, 1), 0.5)), "#EAF7FF", "detail")
    anim(ice, (0.06, -0.04, 1.2 - h), (0, 0, 1), spin(18), hop(0.1), extra_idle=[bob(0.05, 1.9)], lod_keep=True)
    fizz = bubbles("Bubbles", (0, 0, 0.75 - h), 0.38, 4, (0.025, 0.045), seed=19, height=0.4, segs=(4, 3))
    anim(fizz, (0, 0, 0.75 - h), (0, 0, 1), bob(0.05, 1.4))
    return body, [rim, mirror, water, ice, fizz]


@builder4("chime")
def v4_chime(gid):
    h = 2.50
    ctrl = [(0, 0), (0.92, 0), (0.99, 0.11), (0.94, 0.26), (0.73, 0.55), (0.61, 1.2), (0.49, 1.61), (0.29, 1.91), (0.25, 2.3), (0, 2.3)]
    prof = chaikin(ctrl, fixed=(1, 8), iterations=1)
    body = glass4(body_lathe("Body", prof, h, 22, r=0), "#80E7DE", "shell", role="Body")
    clap = bmesh.new()
    tube_bm(clap, [(0, -0.3, 0.62 - h), (0, -0.3, 0.3 - h)], 0.04, 5)
    ellipsoid_bm(clap, (0, -0.3, 0.22 - h), (0.2, 0.2, 0.2), 10, 6)
    clapper = glass4(smooth_normals(_obj("Clapper", clap)), "#F8E6B0", "detail")
    anim(clapper, (0, -0.3, 0.62 - h), (1, 0, 0), sway(6, 1.3), kick(30), lod_keep=True)
    rb = bmesh.new()
    torus_bm(rb, (0, 0, 0.12 - h), 0.95, 0.07, 22, 5)
    rim = glass4(smooth_normals(_obj("BellRim", rb)), "#C5FFF5", "detail")
    cb = bmesh.new()
    torus_bm(cb, (0, 0, 2.38 - h), 0.11, 0.045, 10, 4, Matrix.Rotation(math.pi / 2, 4, "X"))
    lathe_bm(cb, [(0, 2.28), (0.24, 2.28), (0.27, 2.32), (0.18, 2.36), (0, 2.36)], h, 10)
    crown = glass4(smooth_normals(_obj("Crown", cb)), "#C5FFF5", "detail")
    bow = bmesh.new()
    for s_ in (-1, 1):
        slab_bm(bow, [(0, 0), (s_ * 0.12, 0.1), (s_ * 0.24, 0.08), (s_ * 0.26, -0.04), (s_ * 0.14, -0.08)][::s_], 0.05, 0.02, 1, Matrix.Translation((0, -0.27, 2.12 - h)))
        slab_bm(bow, [(0, 0), (s_ * 0.08, -0.08), (s_ * 0.13, -0.3), (s_ * 0.05, -0.26), (s_ * 0.02, -0.08)][::s_], 0.04, 0.015, 1, Matrix.Translation((0, -0.27, 2.12 - h)))
    ellipsoid_bm(bow, (0, -0.28, 2.12 - h), (0.06, 0.04, 0.06), 6, 4)
    centre = Vector((0, -0.27, 2.12 - h))
    for v in bow.verts:
        v.co = centre + (v.co - centre) * 1.7 + Vector((0, -0.05, 0))
    ribbon = paint(smooth_normals(_obj("Ribbon", bow), 60), "#FF8FB0", "SmoothPlastic")
    anim(ribbon, (0, -0.27, 2.12 - h), (0, 1, 0), sway(5, 1.6), kick(12))
    inner = glass4(lathe3("InnerTone", [(0, 0.3), (0.6, 0.3), (0.5, 1.0), (0.36, 1.5), (0, 1.62)], h, 12, sharp_deg=None), "#3FCFC0", "inner")
    notes = bubbles("ChimeBubbles", (0, 0, 1.0 - h), 0.45, 4, (0.025, 0.045), seed=23, height=0.5, segs=(4, 3))
    anim(notes, (0, 0, 1.0 - h), (0, 0, 1), spin(20), spin_boost(180))
    return body, [clapper, rim, crown, ribbon, inner, notes]


# ------------------------------------------------------------------------------------------
# v4 batch 4: Commons (simple and clean: rounded glass, one fill or charm, 1-2 moving parts)
# ------------------------------------------------------------------------------------------

@builder4("milk_bottle")
def v4_milk_bottle(gid):
    h = 2.48
    ctrl = [(0, 0), (0.48, 0), (0.63, 0.08), (0.68, 0.24), (0.68, 1.27), (0.65, 1.48), (0.54, 1.68), (0.37, 1.85), (0.3, 2.01), (0.3, 2.2), (0.37, 2.23), (0.37, 2.3), (0, 2.3)]
    body, prof = bottle(ctrl, h, 20, 0.03, "#FFFFFF")
    cap = lathe3("Cap", [(0, 2.3), (0.36, 2.3), (0.39, 2.34), (0.39, 2.43), (0.33, 2.48), (0, 2.48)], h, 14, sharp_deg=None)
    paint(smooth_normals(crimp(cap, 7, 0.04, -0.06)), "#8DCFFF", "SmoothPlastic")
    anim(cap, (0, 0, -0.18), (0, 0, 1), None, hop(0.07))
    milk = paint(smooth_normals(lathe3("MilkInsert", inset(ctrl, 0.08, 0.06, 1.52), h, 12, sharp_deg=None)), "#FFF6DD", "SmoothPlastic")
    anim(milk, (0, 0, 1.52 - h), (1, 0, 0), slosh(10, 0.25), lod_keep=True)
    rb = bmesh.new()
    torus_bm(rb, (0, 0, 2.15 - h), 0.32, 0.07, 16, 5)
    foam = glass4(smooth_normals(_obj("FoamRim", rb)), "#EAFBFF", "detail")
    ds = [cap, milk, foam]
    for i in range(3):
        ds.append(glass4(smooth_normals(blob(f"FoamBubble_{i + 1}", ((i - 1) * 0.17, -0.26, 2.19 - h), (0.09, 0.08, 0.09), 8, 5)), "#EAFBFF", "detail"))
    return body, ds


@builder4("pickle_jar")
def v4_pickle_jar(gid):
    h = 2.20
    ctrl = [(0, 0), (0.64, 0), (0.85, 0.09), (0.93, 0.28), (0.93, 1.4), (0.87, 1.61), (0.79, 1.73), (0.79, 1.87), (0, 1.87)]
    body, prof = bottle(ctrl, h, 22, 0.035, "#C9F2A6")
    cap = lathe3("Cap", [(0, 1.87), (0.9, 1.87), (0.96, 1.92), (0.96, 2.14), (0.9, 2.2), (0, 2.2)], h, 24, sharp_deg=None)
    paint(smooth_normals(crimp(cap, 24, 0.018, -0.03)), "#76B867", "SmoothPlastic")
    ds = [cap]
    rng = random.Random(5)
    for i, (x, tilt) in enumerate(((-0.3, 0.12), (0.31, -0.1))):
        zs = [0.32 + k * 0.1 for k in range(12)]
        path = [(x + math.sin(tilt) * (z - 0.9), -0.2, z - h) for z in zs]
        rs = [0.17 * math.sin(math.pi * (0.08 + 0.84 * k / 11)) ** 0.5 + 0.02 for k in range(12)]
        pb = bmesh.new()
        tube_bm(pb, path, rs, 8)
        for v in pb.verts:
            d = v.co - Vector((x, -0.2, v.co.z))
            if d.length > 0.05:
                v.co += d.normalized() * rng.uniform(-0.012, 0.02)
        pk = glass4(smooth_normals(_obj(f"Pickle_{i + 1}", pb)), "#71B545", "detail")
        anim(pk, (x, -0.2, 0.9 - h), (0, 1, 0), sway(4, 2.4, i * 1.4), hop(0.05), extra_idle=[bob(0.04, 2.0, i * 1.1)], lod_keep=(i == 0))
        ds.append(pk)
    brine = fill("Brine", ctrl, h, 0.08, 0.08, 1.55, "#D8F5B0", 12, 8, 0.25)
    brine["studio_transparency"] = 0.65
    node = next(n for n in brine.data.materials[0].node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    _set_input(node, "Alpha", 0.3)
    _set_input(node, "Transmission Weight", 0.95)
    bub = bubbles("BrineBubbles", (0, 0.2, 0.9 - h), 0.5, 4, (0.025, 0.045), seed=31, height=0.5, segs=(4, 3))
    anim(bub, (0, 0.2, 0.9 - h), (0, 0, 1), bob(0.04, 1.8))
    return body, ds + [brine, bub]


@builder4("ketchup_bottle")
def v4_ketchup_bottle(gid):
    h = 2.62
    ctrl = [(0, 0), (0.44, 0), (0.6, 0.08), (0.65, 0.24), (0.61, 0.84), (0.53, 1.42), (0.41, 1.7), (0.24, 1.94), (0.21, 2.15), (0, 2.15)]
    body, prof = bottle(ctrl, h, 20, 0.03, "#FF5A4E")
    cap = paint(smooth_normals(lathe3("Cap", [(0, 2.12), (0.25, 2.12), (0.28, 2.16), (0.28, 2.34), (0.22, 2.38), (0, 2.38)], h, 14, sharp_deg=None)), "#F8D76D", "SmoothPlastic")
    nozzle = paint(smooth_normals(lathe3("SqueezeNozzle", [(0, 2.36), (0.12, 2.36), (0.1, 2.5), (0.06, 2.58), (0, 2.6)], h, 10, sharp_deg=None)), "#F8D76D", "SmoothPlastic")
    flip = paint(smooth_normals(lathe3("FlipCap", [(0, 2.44), (0.17, 2.44), (0.18, 2.56), (0.15, 2.62), (0, 2.62)], h, 12, sharp_deg=None)), "#FFC94A", "SmoothPlastic")
    anim(flip, (0.18, 0, 2.46 - h), (0, 1, 0), None, kick(35, 3.5, 0.4), lod_keep=True, note="hit flips the lid open, then it snaps shut")
    badge = paint(smooth_normals(blob("TomatoBadge", (0, -0.6, 0.82 - h), (0.27, 0.06, 0.23), 12, 6)), "#EE7964", "SmoothPlastic")
    leaf = paint(slab("TomatoLeaf", star_points(5, 0.1, 0.035), 0.03, Matrix.Translation((0, -0.66, 1.03 - h)), bevel=0.01, segments=1), "#4FB548", "SmoothPlastic")
    sauce = fill("SauceFill", ctrl, h, 0.06, 0.06, 1.25, "#D11E1E", 10, 10, 0.25)
    return body, [cap, nozzle, flip, badge, leaf, sauce]


@builder4("glass_cup")
def v4_glass_cup(gid):
    h = 1.95
    ctrl = [(0, 0), (0.5, 0), (0.6, 0.06), (0.63, 0.22), (0.74, 1.78), (0.75, 1.9), (0.72, 1.95), (0.63, 1.95), (0.61, 1.84), (0.52, 0.29), (0.46, 0.2), (0, 0.2)]
    body = glass4(body_lathe("Body", round_profile(ctrl, 0.02, steps=1), h, 22, r=0), "#DFF6FF", "shell", role="Body")
    rb = bmesh.new()
    torus_bm(rb, (0, 0, -0.05), 0.69, 0.055, 24, 4)
    rim = glass4(smooth_normals(_obj("ThickRim", rb)), "#EAFBFF", "detail")
    pts = [(0.12, 0.05, 0.28 - h), (0.2, 0.05, 1.3 - h), (0.27, 0.05, 1.82 - h), (0.3, 0.05, 1.9 - h), (0.36, 0.05, 1.96 - h), (0.46, 0.05, 2.0 - h), (0.66, 0.05, 2.06 - h)]
    path = spline(pts, 18)
    rs = [0.055 + (0.01 * math.cos(k * 3.0) if (1.75 - h < p.z < 2.0 - h and p.x < 0.42) else 0) for k, p in enumerate(path)]
    sb = bmesh.new()
    tube_bm(sb, path, rs, 8)
    straw = paint(smooth_normals(_obj("Straw", sb)), "#FF7AA8", "SmoothPlastic")
    anim(straw, (0.12, 0.05, 0.28 - h), (0, 1, 0), sway(4, 2.2), kick(15), lod_keep=True)
    juice = glass4(lathe3("Juice", [(0, 0.24), (0.47, 0.24), (0.52, 0.32), (0.6, 1.25), (0, 1.25)], h, 12, sharp_deg=None), "#FFB0C8", "inner")
    anim(juice, (0, 0, 1.25 - h), (1, 0, 0), slosh(12, 0.35))
    bub = bubbles("Bubbles", (0, -0.1, 0.75 - h), 0.38, 4, (0.025, 0.045), seed=37, height=0.4, segs=(4, 3))
    anim(bub, (0, -0.1, 0.75 - h), (0, 0, 1), bob(0.05, 1.3))
    return body, [rim, straw, juice, bub]


@builder4("water_jug")
def v4_water_jug(gid):
    h = 2.65
    prof = [(0, 0), (0.6, 0), (0.84, 0.13), (0.96, 0.46), (0.95, 1.25), (0.85, 1.57), (0.59, 1.91), (0.4, 2.25), (0.47, 2.36), (0.49, 2.57), (0.45, 2.65), (0.33, 2.65), (0.31, 2.38), (0.46, 1.99), (0.74, 1.53), (0.82, 1.23), (0.81, 0.48), (0.57, 0.23), (0, 0.23)]
    prof = chaikin(prof, fixed=(1, 6, 7, 8, 9, 10, 11, 12, 13, 17), iterations=1)
    body = glass4(body_lathe("Body", prof, h, 22, r=0), "#BFEFFF", "shell", role="Body")
    path = spline([(-0.52, 0, 2.05 - h), (-0.95, 0, 2.02 - h), (-1.32, 0, 1.68 - h), (-1.36, 0, 1.12 - h), (-1.12, 0, 0.62 - h), (-0.88, 0, 0.52 - h)], 16)
    hb = bmesh.new()
    tube_bm(hb, path, 0.13, 8)
    handle = glass4(smooth_normals(_obj("Handle", hb)), "#BDEBFF", "detail")
    water = glass4(lathe3("WaterInsert", [(0, 0.27), (0.54, 0.27), (0.74, 0.48), (0.76, 1.12), (0, 1.12)], h, 14, sharp_deg=None), "#51BFF2", "inner")
    anim(water, (0, 0, 1.12 - h), (1, 0, 0), slosh(14, 0.4), lod_keep=True, note="client also scales it by charge")
    bub = bubbles("Bubbles", (0, -0.1, 0.7 - h), 0.5, 4, (0.03, 0.05), seed=41, height=0.3, segs=(4, 3))
    anim(bub, (0, -0.1, 0.7 - h), (0, 0, 1), bob(0.05, 1.5))
    return body, [handle, water, bub]


@builder4("lemonade_bottle")
def v4_lemonade_bottle(gid):
    h = 2.60
    ctrl = [(0, 0), (0.46, 0), (0.61, 0.08), (0.66, 0.25), (0.65, 1.18), (0.6, 1.43), (0.45, 1.69), (0.29, 1.94), (0.25, 2.15), (0.25, 2.37), (0, 2.37)]
    body, prof = bottle(ctrl, h, 20, 0.03, "#FFF27A")
    cap = paint(smooth_normals(lathe3("Cap", [(0, 2.37), (0.27, 2.37), (0.3, 2.41), (0.3, 2.55), (0.25, 2.6), (0, 2.6)], h, 14, sharp_deg=None)), "#6CD381", "SmoothPlastic")
    rind = paint(smooth_normals(blob("LemonRind", (0.12, -0.6, 1.24 - h), (0.32, 0.06, 0.32), 16, 6)), "#EABF3D", "SmoothPlastic")
    pulp = paint(smooth_normals(blob("LemonPulp", (0.12, -0.65, 1.24 - h), (0.25, 0.025, 0.25), 16, 4)), "#FFF0A2", "SmoothPlastic")
    m = Matrix.Translation((-0.3, -0.18, 2.02 - h)) @ Matrix.Rotation(-0.35, 4, "Y") @ Matrix.Rotation(1.25, 4, "X")
    rb = bmesh.new()
    torus_bm(rb, (0, 0, 0), 0.27, 0.045, 16, 4, m)
    slc = paint(smooth_normals(_obj("LemonSlice", rb)), "#F2C230", "SmoothPlastic")
    anim(slc, (-0.24, -0.08, 2.1 - h), (0, 1, 0), sway(4, 2.0), kick(14), lod_keep=True)
    fb = bmesh.new()
    lathe_bm(fb, [(0, -0.03), (0.25, -0.03), (0.25, 0.03), (0, 0.03)], 0, 16)
    for v in fb.verts:
        if math.hypot(v.co.x, v.co.y) > 0.1:
            k = 1 - 0.1 * max(0.0, math.cos(8 * math.atan2(v.co.y, v.co.x))) ** 8
            v.co.x *= k
            v.co.y *= k
    bmesh.ops.transform(fb, matrix=m, verts=fb.verts)
    flesh = paint(_obj("LemonSliceFlesh", fb), "#FFF3A6", "SmoothPlastic")
    anim(flesh, (-0.24, -0.08, 2.1 - h), (0, 1, 0), sway(4, 2.0), kick(14), note="moves with LemonSlice")
    lem = fill("Lemonade", ctrl, h, 0.07, 0.08, 1.4, "#FFE14A", 10, 10, 0.3)
    fizz = bubbles("Fizz", (0, 0.1, 0.8 - h), 0.38, 4, (0.025, 0.045), seed=43, height=0.5, segs=(4, 3))
    anim(fizz, (0, 0.1, 0.8 - h), (0, 0, 1), bob(0.05, 1.0))
    return body, [cap, rind, pulp, slc, flesh, lem, fizz]
