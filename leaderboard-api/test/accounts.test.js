import { test } from "node:test";
import assert from "node:assert/strict";
import worker from "../src/index.js";
import { AccountVault, isLoginId, tokenClaims, LOGIN_TTL_MS } from "../src/accounts.js";

/** Stand-in Durable Objects: one AccountVault per name. */
function fakeAccounts() {
  const vaults = new Map();
  return {
    vaults,
    idFromName: (name) => name,
    get(id) {
      if (!vaults.has(id)) {
        const data = new Map();
        const storage = {
          async get(k) {
            return data.get(k);
          },
          async put(k, v) {
            data.set(k, v);
          },
          async deleteAll() {
            data.clear();
          },
        };
        vaults.set(id, new AccountVault({ storage }));
      }
      const vault = vaults.get(id);
      return { fetch: (url, init) => vault.fetch(new Request(url, init)) };
    },
  };
}

function fakeIdToken(claims) {
  const part = (o) => btoa(JSON.stringify(o)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  return `${part({ alg: "RS256" })}.${part(claims)}.signature`;
}

const ENV = () => ({ ACCOUNTS: fakeAccounts(), GOOGLE_CLIENT_ID: "client-123", GOOGLE_CLIENT_SECRET: "shh" });
const BASE = "https://w.example";

/** Google's token endpoint, answering with this player's id. */
async function withGoogle(sub, run) {
  const realFetch = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    assert.equal(String(url), "https://oauth2.googleapis.com/token");
    const form = new URLSearchParams(init.body);
    assert.equal(form.get("client_secret"), "shh");
    assert.equal(form.get("redirect_uri"), BASE + "/auth/callback");
    return new Response(JSON.stringify({ id_token: fakeIdToken({ sub, aud: "client-123", iss: "https://accounts.google.com", name: "Bot Coder", email: sub + "@gmail.com" }) }));
  };
  try {
    return await run();
  } finally {
    globalThis.fetch = realFetch;
  }
}

async function signIn(env, sub, deviceCode = "") {
  const start = await (await worker.fetch(new Request(BASE + "/auth/start", { method: "POST", body: JSON.stringify({ code: deviceCode }) }), env)).json();
  assert.ok(isLoginId(start.login));
  const toGoogle = await worker.fetch(new Request(start.url), env);
  assert.equal(toGoogle.status, 302);
  const google = new URL(toGoogle.headers.get("Location"));
  assert.equal(google.searchParams.get("scope"), "openid email", "never the real name (players pick a username)");
  assert.equal(google.searchParams.get("state"), start.login);
  assert.equal((await worker.fetch(new Request(`${BASE}/auth/poll?login=${start.login}`), env).then((r) => r.json())).state, "waiting");
  const back = await withGoogle(sub, () => worker.fetch(new Request(`${BASE}/auth/callback?code=abc&state=${start.login}`), env));
  assert.equal(back.status, 200);
  const html = await back.text();
  assert.ok(html.includes("setTimeout(closeTab"), "the page closes itself");
  assert.ok(html.includes(">Close</button>"), "and has a Close button");
  const done = await (await worker.fetch(new Request(`${BASE}/auth/poll?login=${start.login}`), env)).json();
  assert.equal(done.state, "done");
  assert.equal(done.name, undefined, "no real name, even if Google sent one");
  assert.equal(done.email, sub + "@gmail.com", "the email goes to the player's own device");
  const again = await (await worker.fetch(new Request(`${BASE}/auth/poll?login=${start.login}`), env)).json();
  assert.equal(again.state, "expired", "the code is handed over only once");
  return done.code;
}

test("signing in on two devices gives both the same cloud save", async () => {
  const env = ENV();
  const pc = await signIn(env, "google-user-1");
  assert.equal(pc.length, 12);
  const phone = await signIn(env, "google-user-1");
  assert.equal(phone, pc, "the same account's save on the phone");
  assert.notEqual(await signIn(env, "google-user-2"), pc, "another player gets their own");
  for (const name of env.ACCOUNTS.vaults.keys()) {
    assert.ok(!name.includes("google-user"), "Google's id is only kept hashed");
    const value = (await (await env.ACCOUNTS.get(name).fetch("https://account/get")).json()).value;
    assert.ok(!JSON.stringify(value).includes("Bot Coder") && !JSON.stringify(value).includes("@gmail"), "the name and email aren't kept");
  }
});

test("a device that already had cloud saves brings its save to a new account", async () => {
  const env = ENV();
  assert.equal(await signIn(env, "google-user-3", "ABCD-EFGH-JK23"), "ABCDEFGHJK23");
  assert.equal(await signIn(env, "google-user-3", "ZZZZ-ZZZZ-ZZ22"), "ABCDEFGHJK23", "an existing account keeps its own save");
});

test("a cancelled, expired, or forged sign-in does nothing", async () => {
  const env = ENV();
  const start = await (await worker.fetch(new Request(BASE + "/auth/start", { method: "POST" }), env)).json();
  const cancelled = await worker.fetch(new Request(`${BASE}/auth/callback?error=access_denied&state=${start.login}`), env);
  assert.equal(cancelled.status, 200);
  assert.equal((await (await worker.fetch(new Request(`${BASE}/auth/poll?login=${start.login}`), env)).json()).state, "cancelled");
  assert.equal((await worker.fetch(new Request(`${BASE}/auth/callback?code=x&state=${"0".repeat(32)}`), env)).status, 400);
  const fresh = await (await worker.fetch(new Request(BASE + "/auth/start", { method: "POST" }), env)).json();
  const realNow = Date.now;
  Date.now = () => realNow() + LOGIN_TTL_MS + 1000;
  try {
    assert.equal((await worker.fetch(new Request(fresh.url), env)).status, 400, "too old");
  } finally {
    Date.now = realNow;
  }
  const other = await (await worker.fetch(new Request(BASE + "/auth/start", { method: "POST" }), env)).json();
  const realFetch = globalThis.fetch;
  globalThis.fetch = async () => new Response(JSON.stringify({ id_token: fakeIdToken({ sub: "x", aud: "someone-else", iss: "https://accounts.google.com" }) }));
  try {
    assert.equal((await worker.fetch(new Request(`${BASE}/auth/callback?code=abc&state=${other.login}`), env)).status, 502, "a token for another app is refused");
  } finally {
    globalThis.fetch = realFetch;
  }
});

test("without the Google secrets, sign-in says it isn't set up", async () => {
  const res = await worker.fetch(new Request(BASE + "/auth/start", { method: "POST" }), { ACCOUNTS: fakeAccounts() });
  assert.equal(res.status, 503);
  assert.equal(tokenClaims("not-a-token"), null);
});

test("the privacy policy page is served for Google's sign-in screen", async () => {
  const res = await worker.fetch(new Request(BASE + "/privacy"), {});
  assert.equal(res.status, 200);
  const text = await res.text();
  assert.ok(text.includes("Privacy policy"));
  assert.ok(text.includes("never asks Google for your real name"));
});

test("the web version may call sign-in (the browser's OPTIONS check is answered fully)", async () => {
  const res = await worker.fetch(new Request(BASE + "/auth/start", { method: "OPTIONS" }), ENV());
  assert.equal(res.status, 204);
  assert.equal(res.headers.get("Access-Control-Allow-Origin"), "*");
  assert.ok(res.headers.get("Access-Control-Allow-Methods").includes("POST"));
  assert.ok(res.headers.get("Access-Control-Allow-Headers").includes("Content-Type"));
});
