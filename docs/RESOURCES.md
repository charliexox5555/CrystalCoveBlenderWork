# Glass Clash — Tools, Resources and Best Practices

Companion to [GAME_DESIGN.md](GAME_DESIGN.md). This lists what to build with, so Codex isn't starting from scratch.

> Community plugins and modules change often. **Before adding any of them, open the link, check it's maintained, read the code, and check its license.** Never install a plugin or model that asks for more permissions than it needs. Free models are a common source of backdoor scripts.

## 1. Your AI pipeline

| Tool | Use it for | Notes |
|---|---|---|
| **Codex + Roblox Studio MCP** | Writing scripts, building the place, running tests | Studio now has an MCP server built in ([Roblox docs](https://create.roblox.com/docs/en-us/studio/mcp.md)). Roblox's reference server ([studio-rust-mcp-server](https://github.com/Roblox/studio-rust-mcp-server)) lists `run_code`, `insert_model`, `get_console_output`, `start_stop_play` and `run_script_in_play_mode`. Use `run_code` to run `ServerStorage.Tests` and the balance simulator after every balance change. |
| **Codex + Blender MCP** | Glassy models, Cell Fracture shards, icon renders, marketing videos | Follow the asset spec in GAME_DESIGN §13.3. Use one saved camera and lighting setup for every icon render. |
| **Roblox Cube 3D** (Studio Assistant, `/generate ...`) | Quick filler props for the map (crates, rocks, fences) | Text-to-mesh built into Studio ([Roblox announcement](https://corp.roblox.com/newsroom/2025/03/introducing-roblox-cube)). **Don't use it for hero glassies**, which need clean shapes, a hang point and pre-broken shards. Check current limits in Studio. |
| **Figma** (connected to Claude) | UI mockups, style kit, concept images | Mockups: [Glass Clash UI](https://www.figma.com/design/r3guIIk5deo7vNxLzJN0RZ). Figma AI image generation can make concept art, but **each image uses Figma AI credits**. |
| **Claude plugins** (claude.ai directory) | Extra skills for Claude sessions | **roblox-dev** (Luau patterns for remotes, DataStores, performance, UI, testing), **Design** by Anthropic (critique, design system, handoff) and **image-generation** (prompting guide). |

## 2. Concept art → 3D glassy workflow

1. **Concept:** generate 4–6 2D concepts per glassy (Figma AI or any image model), then pick one.
2. **Model:** have Blender MCP build it from the chosen concept. Keep it chunky and toy-like, readable on a phone, with the origin at the hang point.
3. **Break:** fracture it into 12–20 pieces with Cell Fracture.
4. **Render the icon** with the shared camera and lighting setup (512×512, transparent background).
5. **Import** the model, shards and icon, then add one config entry in `Config/Glassies`.

**Prompt template for concepts:**
> 3D render of a **[object]** made of glossy tinted **[color]** glass, chunky toy-like proportions, smooth rounded edges, subtle inner glow, soft studio lighting, plain white background, game asset, three-quarter view, no text, no logos

Swap in the object (glass rocket, crystal crown, glass unicorn, pumpkin lantern...). Never use alcohol bottles; see GAME_DESIGN §4.5.

## 3. Visual effects (beyond Roblox's defaults)

**Built-in features to use properly first.** These cover most of the "wow" when tuned well:
- `ParticleEmitter` with **flipbook** textures (sparkles, glints, glass dust). Use `:Emit(n)` bursts on impact instead of always-on emitters.
- `Beam` (strings, light streaks) and `Trail` (swing motion trails behind each glassy).
- Post-processing on the final blow: a short `ColorCorrectionEffect` flash, `BloomEffect` boost, and `DepthOfFieldEffect` during slow-mo. Reset them afterwards.
- `Highlight` for the selected or catchable glassy, and `PointLight` inside glowing fantasy glassies.

**Plugins and libraries to look at** (check each first):
- [VFX Forge](https://devforum.roblox.com/t/plugin-vfx-forge-an-advanced-custom-vfx-system/3867553): particles, beams, trails, mesh VFX, flipbooks, lightning and camera shake, with a scripting API. The strongest in-Studio option found.
- [SteakParticles](https://devforum.roblox.com/t/steakparticles-plugin-for-creating-vfx-and-particle-emitters/2908779): pre-made VFX you can drop in.
- [CIX Library](https://devforum.roblox.com/t/over-600-free-particle-with-cix-library-a-particle-library-plugin/2864815): 600+ free particles.
- [Creator Store → Particle Effects](https://create.roblox.com/store/category/visual-effects/particle-effects): free effects. Check the scripts inside before using.
- Paid packs ([BuiltByBit animations & VFX](https://builtbybit.com/resources/roblox/animations-vfx/)): fast, but buy only from well-reviewed sellers.

**The shatter itself:** use the **pre-broken Blender shards** from the design doc rather than breaking parts at runtime. They look better and are cheaper on phones. [Part Fracturing System V3](https://devforum.roblox.com/t/part-fracturing-system-v3/690547) is a good reference for runtime cracks, but it doesn't state a license, so read it for ideas only.

**Custom textures:** render your own glint, sparkle and glass-dust flipbooks (4×4 or 8×8 sheets) in Blender. They match your style and no other game has them.

**Mobile budget:** cap shards at about 150 on screen, keep emitter rates low, and remove effects with `Debris`. Test on a low-end phone, not just in Studio.

## 4. Code foundations

| Need | Use | Why |
|---|---|---|
| Saving player data | [ProfileStore](https://devforum.roblox.com/t/profilestore/3190543) (loleris) | Session locking and safe saves. It replaces ProfileService. |
| Top-bar buttons | TopbarPlus v3 ([docs](https://1foreverhd.github.io/TopbarPlus/)) | Standard for icons in Roblox's top bar. |
| UI code | Plain Instances plus the `Theme` module and components (GAME_DESIGN §12.5) | Simplest for Codex working through MCP, with no build step or package manager. If you want a framework later, [Vide](https://github.com/littensy/vide) (Luau-native, type-checked) or Fusion fit Roblox better than React-lua for a small team. **Pick one and never mix them.** |
| UI animation | `TweenService`, plus a small spring module if you want springy motion | Keep panel motion short (§12.1). |
| Networking | Plain `RemoteEvent`s with server-side validation and rate limits | Already specified in §13.1. Don't trust the client. |
| Reference code | [roblox-game-skill templates](https://github.com/brockmartin/roblox-game-skill) (simulator: hatching, rarity, zones, upgrades) | Read for ideas; don't paste in blindly. |

## 5. UI best practices on Roblox

- **Safe areas:** keep `ScreenGui.ScreenInsets` on **`CoreUISafeInsets`** (the default) for anything interactive. It avoids phone notches and Roblox's own buttons. Use `DeviceSafeInsets` or `None` only for full-screen backgrounds. Use `GuiService.TopbarInset` to place things in the top bar ([ScreenInsets docs](https://create.roblox.com/docs/reference/engine/enums/ScreenInsets)).
- **Test on phones:** use Studio's **Device Emulator** with phone presets for every screen ([Roblox HUD tutorial](https://create.roblox.com/docs/en-us/tutorials/use-case-tutorials/ui/create-hud-meters.md)).
- **Sizing:** use Scale, `UIAspectRatioConstraint` and `UISizeConstraint` (minimum tap size). For text, use `TextScaled` only with a `UITextSizeConstraint`.
- **Panels:** use 9-slice images (`SliceCenter`) so panels stretch without blurring. Keep UI textures at 1024 px or smaller.
- **Console and keyboard:** every button should be selectable with a gamepad (`GuiService.SelectedObject`), and Escape or B closes the open panel.
- **Clarity:** one panel open at a time, the next objective always visible, and the same color meanings everywhere.

## 6. Loading screen

**How it works** (from Roblox docs and DevForum):
1. A `LocalScript` in **ReplicatedFirst** builds a lightweight loading UI, because scripts elsewhere don't run until the game has loaded.
2. Parent it to `PlayerGui` **first**, then call `ReplicatedFirst:RemoveDefaultLoadingScreen()`, so there's no blank gap.
3. `ContentProvider:PreloadAsync` **only what's needed** for the first minute (the lobby, your glassy, UI textures, the shatter sound), with a real progress bar. Let everything else stream in the background. Long loading screens hurt retention.
4. Fade out, ideally into the starter-pick screen for new players.

**Concepts that fit the game:**
- **Filling glass:** a glass bottle silhouette fills with glowing liquid as loading progresses, then shatters into the game (and plays your shatter sound, which doubles as a brand sting).
- **Showcase:** a slowly spinning **fantasy glassy** (unicorn, dragon, crown) on a pedestal, with tips underneath. It hooks new players on what they can unlock.
- **Tips carousel:** "Hit the YELLOW for a PERFECT!", "Heavy beats Sharp, Sharp beats Fizzy, Fizzy beats Heavy", "Shatter a wild glassy and it's gone. Cork it first!"

## 7. Best-practice checklist

- [ ] **Week 1 is the feel prototype.** Don't build content until the swing and shatter feel great on a phone.
- [ ] The server decides every result, and every remote is validated and rate-limited.
- [ ] Data uses ProfileStore, and purchases go through idempotent `ProcessReceipt`.
- [ ] Paid crates show odds, and `PolicyService` hides them where paid random items are restricted.
- [ ] No alcohol references. Fill out the **maturity questionnaire** honestly.
- [ ] `StreamingEnabled` is on, low part counts, and the **MicroProfiler** is checked on a low-end phone.
- [ ] Analytics events from GAME_DESIGN §15 are added **before** soft launch.
- [ ] Publish at every milestone (place version history is your backup).
- [ ] Use Team Test with friends before the soft launch, then cross-promote from your existing game.
- [ ] Every free model or plugin is checked for hidden scripts before use.
