---
name: roblox-game-pipeline
description: The end-to-end pipeline for making a Roblox game with your AI agent, from idea to launch and live updates. It runs phases in order (concept and study, design and economy sim, world, models, systems code, UI, VFX, audio, QA, thumbnails and publishing, analytics and live ops) and calls the right skill and tools for each, with standing rules and measured Studio gotchas. Use whenever the developer wants to make, remake, port or clone a Roblox game, start a new game, continue or finish one, plan a game, "do the whole thing", or asks what's next on a game. For one narrow task (just a UI, just an effect) use that skill directly.
---

# Roblox game pipeline

One game, start to finish, with the developer approving each gate. This skill
is the **conductor**: each phase names the skill or tool that does the work,
what that phase must produce, and how to know it is done. Do not rewrite what
those skills already say; load them when their phase starts.

`SK` = this skill folder. `PB` = an optional playbook of your own: a folder
(`<playbook>/`) of generic lessons sorted into topic folders such as
`game-design/`, `building/`, `engineering/` and `thumbnails/`. If you don't
have one yet, skip the `PB` pointers below and start one as lessons come up.

Companion skills named below (`studify`, `roblox-ui-maker`, `roblox-vfx`,
`roblox-game-score`, `claude-music`, a design-advice skill,
`jest-luau`, `scrapling`, `agent-browser`) are optional. If one
isn't installed, do that phase directly with the same "produces" and gate.

## Before anything

1. **Find or create the game folder:** `<projects>/<slug>/`. Copy
   `SK/templates/GAME.md` into it as `GAME.md`. That file is the single source
   of truth: phase status, decisions, place and universe ids, asset ids, open
   questions. Update it at the end of every phase and whenever a decision lands.
   A new session on this game starts by reading `GAME.md`.
2. **Read memory** for this game and the developer's standing rules. The rules
   summary is in `SK/references/rules.md`; the measured engine and tool facts
   are in `SK/references/gotchas.md`. Read both before the first Studio call.
3. **Find the Studio:** use one Studio MCP server for all edits (this skill
   was written against the community `robloxstudio` MCP server; the official
   built-in `Roblox_Studio` server is used only for `upload_image`). Check
   which place is open before every write: there are often several open places
   with the same default name.
4. **Plan the phases** you will run for this request and say them in one
   message: phase, what it produces, which skill. Skip phases the request does
   not need. A remake of an existing game starts at phase 0 with "study"; a
   brand-new idea starts at phase 0 with "concept".

## The phases

| # | Phase | Produces | Skill / tool |
|---|---|---|---|
| 0 | **Concept / study** | `GAME.md` pitch + reference breakdown | a design-advice skill, `SK/references/study-a-game.md`, scrapling / agent-browser for research |
| 1 | **Design + economy** | `PLAN.md`: core loop, progression, monetization, numbers; a pacing sim | design-advice skill, `PB/game-design/*`, a `sim/` script (Python or `luau`) |
| 2 | **World** | Map in Studio, stud style | `studify`; `PB/building/*` |
| 3 | **Models** | Meshes for what Parts can't do | Meshy MCP (organic shapes; quote credits first), blender MCP, `SK/references/models.md` |
| 4 | **Systems** | Server/client Luau: data, remotes, loop, products | `PB/engineering/*`, `jest-luau` for tests, `luau` CLI for pure logic |
| 5 | **UI** | Every screen, HTML first, then a real ScreenGui | `roblox-ui-maker` (always; read its `LESSONS.md`) |
| 6 | **VFX** | Particle effects for every key moment | `roblox-vfx` (read its `LESSONS.md`) |
| 7 | **Audio** | Music cues + SFX, SoundGroups | `roblox-game-score`, `claude-music*`; keep your verified reusable UI sound ids as described in `SK/references/rules.md` |
| 8 | **QA** | Defect list fixed; screenshots; loop timings | `SK/references/qa.md` |
| 9 | **Launch** | Thumbnails, icon, products, published place, analytics | `SK/references/launch.md` |
| 10 | **Live ops** | Analytics read, next update planned | `SK/references/launch.md` (analytics), design-advice skill |

Phases 2-7 can overlap once phase 1 is approved: a world and its UI do not wait
for each other. Systems (4) gate QA (8).

### Phase gates (what "done" means)

- **0 → 1:** the developer agrees the pitch and the core loop in one sentence
  each.
- **1 → build:** `PLAN.md` approved by the developer; the sim shows the pacing
  they want (first upgrade under a minute, first rebirth in the target window,
  no dead stretch). Numbers come from the sim, not from vibes.
- **Each build phase:** verified by measurement and screenshots, not by
  "it compiled" (see `qa.md`). Show the developer screenshots, ask, and write
  the feedback into the owning skill's `LESSONS.md` (UI, VFX) or into memory.
- **8 → 9:** the loop plays start to finish in a playtest with no errors in
  `get_runtime_logs`, mobile layout checked, 12+ player-height screenshots
  reviewed.
- **9:** nothing goes public without the developer's explicit yes (publishing,
  uploads, dev products, price changes).

## Running phases in parallel (lanes)

For a big push, use background subagents as lanes (Agent tool), one per
independent phase: world, UI, VFX, audio. Rules and ready-made lane prompts are
in `SK/references/lanes.md`. Studio is a single shared resource: only one lane
writes to a given place at a time; the others prepare files (HTML UI, textures,
models, music) and hand them back for import.

## Always

- **Stud style by default** unless the brief or reference says otherwise.
- **Particles, not 3D objects,** for effects.
- **HTML-first UI**, icons only from the project's chosen icon pack, never
  emojis.
- **Parts for the world**, meshes only where Parts fail; no free models for
  things that can be built.
- **Verify yourself** with screenshots and measurements before showing the
  developer.
- **Ask before spending** (Meshy credits, uploads, Robux-priced products) and
  before anything public.
- **Push Luau through `.rbxmx` + `import_rbxm`**, never `set_script_source` for
  anything with `\n` in strings (`gotchas.md`).
- **Record** every decision, id and lesson: `GAME.md` for this game, memory for
  cross-game facts, `PB` for generic lessons (no game names or secrets there).
