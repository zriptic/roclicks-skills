---
name: roblox-game-score
description: Make a custom soundtrack for a Roblox game (lobby/zone themes, combat or boss music, intensity layers, reward stingers), generated locally with claude-music (ACE-Step), cut into seamless loops, mastered for game use, uploaded to Roblox and wired with SoundGroups and crossfades. Use when the user wants a custom score, theme song, background music, zone music, menu music or stingers for a game, or asks to replace stock music.
---

# Roblox game score

Generation is done by the **claude-music** skills (`claude-music-generate`,
`claude-music-compose`, `claude-music-export`, and so on), a separate skill set
that drives the open-source ACE-Step music model locally. If you don't have
those skills, run ACE-Step directly with the same prompts and settings. This
skill adds what a *game* needs on top of a song: loops that never click, layers
that follow the action, levels that sit under the sound effects, and the Roblox
side (upload, SoundGroups, crossfades).

## 1. Plan the score before generating

Write a cue sheet. Each cue has a job, a loop length and an intensity:

| Cue | Job | Typical length | Notes |
|---|---|---|---|
| Main theme / lobby | Identity; what the thumbnail and trailer use | 60-120 s loop | Strongest melody; instrumental |
| Zone themes | One per area or world | 45-90 s loop each | Share the main theme's key and motif, change instruments |
| Combat / boss | Raises stakes | 30-60 s loop | Faster; same key as the zone, so a crossfade stays musical |
| Intensity layers | Calm → busy versions of one cue | Same length and BPM for all | Generate as separate tracks at the same BPM and key, or make one and remix stems |
| Stingers | Rebirth, level-up, rare drop, win, lose | 1-5 s, no loop | Short, bright, in the theme's key |

- **Instrumental by default.** Vocals fight the game's sounds and get
  moderated more. Add "instrumental, no vocals" to every prompt unless the user
  wants a sung theme song.
- **One key and one tempo family per game**, so cross-fades between cues work.
  Write the key and BPM on the cue sheet and put them in every prompt.
- **Genre from the game's feel:** cosy idle and sims suit lo-fi, chiptune or
  light orchestral. Obby and parkour suit upbeat electronic. Horror suits sparse
  ambient drones. Fighting suits drum-heavy orchestral or trap.
- **Save the cue sheet** in the game's folder (`<game>/audio/cues.md`), with
  every prompt, seed, key, BPM and asset id, so a cue can be regenerated or
  extended later.

## 2. Generate

Use claude-music. For a loop, ask for **longer than the loop** (about +30%), so
there is room to cut at a bar line. On an Apple Silicon Mac (no NVIDIA GPU),
ACE-Step runs through MLX (`<ace-step-dir>/start_*_macos.sh`, or the macOS
portable package), where `<ace-step-dir>` is wherever you installed ACE-Step.
Expect slower runs than on CUDA: use `draft` quality to audition ideas, then
`high` for the keeper. On a machine with an NVIDIA GPU, use ACE-Step's CUDA
launcher instead.

## 3. Make it a seamless loop

A loop that clicks or jumps is the most obvious sign of cheap game music.

1. **Bar length:** seconds per bar = 4 × 60 / BPM (4/4). Pick a whole number of
   bars (8, 16 or 32) that lands well inside the generated audio.
2. **Cut on a bar line** after the intro, so the loop starts at full energy:
   `ffmpeg -ss <start> -t <bars × bar_seconds> -i in.flac loop.wav`.
3. **Hide the seam:** crossfade the loop's last ~0.5 s into its first ~0.5 s
   (`acrossfade`), or end on a sustained chord. Then listen to the seam
   played twice in a row.
4. **Zero crossings:** trim a few milliseconds so both ends sit at silence or a
   zero crossing. A click at the seam means this was skipped.

## 4. Master for a game

- **Quieter than a song.** Aim for about **-18 LUFS** integrated for background
  music (streaming uses -14), with peaks at -1 dBTP or below, so effects and UI
  sounds stay on top. Stingers can sit around -14 LUFS.
- `ffmpeg -i loop.wav -af loudnorm=I=-18:TP=-1:LRA=11 -ar 44100 loop_master.ogg`
- **Format:** OGG (Vorbis) or MP3, 44.1 kHz, stereo. Keep files small: Roblox
  limits length and size per upload, so check the current limits before
  uploading a long cue.
- All layers of one cue get the **same** loudness treatment and length, so
  they stay in sync and balanced when they are faded.

## 5. Upload

- Every upload is irreversible and moderated, and audio uploads have a monthly
  quota that depends on account verification. **Say how many uploads a batch
  will use before uploading,** and upload only settled cues.
- Routes:
  - Open Cloud (`rbxcloud assets create --asset-type audio-ogg …` or the Assets
    API) with your Open Cloud API key, if that key has the asset-write scope.
    Keep the key outside the project (a private key file or an environment
    variable such as `ROBLOX_API_KEY`), read it inside the command, and never
    print it;
  - or Studio's Asset Manager / Creator Dashboard by hand.
- Record every asset id on the cue sheet. Check that the experience can play
  it: an audio asset the experience lacks permission for plays as silence,
  with no error.

## 6. Wire it in Studio

- **SoundGroups:** `SoundService.Music` and `SoundService.SFX` (and `UI`), each
  Sound's `SoundGroup` set, so a settings slider or a duck can move a whole
  group.
- **Zone music:** one `Sound` per cue under the client's music controller,
  `Looped = true`. Crossfade over 1-2 s with TweenService on `Volume` when the
  player enters a zone (CollectionService-tagged zone parts, or a region check
  on the client). Never stop one track and start the next cold.
- **Intensity layers:** start every layer of a cue at the same moment with
  `Volume = 0`, `Looped = true`, and the same `TimePosition`. Fade layers in and
  out with the action; they stay in sync because they share length and BPM.
- **Stingers:** a separate non-looping Sound in the SFX group. Duck the music
  (Music group volume to about 40% over 0.15 s, back over 0.8 s) while it plays.
- **Client side:** music is presentation, so it plays on the client. The
  server only says what happened (zone entered, boss started).
- **Settings:** a music volume slider bound to the Music SoundGroup, saved
  with the player's data.
- **Check in a playtest:** hear every crossfade, the loop seam twice, and a
  stinger over the music.

## Report

End with the cue sheet: each cue's file, length, BPM, key, loudness, asset id
and where it is wired, plus anything still to upload.
