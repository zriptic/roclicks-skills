# Shot list: template and how to write one from GAME.md

A Roblox trailer is about 30 s, and most viewers decide in the first 2 seconds. Use one beat per
shot, and every shot should show something happening (no empty walking).

## The beats (in order; each 2 to 5 s in the final cut)

| # | Beat | Purpose | Typical camera | HUD |
|---|---|---|---|---|
| 1 | **Hook** (0-3 s) | The single most exciting real moment, or a fast reveal of the world that lands on the core machine. No logo first. | flyover / crane / whip into action | off |
| 2 | **Core loop** | The thing players do every 10 s (roll, hatch, fight, build). Show input, then result. | player cam, then push-in on the result | on |
| 3 | **Rare moment** | Top-tier reveal, mutation, legendary drop. Slow it down (speed ramp 0.5x). | push-in or orbit, slow-mo | on |
| 4 | **Social / trading** | Two players interacting (trade, duel, co-op). Needs a 2-player playtest. | orbit around both | on |
| 5 | **Base / progression** | Your stuff on display, income, upgrades: the "number goes up" payoff. | orbit reveal, then player cam | off, then on |
| 6 | **Extra system** | Wheel, daily, event, boss: one beat, not a tour. | push-in | on |
| 7 | **Title card** | Game name/logo over a blurred frame from the game. | card | n/a |
| 8 | (social cut only) **CTA** | "Play free on Roblox". Keep it out of the Roblox upload, where it counts as ad text. | card | n/a |

Rules of thumb:
- Cut on action: enter each shot at the moment before the action, leave right after the payoff.
- Alternate gameplay POV and cinematic shots so it reads as "someone playing it", with drama at the payoffs.
- Gameplay shots keep the game HUD (players recognise the game by its UI). Cinematic shots hide it.
  The Roblox top bar, chat, player list and cursor are always hidden.
- Use 1 or 2 whips at most. Use crossfades between calm shots, hard cuts for montage beats, and a flash into the title.
- Record each shot 1.5 to 2x longer than its slot so the edit has handles.

## Writing it from a game's GAME.md

1. Read GAME.md (pitch, core loop, decisions) plus whatever lists the systems (FINISHED.md, SYSTEMS.md).
2. Fill the table: for each beat, pick the system that best shows it. Write one line of action and one line
   of payoff ("pulls the lever -> eggs spin -> Rainbow egg reveal").
3. For each shot, find in the source code:
   - the **anchor** to stand at or film: a CollectionService tag (`grep -rn "Tags.watch\|tagged(" src/`) or a Workspace path;
   - the **trigger** the player uses: ProximityPrompt ActionText, remote name and payload, a Tool name;
   - the **event to sync the camera to**: a RemoteEvent the server fires on the payoff (Reveal, FX), a child added to a folder, an attribute;
   - the **server setup** needed so the payoff happens on cue (cash, a specific item, a ready timer).
     Write these as `server` snippets that call the game's own modules. Never invent features.
4. Turn each line into a `shots[]` entry (schema in luau-api.md). Give each shot a stable id
   (`s03_hatch`); clips and edits are keyed by it.
5. Write the `edit.sequence`: in/out points, speed, transitions, the title card. Add up durations and aim for
   about 29 s in the Roblox cut (`edit.py` warns past 30 s).
6. Ask the user to confirm the beat list before recording. A 2-player beat needs `multiplayer_playtest`.

## Shot list table to show the user

| id | beat | action -> payoff | camera | HUD | setup | raw s | final s |
|---|---|---|---|---|---|---|---|
| s01_... | hook | ... | flyover | off | none | 5 | 3 |
