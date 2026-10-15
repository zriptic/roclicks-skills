# QA (phase 8, and the check at the end of every build phase)

"Done" means measured and seen, never "it compiled".

## Every build phase
- **Logs:** `get_runtime_logs` has no errors or warnings from your code, in
  edit mode and in a playtest.
- **Screenshots:** take them from the player's view. Maps get 12+
  player-height shots under the place's full lighting (Atmosphere, Bloom,
  ColorCorrection, SunRays) plus 2 aerials. List the defects, fix them, and
  re-shoot the same angles before showing the developer.
- **UI:** a property sweep in `eval_client_runtime` checks that:
  - every visible TextLabel has `TextFits`;
  - no sibling controls overlap;
  - nothing escapes its parent;
  - every image `IsLoaded`.

  Also take a mock render at phone, tablet and desktop sizes
  (`roblox-ui-maker` `VERIFY.md`).
- **Effects:** capture key moments from the player's camera (`roblox-vfx`
  `Capture.luau`).

## The loop test (before launch)
1. **Simulate the numbers first** (sim script or the `luau` CLI). The time to
   each milestone should match `PLAN.md`.
2. **Solo playtest the loop as a new player:**
   - join, then follow the first-time flow;
   - first earn, first buy, first zone, first rebirth;
   - leave and rejoin: the data persists and nothing is duplicated.
3. **Multi-client playtest** (2 players) for anything shared: leaderboards,
   trading, servers, isolation between plots.
4. **Mobile:** device simulator at phone size. Buttons are reachable, nothing
   is hidden under the thumbsticks or the top bar.
5. **Purchases:** dev products and passes go through `ProcessReceipt` in
   Studio's test purchase mode, are granted exactly once, and survive a
   rejoin.
6. **Write `QA.md`:** each defect with its repro steps, fixed or open, plus the
   timings you measured against the plan.

If the developer's rules say agents don't start playtests (see `rules.md`),
hand steps 2-5 to the developer as a playtest checklist and verify what you
can in edit mode.

Clicks in playtests: GUI y + 58. Halve the screenshot pixels to get click
coordinates (`gotchas.md`).
