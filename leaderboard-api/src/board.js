/**
 * GemScout leaderboard rules: what a score must look like, how the board is
 * sorted, and how many rows it keeps. No network code here, so it can be
 * tested with `npm test`.
 *
 * There is one board per difficulty (easy, medium, hard), best 50 each:
 *   { _about, updated, boards: { easy: [...], medium: [...], hard: [...] } }
 *
 * One row is one cleared cave:
 *   name       player-chosen, letters/numbers/space/_/- only, up to 12
 *   difficulty "easy", "medium" or "hard" (which board it's on)
 *   seed       the cave's seed (a whole number, 0 to 4294967295, sent as text)
 *   gen        cave generator version (a different gen draws a different cave)
 *   gems       gems collected (every gem in the cave)
 *   time_ms    time taken, in milliseconds
 *   no_damage  true when the cave was cleared without getting hurt
 *   score      worked out HERE from the above (the game's own number is ignored)
 *   map        small PNG picture of the cave, base64 (optional)
 *   version    game version, "XX.XX.XX"
 *   date       set by the Worker, never by the game
 *
 * Scoring (keep in step with scripts/game/scoring.gd):
 *   100 per gem + 500 for no damage + 5 per second faster than par,
 *   where par is 20 seconds per gem.
 */

export const MAX_ENTRIES = 50;
export const DIFFICULTIES = Object.freeze(["easy", "medium", "hard"]);
export const MAX_NAME_LENGTH = 12;
export const MIN_GEMS = 1;
export const MAX_GEMS = 200;
/** Nobody collects a gem faster than this on average (ms). */
export const MIN_MS_PER_GEM = 700;
export const MAX_TIME_MS = 6 * 60 * 60 * 1000;
export const MAX_SEED = 4294967295;
export const MAX_GEN = 1000;
/** Largest map picture, in bytes once decoded. */
export const MAX_MAP_BYTES = 4096;
export const MAX_MAP_SIDE = 256;

export const GEM_POINTS = 100;
export const NO_DAMAGE_BONUS = 500;
export const PAR_S_PER_GEM = 20;
export const SPEED_POINTS_PER_S = 5;

export const ABOUT =
  "GemScout shared leaderboard. Written only by the leaderboard Worker; edits by hand are overwritten.";

const VERSION_PATTERN = /^\d{2}\.\d{2}\.\d{2}$/;
const BASE64_PATTERN = /^[A-Za-z0-9+/]+={0,2}$/;
/** Script / markup characters: a name containing any of these is refused outright. */
const INJECTION_MARKERS = ["'", '"', ";", "--", "/*", "*/", "\\", "`", "<", ">"];

export function looksLikeInjection(raw) {
  const s = String(raw ?? "");
  for (const marker of INJECTION_MARKERS) {
    if (s.includes(marker)) return true;
  }
  for (let i = 0; i < s.length; i++) {
    if (s.charCodeAt(i) < 32) return true;
  }
  return false;
}

/** Keeps A–Z, a–z, 0–9, space, _ and -; trims; cuts to 12. */
export function sanitizeName(raw) {
  let cleaned = "";
  for (const ch of String(raw ?? "")) {
    if (/[A-Za-z0-9 _-]/.test(ch)) cleaned += ch;
  }
  cleaned = cleaned.replace(/ {2,}/g, " ").trim();
  return cleaned.slice(0, MAX_NAME_LENGTH).trim();
}

function wholeNumber(raw, min, max) {
  const n = Number(raw);
  if (!Number.isFinite(n) || !Number.isInteger(n) || n < min || n > max) return null;
  return n;
}

/** The score for a cleared cave (the same sum as the game's Scoring.total). */
export function computeScore(gems, timeMs, noDamage) {
  const seconds = Math.floor(timeMs / 1000);
  const speed = Math.max(0, gems * PAR_S_PER_GEM - seconds) * SPEED_POINTS_PER_S;
  return gems * GEM_POINTS + (noDamage ? NO_DAMAGE_BONUS : 0) + speed;
}

/** The seed as canonical text ("0" to "4294967295"), or null. */
export function normalizeSeed(raw) {
  const text = String(raw ?? "");
  if (!/^\d{1,10}$/.test(text)) return null;
  const n = Number(text);
  if (n > MAX_SEED) return null;
  return String(n);
}

/**
 * The map picture if it's a small, real PNG; "" when none was sent; null when
 * it's something else. Only the PNG signature and its size header are read.
 */
export function validateMap(raw) {
  if (raw === undefined || raw === null || raw === "") return "";
  if (typeof raw !== "string" || raw.length > Math.ceil(MAX_MAP_BYTES / 3) * 4 + 4) return null;
  if (!BASE64_PATTERN.test(raw)) return null;
  let bytes;
  try {
    bytes = Uint8Array.from(atob(raw), (c) => c.charCodeAt(0));
  } catch {
    return null;
  }
  if (bytes.length < 33 || bytes.length > MAX_MAP_BYTES) return null;
  const signature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (!signature.every((b, i) => bytes[i] === b)) return null;
  // The first chunk must be IHDR: width and height are big-endian at bytes 16–23.
  if (String.fromCharCode(...bytes.slice(12, 16)) !== "IHDR") return null;
  const view = new DataView(bytes.buffer);
  const width = view.getUint32(16);
  const height = view.getUint32(20);
  if (width < 1 || height < 1 || width > MAX_MAP_SIDE || height > MAX_MAP_SIDE) return null;
  return raw;
}

/**
 * Checks one score. Returns { entry } when it's acceptable, or { error } with
 * a short reason. `date` is added by the caller.
 */
export function validateScore(body) {
  if (!body || typeof body !== "object" || Array.isArray(body)) return { error: "invalid json" };
  if (looksLikeInjection(body.name)) return { error: "invalid name" };
  const name = sanitizeName(body.name);
  if (!name) return { error: "invalid name" };
  const difficulty = String(body.difficulty ?? "");
  if (!DIFFICULTIES.includes(difficulty)) return { error: "invalid difficulty" };
  const seed = normalizeSeed(body.seed);
  if (seed === null) return { error: "invalid seed" };
  const gen = wholeNumber(body.gen, 1, MAX_GEN);
  if (gen === null) return { error: "invalid gen" };
  const gems = wholeNumber(body.gems, MIN_GEMS, MAX_GEMS);
  if (gems === null) return { error: "invalid gems" };
  const time_ms = wholeNumber(body.time_ms, 1, MAX_TIME_MS);
  if (time_ms === null || time_ms < gems * MIN_MS_PER_GEM) return { error: "invalid time" };
  if (typeof body.no_damage !== "boolean") return { error: "invalid no_damage" };
  const no_damage = body.no_damage;
  const map = validateMap(body.map);
  if (map === null) return { error: "invalid map" };
  const version = String(body.version ?? "");
  if (!VERSION_PATTERN.test(version)) return { error: "invalid version" };
  const score = computeScore(gems, time_ms, no_damage);
  return { entry: { name, difficulty, score, seed, gen, gems, time_ms, no_damage, map, version } };
}

/** Highest score first, then fastest, then earliest. */
export function compareEntries(a, b) {
  return (
    b.score - a.score ||
    a.time_ms - b.time_ms ||
    String(a.date ?? "").localeCompare(String(b.date ?? ""))
  );
}

/** The same clear sent twice (for example a double tap on Submit). */
export function isDuplicate(board, entry) {
  return board.boards[entry.difficulty].some(
    (e) => e.name === entry.name && e.seed === entry.seed && e.gen === entry.gen && e.time_ms === entry.time_ms && e.gems === entry.gems,
  );
}

function emptyBoards() {
  return { easy: [], medium: [], hard: [] };
}

/** Rebuilds a board from stored data, dropping anything malformed. */
export function normalizeBoard(raw) {
  const boards = emptyBoards();
  const items = [];
  for (const d of DIFFICULTIES) {
    for (const item of Array.isArray(raw?.boards?.[d]) ? raw.boards[d] : []) items.push(item);
  }
  for (const item of items) {
    const checked = validateScore(item);
    if (!checked.entry) continue;
    const date = String(item.date ?? "");
    checked.entry.date = /^\d{4}-\d{2}-\d{2}T[\d:.]+Z$/.test(date) ? date : "";
    boards[checked.entry.difficulty].push(checked.entry);
  }
  for (const d of DIFFICULTIES) {
    boards[d].sort(compareEntries);
    boards[d] = boards[d].slice(0, MAX_ENTRIES);
  }
  return { _about: ABOUT, updated: typeof raw?.updated === "string" ? raw.updated : "", boards };
}

/** True when `entry` would make its board (it isn't full, or beats the last row). */
export function qualifies(board, entry) {
  const rows = board.boards[entry.difficulty];
  if (rows.length < MAX_ENTRIES) return true;
  return compareEntries(entry, rows[rows.length - 1]) < 0;
}

/** Adds `entry` (with its date) to its board and returns the new board. */
export function addEntry(board, entry, nowIso) {
  const boards = { ...board.boards };
  const rows = [...boards[entry.difficulty], { ...entry, date: nowIso }];
  rows.sort(compareEntries);
  boards[entry.difficulty] = rows.slice(0, MAX_ENTRIES);
  return { _about: ABOUT, updated: nowIso, boards };
}

/** How many rows in all boards together. */
export function countEntries(board) {
  return DIFFICULTIES.reduce((n, d) => n + board.boards[d].length, 0);
}

export function emptyBoard() {
  return { _about: ABOUT, updated: "", boards: emptyBoards() };
}
