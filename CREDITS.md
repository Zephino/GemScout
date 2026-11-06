# Credits

Third-party tools and components used by GemScout. Every entry needs a license that allows commercial use and redistribution.

| Name | Version | Used for | Source | License |
| --- | --- | --- | --- | --- |
| Godot Engine | 4.7.2 | The game engine (and its built-in default font) | https://godotengine.org | MIT (https://godotengine.org/license) |
| Cloudflare Workers / Wrangler | 3.x | The online service (leaderboard, cloud saves, sign-in, suggestions) | https://developers.cloudflare.com/workers/ | Wrangler: MIT OR Apache-2.0 |
| Pillow | 12 | Only for `tools/make_art.py`, which draws the sprites (not shipped) | https://python-pillow.org | MIT-CMU (HPND) |

Godot's MIT license asks that its copyright notice is included with any game you ship: "Made with Godot Engine. (c) Godot Engine contributors, MIT license." Godot also bundles some open-source libraries; the full list is on the license page above.

## Made for this game

All game code, the cave generator, pixel art (drawn by `tools/make_art.py`), names and text were made for GemScout. Nothing was copied from other games. The style of play (side-on platforming, collecting every gem in a cave to open its exit) is inspired by classic 1990s cave platformers, but the hero, caves, art, names and story are original, and every cave is generated from a seed.
