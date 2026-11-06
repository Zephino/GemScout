# GemScout

A 2D side-scrolling cave platformer. Explore a cave, collect **every gem** to unseal the exit, and get out. Every cave is generated from a **seed**, so no two games are the same, and any cave on the leaderboard can be replayed exactly.

**Play in your browser:** https://zephino.github.io/GemScout/ (PC and phone; it can be installed like an app from Settings).

## How to play

| | Keyboard | Controller | Phone |
| --- | --- | --- | --- |
| Run | A / D or ← / → | D-pad or left stick | ◀ ▶ buttons |
| Jump (hold for higher) | Space, W, ↑ or Z | A (bottom button) | ▲ button |
| Pause | Esc or P | Start | II (top right) |

- Find all the gems (the counter is top left). The exit door stays sealed until you have them all.
- Score: 100 per gem, +500 if you weren't hurt, and +5 for every second faster than par (20 seconds per gem).
- Leaving or restarting a cave throws away that cave's progress.
- On phones, turn sideways for see-through buttons over the game, or hold it upright for a control panel below the game. The buttons only show on touch screens (Settings → Touch controls).

## Online features

- **Leaderboard:** the best cleared caves, each with its seed and a small map of the cave. Tap **Play** on a row to play that exact cave.
- **Sign in with Google** (Settings → Account) carries your progress between your phone and the web. Your Google name is never used: pick a **username** in Settings.
- **Suggest a feature** sends an idea straight to this repository's Issues (no account needed).
- These all run on a small Cloudflare Worker in [`leaderboard-api/`](leaderboard-api/README.md).

## For developers

- Engine: **Godot 4.7.2** (GL Compatibility renderer, for the web). Open `project.godot` in Godot and press Play.
- Tests: `godot --headless --path . -s tests/run_tests.gd` (game) and `cd leaderboard-api && npm test` (online service). Both run automatically before every web build.
- Art: `python3 tools/make_art.py` redraws every sprite and icon from the text grids inside it.
- Every push to `main` builds the web version and publishes it (`.github/workflows/web.yml`). Work happens on `main` only; the `data` branch holds `leaderboard.json` and is written only by the Worker.
- Project rules for AI assistants: `.cursor/rules/` and `CLAUDE.md`. The version is in `VERSION`; every change gets an entry in `CHANGELOG.md`.

### What each file does

**Game**

| File | What it does |
| --- | --- |
| `project.godot` | Godot project settings: name, version, 640 × 360 base screen that scales to any window, autoloads. |
| `scenes/main.tscn` | The scene the game starts in (just runs `scripts/ui/main.gd`). |
| `scripts/autoload/game_input.gd` | The controls (keyboard, controller), set up in code. |
| `scripts/autoload/save_game.gd` | Saved progress (`Save`): username, settings, records; merging two saves. |
| `scripts/autoload/cloud_sync.gd` | Cloud saves (`Cloud`): syncs progress through the Worker after Google sign-in. |
| `scripts/cave/cave_data.gd` | One cave: rock cells, start, gems, exit. |
| `scripts/cave/cave_generator.gd` | Makes a cave from a seed: three winding tunnels joined by shafts, chambers with ledges, rocks and stalactites. Retries until the cave passes the reachability check. |
| `scripts/cave/reachability.gd` | Works out where the scout can walk, fall and jump to, so every gem and the exit can be reached and the scout can never get stuck. |
| `scripts/cave/cave_shape.gd` | Turns the cells into smooth, natural rock (no square tiles): triangles to draw and edges to collide with. |
| `scripts/cave/cave_terrain.gd` | Draws the rock and makes it solid. |
| `scripts/cave/cave_thumbnail.gd` | The small cave map sent with leaderboard scores. |
| `scripts/game/cave_level.gd` | A cave being played: builds it, times it, counts gems, opens the exit, reports the result. |
| `scripts/game/hero.gd` | The scout: running, jumping (hold for higher), forgiving jump timing. |
| `scripts/game/gem.gd` | A gem to pick up. |
| `scripts/game/exit_door.gd` | The exit: sealed until every gem is found. |
| `scripts/game/scoring.gd` | Points for a cleared cave (the Worker uses the same sum). |
| `scripts/net/online_config.gd` | The Worker's address. |
| `scripts/net/account_sign_in.gd` | Sign in with Google. |
| `scripts/net/web_request.gd` | Sends one request to the Worker. |
| `scripts/ui/main.gd` | Switches between the menus and the game; pause; phone camera zoom. |
| `scripts/ui/title_screen.gd` | Main screen: Play, Leaderboard, Settings, Suggest a feature, Quit, signed-in badge. |
| `scripts/ui/settings_screen.gd` | Fullscreen, Install / Update app, touch controls, Google account, username. |
| `scripts/ui/leaderboard_screen.gd` | The leaderboard with maps and Play buttons. |
| `scripts/ui/results_screen.gd` | "Cave cleared!" score breakdown and sending the score. |
| `scripts/ui/pause_menu.gd` | Resume, restart or leave the cave. |
| `scripts/ui/suggestion_form.gd` | Suggest a feature. |
| `scripts/ui/hud.gd` | Gem counter, timer, pause button and messages while playing. |
| `scripts/ui/touch_controls.gd` | Phone buttons, landscape and portrait layouts. |
| `scripts/ui/ui_kit.gd` | The menus' look (big readable text and buttons) and screen helpers. |
| `scripts/ui/app_actions.gd` | Fullscreen, install, update, quit, and broad device details for suggestions. |
| `assets/sprites/*.png`, `assets/icons/*.png`, `icon.png` | Pixel art, drawn by `tools/make_art.py`. |
| `tools/make_art.py` | Draws all the art from text grids. |
| `web/update.js` | Keeps the web version up to date (added to the page by the web build). |
| `export_presets.cfg` | Web export settings (installable app, icons, version stamp). |
| `tests/` | Automated tests (`run_tests.gd` runs every `test_*.gd`). |

**Online service** (`leaderboard-api/`): see [its README](leaderboard-api/README.md).

**Repository:** `LICENSE` (all rights reserved), `CREDITS.md` (third-party licences), `CHANGELOG.md`, `VERSION`, `.github/workflows/web.yml` (tests, build, publish), `.cursor/rules/` and `CLAUDE.md` (project rules).

## License

© 2026 Zephino. All rights reserved; see [LICENSE](LICENSE). Third-party components are listed in [CREDITS.md](CREDITS.md).
