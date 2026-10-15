# Standing rules

These were learned from a developer's feedback across many games. Treat them
as defaults and edit them to match your own taste. The current request
outranks them; when one is broken on purpose, say so.

## Style and art
- **Stud style is the default** (studify; Plastic with stud MaterialVariants on
  every face, chunky shapes broken up by small detail). Not a law: a ninja
  game was deliberately not stud.
- **Parts for the world.** Meshes (Meshy, Blender) only for what Parts do
  badly: creatures, characters, organic or curved props, hero props, vehicles.
  Prompt Meshy for "chunky toy plastic, flat colours" so it sits beside studs.
- **Detail props use EditableMesh** (wheels, gears, wings, rounded machines) in stud colours; plain Parts for the rest. Render meshes aren't saved: mesh spots + runtime bake (a MeshKit-style module in your project). Feedback on a pet-hatching game: "the spinner needs more detail".
- **Measure colours from the reference** (median RGB of stills, compared against a Studio render under the real lighting), never eyeball. Feedback on the same game: "the colors are a bit off".
- **No free Creator Store models** for anything that can be built. Another
  creator's mesh or image renders as nothing without permission (gotchas.md).
- **One icon/vector pack per project.** Prefer purchased packs over generated
  art. Respect each pack's licence: some forbid
  sending the art to an AI model or redistributing it.
- **VFX are particles,** beams and trails with textures. Never 3D ball or part
  clusters (ball-cluster explosions were rejected on a strategy game: they read as 3D objects, not effects).

## UI
- **Design in HTML/CSS first,** check it with the developer, then convert to a
  real ScreenGui (`roblox-ui-maker`). Text stays native (TextLabel + UIStroke).
- **Stud-style UI must show the stud texture** (ui-resources.com).
- **Icons from the project's chosen pack only; never emojis.**

## Process
- **Verify before showing:** maps get 12+ player-height screenshots under the
  full lighting plus 2 aerials; fix what they show; re-shoot the same angles.
- **Quote credits/costs first** (Meshy, image generation) and wait for a yes.
- **Ask before anything public** (publish, upload, products, prices) or
  irreversible.
- **Studio work goes through one Studio MCP server** (written against the
  community `robloxstudio` server). The official built-in `Roblox_Studio`
  server is used only for `upload_image`; say so when you do.
- **Design voice:** for game-design and business calls, load a design-advice
  skill if you have one.

## Reusable assets that are known to load in your places
Keep a short list of your own asset ids that you have verified load in your
places (for example the UI click, hover, purchase (cash register) and reward
sounds) in memory or `GAME.md`:
- click `rbxassetid://<click-sound-id>`
- hover `rbxassetid://<hover-sound-id>`
- purchase (cash register) `rbxassetid://<purchase-sound-id>`
- reward `rbxassetid://<reward-sound-id>`

Re-probe any copied id before wiring it in (`IsLoaded and TimeLength > 0`).

- **Never start a playtest** (solo or multiplayer), and never let subagents do it: verify in edit mode, then hand the developer a playtest checklist. The developer playtests.

- **No "AI look" on props:** no Neon glow strips or random spheres. Make props mechanical (bolts, pipes, gears, cranks, gauges), with 1 or 2 small plastic lamps at most.

- **Never run multi-client / multiplayer playtests** (they can overload the developer's machine). Solo only.
