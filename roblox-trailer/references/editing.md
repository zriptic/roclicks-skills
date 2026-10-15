# Editing (scripts/edit.py)

```bash
python3 $SK/edit.py build --shots $T/shots.json --cut roblox --format landscape   # Roblox upload
python3 $SK/edit.py build --shots $T/shots.json --cut social --format both        # YouTube 16:9 + Shorts/TikTok 9:16
python3 $SK/edit.py card  --shots $T/shots.json --index 9                         # preview one card/text PNG
python3 $SK/edit.py fonts                                                         # what each font name resolves to
```
Output: `$T/out/<game>_<cut>_<WxH>.mp4`. About 2.5 min per format on an Apple Silicon MacBook (each segment is rendered,
then joined in one pass). Then run `qa.py final <file> [--roblox]` and look at the `_sheet.png`.

## The `edit` block
```json
"edit": {
  "size": [1920, 1080], "fps": 60, "font": "Fredoka One",
  "music": { "file": "/abs/path/bed.mp3", "start": 12.0, "gain_db": -2, "fade_out": 1.5 },
  "sfx":   [ { "file": "/abs/whoosh.wav", "at": 3.1, "gain_db": -4 } ],
  "duck":  [[26.0, 29.5]], "duck_db": -9, "loudness": -14,
  "vertical": { "mode": "crop" },
  "sequence": [ items... ]
}
```
- **Shot item**: `shot`, `in`, `out` (seconds from the shot's t=0), `speed` or `ramp` `[[src_t, speed], ...]` (linear
  between keys, applied in 1/15 s steps), `interp: true` (motion-interpolated slow-mo, slower to render; otherwise slow
  parts repeat frames), `transition` (INTO this item), `text`, `focus_x`/`focus_y` (crop centre, used by vertical crop), `social_only`.
- **Card item**: `card: "title"|"text"`, `text`, `sub`, `dur`, `size` (170 at 1080p), `color`, `stroke`, `sub_color`,
  background `bg_shot` + `bg_t` (blurred, darkened frame from a clip) or a `bg`→`bg2` gradient. The title pops in
  with a little overshoot and breathes; the background drifts.
- **Transitions**: `cut` (1 frame), `fade`, `whip` (xfade slideleft, 0.2 s), `whipright`, `whipblur` (hblur), `dip`
  (through black), `flash` (through white, good into the title), `zoom`, or any raw ffmpeg xfade name. Durations
  are clamped to under half of either neighbour.
- **Text overlay**: `{"text", "pos": "bottom|lower|center|top", "size": 72, "from": 0.2, "to": 2.0, "color", "stroke"}`.
  Keep in-game text sparse; the Roblox cut may only have UI-like text and the logo/title (no claims).

## Text, fonts, emoji
The Homebrew ffmpeg this was built on has **no libfreetype, so there is no `drawtext`**. All text is drawn with Pillow into
transparent PNGs, then overlaid. Emoji (e.g. 🥚) come from Apple Color Emoji, rendered at its 160 px bitmap size and scaled.
Font lookup: `edit.font` (a name or a path) → `assets/fonts/` → the user Fonts folder (`$HOME/Library/Fonts`) → system fonts, then
FredokaOne → Luckiest Guy → **Arial Rounded Bold** (always on macOS) → SF Rounded. **Fredoka One is usually not installed**:
to use it, download `FredokaOne-Regular.ttf` from Google Fonts (SIL OFL) into `assets/fonts/`. That's a download,
so ask the user first.

## Audio
- `music.file` is trimmed from `start` to the cut length, faded in over 0.25 s and out over `fade_out`, then
  dipped by `duck_db` inside each `duck` window (e.g. under the title card's stinger).
- `sfx` are layered at `at` seconds of the final cut. When present, the music is sidechain-compressed under them,
  so the music ducks by itself whenever an SFX hits.
- A final `loudnorm` to `loudness` LUFS (-14 = YouTube/TikTok; true peak -1 dBTP), at 48 kHz AAC 192k.
- Roblox cut: catalog or licensed instrumental only, no lyrics, no voice (roblox-video-specs.md). If there's no music file,
  the cut is silent, which is allowed. A bed can come from the `roblox-game-score` skill or the game's own playlist
  (only if its licence allows reuse outside Roblox; for the Roblox upload, catalog music is fine).

## Vertical (1080x1920)
`vertical.mode: "crop"` cuts a 9:16 slice from each 16:9 shot. Set `focus_x` per item so the action stays in frame
(0 = left edge, 1 = right). `"blurpad"` keeps the whole 16:9 frame in the middle over a blurred copy of itself.
That's safer, but the gameplay is small. Cards re-layout for 9:16 automatically.

## Pacing defaults that work
- Hook under 3 s. Speed it up (1.5-1.9x) so travel doesn't drag, and ease to 1x as it lands.
- Payoffs at 0.5-0.6x for about 1 s, then back to 1x. Montage beats run 1.2-1.6 s each, as hard cuts.
- Use 1 or 2 whips total. Flash into the title. Title 2.5 s; CTA 1.6 s (social only).
