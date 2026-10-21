"""Builds one runnable Luau chunk for tools/studio/install_glassies_v4.luau (DATA + OPTIONS + installer).

    python3 tools/studio/glassy_install_chunk.py --mode dry  pop jam prism            > /tmp/chunk.luau
    python3 tools/studio/glassy_install_chunk.py --mode install --set launch            > /tmp/chunk.luau
    python3 tools/studio/glassy_install_chunk.py --mode verify --set all --out /tmp/verify.luau
    # test the fit without any upload, against the creator's raw release_v2 import kept in Studio:
    python3 tools/studio/glassy_install_chunk.py --mode dry --version release_v2 \\
        --raw pop=ServerStorage.CombatReleaseBackups.RawBeforeNormalization_20261015.pop_bundle pop

Then run the chunk with the Studio MCP execute_luau (Edit, after `tools/studio_lock.sh acquire <name>`).
To keep chunks small: send `--installer-only` once (registers _G.GlassyInstallV4), then data chunks with `--split`.
Keep a chunk to about 6 glassies (each carries ~45 parts of data); --set splits nothing by itself.
Asset ids come from the Open Cloud Records written by tools/opencloud/upload_assets.py:
  docs/art/glassy_revamp/roblox_assets.json (24 revamped), docs/art/launch_glassies/roblox_assets.json (12 launch) and
  docs/art/daily_glassies/roblox_assets.json (2 Daily Rewards exclusives).
Part data comes from assets/blender/glassies/<id>/<version>/manifest.json (Blender -> Roblox: (x, y, z) -> (x, z, -y)).
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SETS = {
    "revamp": ["pop", "jam", "prism", "milk_bottle", "pickle_jar", "ketchup_bottle", "glass_cup", "water_jug", "lemonade_bottle",
               "mason_jar", "hot_sauce", "crystal_tumbler", "chime", "crescent_axe", "briar_flask", "arc_coil", "hourglass",
               "frostglobe", "rocket_pop", "prism_blade", "glass_duck", "comet", "glass_dragon", "galaxy_orb"],
    "launch": ["fishbowl", "cookie_jar", "glass_top", "bubble_wand", "piggy_bank", "light_bulb", "potion_flask", "honey_bear",
               "crystal_ball", "grizzly_guardian", "glass_unicorn", "glass_phoenix"],
}
SETS["daily"] = ["whiskers", "midnight_moon"]  # Daily Rewards exclusives (decision 115)
SETS["all"] = SETS["revamp"] + SETS["launch"] + SETS["daily"]
RECORDS = ["docs/art/glassy_revamp/roblox_assets.json", "docs/art/launch_glassies/roblox_assets.json",
           "docs/art/daily_glassies/roblox_assets.json"]


def lua(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int,)) and not isinstance(v, bool):
        return str(v)
    if isinstance(v, float):
        return ("%.6f" % v).rstrip("0").rstrip(".") if abs(v) > 1e-12 else "0"
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, (list, tuple)):
        return "{" + ", ".join(lua(x) for x in v) + "}"
    if isinstance(v, dict):
        return "{" + ", ".join("%s = %s" % (k, lua(x)) for k, x in v.items()) + "}"
    if v is None:
        return "nil"
    raise TypeError(type(v))


def rb(v):
    return [v[0], v[2], -v[1]]


def entry_for(gid, version, assets, raw):
    m = json.loads((ROOT / "assets/blender/glassies" / gid / version / "manifest.json").read_text())
    parts = []
    for e in m["meshes"]:
        lo, hi = e["bounds_blender"]
        a, b = rb(lo), rb(hi)
        rlo = [min(a[k], b[k]) for k in range(3)]
        rhi = [max(a[k], b[k]) for k in range(3)]
        mat = e["material"]
        tr = e.get("transparency")
        if tr is None:
            tr = 0.28 if mat == "Glass" else 0
        p = {"Name": e["name"], "Source": e["source_name"], "Role": e["role"],
             "Center": [(rlo[k] + rhi[k]) / 2 for k in range(3)], "Size": [rhi[k] - rlo[k] for k in range(3)],
             "Color": e["color"], "Material": mat, "Transparency": float(tr), "Pivot": rb(e.get("animation_pivot", [0, 0, 0])),
             "EffectOnly": bool(e.get("effect_only", False))}
        if "motion" in e:
            p["Motion"] = json.dumps(e["motion"], separators=(",", ":"))
        parts.append(p)
    out = {"Parts": parts}
    bundle, icon = assets.get(gid + "_bundle"), assets.get(gid + "_icon")
    if bundle:
        out["AssetId"] = int(bundle["AssetId"])
    if icon:
        out["IconAssetId"] = int(icon["AssetId"])
    if raw.get(gid):
        out["RawPath"] = raw[gid]
    if not bundle and not raw.get(gid):
        print("note: %s has no uploaded bundle in the Records yet" % gid, file=sys.stderr)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ids", nargs="*")
    ap.add_argument("--set", choices=list(SETS))
    ap.add_argument("--mode", choices=["dry", "install", "verify"], default="dry")
    ap.add_argument("--version", default="v4")
    ap.add_argument("--raw", action="append", default=[], help="id=DataModel.path of a raw import to test with")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--library", help="install into this DataModel path instead of ReplicatedStorage.Assets.Glassies (testing)")
    ap.add_argument("--backup", default="GlassiesBeforeV4")
    ap.add_argument("--out")
    ap.add_argument("--split", action="store_true",
                    help="data-only chunk that calls _G.GlassyInstallV4 (send the installer once first with --installer-only)")
    ap.add_argument("--installer-only", action="store_true", help="chunk that only registers _G.GlassyInstallV4")
    ap.add_argument("--rojo-carrier", action="store_true",
                    help="write a TEMPORARY (never commit) src/tests/_GlassyInstallV4/ module tree (installer + Batch1..6 data) "
                         "that Rojo syncs to ServerStorage.Tests._GlassyInstallV4; each MCP call is then one short require")
    args = ap.parse_args()
    body = (ROOT / "tools/studio/install_glassies_v4.luau").read_text()
    wrapped = "_G.GlassyInstallV4 = function(DATA, OPTIONS)\n" + body + "\nend\n"
    if args.installer_only:
        chunk = wrapped + 'return "installer registered as _G.GlassyInstallV4"\n'
        if args.out:
            Path(args.out).write_text(chunk)
        else:
            sys.stdout.write(chunk)
        return
    if args.rojo_carrier:
        out = ROOT / "src/tests/_GlassyInstallV4"
        out.mkdir(parents=True, exist_ok=True)
        assets = {}
        for rec in RECORDS:
            if (ROOT / rec).exists():
                assets.update(json.loads((ROOT / rec).read_text()).get("Assets", {}))
        allids = SETS["revamp"] + SETS["launch"]
        for i in range(6):
            ids = allids[i * 6:(i + 1) * 6]
            data = {g: entry_for(g, args.version, assets, {}) for g in ids}
            (out / f"Batch{i + 1}.luau").write_text("-- TEMPORARY install data (do not commit).\nreturn {\n" +
                                                     "".join("\t%s = %s,\n" % (g, lua(e)) for g, e in data.items()) + "}\n")
        (out / "init.luau").write_text("-- TEMPORARY (do not commit): Rojo carrier for tools/studio/install_glassies_v4.luau.\n"
                                       "local function run(DATA, OPTIONS)\n" + body + "\nend\nreturn function(batches, OPTIONS)\n"
                                       "\tlocal DATA = {}\n\tfor _, b in batches do\n\t\tfor id, e in require(script:FindFirstChild(b)) do\n"
                                       "\t\t\tDATA[id] = e\n\t\tend\n\tend\n\treturn run(DATA, OPTIONS)\nend\n")
        print("wrote", out.relative_to(ROOT), "(Batch1-6: revamp 1-4, launch 5-6). Delete it after the install.", file=sys.stderr)
        return
    ids = list(args.ids) + (SETS[args.set] if args.set else [])
    if not ids:
        ap.error("give glassy ids or --set")
    assets = {}
    for rec in RECORDS:
        p = ROOT / rec
        if p.exists():
            assets.update(json.loads(p.read_text()).get("Assets", {}))
    raw = dict(r.split("=", 1) for r in args.raw)
    data = {gid: entry_for(gid, args.version, assets, raw) for gid in ids}
    options = {"Mode": args.mode, "Version": args.version, "Import": "GlassyV4Import", "Backup": args.backup, "Force": args.force}
    if args.library:
        options["Library"] = args.library
    chunk = "local DATA = {\n" + "".join("\t%s = %s,\n" % (gid, lua(e)) for gid, e in data.items()) + "}\n"
    chunk += "local OPTIONS = %s\n" % lua(options)
    if args.split:
        chunk += 'assert(_G.GlassyInstallV4, "send the --installer-only chunk first")\nreturn _G.GlassyInstallV4(DATA, OPTIONS)\n'
    else:
        chunk += body
    if args.out:
        Path(args.out).write_text(chunk)
        print("%s: %d glassies, %d KB" % (args.out, len(ids), len(chunk) // 1024), file=sys.stderr)
    else:
        sys.stdout.write(chunk)


if __name__ == "__main__":
    main()
