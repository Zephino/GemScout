# Changelog

One entry per change request, newest first (see `.cursor/rules/changelog.mdc`). The version here always matches `VERSION`. Times are US Eastern.

## Version 00.01.02
Date: 11/06/2026
Time: 12:48 AM

### Changes
- **Difficulty**, chosen when you press Play:
  - **Easy:** 5 hearts, unlimited shots with a short cooldown.
  - **Medium:** 3 hearts, 6 shots plus ammo crates (+5 each).
  - **Hard:** 1 heart, 10 shots for the whole cave.
  - On Medium and Hard an empty blaster recharges one shot every 15 s, so a cave can't become impossible.
- **Health:**
  - Each hit costs a heart, then you flash and can't be hurt for a moment.
  - Out of hearts restarts the cave (same seed).
  - One heart pickup per cave.
  - The no-damage bonus now really requires no hits.
- **The blaster:** shoot with J/C, controller B, or the new phone button.
- **Five original enemies:**
  - **Shellback:** an armoured beetle that patrols floors.
  - **Glowmoth:** drifts in a figure-eight.
  - **Dripjaw:** a living stalactite that drops on you.
  - **Spitter:** a wall pod that spits slow globs.
  - **Bouldermaw:** a rock creature blocking a tunnel; 3 shots, or 1 with Power shot.
- **Puzzles and hazards:**
  - **Coloured doors:** red, blue and yellow, opened by the lever of the same colour.
  - **Crystal beams:** hurt until you turn them off with their switch.
  - **Spikes** on the floor.
  - Use levers and switches with E/X, controller X, or the new phone button. An arrow shows when you can.
- **Power-ups:**
  - **Power shot** (15 s): shots go through enemies.
  - **Reverse gravity** (10 s): walk on ceilings. If you land somewhere unsafe afterwards, you're put back on safe ground.
  - **Freeze** (10 s): enemies can't move or hurt you.
  - **Shield:** your next hit is free.
- **Fair caves:** the cave generator (now version 2) places all of this and checks each cave like a player would.
  - Every lever and switch is reachable before its door or beam.
  - Spikes never block the only way.
  - Nothing can leave you stuck.
  - At most 2 Bouldermaws.
  - Enemies never start near you.
- **HUD and phones:**
  - The HUD shows hearts, ammo (with a recharge bar when empty) and active power-ups.
  - The gem counter now uses the blue gem, so it can't be mistaken for a heart.
  - Phones get shoot and lever buttons in both landscape and portrait.
- **Leaderboard:**
  - Separate boards for Easy, Medium and Hard (tabs; best 50 each). Each row keeps its difficulty, seed and map.
  - Play replays that cave on that difficulty.
  - The Worker checks the difficulty.
- **Username:**
  - The username only exists while you're signed in with Google; it hides your Google name, as in Mythriven.
  - Not signed in, you type a name when you send a score, and that device remembers it.
- **Art and tests:**
  - New original pixel art for the enemies, hearts, ammo, power-ups, levers and switches.
  - New tests: a solver that plays 40 caves to prove they're beatable, combat and puzzle rules with real physics, and the touch buttons never overlapping.
  - The leaderboard tests now cover the per-difficulty boards.

### Reason
The owner asked for all the combat, danger, puzzle and power-up features from the GemScout spec: three difficulties that set hearts and how the blaster works, the five proposed enemies, the default hazards and puzzles, and all four power-ups. The owner also asked that the username only appear while signed in to Google, to hide the Google name.

## Version 00.01.01
Date: 11/06/2026
Time: 12:12 AM

### Changes
- **The first playable GemScout** (Godot 4.7.2), playable in the browser and installable as an app.
  - **Seeded caves:** every game makes a new random cave from a seed: three winding tunnels joined by shafts, chambers with floating ledges, rocks and stalactites.
    - **Always finishable:** every cave is checked against the scout's movement before use. Gems and the exit are only placed where the scout can reach them and get back from, so no gem is ever out of reach and you can't get stuck.
  - **Natural rock:** cave walls are smooth, natural shapes (no square tiles), and the camera follows the scout smoothly.
  - **The scout:** original pixel art. Runs and jumps (hold for higher), with forgiving jump timing.
  - **Gems and exit:** collect every gem to unseal the exit door, then walk in to clear the cave.
  - **Score:** 100 per gem, +500 for no damage, and a speed bonus.
  - **Controls:** keyboard, controller and touch.
    - Phones in **landscape** get see-through buttons over the game.
    - In **portrait**, the game sits on top with a control panel below it, so the buttons never cover the cave.
    - The camera zooms in on phones so everything is easy to see.
- **Screens**
  - **Main screen:** Play, Leaderboard, Settings, Suggest a feature, Quit, and a badge showing whether you're signed in to Google.
  - **Settings:**
    - Fullscreen, Install app, Update app, and touch controls (Auto / On / Off).
    - **Sign in with Google** to move progress between phone and web, with a line showing who you're signed in as.
    - A **username** that's shown instead of your Google name.
  - **Pause:** resume, restart the cave, or leave it. Restarting or leaving resets that cave's progress.
  - **Results:** the score breakdown, the cave's seed and map, and sending the score.
  - **Leaderboard:** each row has the cave's seed and a small map picture. **Play** replays that exact cave.
  - **Suggest a feature:** sends an anonymous GitHub issue.
- **Online service** (`leaderboard-api/`), a Cloudflare Worker at gemscout.thebotcoder.workers.dev, adapted from Mythriven's:
  - **Leaderboard:** stored in KV and in `leaderboard.json` on the `data` branch, which the Worker creates by itself with only that file.
  - **Score checks:** the Worker works out each score itself and checks the map picture.
  - **Accounts and feedback:** cloud saves, Google sign-in, suggestions and a privacy page.
- **Repository:**
  - `LICENSE` (the same All Rights Reserved licence as your other games, naming Zephino/GemScout) and `CREDITS.md`.
  - A `README.md` explaining every file.
  - A web build workflow that runs all tests before publishing to GitHub Pages.
  - The changelog rule (`.cursor/rules/changelog.mdc`, listed in `CLAUDE.md`).
- **Tests:**
  - 120 seeds checked for finishable caves.
  - Drawn rock matches the checked layout.
  - Real-physics play of whole caves, plus screens, saves and version checks.
  - 37 tests for the online service.

### Reason
The owner asked for GemScout: a Crystal Caves–style cave platformer that is 100% original, with seeded caves and organic shapes. It needed to work well on PC and phones (both orientations), with the same licensing and online features as Mythriven: leaderboard with seed and picture, Google sign-in, username, settings, install/update, quit and suggestions.

## Version 00.01.00
Date: 11/05/2026
Time: 10:55 PM

### Changes
- Added the project rules in `.cursor/rules/`: think before acting, version, protect data and secrets, testing strategy, bug investigation, and a branch policy.
  - **Branch policy:** use `main` only; `data` is kept for the leaderboard; any other branch is deleted.
- Added `CLAUDE.md` (all rules are mandatory) and `VERSION` (00.01.00).

### Reason
The owner asked for these rules to be added and always followed, and for all work to go to the `main` branch. (This entry was written after the changelog rule was added, to record that first change.)
