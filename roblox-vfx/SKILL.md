---
name: roblox-vfx
description: Build Roblox visual effects the way experienced Roblox VFX artists do, covering hits, slashes, explosions, spells, projectiles, beams, trails, auras, pickups, charge-ups, shockwaves, camera shake and impact frames, from layered ParticleEmitters with custom drawn textures and flipbooks, timed by an attribute-driven emit module, checked frame by frame in Studio. Use for ANY Roblox VFX, particle, effect, ability/skill visual, "make it juicier", flipbook, particle texture, slash/impact/explosion request, or when matching a reference clip of an effect. Works through a Roblox Studio MCP server (written for the open-source robloxstudio MCP), plain python3 with numpy for textures, and optionally a Blender MCP. Adapted from Roqer's roblox-animation-vfx skill (MIT).
---

# Roblox VFX

`SK` = the folder this skill is installed in (for example
`<skills-dir>/roblox-vfx`). Adapted from the VFX half of Roqer's
`roblox-animation-vfx` skill (github.com/S4US/Roqer, skills MIT-licensed by
TabooHarmony, `LICENSE-ROQER-SKILLS.txt`), re-pointed at the robloxstudio MCP,
plain python3 and the blender MCP.

**Read `LESSONS.md` first.** It holds every rule the developer has taught about effects,
and it wins over anything below that disagrees. Write new VFX feedback there.

## The loop

1. **Name the move** (basic skill, ultimate, pickup, aura...) and where the
   player sees it. That sets size, palette and timing (`vfx-design.md` §1).
2. **Plan the layers** from a skeleton (`vfx-craft.md` §4) on the intensity
   curve (`vfx-design.md` §6): anticipation, flash, body, secondaries, smoke.
3. **Draw the textures** with numpy (`vfx-textures.md`), preview them in
   Studio without uploading.
4. **Build the template** in `ReplicatedStorage.VFX.<Name>` with `Build`,
   attributes for timing (`EmitCount`/`EmitDelay`/`EmitDuration`).
5. **Check it** in edit mode with `Capture.hold` at 4-6 moments, close and
   from the player's camera (`vfx-craft.md` §6). Fix, re-check.
6. **Upload** the settled textures in one batch, swap out preview addresses,
   wire it to gameplay (server fires an UnreliableRemoteEvent, each client
   plays it), and check once in a playtest.
7. Tell the developer what was checked; ask for a look at full speed; write feedback
   into `LESSONS.md`.

## References (load what the effect needs, together in one go)

| File | Load when |
|---|---|
| `references/vfx-design.md` | **Always.** What the effect is for, palette, value (dark layers, black twins), brightness vs bloom, layers, timing curve, motion. Numbers measured from published effects |
| `references/vfx-craft.md` | **Always.** Runtime install, emit attributes, replication, particle properties, layer skeletons with `Build` examples, budgets, the check loop |
| `references/vfx-textures.md` | Most effects: drawing particle textures and flipbooks, preview, check, upload |
| `references/vfx-motion.md` | Projectiles, volleys, trails, beams, slashes, dashes, orbs, sigils, auras |
| `references/vfx-mesh-shapes.md` | Crescent meshes, shockwave rings, swirls, domes, ground waves |
| `references/vfx-camera-world.md` | Camera shake, FOV, blur, impact frames, lights, craters, scorch marks, cast pose from code |
| `references/vfx-rendered-flipbooks.md` | A flipbook rendered from a 3D scene in Blender instead of drawn |
| `references/vfx-reference.md` | The developer supplied a video/GIF of an effect to match |

## Tools in this skill

| Path | What |
|---|---|
| `templates/Emit.luau` | Plays effects from attributes; `VFX.play(template, cf)`, `VFX.emit(inst)`; handle `freeze`, `setTimeScale`, `stop` |
| `templates/Build.luau` | `Build.run(path, steps)`: JSON/table steps -> instances (sequences, ranges, enums, `$id` links), one undo step, report string; `Build.previewLeftovers()` |
| `templates/Capture.luau` | `Capture.aim`, `Capture.playerView`, `Capture.hold(template, cf, t)`, `Capture.slow`, `Capture.release`, `Capture.marker` |
| `templates/Shapes.luau` | EditableMesh shapes (`Arc`, `Ring`, `TornRing`, `Cone`, `Swirl`, `Shell`, custom) baked from spot parts; `Shapes.prepare(template)` |
| `scripts/bundle_runtime.py` | Writes the four modules into one `.rbxmx` (Folder `VFX`) for `import_rbxm` |
| `scripts/vfxtex.py` | numpy texture library (`tex_stroke`, `tex_blob`, `tex_warp`, `draw_flipbook`...) + CLI `check`, `review`, `preview`, `clean-preview` |
| `scripts/vfxblender.py` | For the blender MCP: `flipbook()` renders a scene to a sheet; `vfx_arc/ring/cone/swirl/shell/surface`; `export_glb` |
| `scripts/clip_frames.py` | Reference clip -> labelled frame sheet + timing/brightness/colour table (ffmpeg) |

## Ground rules

- **Particles, not 3D objects.** Effects are layered ParticleEmitters, Beams
  and Trails with real textures. Never ball/part clusters for smoke, fire or
  explosions. Mesh shapes are a layer (crescent, shockwave), not the effect.
- **Studio = `robloxstudio` MCP**, never the built-in `Roblox_Studio` server,
  except `upload_image` for textures (robloxstudio has no upload auth). Say so
  when using it.
- **Never push Luau with `set_script_source`** (it expands `\n`); use
  `bundle_runtime.py` / an `.rbxmx` + `import_rbxm`.
- **Tool calls in one turn race.** Hold/aim in one turn, `capture_screenshot`
  in the next.
- **`require` caches in edit mode** for the whole Studio session: after
  changing a module, re-import it and its dependents before re-checking.
- **Effects are client-side.** Server decides, fires names + CFrames over an
  `UnreliableRemoteEvent` (< 1000 bytes); damage never waits on an effect.
- **Uploads are irreversible and moderated:** only the settled set, one batch,
  say how many first.
- Keep each effect's texture script and asset-id map in the game's project
  folder (`<game>/vfx/<effect>/`), so it can be redrawn and re-uploaded.
