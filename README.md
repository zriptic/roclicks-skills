# RoClicks skills for Roblox development

The Claude Code skills and the meshlab toolkit behind [roclicks.gg](https://roclicks.gg): the
same ones used to make the games in the [showcase](https://roclicks.gg/showcase), cleaned up
so they work in anyone's project.

A skill is a folder of instructions, scripts and templates that teaches an AI coding agent how
to do one job well. Claude Code picks a skill up automatically when a task matches it.

## Skills

| Skill | Job | What it does |
|---|---|---|
| [`roblox-game-pipeline`](roblox-game-pipeline/SKILL.md) | Idea to launch | The conductor: runs a game from concept through economy sim, world, models, systems, UI, VFX, audio, QA, launch and live updates, with a gate you approve at each phase. |
| [`roblox-ui-maker`](roblox-ui-maker/SKILL.md) | UI | Designs game UI in HTML first from your style reference, then builds a real ScreenGui in Studio with ready-made Luau modules. You bring textures from ui-resources.com and a licensed icon pack. |
| [`roblox-vfx`](roblox-vfx/SKILL.md) | VFX | Hits, slashes, explosions, projectiles, auras and camera shake from layered ParticleEmitters, with an emit module, EditableMesh shapes and a frame-by-frame capture tool. Adapted from Roqer (MIT). |
| [`studify`](studify/SKILL.md) | Building | Stud-style maps, buildings and props in Studio: studded materials, a pastel palette, tree/hill/water recipes, no gaps or z-fighting, screenshot-checked. |
| [`roblox-trailer`](roblox-trailer/SKILL.md) | Trailers | Gameplay trailers end to end: a Luau driver plays each shot, a camera rig adds moves, ffmpeg cuts a 30 s Roblox video thumbnail and a vertical edit. macOS only. |
| [`roblox-game-score`](roblox-game-score/SKILL.md) | Music | A custom soundtrack generated locally with ACE-Step: themes, combat music, layers and stingers, looped, mastered and wired up in Studio. |

Install one by copying its folder into your skills directory, so the skill sits at
`~/.claude/skills/<name>/SKILL.md` (or `.claude/skills/<name>/` inside a single project):

```bash
git clone https://github.com/zriptic/roclicks-skills
cp -r roclicks-skills/roblox-vfx ~/.claude/skills/
```

Start a new Claude Code session and it's available. Each skill's `SKILL.md` lists what it needs
(Studio MCP server, Blender, ffmpeg and so on).

## meshlab: stud-style models as code

[`meshlab/`](meshlab/README.md) is the toolkit for modelling stud-style meshes as Luau: models
run under Lune, Blender renders them lit like Studio, and your agent fixes the code from the
picture. The full guide with pictures is at
[roclicks.gg/resources/tricks/stud-models-with-lune](https://roclicks.gg/resources/tricks/stud-models-with-lune).
Run it from the repo root:

```bash
lune run meshlab/run Barrel
blender -b -P meshlab/render.py -- meshlab/out/Barrel.obj meshlab/out/Barrel.png hero 1.4
```

## More

- Guides, prompts and tricks: [roclicks.gg](https://roclicks.gg)
- The same skills as single downloads: [roclicks.gg/skills](https://roclicks.gg/skills)

Free to use and change in your own games. `roblox-vfx` is adapted from Roqer's skills and keeps
their MIT licence in `LICENSE-ROQER-SKILLS.txt`.
