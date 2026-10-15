# Launch (phase 9) and live ops (phase 10)

Nothing here goes public without the developer's explicit yes.

## Thumbnails and icon
- **Best results: Google Flow** with your reference thumbnails, in a browser
  signed in to a Google account with a Pro plan. Driving it from an agent:
  - upload the `ref_*` images by intercepting the file input;
  - attach them all with shift-click in the + picker;
  - set 16:9 and Nano Banana Pro;
  - ask for "10 SEPARATE thumbnails, one per idea";
  - send with the arrow button, since Return only adds a newline;
  - collect the 1376x768 results.
- **Fallback: Meshy `text_to_image`** at 16:9. Put the style in the prompt and
  name invented buildings ("not a real building"). Costs 9 credits each.
- **Write 10 distinct ideas first** (`PB/thumbnails/*` if you keep a
  playbook): one focal action, a big readable title, the game's colour
  identity. Show them, let the developer pick 3-5, then iterate.
- **The icon** is a 512x512 crop of the strongest thumbnail idea, readable at 50 px.

## Store setup
- **Name, description, genre, max players, and devices** (phone, tablet,
  console as they apply).
- **Dev products and passes:** create them with the Open Cloud key (Developer
  Products API, multipart with name, price and image). Read the key inside the
  command and never print it. Confirm every price with the developer.

## Publishing
- **First publish:**
  - Studio: File > Publish to Roblox As, choosing the owner (your account or a
    group).
  - Or a deployment tool such as Mantle (some Studio MCP servers wrap it as a
    create-game tool).
- **Updates:**
  - Team Create saves edits continuously.
  - Make them live with File > Publish, or Open Cloud place publishing from a
    `.rbxl` (`rbxcloud experience publish`, place id flag `-i`, key from an
    env var).
- **Settings:** Security has "Allow HTTP Requests" (needed for analytics) and
  "Allow Mesh & Image APIs" (needed if EditableMesh or EditableImage is used).
- **Group games:** your role needs to be allowed to create and edit
  experiences. A key from your personal account can't publish to a group's
  game.

## Analytics (wire in before launch)
- **An external analytics service** (third-party or self-hosted: sessions,
  live CCU, purchases, funnels), if you use one: put its SDK ModuleScript in
  ServerScriptService (for example as the ModuleScript `Analytics`), turn on
  HTTP Requests, add the game in its dashboard and use its key, then log
  funnel steps for the core loop's milestones.
- Roblox's own analytics: `AnalyticsService` custom events and funnels for the
  same milestones.

## Live ops (after launch)
- **Read the funnel daily for the first week.** The biggest drop-off is the
  next fix.
- **Plan updates with a design-advice skill**: what to ship
  next, and what goes in the thumbnail and update log.
- **Record** what changed and the effect it had in `GAME.md` (and generic
  lessons in `PB`).
