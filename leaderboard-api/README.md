# GemScout online service

A small free **Cloudflare Worker** (`gemscout`, at https://gemscout.thebotcoder.workers.dev) that runs GemScout's online features:

| Path | What it does | Code |
| --- | --- | --- |
| `GET /leaderboard` | The board, best first | `src/index.js`, `src/board.js` |
| `POST /leaderboard` | Send one cleared cave; the Worker checks it and works out the score itself | `src/board.js` |
| `GET/PUT /cloud/save` | Cloud saves, by the account's private code | `src/cloud.js` |
| `/auth/*` | Sign in with Google | `src/accounts.js` |
| `GET/POST /suggestions` | Anonymous suggestions become GitHub issues | `src/suggestions.js` |
| `GET /privacy` | Privacy policy (linked from Google's sign-in screen) | `src/privacy.js` |

```
Game ──POST score──▶ Worker (checks it) ──▶ Workers KV "GemScout" (fast copy)
                                        └─▶ GitHub: leaderboard.json on the `data` branch
```

- The game **never holds a key**. The GitHub token and Google secrets live only on Cloudflare as secrets.
- Each leaderboard row keeps: name, score, time, gems, no-damage, the cave's **seed** and generator version (so the cave can be replayed), a small **map picture** of the cave (PNG, at most 4 KB), the game version, and the date. The best 50 are kept.
- The first score creates the `data` branch by itself, holding only `leaderboard.json` (no copy of the game's code).

## Setup (already done)

- **Secrets** on Cloudflare → Workers & Pages → gemscout → Settings → Variables and Secrets: `GITHUB_TOKEN`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`.
- **KV namespace** `GemScout`, bound as `LEADERBOARD_KV` in `wrangler.toml`.
- **Durable Objects** `SaveVault` and `AccountVault` are declared in `wrangler.toml`, so a normal deploy creates them.

### Automatic deploys (Cloudflare Builds)

Cloudflare → Workers & Pages → gemscout → Settings → Builds, connected to `Zephino/GemScout`:

- Production branch: `main`
- Root directory: `leaderboard-api`
- Build command: none
- Deploy command: `npx wrangler deploy`

Every push to `main` then redeploys the Worker. **Check the Cloudflare deployment separately**: a green GitHub Pages build doesn't mean the Worker deployed.

### Check it works

- `https://gemscout.thebotcoder.workers.dev/leaderboard` shows `{"_about": ..., "entries": []}`.
- `https://gemscout.thebotcoder.workers.dev/suggestions` shows `{"accepting":true}`.
- `https://gemscout.thebotcoder.workers.dev/privacy` shows the privacy policy.
- In the game: Settings → **Sign in with Google**, then sign in on your phone too: both share progress.

## If something goes wrong

- **Token expired:** make a new fine-grained token (Zephino/GemScout only; Contents and Issues: Read and write) and replace the `GITHUB_TOKEN` secret. No game change needed.
- **Sign-in says it isn't set up:** the `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` secrets are missing.
- **Google says "redirect_uri_mismatch":** the Google client's Authorized redirect URI must be exactly `https://gemscout.thebotcoder.workers.dev/auth/callback`.
- **A deploy fails about Durable Objects or migrations:** open Workers & Pages → gemscout → Deployments, copy the red message, and send it to Claude.

## Protecting the `data` branch (recommended)

GitHub → GemScout → **Settings → Rules → Rulesets → New branch ruleset**: name `data branch`, Enforcement **Active**, target `data`, tick **Restrict deletions** and **Block force pushes** (leave "Restrict updates" off, or the Worker can't write).

## Honest limits

Scores come from players' devices, so a determined cheater could fake one. The Worker works out the score itself and refuses impossible clears (faster than 0.7 s per gem, bad seeds, oversized or fake pictures), double submissions, and more than 3 scores a minute from one address. To remove a bad score, ask Claude.

## For developers

- `npm test`: checks every rule above with pretend storage and a pretend GitHub (`test/`).
- Test the game against a Worker on your computer: `npx wrangler dev`, then start Godot with `-- --api=http://127.0.0.1:8787`.
- `.gdignore` keeps Godot from importing this folder.
