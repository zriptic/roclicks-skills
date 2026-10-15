# REVIEW_LOOP: show the developer, learn from them, then import

Nothing goes into Roblox until the developer has checked the HTML and said yes. Every correction they make
becomes a rule in LESSONS.md.

## 1. Before showing anything (self-check)
- `python3 build.py`, then open each page with `?check` in the browser pane: `checkOverflow()` must return
  `{overflow: [], broken: []}`. Fix spills (text past its plate/tile) and broken images first.
- Render headless for a layout pass (images may drop at random in headless; judge images in the pane):
  ```bash
  mkdir -p shots
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --hide-scrollbars \
    --window-size=1920,1080 --force-device-scale-factor=2 --run-all-compositor-stages-before-draw \
    --disable-features=LazyImageLoading,LazyFrameLoading --virtual-time-budget=15000 \
    --screenshot=shots/<page>.png "http://127.0.0.1:<port>/<page>.html?raw"
  ```
  Read the PNG. Compare against the reference: tokens right? one treatment per element type? nothing drawn over
  a prize? text readable at phone scale (body >= 26 px)? Fix before the developer sees it.
- Every state exists: normal, hover, pressed, locked, unaffordable, owned, empty, full, error, longest text,
  phone layout (`states.html`, `hud_phone.html`). Runtime pieces are on `templates.html`.

## 2. Show it
- First round of a new game: `style.html` (reference | tokens | kit) + the first real screen, and a one-line
  question: "Does this style match what you want?"
- Open the page in the browser pane so the developer can click around: `mcp__Claude_Browser__navigate` to
  `http://127.0.0.1:<port>/index.html` (gallery of every page) or a single page. The preview server must be
  running (`preview_start` with a `.claude/launch.json` entry, or `python3 -m http.server <port> --bind
  127.0.0.1` from ui/). The pane screenshot is small; say which page to look at.
- If the developer is not at the desktop app, or wants to pass it on: publish a gallery page as an Artifact (the HTML
  with images inlined as data URIs) or send the 2x PNGs from `shots/`.
- Tell the developer in plain words: what is on each page, which states are shown, what is a placeholder (stand-in world,
  sample numbers), and what you are unsure about. Offer 2-3 options only where you genuinely have a choice
  (style directions, layout variants); a decision page with phone + desktop shots and a recommendation works well.
- Then STOP and wait. Do not export or import while waiting.

## 3. Take feedback (every message about a UI)
1. Work out the GENERAL rule behind the specific complaint ("the buy button on the other one looks better" ->
   "measure every plate as rigorously as text").
2. Add it to the right section of LESSONS.md as **rule**, then why (the developer's words, short). Update an existing rule
   rather than adding a duplicate; mark contradictions "superseded".
3. Apply it to the element they named AND every element of the same type on every screen.
4. Reply with one line: what you learned and saved, then show the fixed screens again.
5. Praise is feedback too: when the developer approves something ("the UI is good", "yes I approve"), record WHAT was
   approved and why in LESSONS.md section 25 so the approach is reused.

## 4. Approval
- Import only after an explicit yes for those screens ("yes", "approve", "looks good, import it"). "Looks good
  but..." is not approval: fix the "but" first and show again.
- Approval is per screen set. A later change to an approved screen needs a quick re-show.
- After import, tell the developer what was built (screens, templates, instance count), what was verified and how
  (fit ratios, sweep results, mock scores), and what still needs their eyes in-game (sounds, real data, phone).
