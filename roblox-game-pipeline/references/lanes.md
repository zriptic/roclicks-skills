# Lanes: running phases in parallel with subagents

For a big push, run independent phases as background subagents (Agent tool,
`run_in_background: true`), each with one job. You are the lead: you plan,
brief, review and integrate. Keep reports short and the context lean.

## Rules
- **One Studio writer at a time.** Studio is shared. A lane that needs Studio
  (world, systems) owns it for its run. The other lanes produce **files**
  (HTML UI, textures, models, music, `.rbxmx` bundles) in the game folder, and
  you import them afterwards.
- **A complete brief.** A lane starts fresh, so give it the game folder path,
  what to make, the style, the size, the constraints from `GAME.md` and
  `rules.md`, the skill to load, and the done-when.
- **A short report back:** the files and instance paths it made, what it
  verified and how, and what is left. No transcripts.
- **Review before integrating:** check its screenshots and files yourself,
  then update `GAME.md`.
- **Progress:** tell the developer which lanes are running and what each is
  on. When a lane finishes, report its result in one line.

## Lane prompt template
```
You are the <World|UI|VFX|Audio|Models|Systems|QA> lane for the Roblox game in <folder>.
Read <folder>/GAME.md and <folder>/PLAN.md first, then load the <skill> skill and follow it.
Task: <what to make, where, style, size, numbers>.
Constraints: <from rules.md and GAME.md; Studio access yes/no>.
Done when: <measurable checks + screenshots/files to produce>.
Do not touch: <other lanes' files / Studio if not yours>.
Report: files and instance paths made, what you verified, anything open. Keep it under 15 lines.
```

## Typical parallel set after the plan is approved
- **World lane** (Studio owner): `studify`, builds the map.
- **UI lane** (files only): `roblox-ui-maker`, HTML screens for every state,
  exported for import.
- **VFX lane** (files only, then a short Studio slot): `roblox-vfx` textures
  and templates.
- **Audio lane** (files only): `roblox-game-score` cue sheet, then the music
  with claude-music.

After that: the **Systems lane** owns Studio, then the **QA lane** judges and
changes nothing.
