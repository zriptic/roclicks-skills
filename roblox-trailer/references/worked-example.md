# Worked example: a pet-hatching roll game ("🥚 Pet Roll"), about 29.6 s

Game: a project folder `<game>/` with GAME.md, FINISHED.md and PARITY.md. It's a stud world
with a glass HUD. Pull the lever to roll eggs; eggs sit in the bottom hotbar until ready, then drop, shake and
hatch; animals go on vault podiums whose pads pay out; there's a Mutation Machine (tier-up), 12 physical trade lanes
and a Lucky Wheel. The ready-to-copy config is **`references/example.shots.json`**. Put it at
`<game>/trailer/shots.json` and rename the tags, remotes, prompt text and module names to match your game.

## Shot list
| # | id | beat | action -> payoff | camera | HUD | final |
|---|---|---|---|---|---|---|
| 1 | s01_flyover | hook | high over the island, swooping down onto the roll stage | flyover spline, fov 75→62, ramp 1.9x→1x | off | 3.2 s |
| 2 | s02_roll | core loop | walks to the lever, presses "Roll", eggs spin on the carousel, egg reveal | player cam → push-in on RollStage → player cam on the `Reveal "Roll"` event | on | 4.0 s |
| 3 | s03_hatch | core loop 2 (new hatching) | holds a ready egg from the hotbar, clicks: it drops, shakes, cracks, the animal pops out | player cam → push-in on `Workspace.Hatching` when the egg model appears; 0.5x at the crack | on (hotbar!) | 4.7 s |
| 4 | s04a/b/c_mutate_* | rare moment | Mutate → Skip → Collect, three real takes: **Gold→Diamond, Diamond→Galaxy, Galaxy→Rainbow**, hard-cut montage, Rainbow slowed | push-ins, then an orbit for Rainbow | on | 5.6 s |
| 5 | s05_base_cash | base and progression | orbit of the vault with 3 showy animals on podiums; then walks onto a pad: bills burst and fly into the player, the cash number jumps | orbit (HUD off) → player cam (HUD on) | off→on | 3.7 s |
| 6 | s06_trade | social | two players meet at lane 1, both add animals, both step on ✓ | player cam → orbit around the lane | on | 3.5 s |
| 7 | s07_wheel | extra system | presses "Spin" at the Lucky Wheel; slow push-in while it spins | push-in on WheelSpinner | on | 4.1 s |
| 8 | title card | title | "🥚 Pet Roll" over the blurred flyover, flash in | card | n/a | 2.5 s |
| 9 | (social only) | CTA | "Play free on Roblox" | card | n/a | 1.6 s |

Roblox cut: about 29.6 s (checked by building it from placeholder clips). Social cut: about 30.9 s.

## Things specific to this game (why the config looks the way it does)
- **Gold → Rainbow is three steps.** `MetaLogic.mutationRoll` moves a tier up **one** step per mutation
  (UpgradeOdds Gold 60%, Diamond 35%, Galaxy 15%, Rainbow 5%). One clip jumping Gold→Rainbow would show something the
  game can't do, and Roblox rejects videos that misrepresent gameplay. So it's a 3-cut montage of real
  upgrades. For the takes, each shot's `server` snippet temporarily sets the next tier's odds to 1, and
  `server_after` restores them. That only picks *which* real outcome happens on camera (a curated highlight).
- **Hatching is the new hotbar flow** (recorded as a decision in GAME.md): `Equip {id}` then `HatchEgg {}` on the
  Action remote. The server spawns the egg under `Workspace.Hatching`, and the `childAdded` trigger starts the push-in
  on it. The setup makes a Rainbow Giant Dragon egg ready (`Hatch.makeReady`) and passes its id through the player
  attribute `TrailerEgg` (`"$attr:TrailerEgg"` in args).
- **Rolling**: the `Roll - $500` prompt is on the `RollCabinet` lever. The carousel spins about 4 s before
  `Remotes.Reveal("Roll")` fires, so the push-in starts right after the press and the reveal hands back to the player cam.
- **Trading** is physical: TradePads tagged with attributes `LaneId`, `Side` (A/B) and `Action` (Add/Accept/Cancel).
  Standing on both Add pads opens the session; walking onto Accept accepts. client-1 is side A, `actors["client-2"]` is side B.
  Needs `multiplayer_playtest start numPlayers=2`; record client-1's window (`--window`).
- **Wheel**: the wheel is gated behind group membership, but the group id in the game's config is left at 0, so the
  gate is open in Studio. `Wheel.addSpins(p, 1)` gives a spin.
- **Base**: run `p05_base_prep` (kind `prep`, not recorded) first. It places HYDRA (Galaxy, Giant), PHOENIX (Rainbow)
  and WYVERN (Diamond, Titanic) on podiums 1-3. Wait about 8 s so the pads fill (about $100/s each), then record
  s05. The vault is client-sided: only the recording player's animals show, which is exactly what the shot wants.
- The place is not saved by agents. The kit import and all setup live only in the playtest and edit
  session. Remove `ReplicatedStorage.TrailerKit` afterwards.
- **Server setup and the require cache**: the `server` snippets in the JSON call the game's modules directly so they
  are easy to read. `eval_server_runtime` gets a fresh require cache, though, so in practice route each step through a
  `TrailerHook` BindableFunction (SKILL.md, Known gaps) and make the snippet `:Invoke` it.
- Music: the game's playlist is Toolbox/APM tracks (GAME.md). For the Roblox upload, catalog music is allowed. For
  YouTube/TikTok use a bed from `roblox-game-score` or another licensed instrumental. Set `edit.music.file`.

## Run order
```bash
SK=<path to roblox-trailer>/scripts; G=<game>; T=$G/trailer
mkdir -p $T && cp <path to roblox-trailer>/references/example.shots.json $T/shots.json
python3 $SK/build_kit.py rbxmx --shots $T/shots.json        # import_rbxm -> ReplicatedStorage (edit mode)
```
1. Tell the user: keep Studio up front and uncovered, mouse off the viewport, hands off until done.
2. `solo_playtest start mode=play` → calibrate (`call --calibrate 10` + `record.py calibrate --out $T`).
3. For s01, s02, s03, s04a/b/c, p05 (no recording), s05, s07: `server` → `call --shot` → `record.py shot` → `server --after`.
   Test-take the first two, fix `localOffset`s, then `record.py clean`.
4. Stop; `multiplayer_playtest start numPlayers=2`; recalibrate on client-1's window; s06.
5. `qa.py clips`, retake failures; `edit.py build --cut roblox --format landscape` and `--cut social --format both`;
   `qa.py final ... --roblox`; look at the sheets; show the user the cuts.
6. Clean up: stop the playtest, delete `ReplicatedStorage.TrailerKit`, run `record.py clean`, and remove `$T/build`.

## First test take: what to check
- The player stands where the shot expects (offsets are guesses from tags; the lever's facing is unknown).
- The prompt fired: `D.status().last.log` lists `prompt Roll - $500`; "prompt not found" means move closer or fix `match`.
- The hotbar is visible in s03 (HUD on) and the top bar, chat and cursor are gone everywhere.
- The Mutation flow: if `MutateCollect` returns "Not ready" after `MutateSkip`, add a `{"t": 2.4, "do": "prompt", "match": "collect"}`.
