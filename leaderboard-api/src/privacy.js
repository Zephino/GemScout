/**
 * The privacy policy (GET /privacy), linked from Google's sign-in screen
 * (Google Auth Platform → Branding). Plain text about what the game and this
 * Worker keep; update it whenever that changes.
 */

const CONTACT = "thebotcoder@gmail.com";

const SECTIONS = [
  ["What GemScout keeps", [
    "<b>Sign in with Google:</b> Google's account id for you, stored scrambled (hashed). Your Google email is passed straight to your own device so the game can show which account you're signed in with; the server doesn't keep it. GemScout never asks Google for your real name.",
    "<b>Username:</b> the name you choose in the game, saved with your progress and shown on the leaderboard.",
    "<b>Cloud save:</b> your game progress (records, username, settings), stored under your account's private code, so it can follow you between devices.",
    "<b>Leaderboard:</b> the name you send (up to 12 characters), your score, difficulty, time, the cave's seed, a small map picture of the cave, and the game version, shown publicly.",
    "<b>Suggestions:</b> the text you send, posted anonymously as a GitHub issue on the game's repository.",
  ]],
  ["What it doesn't do", [
    "No ads, no tracking, no analytics, and nothing is sold or shared with anyone.",
    "Your progress is also saved on your own device and the game works without an account.",
  ]],
  ["Deleting your data", [
    `In the game, Settings → Account → Sign out stops syncing on that device. To have your cloud save and account deleted from the server, email ${CONTACT}.`,
  ]],
  ["Where it's stored", [
    "On Cloudflare (Workers and Durable Objects), which runs the game's online features. The leaderboard is also kept on the game's GitHub repository.",
  ]],
];

export function privacyPage() {
  const body = SECTIONS.map(([title, items]) => `<h2>${title}</h2><ul>${items.map((i) => `<li>${i}</li>`).join("")}</ul>`).join("");
  const html = `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>GemScout — Privacy policy</title><style>body{font-family:system-ui,sans-serif;background:#1b1622;color:#f2ead8;max-width:720px;
margin:0 auto;padding:16px;line-height:1.5}h1{font-size:1.6em}h2{font-size:1.15em;margin-top:1.5em}a{color:#e7c46a}</style></head>
<body><h1>GemScout — Privacy policy</h1><p>Last updated November 6, 2026. GemScout is a game made by one developer. This page says what it keeps about you.</p>
${body}<p><a href="https://zephino.github.io/GemScout/">Play GemScout</a></p></body></html>`;
  return new Response(html, { headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "public, max-age=3600" } });
}
