# VFX lessons

Rules the developer has taught about effects, each with the moment behind it. Newest
at the bottom. These win over the references when they disagree. Add one entry
per piece of feedback: the rule, then **Why** (what happened) and **How to
apply**.

## 1. Actual VFX, never 3D objects

Build effects from ParticleEmitters, Beams and Trails with textures. Never
from 3D objects such as sphere or ball-cluster "puffs".

**Why:** after a "flat, terrible coloring" complaint on a strategy game's
explosions, they were remade as shaded 3D ball clusters, and those were rejected
too: they read as 3D objects, not effects.

**How to apply:** fix flatness with particle technique instead:
- layered flipbook emitters with offset spawn shapes, random rotation and
  staggered `EmitDelay`;
- colour and size sequences; a dark layer or black twin for value
  (`vfx-design.md` §3);
- soft opaque smoke textures at `LightInfluence` 1 so the scene shades them;
- warm colour ramps, and smoke beside fire carrying the fire's colour.
