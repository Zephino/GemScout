/**
 * Cloud saves: GemScout progress shared between the web, PC and phone.
 *
 *   GET /cloud/save   the player's saved progress ({ save, updated } or { save: null })
 *   PUT /cloud/save   store the player's (already merged) progress
 *
 * A player is known only by their private sync code, sent as
 * `Authorization: Bearer <code>`. Signing in with Google (accounts.js) is how
 * a device gets its account's code. The Worker never stores the code itself:
 * each save lives in its own Durable Object named by the code's SHA-256 hash,
 * so nobody can list saves or read one without the code. No names, emails,
 * or other personal data are kept (the username the player picks is part of
 * the save).
 *
 * The game merges its save with the cloud copy before sending (best records
 * win, the newest username and settings win), so the Worker just keeps what
 * it is given.
 *
 * Binding: SAVE_VAULT (Durable Object class SaveVault, see wrangler.toml)
 */

export const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
export const CODE_LENGTH = 12;
export const MAX_SAVE_BYTES = 256_000;
/** A device may write at most once every this many ms (the game waits 30 s). */
export const MIN_WRITE_GAP_MS = 5_000;

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, PUT, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Accept, Authorization",
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
  };
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders() });
}

/** The code without dashes or spaces, upper-case; "" if it isn't a valid code. */
export function normalizeCode(raw) {
  if (typeof raw !== "string") return "";
  const code = raw.replace(/[\s-]/g, "").toUpperCase();
  if (code.length !== CODE_LENGTH) return "";
  for (const ch of code) {
    if (!CODE_ALPHABET.includes(ch)) return "";
  }
  return code;
}

export async function hashCode(code) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode("gemscout-save:" + code));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** A save the Worker will keep: a JSON object from the game, not too big. */
export function validateSave(text) {
  if (typeof text !== "string" || text.length === 0) return { error: "empty save" };
  if (text.length > MAX_SAVE_BYTES) return { error: "save too large" };
  let save;
  try {
    save = JSON.parse(text);
  } catch {
    return { error: "invalid json" };
  }
  if (!save || typeof save !== "object" || Array.isArray(save)) return { error: "invalid save" };
  if (!Number.isFinite(save.save_version)) return { error: "invalid save" };
  return { save };
}

/** Routes /cloud/save to the player's own SaveVault. */
export async function handleCloud(request, env) {
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders() });
  if (!env.SAVE_VAULT) return json({ error: "cloud saves are not set up" }, 503);
  const auth = request.headers.get("Authorization") || "";
  const code = normalizeCode(auth.replace(/^Bearer\s+/i, ""));
  if (!code) return json({ error: "invalid code" }, 401);
  if (request.method !== "GET" && request.method !== "PUT") return json({ error: "method not allowed" }, 405);
  let body = "";
  if (request.method === "PUT") {
    const declared = parseInt(request.headers.get("content-length") || "0", 10);
    if (Number.isFinite(declared) && declared > MAX_SAVE_BYTES) return json({ error: "save too large" }, 413);
    body = await request.text();
    const checked = validateSave(body);
    if (checked.error) return json({ error: checked.error }, checked.error === "save too large" ? 413 : 400);
  }
  const stub = env.SAVE_VAULT.get(env.SAVE_VAULT.idFromName(await hashCode(code)));
  return stub.fetch("https://vault/save", { method: request.method, body: request.method === "PUT" ? body : undefined });
}

/** One player's cloud save. */
export class SaveVault {
  constructor(state) {
    this.storage = state.storage;
  }

  async fetch(request) {
    if (request.method === "GET") {
      const save = (await this.storage.get("save")) ?? null;
      const updated = (await this.storage.get("updated")) ?? 0;
      return json({ save: save ? JSON.parse(save) : null, updated });
    }
    const now = Date.now();
    const last = (await this.storage.get("updated")) ?? 0;
    if (now - last < MIN_WRITE_GAP_MS) return json({ error: "too soon", updated: last }, 429);
    const text = await request.text();
    await this.storage.put({ save: text, updated: now });
    return json({ ok: true, updated: now });
  }
}
