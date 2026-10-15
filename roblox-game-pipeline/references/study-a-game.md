# Studying a game (phase 0)

Before remaking, porting or competing with a game, pin down what it is
**measured**, not remembered. Prefer, in this order:

1. **Its source, when it exists.** Web games (CrazyGames, Poki) often ship their
   whole economy:
   - **Construct 3:** `scripts/c3runtime.js` holds every formula in the
     `C3_ExpressionFuncs = [` array; grep it for `pow(` to get the cost curves
     verbatim. `data.json` holds globals and atlases, and `<name>.json` the
     designer's balance tables. Skip the CrazyGames wrapper: the real bundle
     origin is the last entry in `performance.getEntriesByType('resource')`.
   - **Other engines:** look for JSON tables, then minified constants.
   - Recover the numbers exactly and say so. Never ship another studio's art;
     recreate it.
2. **Gameplay video.** The developer plays 10-15 minutes and records it, or use
   a YouTube playthrough (download it with the developer's OK). Extract frames
   with ffmpeg (`roblox-vfx/scripts/clip_frames.py` tiles labelled frames) and
   read off:
   - the core loop in one sentence and its steps;
   - the time to each milestone (first upgrade, first zone, first rebirth);
   - prices and yields per tier, to fit the curve (say it is fitted, not
     recovered);
   - the UI flow (which screens, in what order, what the HUD always shows);
   - where monetization appears (when the first offer shows, what it sells).
3. **Live game observation.** The AI can play a live Roblox game only by driving
   the real client with screen control (slow: about 3-5 s per action). Use an
   **alt account**, observe only, never farm. Botting risks moderation.
4. **Market data:** whatever analytics you have access to (a genre trend and
   breakout tracker, your own games' analytics) and scrapling or agent-browser
   for public pages.

## Output: `REFERENCE.md` in the game folder
- **The pitch** in one line, and the **core loop** as a numbered cycle.
- **A milestone timeline** (minute marks).
- **An economy table:** currency sources and sinks, cost and yield per tier,
  with formulas when known.
- **Screens and HUD.**
- **Monetization:** passes, products, prices, and when each is offered.
- **What to keep, cut and improve** for your version, with the design-advice
  skill's read on it.
