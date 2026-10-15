# Style notes: distilled from the 142-image reference dataset (July 2026)

This dataset is THE target look; it supersedes all earlier palette/recipe
mandates. The images are in the online gallery at
https://roclicks.gg/assets#stud-references (see INDEX.md for how they are
grouped and how to pick relevant ones). What they teach:

## Palette doctrine (no fixed RGB list)

- High-key pastel, sun-washed, minimal shadow. The recurring families:
  bright lime/spring greens (ground, hedges, tree blobs), **salmon / coral /
  terracotta for dirt, cliffs, and island rock** (earth is pink-orange, NOT
  brown), sand tans, **periwinkle / lavender for stone, castles, decks, and
  roads** (stone is purple-blue, NOT grey), flat cyan for sky and water.
- Accents are saturated candy colors: red/white and multicolor awning
  stripes, pink race paths and portals, gold/yellow markers, glow highlights
  on gameplay-important things (one glow accent per zone still holds).
- **Theme reskins the same vocabulary**: identical layout language recolored
  per biome: summer lime, winter white-blue + coral, sakura pink, halloween
  maroon + black trees, desert/savanna tan, underwater teal, lava. Pick 5-8
  colors per zone, uniform within the zone.
- A muted, atmospheric variant exists (the gallery's muted arena maps and the
  castle wall gate: sage pines, brown dirt arena, grey ruin skyline). Use it
  when the brief says gritty/realistic.

## Terrain & maps

- Maps are **floating islands** (in sky or flat cyan sea): green cap, salmon
  dirt strata, chunky stepped underside, often a sand lip at the waterline.
  Zigzag/terraced contour edges everywhere; no smooth slopes.
- Big surfaces wear big-scale stud texture; the **checkerboard two-tone tint**
  on fields/hills is a tiling Texture overlay, not colored parts: a 2×2
  checker image (`rbxassetid://<CHECKER_TEXTURE_ID>`, upload your own or pick
  one from the Creator Store), Face=Top, StudsPerTileU/V=8, Transparency=0.8
  (measured from a production baseplate .rbxm; full recipe in SKILL.md
  Material section). The Sonic-style checker hills in the gallery are the
  same idea.
- Tilled farm soil is terracotta with a visible **hex/waffle grid pattern**;
  worn dirt patches are irregular stepped blobs in grass.
- Islands chain together with **arched wooden bridges** (posts + rails).
  Rivers/waterfalls cut through hub maps; water is a FLAT bright cyan plane
  by default. The layered transparent water recipe is for hero water
  features, not every pond.

## The plot formula (the dataset's core layout unit)

Rectangular lawn plot + fence or hedge ring (coral picket, wood ranch, or
brick wall with corner posts) + grid of flat colored station pads/mats +
small shop stall at the edge + floating name sign. Plots repeat in rows,
rings, or island chains around a central road/strip. Player plots get a
"YOUR PLOT" banner. Whole games are built from this unit (farms, bee yards,
crafting yards, truck depots, dig fields, poker decks).

## Signature vocabulary (recurs across every map)

- **Striped awning stall**: the universal shop: 4 posts, counter, 2-color
  striped awning (any candy color + white), floating colored sign text.
- **Portal doorway**: chunky frame (coral/stone) with glowing blue/purple
  fill plane.
- **Trees: the verified voxel-blob recipe** (from close-up reference crops,
  July 2026; this supersedes the "few big cubes" guess): canopy is a stepped
  voxel SPHERE: ~7 stacked courses whose widths follow a rounded profile
  (0.5→1.0→0.55 of max width ~10-12), each course jittered ±0.8 with 2-3
  proud bump blocks (1.6-2.8), ~40% of bumps in a second patch green; trunk
  is a TALL stacked coral column (~40% of tree height, 2.8 wide, 4 segments,
  slight offsets). **Roots grow OUT OF THE TRUNK, not out of the ground**:
  each root starts on the trunk side ~2 studs up and angles ~40° down into
  the ground with a toe block at the landing; flat blocks lying beside the
  trunk read wrong. **Branches are arced, detailed limbs**: 3 chained
  tapering segments (built like a mini trunk, alternating shades), each
  joint buried 0.3 in the last, pitching up ~25° more per segment so the
  limb curves out of the trunk and dives into the canopy underside. Trunk
  coral (232,126,120)/(218,110,108).
  Other recipes stay for other zones: tiered pine, palm, dead tree. Winter
  frosts them white-blue; sakura pinks. USE FEW: reference maps run ~12-14
  ring trees + ~5 field trees on a 360-stud map; sparse and large beats
  many and small.
- **Highland borders are PLATEAU MASSES, not a perimeter wall** (from
  close-up crops plus a correction during review, July 2026): ~25 individual
  overlapping masses ring the map. Sizes vary wildly (small ledges 25×15×5 up
  to 85×45×24 three-tier stacks); each mass = stacked shrinking tiers with
  random offsets, grass cap + a protruding nib per tier, lower tiers darker
  rose. Long axis runs ALONG the border (depth points inward; orientation
  bugs kill it), inner faces clamped out of the play field, masses straddle
  the map edge. Trees go on the tall masses' top caps, spread evenly. Random
  placement + wild size variety is what makes it read natural; uniform cells
  read as a fence. The barrier rules (July 2026, confirmed on close-ups):
  - **The ring is a BARRIER: it surrounds the map with NO gaps.** Chain
    masses with ~20% overlap while marching each side; players must not be
    able to walk out anywhere.
  - **Minimum total height ~16 studs** (2 tiers); tall masses run ~23-27
    (3 tiers). No low open bay: every side is walled.
  - **NEVER two same-size masses at the same Y directly in front of each
    other** (depth-staggered pairs must differ clearly in size AND height;
    rotate height classes so neighbors never match; forward mini-ledges
    must be far smaller and lower than what's behind them).
- **Paths are voxel TILE fields, not overlapping rectangles**: axis-aligned
  4-stud tiles (0.3 thick) filling a curved band (ring: radius band with a
  sine wobble on the edges), two-tone checker by grid parity; the edges
  come out naturally stepped. Way closer than chained rectangles.
- Roads: blue-grey asphalt with yellow center dash + white edge lines;
  tan paved paths with white stepped-chevron arrows; red-carpet lanes and
  pink ribbon race paths for gameplay routes.
- Castles: periwinkle brick walls with **random darker brick inset patches**
  for texture, crenellations, cone/tent spire roofs in mint/teal/orange/team
  colors; castle rows recolor per team.
- Buildings: warehouse sheds with rust/maroon roofs (steal-a-base rows along
  a road), beach pavilions with orange tile roofs, thatched huts, simple
  gable houses, stacked-floor tower malls with per-floor shop fronts.
- Props: crates, barrels, lanterns, telephone poles with sagging wires,
  parasols, floor decals (Safe Zone shields, arrows, zone rings).
- Interiors exist (backrooms-orange stud walls, gym/hub rooms, castle
  courtyards with FURNACE/enchanting stations): same stud doctrine inside.
- **Warehouse interior kit** (built 1:1 July 2026, recipes verified): floor =
  8-stud diamond-plate tiles (Weld) in two charcoal greys over a dark grout
  underlay; walls = 2-stud corrugation courses alternating two greys with
  indigo pilasters (one gets a black/white hazard-stripe base); roof = 1-2
  open lattice trusses (top/bottom flange + diagonal web struts) high up
  with sky gaps. Keep it SPARSE; dense lattice reads wrong. Garage door =
  indigo frame + navy 5×4 raised panel grid; pallet racking = indigo posts
  with X cross-braces + orange beams/decks; crate = gold cube + dark corner
  trims + X braces on ALL four side faces (dark, chunky); container = body +
  vertical ribs on all faces incl. ends + corner posts + top rails/slats +
  double doors with 2 lock rods & handles each; tarp bale = chamfered core
  in pale yellow-green, Weld quilt pattern, 2 darker strap bands, sized to
  tower over whatever it sits behind; pallets = 3 runners + 6 slats,
  terracotta.

## Composition habits

- Whole map reads as ONE island silhouette from orbit; hub roads cross it.
- Vendor/shop rows cluster at spawn; gameplay plots fan out from them.
- Vertical drama: volcano cones with lava streak + smoke, waterfalls off
  cliff faces, race paths climbing through stacked biome gauntlets, spire
  towers. Don't build flat.
- Signage is part of the style: floating bold colored text over every shop,
  billboards (MYTHIC in 10:00), menu boards on posts.
- Cross-sections show: cliff faces reveal strata (cap/dirt/rock), so build
  islands as real layered volumes, not skinned boxes.

## Confirmed constants (dataset agrees with existing rules)

Studded plastic on every surface; chunky rectilinear massing (chamfered
cubes OK for tree blobs/rounded terrain lips); stepped/terraced everything;
scenery gets the detail budget while gameplay furniture stays simple; market
stall + fence + bridge vocabulary; one glow accent per zone; Neon as accent
only.

## Measured exemplar: a production player base

Measured part by part (2026-07-20) from the player-base template of a live
stud-style tycoon place: 1,033 BaseParts (including 102 Unions and 42
MeshParts) in 112 sub-models. The raw dump is not shipped with this skill; these are
the lessons it gave.

### Inventory (parts per section)

Nature/set dressing 594 · main item display structure 172 · shop 84 ·
bridge 30 · two roller (gacha) machines 22 each · placement area 19 ·
upgrade board, leaderboard and gamepass stands 17 each · base-upgrade
station 15 · reward chest 11 · base-unlock gate 6 · action (launch) button 5

Lesson: ~60% of the part budget is Nature/set-dressing, and every gameplay
element (rollers, buttons, launch pad) stays simple. This matches the skill's
"extreme detail on scenery, simple functional elements" doctrine with real
numbers.

### Palette actually used (top colors, RGB)

- Greens: 126,179,60 · 84,175,59 · 77,161,54 · 113,206,42 (foliage/ground)
- Browns/wood: 136,83,52 · 132,87,62 · 149,94,76 · 165,105,62 · 173,120,28
- Rock/greys: 121,99,97 · 104,85,83 · 124,124,124 · 109,109,109 · 203,203,203
- Accents: 207,109,76 (terracotta) · 2,106,175 (blue) · 243,164,107 (peach
  panel fill)

### Construction observations

- MaterialService carries four Plastic variants: `Universal`, `Weld`,
  `StudsNoGrid`, `Studs`; the template uses the first three (458/297/242
  parts). This set is canon (confirmed 2026-07-20) and SKILL.md matches it;
  the old Studs/Inlet/Weld set and the old ban on Universal are superseded.
  Faces are Smooth; variants do all the texturing.
- Structures (stall frames, posts, rails) run `Weld`; big fills and terrain
  run `Universal`/`StudsNoGrid`.
- Typical member sizes: posts/rails ~0.88 thick, panel fills ~0.08-0.12 thin
  slabs layered in front of structure, kiosk footprints ~25 studs wide.
- Cylinders are rare (12 of 1,033), used as feet/caps on posts, rotated 90°.
- Unions carry curved/punched shapes (ramps, arches); meshes are decorative
  one-offs. Everything else is plain Parts, which confirms the parts-first
  doctrine.
