// Un faux Supabase pour regarder l'app connectée sans compte ni réseau.
//
// Il répond à ce que le site demande, et à rien d'autre : le jeton par mot de passe, l'utilisateur
// derrière un jeton, une lecture PostgREST filtrée (eq, neq, is, in, gte, lte, ilike, or, order,
// limit) et les huit fonctions RPC. Les écritures sont acceptées et oubliées.
//
//     node scripts/demo/server.mjs            # écoute sur 54329
//     NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54329 pnpm dev
//     puis http://localhost:3000/auth/dev?email=camille@micabo.test&password=demo

import { createServer } from "node:http";
import { createHmac } from "node:crypto";

import { USER, edgeFunction, rpc, tables } from "./fixtures.mjs";

const PORT = Number(process.env.DEMO_SUPABASE_PORT ?? 54329);
const SECRET = "demo-secret";

function b64url(value) {
  return Buffer.from(value).toString("base64url");
}
function jwt(payload) {
  const head = b64url(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const body = b64url(JSON.stringify(payload));
  const sig = createHmac("sha256", SECRET).update(`${head}.${body}`).digest("base64url");
  return `${head}.${body}.${sig}`;
}

const user = {
  id: USER.id,
  aud: "authenticated",
  role: "authenticated",
  email: USER.email,
  email_confirmed_at: new Date().toISOString(),
  app_metadata: { provider: "email", providers: ["email"] },
  user_metadata: {},
  identities: [],
  created_at: new Date().toISOString(),
  updated_at: new Date().toISOString(),
};

function session() {
  const exp = Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30;
  return {
    access_token: jwt({ sub: user.id, email: user.email, role: "authenticated", aud: "authenticated", exp, iat: Math.floor(Date.now() / 1000), iss: `http://127.0.0.1:${PORT}/auth/v1`, session_id: "demo" }),
    token_type: "bearer",
    expires_in: 60 * 60 * 24 * 30,
    expires_at: exp,
    refresh_token: "demo-refresh",
    user,
  };
}

function parseValue(raw) {
  if (raw === "null") return null;
  if (raw === "true") return true;
  if (raw === "false") return false;
  return raw;
}

function matches(row, key, op, raw) {
  const value = row[key];
  switch (op) {
    case "eq": return String(value) === raw;
    case "neq": return String(value) !== raw;
    case "is": return parseValue(raw) === null ? value == null : value === parseValue(raw);
    case "not.is": return parseValue(raw) === null ? value != null : value !== parseValue(raw);
    case "in": return raw.replace(/^\(|\)$/g, "").split(",").map((v) => v.replace(/^"|"$/g, "")).includes(String(value));
    case "gte": return String(value) >= raw;
    case "lte": return String(value) <= raw;
    case "gt": return String(value) > raw;
    case "lt": return String(value) < raw;
    case "ilike": {
      const pattern = new RegExp(`^${raw.replace(/[.*+?^${}()|[\]\\]/g, "\\$&").replace(/%/g, ".*")}$`, "i");
      return pattern.test(String(value ?? ""));
    }
    default: return true;
  }
}

function applyFilters(rows, params) {
  let out = rows;
  for (const [key, raw] of params) {
    if (["select", "order", "limit", "offset"].includes(key)) continue;
    if (key === "or") {
      const clauses = raw.replace(/^\(|\)$/g, "").split(/,(?=[a-z_]+\.)/);
      out = out.filter((row) => clauses.some((clause) => {
        const [col, op, ...rest] = clause.split(".");
        return matches(row, col, op, rest.join("."));
      }));
      continue;
    }
    const dot = raw.indexOf(".");
    let op = raw.slice(0, dot);
    let rest = raw.slice(dot + 1);
    if (op === "not") {
      const dot2 = rest.indexOf(".");
      op = `not.${rest.slice(0, dot2)}`;
      rest = rest.slice(dot2 + 1);
    }
    out = out.filter((row) => matches(row, key, op, rest));
  }
  const order = params.get("order");
  if (order) {
    const [col, dir] = order.split(".");
    const sign = dir === "desc" ? -1 : 1;
    out = [...out].sort((a, b) => (a[col] < b[col] ? -sign : a[col] > b[col] ? sign : 0));
  }
  const offset = Number(params.get("offset") ?? 0);
  const limit = params.get("limit");
  out = out.slice(offset, limit ? offset + Number(limit) : undefined);
  return out;
}

function project(rows, select) {
  if (!select || select === "*") return rows;
  const cols = select.split(",").map((c) => c.trim().split(":").pop().split("(")[0]);
  return rows.map((row) => Object.fromEntries(cols.map((c) => [c, row[c] ?? null])));
}

function send(res, status, body, headers = {}) {
  res.writeHead(status, {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "*",
    "Access-Control-Allow-Methods": "GET,POST,PATCH,DELETE,HEAD,OPTIONS",
    ...headers,
  });
  res.end(body === undefined ? "" : JSON.stringify(body));
}

async function readBody(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  const text = Buffer.concat(chunks).toString();
  try { return text ? JSON.parse(text) : null; } catch { return null; }
}

createServer(async (req, res) => {
  const url = new URL(req.url, `http://127.0.0.1:${PORT}`);
  const path = url.pathname;
  if (req.method === "OPTIONS") return send(res, 204);

  if (path.startsWith("/auth/v1/")) {
    if (path === "/auth/v1/token") return send(res, 200, session());
    if (path === "/auth/v1/user") return send(res, 200, user);
    if (path === "/auth/v1/logout") return send(res, 204);
    if (path === "/auth/v1/settings") return send(res, 200, { external: { apple: true, google: true, email: true } });
    if (path.endsWith("/.well-known/jwks.json")) return send(res, 200, { keys: [] });
    return send(res, 200, session());
  }

  if (path.startsWith("/functions/v1/")) {
    const name = path.slice("/functions/v1/".length);
    const body = await readBody(req);
    return send(res, 200, edgeFunction(name, body));
  }

  if (path.startsWith("/rest/v1/rpc/")) {
    const name = path.slice("/rest/v1/rpc/".length);
    const args = await readBody(req);
    return send(res, 200, rpc(name, args));
  }

  if (path.startsWith("/rest/v1/")) {
    const table = path.slice("/rest/v1/".length);
    const rows = tables[table];
    if (!rows) return send(res, 404, { message: `Table inconnue : ${table}` });
    const accept = req.headers.accept ?? "";
    const prefer = req.headers.prefer ?? "";
    if (req.method === "GET" || req.method === "HEAD") {
      const filtered = applyFilters(rows, url.searchParams);
      const headers = {};
      if (prefer.includes("count=")) headers["Content-Range"] = `0-${Math.max(0, filtered.length - 1)}/${filtered.length}`;
      if (req.method === "HEAD") return send(res, 200, undefined, headers);
      const out = project(filtered, url.searchParams.get("select"));
      if (accept.includes("vnd.pgrst.object")) {
        if (out.length === 0) return send(res, 406, { code: "PGRST116", message: "Aucune ligne", details: "0 rows" }, headers);
        return send(res, 200, out[0], headers);
      }
      return send(res, 200, out, headers);
    }
    // Les écritures sont gardées en mémoire : sans ça, un examen blanc ouvert ne se
    // relirait pas, et la moitié des écrans de démonstration seraient inaccessibles.
    const body = await readBody(req);
    const written = Array.isArray(body) ? body : body ? [body] : [];

    if (req.method === "POST") {
      for (const row of written) rows.push({ ...row, deleted_at: row.deleted_at ?? null });
    } else if (req.method === "PATCH") {
      const targets = applyFilters(rows, url.searchParams);
      for (const row of targets) Object.assign(row, written[0] ?? {});
    } else if (req.method === "DELETE") {
      for (const row of applyFilters(rows, url.searchParams)) {
        const index = rows.indexOf(row);
        if (index >= 0) rows.splice(index, 1);
      }
    }

    console.log(`  ${req.method} ${table} (${written.length})`);
    if (accept.includes("vnd.pgrst.object")) return send(res, 200, written[0] ?? {});
    return send(
      res,
      prefer.includes("return=representation") ? 200 : 204,
      prefer.includes("return=representation") ? written : undefined,
    );
  }

  return send(res, 404, { message: "Introuvable" });
}).listen(PORT, "127.0.0.1", () => {
  console.log(`Faux Supabase : http://127.0.0.1:${PORT}  (${tables.flashcards.length} cartes, ${tables.courses.length} cours, ${tables.exams.length} épreuves)`);
});
