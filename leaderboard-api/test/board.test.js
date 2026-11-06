import { test } from "node:test";
import assert from "node:assert/strict";
import { deflateSync } from "node:zlib";
import worker from "../src/index.js";
import {
  MAX_ENTRIES,
  MAX_MAP_BYTES,
  addEntry,
  computeScore,
  countEntries,
  emptyBoard,
  normalizeBoard,
  qualifies,
  sanitizeName,
  validateMap,
  validateScore,
} from "../src/board.js";

/** A real, tiny PNG (grey pixels) of the given size, as base64. */
function png(width, height, extraBytes = 0) {
  const crcTable = Array.from({ length: 256 }, (_, n) => {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    return c >>> 0;
  });
  const crc = (buf) => {
    let c = 0xffffffff;
    for (const b of buf) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8);
    return (c ^ 0xffffffff) >>> 0;
  };
  const chunk = (type, data) => {
    const out = Buffer.alloc(12 + data.length);
    out.writeUInt32BE(data.length, 0);
    out.write(type, 4, "ascii");
    data.copy(out, 8);
    out.writeUInt32BE(crc(out.subarray(4, 8 + data.length)), 8 + data.length);
    return out;
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 0; // greyscale
  const rows = Buffer.alloc((width + 1) * height, 0x80);
  for (let y = 0; y < height; y++) rows[y * (width + 1)] = 0;
  const parts = [
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", ihdr),
    chunk("IDAT", deflateSync(rows)),
  ];
  if (extraBytes > 0) parts.push(chunk("tEXt", Buffer.alloc(extraBytes, 0x41)));
  parts.push(chunk("IEND", Buffer.alloc(0)));
  return Buffer.concat(parts).toString("base64");
}

function score(overrides = {}) {
  return {
    name: "Ari",
    difficulty: "medium",
    seed: "123456789",
    gen: 1,
    gems: 12,
    time_ms: 95_000,
    no_damage: true,
    map: png(96, 48),
    version: "00.01.01",
    ...overrides,
  };
}

test("a normal cleared cave is accepted, and the Worker works out the score itself", () => {
  const { entry, error } = validateScore(score({ score: 999_999 }));
  assert.equal(error, undefined);
  // 12 gems × 100 + 500 no-damage + (240 s par − 95 s) × 5
  assert.equal(entry.score, 1200 + 500 + 145 * 5);
  assert.equal(entry.seed, "123456789");
  assert.equal(computeScore(3, 120_000, false), 300, "no speed bonus past par");
});

test("names keep only safe characters and are cut to 12", () => {
  assert.equal(sanitizeName("  Gem  Scout!!  "), "Gem Scout");
  assert.equal(sanitizeName("ABCDEFGHIJKLMNOP"), "ABCDEFGHIJKL");
  assert.equal(validateScore(score({ name: "<script>" })).error, "invalid name");
  assert.equal(validateScore(score({ name: "!!!" })).error, "invalid name");
});

test("impossible or malformed clears are refused", () => {
  assert.equal(validateScore(score({ time_ms: 12 * 700 - 1 })).error, "invalid time", "faster than any player");
  assert.equal(validateScore(score({ gems: 0 })).error, "invalid gems");
  assert.equal(validateScore(score({ gems: 2.5 })).error, "invalid gems");
  assert.equal(validateScore(score({ seed: "4294967296" })).error, "invalid seed");
  assert.equal(validateScore(score({ seed: "-5" })).error, "invalid seed");
  assert.equal(validateScore(score({ seed: "12a" })).error, "invalid seed");
  assert.equal(validateScore(score({ gen: 0 })).error, "invalid gen");
  assert.equal(validateScore(score({ no_damage: "yes" })).error, "invalid no_damage");
  assert.equal(validateScore(score({ version: "1.0" })).error, "invalid version");
  assert.equal(validateScore(score({ difficulty: "nightmare" })).error, "invalid difficulty");
  assert.equal(validateScore(score({ difficulty: undefined })).error, "invalid difficulty");
  assert.equal(validateScore([]).error, "invalid json");
});

test("the map picture must be a small real PNG; it's optional", () => {
  assert.equal(validateMap(undefined), "");
  assert.equal(validateMap(""), "");
  assert.equal(validateMap(png(96, 48)), png(96, 48));
  assert.equal(validateMap(Buffer.from("GIF89a not a png at all, padded out....").toString("base64")), null);
  assert.equal(validateMap(png(300, 10)), null, "too wide");
  assert.equal(validateMap(png(16, 16, MAX_MAP_BYTES)), null, "too many bytes");
  assert.equal(validateMap("<img src=x>"), null, "not base64");
  assert.equal(validateScore(score({ map: "AAAA" })).error, "invalid map");
});

test("highest score ranks first, then the fastest", () => {
  const slow = { ...validateScore(score({ name: "Slow" })).entry, date: "2026-11-06T00:00:00Z" };
  const best = { ...validateScore(score({ name: "Best", gems: 20, time_ms: 100_000 })).entry, date: "2026-11-06T00:00:01Z" };
  const board = normalizeBoard({ boards: { medium: [slow, best] } });
  assert.deepEqual(board.boards.medium.map((e) => e.name), ["Best", "Slow"]);
  const tieFast = { ...slow, name: "Fast", time_ms: slow.time_ms - 500 };
  assert.equal(normalizeBoard({ boards: { medium: [slow, tieFast] } }).boards.medium[0].name, "Fast", "same score: faster wins");
});

test("each difficulty has its own board", () => {
  let board = emptyBoard();
  board = addEntry(board, validateScore(score({ name: "E", difficulty: "easy" })).entry, "2026-11-06T00:00:00Z");
  board = addEntry(board, validateScore(score({ name: "H", difficulty: "hard" })).entry, "2026-11-06T00:00:01Z");
  assert.deepEqual(board.boards.easy.map((e) => e.name), ["E"]);
  assert.deepEqual(board.boards.hard.map((e) => e.name), ["H"]);
  assert.equal(board.boards.medium.length, 0);
  assert.equal(countEntries(board), 2);
  // A row stored on the wrong board goes back to its own.
  const fixed = normalizeBoard({ boards: { easy: [{ ...board.boards.hard[0] }] } });
  assert.equal(fixed.boards.hard.length, 1);
  assert.equal(fixed.boards.easy.length, 0);
});

test("the board keeps only the best entries", () => {
  let board = emptyBoard();
  for (let i = 0; i < MAX_ENTRIES + 5; i++) {
    board = addEntry(board, validateScore(score({ name: `P${i}`, gems: 5 + i, time_ms: 300_000 })).entry, "2026-11-06T00:00:00Z");
  }
  assert.equal(board.boards.medium.length, MAX_ENTRIES);
  assert.equal(qualifies(board, validateScore(score({ gems: 1, time_ms: 300_000, no_damage: false })).entry), false);
});

test("hand-edited junk in the stored file is dropped", () => {
  const board = normalizeBoard({ boards: { medium: [{ name: "x" }, "junk", { ...score(), date: "not a date" }] }, entries: "old" });
  assert.equal(countEntries(board), 1);
  assert.equal(board.boards.medium[0].date, "");
});

/** A stand-in Workers KV that remembers puts. */
function fakeKV() {
  const data = new Map();
  return {
    data,
    puts: 0,
    async get(key, opts) {
      const v = data.get(key);
      if (v === undefined) return null;
      return opts?.type === "json" ? JSON.parse(v) : v;
    },
    async put(key, value) {
      this.puts++;
      data.set(key, value);
    },
  };
}

/** A stand-in GitHub that records calls; `branch` says whether the data branch exists. */
async function withGitHub(branch, run) {
  const calls = [];
  const realFetch = globalThis.fetch;
  globalThis.fetch = async (url, init = {}) => {
    const u = String(url);
    calls.push({ url: u, method: init.method || "GET", body: init.body ? JSON.parse(init.body) : null });
    if (u.startsWith("https://raw.githubusercontent.com/")) return new Response("", { status: 404 });
    if (u.includes("/contents/")) {
      if ((init.method || "GET") === "GET") return new Response("{}", { status: 404 });
      return new Response("{}", { status: 201 });
    }
    if (u.includes("/git/ref/heads/")) return new Response("{}", { status: branch ? 200 : 404 });
    if (u.endsWith("/git/trees")) return new Response(JSON.stringify({ sha: "tree1" }), { status: 201 });
    if (u.endsWith("/git/commits")) return new Response(JSON.stringify({ sha: "commit1" }), { status: 201 });
    if (u.endsWith("/git/refs")) return new Response("{}", { status: 201 });
    return new Response("{}", { status: 404 });
  };
  try {
    await run(calls);
  } finally {
    globalThis.fetch = realFetch;
  }
}

function post(body, ip = "1.2.3.4") {
  return new Request("https://w.example/leaderboard", {
    method: "POST",
    headers: { "Content-Type": "application/json", "CF-Connecting-IP": ip },
    body: JSON.stringify(body),
  });
}

const ENV = () => ({ LEADERBOARD_KV: fakeKV(), GITHUB_TOKEN: "test-token", GITHUB_REPO: "GemScout", GITHUB_BRANCH: "data" });

test("the first score creates the data branch with only leaderboard.json (no parent commit)", async () => {
  const env = ENV();
  await withGitHub(false, async (calls) => {
    const res = await (await worker.fetch(post(score()), env)).json();
    assert.equal(res.accepted, true);
    assert.equal(res.rank, 1);
    const tree = calls.find((c) => c.url.endsWith("/git/trees"));
    assert.deepEqual(tree.body.tree.map((t) => t.path), ["leaderboard.json"]);
    assert.ok(!("base_tree" in tree.body), "not built on main's files");
    assert.deepEqual(calls.find((c) => c.url.endsWith("/git/commits")).body.parents, []);
    assert.equal(calls.find((c) => c.url.endsWith("/git/refs")).body.ref, "refs/heads/data");
    assert.ok(!calls.some((c) => c.method === "PUT"), "no contents write before the branch exists");
  });
});

test("later scores are written to the data branch and a double submit is ignored", async () => {
  const env = ENV();
  await withGitHub(true, async (calls) => {
    assert.equal((await (await worker.fetch(post(score()), env)).json()).accepted, true);
    const put = calls.find((c) => c.method === "PUT");
    assert.equal(put.body.branch, "data");
    assert.ok(put.url.endsWith("/contents/leaderboard.json"));
    const again = await (await worker.fetch(post(score()), env)).json();
    assert.equal(again.accepted, false);
    const board = await (await worker.fetch(new Request("https://w.example/leaderboard"), env)).json();
    assert.equal(board.boards.medium.length, 1);
    assert.equal(board.boards.medium[0].map, score().map, "the picture is kept with the score");
    assert.equal(board.boards.medium[0].difficulty, "medium");
  });
});

test("one player can't flood the board", async () => {
  const env = ENV();
  await withGitHub(true, async () => {
    const codes = [];
    for (let i = 0; i < 4; i++) codes.push((await worker.fetch(post(score({ time_ms: 100_000 + i })), env)).status);
    assert.deepEqual(codes, [200, 200, 200, 429]);
  });
});

test("reading the board writes nothing to KV (free plan: ~1,000 writes a day)", async () => {
  const env = ENV();
  await withGitHub(true, async () => {
    await worker.fetch(new Request("https://w.example/leaderboard"), env);
    assert.equal(env.LEADERBOARD_KV.puts, 0);
  });
});

test("oversized or broken requests are refused", async () => {
  const env = ENV();
  const big = new Request("https://w.example/leaderboard", { method: "POST", body: "x".repeat(13_000) });
  assert.equal((await worker.fetch(big, env)).status, 413);
  const broken = new Request("https://w.example/leaderboard", { method: "POST", body: "{nope" });
  assert.equal((await worker.fetch(broken, env)).status, 400);
  assert.equal((await worker.fetch(new Request("https://w.example/elsewhere"), env)).status, 404);
});
