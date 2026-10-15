---
name: studify
description: Stud-style Roblox building (the modern studded-plastic revival look of recent hit simulator and tycoon games). Use this whenever building, generating, or scripting models, maps, houses, towers, props, plants, or scenery in Roblox Studio, whether via Studio MCP tools or by writing Luau build scripts. Especially when the user says "stud", "studded", "brick", "chunky", "retro", "classic", or just asks to "build" something without naming a style, and ALWAYS when the user provides a reference image of any style or subject and wants it recreated as a detailed stud-style build. Do not use for flat low-poly/SmoothPlastic or realistic PBR builds when the user explicitly asks for those.
---

# Stud-Style Building

**Study the references first.** This skill's reference dataset (142 images of stud-style builds) lives in the online gallery at https://roclicks.gg/assets#stud-references . Read `references/style-notes.md` (the distilled doctrine; it supersedes any older rule it contradicts) plus `references/INDEX.md`, which describes how the gallery groups the builds (one group = one build shot from several angles). Before building, open the 3-6 gallery images whose group matches the job (a castle job means the castle-kingdom and castle-row shots, a farm-plot job the ranch/animal-plot and bee-farm shots), saving them to a scratch folder if your tools need local files to view them, and treat them as ground truth for silhouette, detail density, color balance, and prop vocabulary. Your own reference images work the same way: keep them in a local folder and open the relevant ones before building. The written rules below tell you WHAT to do; the images show what DONE looks like. When a rule and a reference image disagree, the image wins for look-and-feel questions (colors, shapes, proportions); flag structural contradictions to the user.

You are building in the stud style: bright plastic bricks whose faces visibly wear stud patterns, chunky silhouettes carrying lots of small detail. Think of the recent wave of hit stud-style simulators: a modern, playful aesthetic that quotes old Roblox without being stuck in 2008. The two things that make or break it: **every surface shows a stud pattern**, and **big shapes are broken up by small detail pieces**. A build that is just a few large smooth boxes fails on both.

## Material and surfaces: the non-negotiables

- `Material = Enum.Material.Plastic` on **every part**. Never SmoothPlastic, never textured PBR materials (Brick, Concrete, WoodPlanks, Glass...). Color does the work, plastic carries the studs.
- **Neon is an accent, never a body.** Allowed for thin glow strips and trim edging, lava, portals, glowing pads/bases under hero props, machine glow cores: the one glow accent that marks a zone's gameplay-important things (see `references/style-notes.md`). Neon parts skip the stud pattern (Smooth faces, no MaterialVariant). Walls, props, and massing stay Plastic; if a Neon part is thicker than trim or bigger than a pad, it's a body and it's wrong.
- Every part wears a **stud pattern on all faces, walls included**. The canon variant set (verified against live production stud-style places, July 2026; see the "Measured exemplar" section of `references/style-notes.md`) is four Plastic-based `MaterialVariant`s:
  - `Universal`: the workhorse; big fills, terrain, ground, panel faces, large slabs.
  - `StudsNoGrid`: clean stud field; the alternative large-surface look, roofs, floors.
  - `Weld`: X pattern; structural members (posts, rails, frames), crates, trim.
  - `Studs`: classic round studs; available for walls and accents.
  - `Glue` stays banned, and there is no `Inlet` variant in current places (older skill text referenced a `Studs`/`Inlet`/`Weld` set, now superseded).
- **Preferred mechanism: MaterialService variants.** Check `game:GetService("MaterialService")` at the start of every build (part of the survey; never assume the roster) and use ONLY variants that actually exist there; apply with `p.Material = Enum.Material.Plastic` and `p.MaterialVariant = "Universal"`. This textures every face of the part, walls included, which is exactly the look. Faces stay `Smooth` when variants are doing the texturing; that is how the real template is built. If a place carries scale versions (`_2`/`_4` suffixes), use them when a big part needs bigger studs to read well.
- **Fallback: SurfaceTypes.** If the place has no such variants, set patterns as SurfaceTypes on every face (`TopSurface`, `BottomSurface`, `FrontSurface`, `BackSurface`, `LeftSurface`, `RightSurface`) and tell the user they can add MaterialService variants for a stronger render. Map `Universal`→`Universal`, `Weld`→`Weld`, `Studs`/`StudsNoGrid`→`Studs` (there is no StudsNoGrid SurfaceType).
- **Consistency beats variety.** Decide a pattern map up front by *role* and apply it uniformly. The real template's map: structure (posts, rails, frames, crates) = Weld, big fills/terrain/panels = Universal or StudsNoGrid. Every instance of a repeated element gets the SAME pattern: if one merlon is Studs, all merlons are Studs; if one fence post is Weld, they all are. Mixed patterns across identical siblings read as a bug, not detail. Two to three patterns per build, assigned by role, never at random.
- **Texture overlays are part of the style: ground reads checkered, not flat.** The dataset's checkerboard ground is NOT colored plates: it's a tiling `Texture` instance laid over the studded part (confirmed from a production baseplate .rbxm, July 2026). The known-good recipe: `Texture` with `Texture = "rbxassetid://<CHECKER_TEXTURE_ID>"` (a 2×2 checker image; upload your own or pick one from the Creator Store), `Face = Top`, `StudsPerTileU/V = 8` (≈4-stud squares), `Transparency = 0.8`, on grass fields, mound caps, and path tops (`StudsPerTileV = 6` reads well on narrow paths). The part below keeps its stud pattern: the texture is a tint, the studs still carry the surface. Use one Texture per big slab, not per-plate colored checkering (450 plates of fake checker was the failure that taught this). Other subtle top-face tint textures (tilled-soil grids, worn patches) follow the same pattern once you have their asset ids. This does NOT reopen decals-as-detail: doors, signs painted on walls, and fake modeled detail stay banned. Overlays are for large ground/top surfaces only.
- **Rock exception**: rocks (and similar raw ground props) get `Inlet` on the **top face only**; sides and bottom stay `Smooth`. With MaterialVariants (which texture all faces), skip the variant on rocks and set `TopSurface = Inlet` instead.
- **Tiny-part exception**: parts under ~0.5 studs in every visible dimension (door handles, bolts, petal tips, lamp fittings) skip the pattern entirely: plain `Plastic`, no MaterialVariant, `Smooth` faces. Studs at that size are visual noise; clean plastic reads better.

## Grid and rotation

- Work on a **0.1-stud grid**: sizes and positions in 0.1 increments. Do the big massing in whole studs so the build stays tidy, then go fine for detail: 0.2-0.5 thick plates, sills, and trim are encouraged. Parts do not need to be 1 stud thick; walls can be 0.5, trim can be 0.2. Match the increment to the job: whole studs for floors, walls, and layout; 0.1 for planned detail work. 0.01-level precision is only for perfecting something already built (final alignment of a fitting, the z-fighting micro-offsets); general placement at arbitrary decimals reads as sloppy work, not precision.
- Rotations in **15° increments** (0, 15, 30, 45, 60, 75, 90...). Use tilts sparingly and with intent (a roof pitch, a leaning signpost, a flower head cocked 15°), not random jitter.
- Parts should meet cleanly: compute Y as `baseY + height/2`, rest faces on each other.
- **Kill z-fighting with tiny scale offsets, on EVERY axis, not just the obvious flush face.** Think of it as x-fighting, y-fighting, AND z-fighting: the flicker happens whenever two faces land in the same plane on ANY axis, and Y is the most common offender. Two parts whose tops sit at the same height while their volumes touch or overlap (stacked slabs, overlapping ring/road segments, seat rows, floor pieces meeting a threshold) shimmer just as badly as trim flush on a wall. The rule: **any time two parts touch or overlap, check every axis for coincident faces and scale one part by 0.0001** (or nudge it 0.0001) so no pair of faces is exactly coplanar: `1.7` tall vs `1.7001`, `4` deep vs `4.0001`. Deliberate overlaps are the biggest trap: identical-size parts overlapping at identical heights (curved ring joints, organic clipping, rope segments, path chains) WILL flicker where they cross, so give the overlapping one a hair more height or depth. It's invisible to the eye; sweep for shared planes before calling a build done.
- **Check at placement time, every single part, before it's committed.** Name the part's neighbors (what it rests on, butts against, or overlaps) and compare all six of its face planes against theirs; if any min/max face lands exactly on a neighbor's plane with visible overlap, bake the offset in NOW. Placing first and hoping to catch it in QA is how 300-conflict builds happen. Flush is never the intent: trim, pilasters, plinths, bands, and parapet caps sit PROUD of their wall (0.05+), not on its plane. Then don't trust eyeballs for the final pass: run an **automated coplanar sweep** before calling any build done. For every pair of touching/overlapping axis-aligned parts, compare face planes per axis (flag pairs whose min or max planes are within ~0.00005 while overlapping more than ~0.05 on the other two axes), fix hits by growing the smaller/decorative part ~0.05 proud of the shared plane (relief reads better than flush anyway) or nudging 0.001, and repeat the sweep until it reports zero.

## Scale and proportion

A Roblox character is about **5 studs tall and 3-4 studs wide** (R15 runs a touch taller; call it 5-6). Size everything against an imaginary figure standing next to it, and keep the whole build on that one ruler:

- Doorways ≥ **7-8 tall × 4-5 wide** including the frame; interior ceilings 8-12.
- Storeys ~10-12 studs floor-to-floor; window sills start ~3 studs up.
- Counters and tables ~2.5-3 tall; seats ~1.5; fences and railings 3-4.
- Handheld props (tools, food, gear) ~1-3 studs so they read hand-sized.

Stay on human scale **unless the user asks for something different** (a giant's kitchen, a micro village); then rescale everything consistently to the new ruler, never just one object.

## Shape language: chunky, not blocky

The silhouette is chunky; the surfaces are busy. Build in three scales:

1. **Massing** (whole studs): the body of the house, the tower shaft, the ground slab.
2. **Mid detail** (0.5-1 stud): window and door frames that protrude 0.1-0.3 from the wall, corner posts, trim bands at floor lines, sills, fence posts.
3. **Fine detail** (0.1-0.4): shingle lips, flower petals, door handles, lamp fittings.

Every large flat face should have something on it: a frame, a band, a shutter. If a wall is one big rectangle of a single color, it needs a detail pass.

- **Break the box.** Boring cube rooms and flat uninterrupted walls are the mark of a beginner build. Footprints get notches, L-shapes, and stepped-out wings instead of one rectangle; long walls get piers, pilasters, insets, or windows every 8-12 studs so no wall reads as a single slab (floors and ceilings too: beams, coffers, borders). And **don't forget the Y axis**: never put everything on one plane. Small elevation changes are enough: a doorstep up, a sunken hearth, a raised platform for the counter, two stairs to the back room. Flat ground plus flat rooms is bland no matter how good the trim is.

- **Roofs**: prefer **stepped roofs** (stacked slabs that shrink as they rise, giving a staircase silhouette) or layered shingle rows (thin wide slabs, each row overlapping the one below by a lip). Wedges are allowed as accents (dormers, small canopies), but a roof made of exactly two big wedges is the "too blocky" look to avoid.
- **Stay rectilinear.** Balls are for very rare tiny accents (a lamp bulb, a doorknob), never for foliage, bushes, or any massing; the style is square-shouldered. Cylinders sparingly (poles, barrels); trunks and pillars read better as square posts.
- Use `Part`, `WedgePart`, `CornerWedgePart`, `TrussPart`. **Never** MeshParts or inserted free models: complexity comes from many simple parts.
- **Unions are a tool: reach for them when steps can't make the shape.** `UnionAsync`/`SubtractAsync` (or Studio's Union/Negate) earn their place for arches, round-cornered slabs, curved cutouts, wheel arches, and for punching door/window openings cleanly through a wall; negating the opening out of one wall slab makes clipping impossible. Apply `Plastic` + the stud `MaterialVariant` to the result; SurfaceType studs do NOT render on unions, so in fallback places without variants use unions only where a smooth face is acceptable. The bread and butter is still many simple parts; unions are for the shapes that need them.
- **Unions are for shape, never for performance.** A plain Part is already the cheapest thing Roblox renders (12 tris, preloaded); a union is a unique shape the engine must compute, its tri output is poorly optimized, and a duplicated union still loads all its source parts before running the CSG. So "unioning to consolidate" usually makes performance WORSE, not better. Part count alone is not lag (cylinders and wedges already carry more tris than blocks). So: union when the shape demands it (arches, curved cutouts, punched openings), keep the source parts recoverable (`UsePartColor`, or an un-unioned template copy set aside) so editing isn't destroyed, and never union a pile of blocks just to shrink the Explorer. The professional answer for genuinely complex one-piece shapes is a Blender mesh, but MeshParts are outside this style, so here the answer stays: many simple parts. Real optimization wins: one long rail instead of five collinear segments, clone a finished sub-model instead of regenerating it, and don't spend parts where no camera will ever be.

## Fit and depth

- **No gaps, ever.** Windows, doors, walls, frames, sills, and trim must actually touch the parts they meet. A hairline gap between a jamb and its wall strip, a sill floating 0.1 off the wall, or wall strips that don't quite close around an opening all read as broken, not detailed. Frames fill their openings exactly; wall strips around an opening meet the frame on every side. Fix gaps by **resizing** the part to close the distance (then apply the 0.0001 anti-z-fight offset), not by nudging until it looks close. Sweep every opening for daylight during QA.
- **Close seams by overlap, never by inset: deliberate micro-gaps are the #1 self-inflicted bug.** Never "avoid z-fighting" by insetting a part 0.05-0.3 from its neighbor: that slit is invisible from the build camera and glaring at player height, where it reads as a bright daylight crack. The correct seam is EMBED + DIFFER: extend the part 0.1-0.3 INTO its neighbor so the joint is buried, and make the two sizes differ by 0.0001+ so no faces are coplanar. This applies doubly to environment joints (water against bank walls, bed slabs against channel edges, foam against rocks, surface strips on water): butt or overlap them, never float them apart. The 0.0001 rule kills shimmer; overlap kills slits; you always need both, and a gap is never the fix for a flicker.
- **Openings are SEALED, not just occupied: the door test.** A door or window is finished only when no sight line escapes it: the frame fills the opening on all four sides (head + both jambs + threshold/sill), every frame member overlaps 0.1 into the wall strips around it, and the leaf/pane overlaps 0.1 into the frame members. A leaf sized to "fit" its opening exactly is guaranteed to leave 0.1-0.4 slits at the top and sides, which read as black cracks or sky. Slab-only doors (a panel floating in a hole with no frame) are banned. Behind every opening sits something opaque (an interior color box or warm glow block filling the space behind, embedded into the opening's edges) so nothing sees through the model to the outside. Verify by orbiting each doorway at player height: any dark slit, sky sliver, or through-view means it's unsealed.
- **A door leaf is a framed panel, never a bare pane.** Each leaf gets its own visible construction: side stiles (0.4-0.5), a top rail, a chunky bottom rail (1-1.5), a mid rail at handle height, and glass/panel insets embedded 0.2 into those rails. Push bars, handles, and kick plates sit PROUD of the leaf's outer face (0.1-0.2 in front of it); a plate placed at the same depth as the glass ends up inside it, which both z-fights and looks broken. A full-height pane with one thin stile reads as a shop display, not a door.
- **Transparent parts get one layer and buried edges.** Transparency double-punishes sloppy seams: any gap behind or beside a transparent part glows through it, and stacked transparent slabs (a "deep" layer under a "surface" layer) sort against each other and shimmer. So: ONE transparent slab per line of sight (a single full-depth water body, not stacked tints), its edges embedded 0.1-0.2 into the opaque banks/walls around it, and everything meeting it either fully inside it (fish, pebbles: organic clipping is fine) or fully outside, never edge-kissing a transparent face.
- **Wedges flatten junctions.** When two parts of different heights meet and the step between their tops isn't an intentional feature, cap the junction with a `WedgePart` so the transition ramps instead of jumping: a roofline dying into a wall, a low trim meeting a taller sill, a stair stringer, the shoulder where a chimney narrows. A deliberate step is style; an accidental one is a mistake, and a wedge is the eraser.
- **Depth replaces pattern.** If a surface would be flat for more than a few studs, break it with relief, not color:
  - Wall bands aren't painted stripes: the zigzag triangles and dots are physical plates sitting ~0.1-0.2 proud of the wall.
  - Stone window surrounds are castellated by geometry: each quoin block is a separate part at a slightly different depth, alternating wide/narrow, so the frame edge is a literal zigzag silhouette. Sills get small corbel blocks underneath.
  - Doors get real recessed panels and a real pane grid, never a flat slab standing in for detail, never a decal.
- **Studs on tops earn their keep.** Even when a build leans on modeled relief for its texture, top faces often read best with the Studs pattern: a studded roof course, wall top, or ledge is part of the charm. Don't strip tops to Smooth without a reason (the rock and tiny-part exceptions above are the reasons).

## Color

- **No fixed palette: colors come from the reference dataset** (`references/style-notes.md`, Palette doctrine). The default register is high-key pastel: bright lime/spring greens for ground and foliage, **salmon/coral/terracotta for dirt, cliffs, and island rock** (earth is pink-orange, not brown), sand tans, **periwinkle/lavender for stone, castles, and roads** (stone is purple-blue, not grey), flat cyan sky/water, saturated candy accents (stripe reds/pinks, gold). A muted atmospheric variant exists for gritty briefs; see the gallery's muted/atmospheric arena group.
- Pick **5-8 colors per build/zone including at least one accent**, then apply them uniformly within the zone. Themes reskin the same vocabulary (summer lime, winter white-blue + coral, sakura pink, halloween maroon, desert tan, underwater teal): recolor, don't relayout.
- One leaf color per tree (trees are uniform, not gradient); vary the shade *between* neighboring trees. Rocks pick a random tone per slab from the zone's rock family so piles look natural.
- **Flowers are little models, not two blocks**: a green stem (thin part or cylinder), a leaf or two, 4-6 petal blocks around a contrasting center, 5-8 parts each; petals can tilt 15°.
- Windows: a pane is a simple plastic block (light blue or a pale sky tone reads as glass), always inside a protruding frame. Panes may be **fully opaque or lightly transparent (T ~0.2-0.4)**, but either way the material stays plain `Plastic`: NEVER the Glass material, never SmoothPlastic, never Neon. Color and (optionally) Transparency do the work; a material swap never does. Transparent panes need something behind them (interior wall color or a glow block), or they read as holes.
- **Water also earns Transparency**: see the Water recipe under Construction patterns. Semi-transparent water over a modeled riverbed is what makes water read as deep instead of painted.

## Blockout checkpoint: maps only

When the job is a MAP (a whole scene or area: a lobby, arena, park, town, tycoon plot, anything with a layout), do NOT go straight to finished building. Blockout first, then hand the layout to the user:

1. **Blockout pass**: lay rough placeholder volumes for every zone: ground slabs, hill masses, water bodies, building footprints as plain boxes, path ribbons, gameplay zones (spawns, lanes, pads). One flat-colored anchored part (or a few) per zone, named for what it becomes (`BLOCKOUT_Shop`, `BLOCKOUT_Path`, `BLOCKOUT_Hills`), all under one `Blockout` model. Spacing gets decided HERE (walking distances, gaps between buildings, breathing room around gameplay elements) because it's nearly free to fix at this stage and expensive later.
2. **Stop and hand it over**: screenshot the blockout, tell the user what each block is, and let them edit it in Studio: move, resize, delete, add blocks. Do not commence until they say so.
3. **Commence**: build the real thing to the adjusted blockout's positions and sizes, replacing each placeholder as its real version lands.

Single assets (a house, a tree, a prop, a vehicle) skip the checkpoint and get built directly. The blockout exists for layout decisions, and only maps have layout.

## Construction patterns

- **House**: floor slab, walls (0.5-1 thick) with protruding door/window frames and sills, a trim band between storeys, stepped roof in a contrasting color with a chimney punching through, doorstep, maybe flower beds under windows.
- **Stepped roof**: rows of 1.2-tall slabs, each 2 studs narrower than the last, overhanging the walls by 1-2 on the first row. 4-7 rows reads well.
- **Tree: pick ONE recipe per zone** from the dataset's menu, square/chamfered geometry only (no balls, no cylinders for canopies), canopy in ONE leaf color per tree:
  - *Blob tree*: 2-4 chamfered cubes clustered on a short square trunk; the dataset's most common tree.
  - *Tiered pine*: stacked shrinking slabs, tight and pointed, with a readable width rhythm (alternating cake 8,5,7,4,2 or symmetric diamond 4,6,8,8,6,4,2), every tier centered on the trunk, never nudged sideways.
  - *Palm*: bent/stepped trunk + chunky frond cross at the top (beach/tropical zones).
  - *Dead tree*: dark branching posts, no canopy (halloween/lava zones).
  Biome reskins recolor the same recipe (frost white-blue, sakura pink). **One scene, one recipe**: generate every tree in a zone from the same parameterized function (same trunk proportions, same canopy logic), varying only overall height (±20%) and the leaf shade between neighbors. Trees that each follow their own logic read as slop; consistent trees read as a forest.
- **Clipping is a bug between things, a technique inside a model.** Parts may interpenetrate ONLY while constructing a single model's form: a tree's canopy tiers sinking into each other and the trunk, a rock model's slabs clipping together, path segments chaining into one path model. Between separate things (one model into another, a prop into the ground, a crate into a wall, two neighboring props) clipping is NEVER acceptable: rest parts on surfaces and butt them against neighbors cleanly (with the 0.0001 anti-z-fight offset), never sink one into the other. The joinery micro-embeds from Fit and depth (0.1-0.3 buried seam joints, cable ends landing inside their anchors) stay; those are invisible connections, not clipping. If two separate things visibly share volume, one of them is the wrong size or in the wrong place.
- **Architecture never interpenetrates.** Windows, doors, and their frames own their wall space: leave a real opening (build the wall in strips around it, or negate it out with a union) and fit the frame into the opening. Never stamp a window through an unbroken wall so it clips the bricks, never let a door overlap the wall beside it, never let two solid architectural parts share volume. On buildings, overlap is a bug: if two parts intersect, one of them is the wrong size.
- **Cables, ropes, wires, and chains hang connected, never floating.** Build a hanging line as a chain of segments along a sagging polyline: compute the two anchor points ON the objects being connected (pole top, wall bracket) and embed each end ~0.2 into its anchor part; pick 3-7 midpoints dipping toward the middle; place each segment with `CFrame.lookAt(p1, p2)` sized to `(p1 - p2).Magnitude + 0.2` so consecutive segments interpenetrate at every joint. Both ends land inside the things they connect; a gap anywhere breaks the whole illusion.
- **Curved organic forms (trunks, branches, tails, necks) bend at the joints, not in space.** Chain segments the same way: each next segment starts buried ~0.3 in the end of the previous one and turns a consistent 15° step further, so the arc reads smooth and continuous. Rotating segments around their own centers leaves wedge-shaped gaps at every bend; that broken-curve look is exactly what to eliminate.
- **Grass tufts**: 3-5 thin blades (0.2-0.4 wide, 0.8-1.6 tall) in a deeper accent green than the ground, **leaning in different directions**: usually fanning out from one sprout point (blades tilted 15° outward opposite ways), sometimes a looser scatter of 2-3 blades. Mix both so no two tufts look identical. Sprinkle near trees, rocks, paths, and building corners.
- **Rock**: 2-4 slabs stacked with overhanging edges, each at a *different* 15°-step yaw, clipped into each other (all parts of the one rock model), resting cleanly ON the ground with the 0.0001 offset (never sunk through it), each in a different tone from the zone's rock family. Inlet on top faces only, sides Smooth (see the rock exception above).
- **Hill / map barrier** (also good decoration): hills must look *grown from the ground, not placed on it*. Build each hill from **2-4 overlapping dirt-tone blocks** (salmon/terracotta in the dataset's islands, tan in muted zones) of different heights and footprints, clipped into each other inside the one hill model, seated flush ON the grade (0.0001 offset, never sunk through the ground slab), some yawed 15° so the outline isn't one rectangle; cap every exposed top with an **overhanging leaf-green slab** (1.2-2.4 thick, 1-2 studs of overhang) that follows its block. Cluster hills in runs of varying size (a big one flanked by smaller shoulders that clip into it, built as ONE model per run so the overlap stays internal) rather than isolated boxes. Use bigger stud scales (`_2`/`_4`) on the big faces where the place carries them, and decorate the tops with trees, rocks, and grass tufts. Ring a map with them as natural walls.
- **Wooden ranch fence** (the reference fence; use for parks, yards, paddocks): square posts about 1×3×1 in the zone's wood tone, spaced every 5-7 studs, with **two horizontal rails** (0.5-0.8 thick, slightly thinner than the posts) spanning post to post: the top rail a little below the post tops so the posts poke up ~0.5-1 stud, the lower rail around mid-height. Rails butt into the posts or overlap them slightly rather than aligning perfectly; alternate two wood tones between posts and rails and apply the usual prop imperfection (a post 0.1-0.2 taller here, a rail nudged off-center there). Everything Weld pattern: the real template's fences run Weld on posts and rails.
- **Flowers, two forms**: the stemmed kind (stem + leaves + center + petals), and the *flat ground flower*: five 0.4-thick blocks laid flat on the grass in a plus shape, four petal blocks around a contrasting center.
- **Imperfection is charm, on props.** Hand-placed furniture-scale props (fences, rocks, crates, signs) shouldn't be laser-perfect: nudge fence post heights ±0.1-0.2, let a rail sit slightly off-center, yaw a rock or crate by 15°. Keep architecture (walls, roofs, towers) square and true; the wobble belongs to the small stuff.
- **Tower**: shaft with corner posts and a trim band every ~6 studs so it isn't one slab; overhanging crenellated top; TrussPart or spiral of steps inside; banners, braziers, arrow-slit frames as detail.
- **Ground/park**: layered slabs: grass base (leaf greens), sandy areas in the zone's sand tone, flower clusters, varied trees, ranch fencing.
- **Maps have altitude: never build a scene on one plane.** Any outdoor map or diorama gets real elevation by default, not on request: a raised plateau or high ground at one end (4-6 studs up, built like the hill recipe with tan mass + overhanging grass cap), corner hills of varying size, at least one terraced ledge (0.5-0.8 step with a wedge ramp per Fit and depth), and edge nibs (small ground blocks jutting past the plot border so the outline isn't a rectangle). Put trees and scatter ON the high ground so the skyline steps. If the scene has water, let the elevation drive it: the river should ENTER from high ground and drop, not lie in a flat trench.
- **Water, two registers.** Big water bodies (the sea around an island map, wide moats) are FLAT bright cyan planes in the dataset; no layering needed, the island silhouette does the work. Hero water features (a river through the hub, a pond players walk around, waterfalls) get the full layered recipe:
  - *Levels*: give any watercourse 2-3 elevations (a source stream up high, a waterfall or stone weir step, a lower reach) so the water itself has a silhouette. Weir/rapid: a row of grey stones across the channel with light-blue WedgeParts (high edge upstream) pouring over, foam row at the base.
  - *Transparent body over a modeled bed*: water slabs at Transparency ~0.35 sitting on an opaque sand bed, with the bed dressed: pebble scatter (small flat grey blocks), seaweed blades, fish (body + angled tail, 2-3 per scene), a half-sunken mossy log or similar. The bed showing through IS the depth.
  - *Waterfall*: rocky lip stones, vertical transparent panels (T ~0.25) with opaque white streak strips on the face, plunge foam cluster at the base, 2-3 mist puffs (T ~0.55) rising.
  - *Moving-surface detail*: elongated light-blue current streaks (0.1-0.15 thick, T ~0.1) riding just proud of the surface, all aligned with flow; white edge-foam licks where water meets the bank walls; small white/pale bubble cubes trailing downstream of rocks, falls, and rapids. Cause pairs with effect: foam and bubbles only where something churns the water.
  - *Life on top*: pick 2-3 per scene: a duck with transparent ripple rings, lily pads (flat green cylinders, one blooming), a jumping fish mid-leap with splash ring and droplets, cattails growing at the waterline. Banks are staggered rectangles lined with tan earth walls, never straight parallel edges.
- **Site logic: vehicles, circulation, zones.** Any build with roads, parking, or service lanes gets planned like a real site, BEFORE any detail:
  - *Zone the plot first*: building pad, vehicle lanes, parking aisle + stalls, pedestrian walks, landscaping, as non-overlapping rectangles. Nothing encroaches into a movement zone: no patio table in a parking stall, no wing or prop across a lane, no planter in the aisle.
  - *Vehicle proportions from the 5-stud ruler*: a car is ~8 long × 5 wide → parking stall ≈ 5-6 wide × 9-10 deep, one-way lane 6-7 wide, two-way aisle 9-10. Eyeball a car into every space you paint.
  - *Stalls hang off an aisle*: stall lines run perpendicular to the drive aisle with the OPEN end facing the aisle and the bumper/curb at the closed end; double-load the aisle where space allows. A stall whose open end faces a sidewalk, wall, or hedge is backwards: cars couldn't enter it.
  - *Trace every route enter→exit before building*: a drive-thru is a complete loop (enter from the lot, clearance bar, menu board + speaker, pay window, pickup window, exit back to the lot) with no dead ends and no structure sitting across it. Pedestrians too: door → walk → crosswalk stripes → parking. If the trace fails, move the massing, not the lane.
  - *Road paint is flat plates only*: dashes, stop bars, and stall lines are thin plates; a painted arrow is a rectangle tail plus a STEPPED CHEVRON head (2-3 flat plates narrowing along the travel direction). Never use a WedgePart lying on the ground as an arrow: its top-down silhouette is a rectangle, so from the only angle that matters it reads as a random floating square.
- **Plan before you place: every part answers three questions.** The recurring failure mode is placing parts one at a time without thinking through consequences; prevent it with discipline, not cleanup:
  - *What does this spot already hold?* Before adding any detail (canopy, counter, ledge, badge, trim), name what's already occupying that wall zone (wainscot, sill, another ledge). The new part REPLACES or MERGES with it; two decorative parts stacked in the same volume is guaranteed z-fighting and visual mud. One protrusion per spot.
  - *What holds this part up?* Every accent has a nameable anchor with both ends embedded: a badge sits ON a fascia (overlapping into it), a bracket connects canopy to wall (embedded both ends), a counter replaces the sill. At stud scale, solid chunky brackets and side cheeks beat thin diagonal sticks: if a support looks like a toothpick or the part floats, redesign it chunky. If you can't name the anchor, don't place the part. The one exception is deliberate floating: signs, floating islands, and magical set pieces MAY hover when the design calls for it. Ask "should this float?" first; if yes, let it float confidently (no fake toothpick support), if no, anchor it properly.
  - *What happens around it?* Check the neighbors and zones the part touches: does it poke into a lane or walk, block a turning corner (keep 2-3 studs clear inside every lane turn, 1+ stud from lane edges), shadow a window, or collide with a feature on the other side of the wall? Imagine standing at the worst angle (under the canopy, at the corner, in the lane) before committing.
  Write the zone map (explicit coordinate rectangles for pad, lanes, aisle, stalls, walks, patio, landscaping) BEFORE the first brick call, and re-check it whenever massing moves.
- **Facade composition: openings are composed, not scattered.** Compose each face separately: equal margins at both ends, even spacing between openings, centerlines aligned between storeys, windows centered on the face or on its structural bays. An off-center window is a deliberate move balanced by something (a door, a tower), never leftover space. And **never one box**: any commercial/civic build gets at least two massing moves before detailing: a projecting entry tower or vestibule that rises past the eave (the focal), a wing stepped forward or back, varied parapet heights. If the plan is one rectangle and the roofline one height, push or pull something first.
- **Paths**: no runway look; skip border trim rails. A *dirt path* is a **connected chain of overlapping dirt-tone rectangles** (terracotta/tan, 0.2-0.4 thick, Universal) of varying widths and lengths, each segment offset half a stud left or right of the last so the edge meanders, clipped together so there are no gaps: one continuous worn track, NOT scattered splotches and NOT a uniform strip. A *stone path* can be spaced stepping plates in the rock greys.
- **Detail pass**: after massing, walk each face and add the mid + fine scale. This pass is what makes the style; budget as many parts for detail as for massing. **Slow down here.** A build that stops at massing is slop; the extra time on sills, trim bands, lanterns, doorsteps, and set dressing is the entire difference between generated-looking and hand-made-looking. Never call a build done straight after the big shapes. **The expectation is EXTREME detail on EVERYTHING**, not just the hero building: every prop, fence, tree, sign, and corner of the map gets its own mid + fine pass. If any element looks like it took less effort than its neighbors, it isn't done.
- **The bar is a professional Roblox game, not a passable model.** Every build should look like a showcase piece from a shipped title, and that comes from depth and invention, not just correctness:
  - *Depth*: no face lives on one plane. Recess the openings, pop the frames, overhang the eaves, and put something visible BEHIND openings (a dark passage mouth, an interior wall color, a lit window glow block) so arches and doors read as space, not paint. Vary the roofline and footprint; a silhouette with steps, towers, and asymmetry beats a box with trim.
  - *A composed scene*: give the build a focal moment the camera lands on (a fountain, banner cluster, glowing forge), repeat one accent color as a thread through the whole piece, and occupy the edges (planters, crates, lanterns, scatter at corners) so it sits IN a place rather than on a slab.
  - *Invention*: add two or three unasked-for ideas per build that make it feel authored: a cat silhouette on a windowsill, a cart with spilled apples, washing on a line, a cracked step. Creative, specific, in-style surprises are what separate hand-made from generated; take the swing.
- **Compose in 3D with cause and effect.** A 3D scene is never captured from one angle: orbit it and make every viewpoint hold up, not just the screenshot angle. Two rules make set dressing read as real instead of "assets placed": (1) *function*: props sit where they'd functionally be (the shelf holds the herbs, bottles, and price tags this shopkeeper would actually use; the woodpile is by the door, the bucket by the well); (2) *cause pairs with effect*: a plant grows out of a crack, not out of solid pavement; moss sits under the drip line, soot above the brazier, wear on the step that gets walked on. If the effect is there but the cause isn't, move one until they line up; one misaligned pair quietly breaks the whole scene's logic.
- **Small objects get big detail.** Tools, food, handheld items, and hero props deserve 10-30 parts each: a hammer is head + face bevels + neck + wrapped grip bands, not two blocks. When the user asks for a small object, the part count goes UP, not down; detail density is what makes tiny things feel crafted.
- **Except functional/tycoon elements.** Buttons, pads, conveyors, spawn points, and other gameplay furniture stay SIMPLE: players read them as UI, not scenery. A conveyor is rails + belt plates + rollers; a button pad is base + button + maybe a price tag. No bolts, motors, gauges, cables, or chevrons on these. Spend the detail budget on buildings, nature, and decor props instead.

## Scripting pattern

Build via one Luau script (command bar or `execute_luau`):

```lua
local model = Instance.new("Model")
model.Name = "StudHouse"

-- true when the place has the stud MaterialVariants installed
local hasVariants = game:GetService("MaterialService"):FindFirstChild("Universal") ~= nil
	or game:GetService("MaterialService"):FindFirstChild("Studs") ~= nil

local function brick(size, cframe, color, props)
	local p = Instance.new((props and props.Class) or "Part")
	p.Size = size
	p.CFrame = cframe
	p.BrickColor = BrickColor.new(color)
	p.Material = Enum.Material.Plastic
	local pattern = (props and props.Pattern) or "Universal" -- "Universal"|"StudsNoGrid"|"Weld"|"Studs" (+ scale suffixes if the place has them)
	if hasVariants then
		p.MaterialVariant = pattern -- variants texture every face; faces stay Smooth
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	else
		-- SurfaceType fallback: StudsNoGrid has no SurfaceType, map to Studs
		local name = pattern:gsub("_%d$", ""):gsub("StudsNoGrid", "Studs")
		local surf = Enum.SurfaceType[name]
		p.TopSurface, p.FrontSurface, p.BackSurface = surf, surf, surf
		p.LeftSurface, p.RightSurface = surf, surf
		p.BottomSurface = Enum.SurfaceType.Inlet
	end
	p.Anchored = true
	for k, v in pairs(props or {}) do
		if k ~= "Class" and k ~= "Pattern" then p[k] = v end
	end
	p.Parent = model
	return p
end

-- stepped roof: rows shrink as they rise
local rows, wallTop = 5, 12
for i = 1, rows do
	local w = 20 - (i - 1) * 2
	brick(Vector3.new(w, 1.2, 16 - (i - 1) * 2),
		CFrame.new(0, wallTop + (i - 0.5) * 1.2, 0),
		"Bright red", { Pattern = "StudsNoGrid", Name = "RoofStep" .. i })
end

model.Parent = workspace
```

- Everything `Anchored = true`, everything under **one named root Model** parented to workspace.
- **Organize with nested Models: a hierarchy, not a flat dump.** Inside the root Model, give every logical section of the build its own sub-Model (`Base`, `Walls`, `Roof`, `Interior`, `Props`, `Landscaping`...), and every repeated multi-part assembly its own small Model inside those. Each tree, statue, lamp, table, flower is a Model of its parts, so the user can select, move, clone, or delete any piece with one click in the Explorer. Big builds nest deeper: `Colosseum → Arcade2 → Bay14 → Statue`. A 500-part flat list is unworkable; a tidy tree is what a professional place file looks like.
- Compute positions from shared dimension variables, not magic numbers, so the fine grid stays consistent.
- Name the parts that matter (`"Door"`, `"RoofStep3"`, `"PetalN"`).

## Reference forensics: MANDATORY when copying a specific build

Eyeballing a reference from memory produces wrong colors, wrong construction, and unnatural terrain. This was proven in July 2026 on a pet-arena map remake (three misses in one build: tan paths that were actually peach, a framed-rectangle portal that was actually a floating voxel oval, rectangular terraces that were actually rounded strata). When the job is "remake THIS," run forensics on the image BEFORE building:

1. **Crop and magnify** (PIL in a scratch folder): cut the reference into 4-6 regions (terrain edge, hero prop, path, one tree/prop close) and upscale 2x. Read each crop: construction details invisible at full-frame (voxel-built shapes, strata bands, branching trunks, texture overlays vs colored parts) are obvious zoomed.
2. **Sample exact colors**: pick pixels from each material region (5×5 median, avoid shadows and AO edges). Verify each sample landed where intended by cross-checking against the crop; blind coordinate guesses hit grass and sky. Build the palette from sampled values, not from named approximations.
3. **Count studs for dimensions**: studs are 1×1, so a close crop is a blueprint. Count studs across a door, table, or trunk to get real sizes instead of guessing proportions.
4. **The self-diff pass: the build is not done until the differences list is empty.** After building, capture the QA screenshot at the reference's camera angle and write the FULL differences list, element by element (terrain massing, path shape/width, each prop's construction and scale, scatter density, colors, lighting/framing), with the two images actually side by side: the same exhaustive enumeration you'd produce if the user asked "tell me all the differences." Do NOT compare the build against your plan or your memory of the reference; compare it against the reference image itself. QA-for-defects (z-fighting, gaps, floating parts) and QA-for-fidelity (does it match the target) are different tests; run both. Then fix the list and re-diff. Only an empty list, or the user approving the remainder, ends a remake. (Lesson from the pet-arena remake, July 2026: the build passed defect QA while a side-by-side found ~12 major fidelity misses, because no side-by-side ever happened during the build.)

Construction facts this process has already established (reuse them): checker ground = texture overlay (see Material section); terraces = rounded outlines with 2 horizontal strata bands (light rose over deep rose), built from wobble-edge perimeter cells; portals in this family = floating voxel ellipses (ring of ~1.5 cubes, pink fill, dark swirl), not framed rectangles; trees = branching coral trunks with 5-7-cube canopy clusters.

## Converting a reference image to stud style

When the user shares an image of *any* style (a photo, a render, another game's screenshot, concept art) and wants it as a stud build, translate it rather than copy it:

1. **Read the massing**: break the subject into 3-8 big rectilinear volumes (body, roof, wings, base). Curves become steps: a dome becomes stacked shrinking slabs, a cone becomes a stepped pyramid, an arch becomes a stack with corbelled sides.
2. **Map the palette**: pick the 4-7 dominant colors and snap them to the dataset's pastel families (lime greens, salmon/terracotta earth, periwinkle stone, cyan water, candy accents; see Color section). Ignore photorealistic texture; the stud patterns replace it.
3. **Keep the recognizable details**: the two or three features that make the subject *itself* (a clock face, a fin, a striped awning) get the mid/fine detail budget first.
4. **Apply the style rules as usual**: variants by role (Weld structure, Universal/StudsNoGrid fills), 15° rotations, stepped roofs, no transparency, no balls.
5. Show the result next to the reference expectations and iterate on what reads wrong.

## Building via Studio MCP

When connected to Roblox Studio through MCP tools:

1. **Never build blind: survey first, every time.** Before the first brick call, run a snapshot of the build area via `execute_luau` and work only from what it returns:
   ```lua
   -- survey the target region: real names, sizes, positions, rotations
   local params = OverlapParams.new()
   local region = CFrame.new(cx, cy, cz) -- center of intended build area
   local parts = workspace:GetPartBoundsInBox(region, Vector3.new(w, h, d), params)
   local out = {}
   for _, p in ipairs(parts) do
       table.insert(out, { Name = p:GetFullName(), Size = {p.Size.X, p.Size.Y, p.Size.Z},
           CFrame = {p.CFrame:GetComponents()} })
   end
   print(game:GetService("HttpService"):JSONEncode(out))
   ```
   The rules that follow from the survey:
   - **Guessed coordinates are banned.** Any number that CAN be read from the place MUST be read from it: ground top Y, plot bounds, an existing wall's face, a baseplate edge. Compute anchors from surveyed `Size`/`CFrame` (half-size offsets), store them in named variables (`groundY`, `plotCenter`), and derive everything from those. "The ground is probably at Y=0" is how builds end up floating or sunken.
   - **Attaching to a rotated part means using ITS CFrame** (`existing.CFrame * CFrame.new(offset)`), never world-axis math against a part the survey shows is rotated.
   - **Re-survey after any hand-back.** When the user edits the blockout (or anything else) in Studio, the positions you sent are stale: re-read the blockout's ACTUAL positions before commencing the real build. Same after any manual user edit mid-session.
   - **Audit collisions against pre-existing geometry after building**: run `GetPartBoundsInBox` over the finished build's bounds and flag any pre-existing part (not yours) intersecting your model. Clipping into the ground, a tree, or an existing building is a survey failure; fix it before QA.
   - If MCP is NOT connected (script-only / chat mode), don't guess either: ask the user to run the snapshot loop above on their selection in the command bar and paste the JSON back.
2. Build with `execute_luau` using the pattern above, wrapped in `ChangeHistoryService:SetWaypoint` calls so the user can undo.
3. **Mandatory QA + polish pass: when you think the build is done, it isn't.** Frame the build with `screen_capture` from several angles (front, back, three-quarter, plus close-ups of doors, windows, and any cables or curves) and hunt for:
   - z-fighting shimmer → fix with the 0.0001 scale rule, checking EVERY axis: same-height tops on touching/overlapping parts (Y) are the most common source, not just flush vertical faces
   - windows/doors clipping into wall bricks, or any two parts visibly sharing volume that don't belong to the same model's construction (cross-model clipping is always a bug)
   - hairline gaps where windows, doors, frames, sills, or wall strips should touch: close them by resizing (see Fit and depth), and cap accidental height steps between meeting parts with a wedge
   - deliberate insets left as z-fight "fixes" (water floating off its bank walls, bed slabs shy of channel edges, foam hovering off rocks): embed them per Close-seams-by-overlap; and drop the camera to PLAYER HEIGHT for at least one close-up sweep, because slits and seams invisible from orbit are glaring from the ground, especially behind transparent parts
   - cable/rope/wire segments with gaps or ends that don't land inside their anchors
   - organic curves (trunks, tails, branches) breaking apart at the joints
   - accidentally floating parts (deliberate floaters such as hovering signs and islands are fine when chosen on purpose), sunken parts, smooth faces that should be studded
   - out-of-proportion elements: check against the 5-stud character
   - flat undetailed faces that still need the mid/fine pass
   - a map sitting on one plane: outdoor scenes need the altitude pass (plateau/hills/terrace/edge nibs), and water needs its levels, transparent body over a dressed bed, and churn detail (see the Maps-have-altitude and Water recipe bullets)
   - broken site logic: stalls opening away from their aisle, a lane or drive-thru loop blocked or dead-ended, props sitting inside movement zones, lane/stall widths a car couldn't use (see Site logic)
   - props clipping neighboring props (a seat into a hedge, a bin into a planter, an umbrella into a wall): the plan-before-place neighbor check applies BETWEEN props too; and road-paint arrows that read as floating squares from above (must be flat stepped-chevron plates)
   - scattered or off-center openings: check each face's margins and spacing against Facade composition, and a one-box silhouette that never got its massing moves
   Fix everything found, re-capture, then take one more polish lap for nice-to-haves (an extra trim band, a lantern, grass tufts at a corner). Only a clean pass ends the build.
4. Do not delete or modify anything you didn't create.
