"""Generate the release production table, import list and visual timeline drafts.

No runtime catalog/pool/data changes. Source briefs remain the authority for rules.
"""
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[2]
roster_path=ROOT/'docs/design/RELEASE_ROSTER_24.json'
roster=json.loads(roster_path.read_text())
rows=roster['roster'];assert len(rows)==24 and len({r['id'] for r in rows})==24
OUT=ROOT/'docs/art/combat_release';OUT.mkdir(parents=True,exist_ok=True)
patterns={
 'pop':('contact_3','pressure_ring','glass_glint'),
 'jam':('turnaround_2','lid_guard','glass_glint'),
 'prism':('ready_timer','narrow_ray','glass_glint'),
 'crescent_axe':('turnaround_2','axe_sweep','directional_streak'),
 'briar_flask':('turnaround_3_then_contact','thorn_bloom','shard_fleck'),
 'arc_coil':('contact_3','electric_arc','electricity_strip'),
 'milk_bottle':('low_hp_once','foam_seal','soft_puff'),
 'pickle_jar':('contact_3','brine_tether','droplet_mask'),
 'ketchup_bottle':('contact_3_then_next_contact','splat_pop','droplet_mask'),
 'glass_cup':('turnaround_2','rim_rush','directional_streak'),
 'water_jug':('received_contacts_2_then_turnaround','splash_cone','droplet_mask'),
 'lemonade_bottle':('ready_timer','three_pip_fan','glass_glint'),
 'mason_jar':('heavy_received_then_contact','lid_counter','directional_streak'),
 'hot_sauce':('low_hp_once','heat_rush','directional_streak'),
 'crystal_tumbler':('ranged_catch_or_window_expiry','mirror_return','glass_glint'),
 'chime':('turnaround_2','traveling_ring','glass_glint'),
 'hourglass':('stored_damage_then_turnaround','sand_shot','shard_fleck'),
 'frostglobe':('ready_timer','frost_cone','soft_puff'),
 'prism_blade':('turnaround_2','traveling_slash','directional_streak'),
 'rocket_pop':('turnaround_3','booster_rush','directional_streak'),
 'glass_duck':('low_hp_once','bubble_guard','glass_glint'),
 'comet':('charged_contact_then_turnaround','returning_star','glass_glint'),
 'glass_dragon':('long_ready_timer','three_pulse_breath','soft_puff'),
 'galaxy_orb':('long_ready_timer','bounded_orbit','glass_glint'),
}
lines=['# Combat release production status','','Generated from actual package manifests. Blender exports and round-trips do not establish a Roblox import.','','| Batch | Glassy | Intact tris | Closed shards | FBX round-trip | Studio import | Live kit |','|---|---|---:|---:|---|---|---|']
imports=['# Combat release — batch import','','The connected Studio MCP has no local FBX importer. These are the completed packages for the creator’s normal Studio 3D Importer. No desktop automation is needed.','','Import one **bundle FBX** per glassy into an isolated `ServerStorage.CombatReleaseImports` folder. Each bundle contains Body, recolorable details and 16 aligned shards. Individual body/details/shards files are also included for recovery.','','Settings/checks: 1 unit = 1 stud; preserve imported pivots, keep meshes separate, import no cameras/lights, no collision on cosmetic parts. Do not promote over live assets yet. Match names and role attributes to manifest; use its colors/materials and bounds. Confirm source origin `(0,0,0)` at the hang point. Use DoubleSided on the thin VFX sheets if their back-face test needs it. Verify actual scale against each manifest rather than compensating by eye.','','First proof: import Pop plus the VFX kit, check hang pivot/scale/shard alignment and texture alpha. Then import the other five A assets. Live six-kit work precedes gameplay expansion. B–D can be imported together afterward.','','## Files','']
timelines={};complete=0;imported=0
for row in rows:
    gid=row['id'];folder=ROOT/'assets/blender/glassies'/gid/'release_v2';p=folder/'manifest.json'
    if p.exists():
        m=json.loads(p.read_text());complete+=1;passed=m.get('fbx_roundtrip',{}).get('passed',False)
        body=next(e for e in m['meshes'] if e['role']=='Body')
        lo,hi=body['bounds_blender'];center=[(a+b)/2 for a,b in zip(lo,hi)]
        markers={'Hang':[0,0,0],'BodyCenter':center,'BodyFront':[center[0],lo[1],center[2]]}
        for e in m['meshes']:
            if e['role']!='Detail':continue
            a,b=e['bounds_blender'];c=[(x+y)/2 for x,y in zip(a,b)]
            if any(word in e['source_name'] for word in ('Lens','Nozzle','Terminal','Snout','Clapper','Mirror','Charge','Ember','Coil','Thorn','Seed','Core')):markers[e['source_name']]=c
            if any(abs(x)>.00001 for x in e['animation_pivot']):markers[e['source_name']+'_Pivot']=e['animation_pivot']
        m['markers_blender']=markers;m['markers_roblox']={k:[v[0],v[2],-v[1]] for k,v in markers.items()}
        m['measured_body_dimensions_roblox']=[hi[0]-lo[0],hi[2]-lo[2],hi[1]-lo[1]]
        m['collision_config_promoted']=False
        p.write_text(json.dumps(m,indent=2)+'\n')
        native=m.get('status',{}).get('studio_normalized',False)
        imported+=int(native)
        lines.append(f"| {row['batch']} | {row['name']} | {m['intact_triangles']} | {m['shard_count']} | {'Pass' if passed else 'Pending'} | {'Staged / normalized' if native else 'Pending'} | Pending |")
        imports.append(f"- **{row['batch']} · {row['name']}**: `{folder.as_posix()}/{gid}_bundle.fbx` — {m['intact_triangles']} intact triangles; `manifest.json` alongside.")
        row['status']='studio_imported_normalized_pending_live_kit' if native else 'exported_blender_validated_pending_studio_import'
    else:lines.append(f"| {row['batch']} | {row['name']} | — | — | Pending | Pending | Pending |")
    trigger,action,texture=patterns[gid]
    timelines[gid]={'status':'presentation draft; not connected to live rules','trigger_brief':trigger,'action':action,'charge_seconds':.30 if gid!='glass_dragon' else .45,'action_seconds':.14 if gid!='glass_dragon' else .36,'contact_seconds':.08,'tail_seconds':.25,'static_texture':texture,'contact_texture':'glass_glint','contact_particles':4,'heavy_particles':6,'shatter_particles':18,'flipbook':'pressure_pop_4x4' if gid=='pop' else 'glass_dust_4x4','ordinary_hit_uses_flipbook':False,'result_branches':['hit','miss','block'],'contact_requires_server_hit':True,'miss_uses_locked_cast_direction':True,'cleanup_on':['tail_end','round_end','shatter','forfeit','watch_stop','destroy'],'audio':'existing approved Clink/Break/Tinkle/Whoosh only'}
lines+=['',f'Exported: **{complete}/24**. Native imported/normalized: **{imported}/24**. Live kits remain pending.','','## Required next gate','','Imports are normalized and staged under ServerStorage.CombatReleaseStaged. All 24 native bounds/pivots/part flags and 384 shard origins pass checks; the first six were reviewed at the fixed camera and current sky. Next: authoritative trigger/attack vocabulary and live six-kit/VFX animation proof, then all-24 kit expansion, profile ownership audit, deliberate rarity/acquisition mapping, release allowlist, simulator/native/multiplayer/performance checks. No live pools or inventories changed in this asset pass.' if imported==24 else 'Creator imports the FBXs, then verify the revised first six against the actual fixed camera and current sky before gameplay expansion.','','## Previews','','[Native batch A](../../testing/combat_release/native_batch_A.png) · [Blender batch A](batch_A.png) · [Batch B](batch_B.png) · [Batch C](batch_C.png) · [Batch D](batch_D.png). Blender sheets include genuine 64px samples; before/after sheets use original saved sources.']
imports+=['','## Shared kit','',f"- `{(ROOT/'assets/blender/vfx/combat_release/combat_vfx_bundle.fbx').as_posix()}` — 10 separate reusable meshes; origins recorded in `manifest.json`.",f"- `{(ROOT/'assets/vfx/combat_release').as_posix()}` — six 256px static RGBA textures, two 512px 4×4 atlases; source frames in `frames/`.",'','All eight texture images are already uploaded. Use their actual IDs in `assets/vfx/combat_release/roblox_textures.json`; no reupload is needed. Native visual alpha/order verification remains pending.','','Keep ParticleEmitters disabled at rest, use bounded `Emit`, and `Clear` on interruption. No shaders, animation rigs or physics come from the FBXs.','','Only exported/source-validated status is complete. Creator publishing and real-device review remain separate.']
(OUT/'PROGRESS.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
if imported==24:
    imports[2]='Import completed by the creator. All 24 glassies and the shared kit are now normalized and validated in Studio; no further import is requested.'
    imports[4]='Canonical models: `ServerStorage.CombatReleaseStaged.Glassies`. Shared meshes and eight named texture references: `ServerStorage.CombatReleaseStaged.VFX`. Raw models in `CombatReleaseImports` were corrected by 0.01× and anchored. Originals, including the extra Pop, are preserved in `CombatReleaseBackups.RawBeforeNormalization_20261015`.'
    imports[8]='The imported geometry had a 100× unit conversion and baked 180° yaw. Both were corrected against actual source bounds and hang pivots, rather than by eye. Native first-six geometry/material review passed; client effect timing and flipbook/alpha validation remain pending.'
    imports[10]='## Export source references (already imported)'
    imports[-1]='Native imports are complete and staged; live kits/catalog changes are pending. Editable native snapshots are in places/CombatRelease_Staged_v2.rbxm and places/CombatRelease_RawBeforeNormalization_20261015.rbxm. Creator publishing and real-device review remain separate.'
(OUT/'BATCH_IMPORT.md').write_text('\n'.join(imports)+'\n',encoding='utf-8')
vfx=ROOT/'assets/vfx/combat_release';vfx.mkdir(parents=True,exist_ok=True)
(vfx/'timelines.json').write_text(json.dumps({'status':'offline presentation drafts; no gameplay parameters changed','shared_contact':{'windup':0,'contact':.08,'tail':.15,'particles':4},'shared_shatter':{'presentation_hold':.08,'tail':.65,'max_shards':20,'camera_change':False},'kits':timelines},indent=2))
roster['status']=f'{complete}/24 exported/source-validated; {imported}/24 native imported/normalized; live integration pending'
roster['notes'][0]='Production status manifest, not loaded by current game runtime.'
roster_path.write_text(json.dumps(roster,indent=2)+'\n',encoding='utf-8')
print(f'Packaged {complete}/24; runtime unchanged')
