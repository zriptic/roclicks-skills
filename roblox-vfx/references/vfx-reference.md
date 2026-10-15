# Matching a reference clip

Load this with `vfx-design.md` and `vfx-craft.md` when the developer attaches
or points to a video or GIF of an effect to match.

## Reading the clip

`python3 SK/scripts/clip_frames.py <clip> [--from S --to S] [--count N] [--slowed X] [--full] -o sheet.png`
(needs ffmpeg) samples up to 16 frames over a span into one labelled sheet,
cropped to where the clip changes, and prints per frame:
- **time** in effect seconds from the span start. A clip known to be slowed
  (`--slowed 2` for half speed) is converted to real speed. Build to these
  times.
- **brightness** and **share** of the frame that changed, and the dominant
  **colour** of its brightest part: approximate. Compression, bloom and the
  background shift them, so check each against the frames.

Read the sheet image. Start with the whole clip at `--count 12`, then look
closer at fast stretches with a narrow span (the first 0.2 s of an impact, a
ring growing, sparks leaving the core), one span at a time. `--full` shows
what is around the effect, such as the ground or the caster.

## Read it before building

Name the layers the frames show, in the order they appear:
- the anticipation;
- the flash or core;
- the main body;
- secondaries (sparks, ring, debris);
- smoke and the fade.

Give each layer the times its labels show. Then plan it as `vfx-design.md`
describes, with the clip's timing and palette instead of your own.

**From the measurements to properties:**
- **Timing.** "Starts" is when the first layer emits. "Peaks" is when the
  flash or core is at its brightest. "Falls to half by" places the main
  layer's fade. "Gone by" is the latest any layer may still show (its
  delay plus its lifetime).
- **Brightness.** A peak near white across the frame is a flash core: short
  life, `LightEmission` 1, bright `Brightness`. A small rise is a glow, not
  a flash.
- **Size.** The share of the frame, and how much it grows from start to
  largest, is a ratio for a `Size` sequence, not studs. The clip's camera
  is not Studio's.
- **Colours by phase.** These are `ColorSequence` keypoints in order:
  build-up first, peak, then fade. Fading pixels are mixed with the
  background, so take the hue and lift its brightness rather than copying
  a muddy value.
- **A moving camera.** When the backdrop moves too, `share` is meaningless:
  read size and timing from the frames instead.

## Compare

Capture Studio at the clip's own key times (`Capture.hold`, `vfx-craft.md`
section 6) and put each capture beside the clip's frame at the same time.
- Use 4-6 moments: start, peak, half, gone.
- Aim the view the way the clip frames the effect: from the side, the
  front or above.
- Compare each pair for when it starts, peaks and fades, its size against
  the frame, its colours and its shape. Compare proportions, not position.
- **Compare at most twice.** Each round is a rebuild plus captures, and
  the reference cannot be copied exactly. After the second round, fix
  what the pairs show most clearly, then report what still differs.

## Say what you approximated

Roblox has no custom shaders. These can only be approximated:
- distortion and heat haze;
- refraction;
- an engine's bloom strength;
- a texture you cannot see in the frames.

Exact particle counts cannot be read from frames either. Say which parts
are approximations and how the result compares. Do not claim it matches.

If the result looks clearly faster or slower than the clip, and the
developer did not say how fast the clip plays, ask.
