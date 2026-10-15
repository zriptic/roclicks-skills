# ui-resources.com: textures, effects, backgrounds

This skill ships NO texture files. Every texture below is downloaded by you from https://ui-resources.com into
your own project, so the site and its creators keep the credit and the latest versions.

## What it is
https://ui-resources.com ("UI Resources" / ResourceHub) is a free, community-run library of Roblox UI/GFX
design assets: textures (including the **stud textures**), effects (sunbursts, halftones, sparkles, shines,
speedlines, chains, flames), cartoon game-map backgrounds, character renders, faces, brushes, UI sounds, plus
links to kits, plugins, fonts and tutorials. 1,100+ resources. Every card credits its creator. The rule:
**look here first for any texture/effect/background**, and **stud style must use a stud texture from here**.
Icons do NOT come from here: icons come only from your one licensed icon pack (SKILL.md step 3).

## Where downloads go in your project
```
<game repo>/ui/
  stud.png        the stud texture (kit.css and build.py load it by this name)
  tex/            every other texture/effect/background you download (paper, sunburst, halftone, ...)
```

## How to find and download an asset
1. Open https://ui-resources.com in the browser pane (`mcp__Claude_Browser__navigate`; load the browser
   tools first with ToolSearch) or your own browser. The page is client-rendered: plain `curl` of the page
   shows no resources.
2. Filter: the **Category** dropdown (Backgrounds, Brushes, Components, Effects, Faces, Gfx, Icons, Kits, Other,
   Plugins, Renders, Software, Sounds, Textures, Tutorials, Websites) and the **Tag** dropdown (Stud, Paper,
   Halftones, Sunbursts, Sparkle, Speedlines, Grid, Checkerboard, Metal, Light, Rays, Gradients, Fonts...), or
   the search box. The tag filter is also a URL: `https://ui-resources.com/?tag=Stud`.
3. Each result is a card (`article.resource-card`) with a preview and a **Download** button. Use the Download
   button, or, when automating, note that images lazy-load: scroll first, then read the real URL from the
   preview image. In the browser pane:
   ```js
   await new Promise(r => setTimeout(r, 1500));
   [...document.querySelectorAll('article.resource-card')].map(c => ({
     title: c.innerText.split('\n')[0], img: c.querySelector('img')?.currentSrc }))
   ```
   Download with `curl -sL -o <name> <url>` into the project (`ui/stud.png` or `ui/tex/`).
4. **Check the real format**: `file <name>`. Many files are WebP even when named `.png` (the stud texture
   is). Browsers don't care; Roblox uploads accept PNG/JPG/BMP/TGA only. Convert:
   `sips -s format png in.webp --out out.png` (macOS) or PIL `Image.open(x).save('y.png')`.
5. Note the creator from the card in the project's build.py header (credit is courtesy; the assets are free).
6. Respect "provided by"/credit lines; never re-upload a resource as your own pack, and don't redistribute
   the downloaded files (link to the site instead).

## The stud texture (default for stud style)
- ui-resources **"Stud texture"** (tag Stud, first card). The file is a WebP even though it is named `.png`:
  convert it, then save it as `ui/stud.png`. Expect about 894x894 RGBA, light grey studs on transparent,
  **4x4 studs per tile**.
- Use: overlay on a coloured plate face. CSS: `background: url(stud.png) 3px 4px / 112px 112px;
  mix-blend-mode: overlay; opacity: .95` (one stud every 28 design px). Smaller plates 84 or 72 px tiles; headers
  ~120 px. Keep it off the plate's dark bottom lip. Phase it so studs start on a clean edge.
- In Roblox the plate is exported as an image with the studs already baked (the stud blend happens in the
  HTML render), so the texture itself only needs uploading for runtime tiles or world MaterialVariants
  (`stud_asset` in rbx.json).
- Other stud textures on the site (tag Stud) have been useful: a 2x2 big-stud tile (~420 px), a darker 4x4
  raised-squares tile (~500 px), a small "universal" tile (~230 px) and wide opaque stud maps (~1516x758).
  Pick by the reference's stud size and contrast; one stud texture per game. If a different texture has a
  different studs-per-tile count, adjust `--stud` (tile size) so one stud still lands every ~28 design px.

## Other textures worth downloading (into `ui/tex/`)
| Look for (ui-resources category/tag) | Used for |
|---|---|
| Textures/Paper (e.g. "Cloud paper", old paper) | parchment/scroll styles, multiply over tan |
| Effects/Sunbursts | reward rays behind prizes (rotate slowly) |
| Effects/Halftones | comic/punk panel shading |
| Effects/Stars, Sparkle (shine, sparkle) | legendary sweeps, orbiting sparkles |
| Effects/Speedlines | speed/boost moments |
| Textures (scratch) | worn/grunge plates (screen blend) |
| Textures/Grid, Checkerboard | sheet backgrounds, debug |

Other styles have used, from the site: brush swashes and crown doodles (Brushes), splatters, wood, pirate/village
maps (Backgrounds), player renders (Renders). Download them per project when a style needs them.

## Design tips published on the site (worth following)
- One UIAspectRatioConstraint per section's top frame, never on every descendant (messy and slow).
- Nested corner radius: inner = outer - gap.
- Colour: strong text/background contrast, few colours, only the primary action saturated; black text is safe on
  bright backgrounds, white on dark; never a saturated hue on its neighbour (red on orange).
- Dark themes use near-blacks (#121212, #0B1215, #101720...) rather than pure #000.
- Check padding with equal markers on all four sides.
