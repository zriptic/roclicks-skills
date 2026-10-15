# Recording (macOS screencapture)

`screencapture -v` records the user's **real screen** (verified on a MacBook: 60 fps, 2940x1912 Retina,
Screen Recording permission granted). That brings three duties:

1. **Before the first take, tell the user**, in chat, in plain words: "I'm about to record your screen for
   about N minutes. Please keep Roblox Studio visible and uncovered, move the mouse off the game view, and don't use the
   computer until I say done." Wait for an OK. Repeat a one-liner before each later batch.
2. **Never record anything but the Studio viewport.** Calibrate the region and crop to it. `record.py shot` refuses
   if another app's window overlaps the region (`--force` overrides; use it only when the user agrees).
3. **Delete stray recordings.** Test takes, aborted takes and `_full.mov` intermediates go:
   `record.py clean --out <trailer> --shots shots.json` deletes everything in `clips/` that isn't a current shot id.
   Never write recordings anywhere but `<game>/trailer/clips/`.

No cursor: `screencapture` only shows the cursor with `-C`, which the script never passes. The driver also sets
`UserInputService.MouseIconEnabled = false`. No audio is recorded; the trailer's sound is the music bed and SFX.

## Steps
```bash
SK=<path to roblox-trailer>/scripts
T=<game>/trailer          # holds shots.json, clips/, out/
python3 $SK/record.py windows                      # Studio must show as [front]/[visible]
```
1. **Calibrate once per window layout** (and again whenever Studio is moved or resized):
   - in the playtest client, run `build_kit.py call --calibrate 10` (send the snippet with eval_client_runtime);
   - straight away: `python3 $SK/record.py calibrate --out $T`, which finds the cyan viewport and writes `$T/region.json` (points).
   It warns if the viewport isn't about 16:9; edit.py crops to 16:9 anyway, but a near-16:9 viewport wastes the least.
   Tip: hide Studio's Explorer and Properties (or use View > Full Screen) so the viewport is big. More source pixels give a sharper 1080p.
2. **Per shot**:
   1. `build_kit.py server --shot ID` and run the output (if any) with eval_server_runtime.
   2. Send `build_kit.py call --shot ID --delay 6` with eval_client_runtime and note `startsAtMs` and `dur` in the result.
   3. Immediately run `python3 $SK/record.py shot ID --out $T --start-ms <startsAtMs> --dur <dur>` (foreground).
      It sleeps until `startsAtMs - preroll`, records `preroll + dur + tail`, and writes `clips/ID.mov` + `clips/ID.json`.
      If the tool round trip took longer than the delay, it exits "too late": rerun with a larger `--delay`.
   4. `build_kit.py server --shot ID --after` if the shot has `server_after`.
   5. `python3 $SK/qa.py clips --shots $T/shots.json` and look at `clips/ID_sheet.png`. Retake or adjust offsets.
3. **Two-player shots**: start `multiplayer_playtest` with 2 players. Each client gets its own Studio window, so
   calibrate with `--window <part of the client window's title>` and pass the same `--window` to `shot`.
   Start client-2 first (`call --shot ID --actor client-2`, sent with `eval_client_runtime target=client-2`),
   then client-1, with the same delay so both timelines line up.

## How the trim stays frame-accurate
The driver's `startsAtMs` comes from `DateTime.now()` in the client, the same wall clock as Python's.
screencapture takes a moment to start, so record.py measures when the file **ends** (when the process exits)
and subtracts the file's duration to get the real first-frame time. `shot_in = startsAtMs - videoStart` is stored
in `clips/ID.json`, and the edit's `in`/`out` are measured from the shot's own t=0.

## Fallbacks
- Region recording fails: `--full-crop` records the whole display, then ffmpeg crops the region (in pixels = points x scale).
- Studio is on a second display: add `--display 2` (and calibrate on that display).
- No screen recording at all: save robloxstudio `capture_screenshot` frames (one per call, about 2-10 fps) into a folder
  as numbered PNG/JPEGs, then `record.py stitch ID --out $T --frames DIR --fps <capture rate> [--interp]`.
  It's choppy (use it for stills and slow orbits only), and playtest GUI captures are known to come back magenta,
  so hide the HUD for stitched shots. If the tool returns images only inline (no file path), this fallback isn't
  available. Say so instead of faking footage.
- Dropped frames (qa reports more than 2%): close heavy apps (browsers with video, Discord), retake. The unfocused
  Studio window caps at 15 fps, so Studio must be the **frontmost, focused** app during the take.
