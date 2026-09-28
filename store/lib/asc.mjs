/**
 * **Le client App Store Connect, réduit à ce dont la grille a besoin.**
 *
 * Aucune dépendance : un jeton ES256 signé avec `node:crypto`, et `fetch`. La clé est une
 * clé d'API App Store Connect (Users and Access → Integrations → App Store Connect API,
 * rôle *App Manager* au minimum) — pas la clé In-App Purchase que RevenueCat utilise.
 */

import { createPrivateKey, sign } from "node:crypto";

const API = "https://api.appstoreconnect.apple.com";

/** Un jeton vaut vingt minutes au plus ; on le refait au bout de quinze. */
const TOKEN_SECONDS = 15 * 60;

function base64url(value) {
  return Buffer.from(typeof value === "string" ? value : JSON.stringify(value)).toString("base64url");
}

/**
 * La clé `.p8` telle qu'on la colle dans un secret GitHub : avec ses lignes, ou aplatie avec
 * des `\n` littéraux, ou encodée en base64. Les trois arrivent en pratique.
 */
export function readPrivateKey(raw) {
  let text = raw.trim();
  if (!text.includes("BEGIN")) text = Buffer.from(text, "base64").toString("utf8").trim();
  text = text.replace(/\\n/g, "\n");
  return createPrivateKey(text);
}

/**
 * **Ce qui se vérifie sans appeler Apple.** Un 401 d'Apple ne dit jamais laquelle des trois
 * valeurs est fausse : on attrape ici celles qui ont la mauvaise forme, avant l'appel.
 *
 * - Key ID : dix caractères, lettres majuscules et chiffres (`2X9R4HXF34`).
 * - Issuer ID : un UUID (`57246542-96fe-1a63-e053-0824d011072a`). Le Team ID, lui, fait dix
 *   caractères — c'est la confusion la plus fréquente. Vide : clé **individuelle**.
 */
export function credentialProblems({ keyId, issuerId }) {
  const problems = [];
  if (!/^[A-Z0-9]{10}$/.test(keyId)) {
    problems.push(`ASC_KEY_ID n'a pas la forme d'un Key ID (10 caractères, majuscules et chiffres) : ${keyId.length} caractères reçus`);
  }
  if (issuerId && !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(issuerId)) {
    problems.push(
      `ASC_ISSUER_ID n'a pas la forme d'un Issuer ID (un UUID de 36 caractères avec des tirets) : ${issuerId.length} caractères reçus` +
        (/^[A-Z0-9]{10}$/.test(issuerId) ? " — ça ressemble à un Team ID ou à un Key ID" : ""),
    );
  }
  return problems;
}

/**
 * Le jeton. Une clé **d'équipe** signe avec son Issuer ID (`iss`) ; une clé **individuelle**
 * n'en a pas et signe `sub: "user"` à la place — sinon Apple répond 401 sans autre détail.
 */
export function makeToken({ keyId, issuerId, privateKey, now = Math.floor(Date.now() / 1000) }) {
  const header = base64url({ alg: "ES256", kid: keyId, typ: "JWT" });
  const who = issuerId ? { iss: issuerId } : { sub: "user" };
  const payload = base64url({ ...who, iat: now, exp: now + TOKEN_SECONDS + 60, aud: "appstoreconnect-v1" });
  const signature = sign("sha256", Buffer.from(`${header}.${payload}`), {
    key: privateKey,
    dsaEncoding: "ieee-p1363",
  }).toString("base64url");
  return `${header}.${payload}.${signature}`;
}

export class AppStoreConnect {
  constructor({ keyId, issuerId, privateKey, log = console.log }) {
    // Un secret collé garde souvent un espace ou un retour à la ligne : Apple le refuse.
    this.credentials = { keyId: keyId.trim(), issuerId: (issuerId ?? "").trim(), privateKey: readPrivateKey(privateKey) };
    this.log = log;
    this.token = null;
    this.tokenAt = 0;
    this.requests = 0;
  }

  bearer() {
    const now = Math.floor(Date.now() / 1000);
    if (!this.token || now - this.tokenAt > TOKEN_SECONDS - 60) {
      this.token = makeToken({ ...this.credentials, now });
      this.tokenAt = now;
    }
    return this.token;
  }

  /**
   * Un appel, avec les reprises qu'Apple demande : 429 respecte `Retry-After`, 5xx attend
   * un peu plus à chaque essai. Une 4xx n'est jamais reprise — elle dit une erreur de
   * requête, et la répéter ne la corrige pas.
   */
  async request(method, path, body) {
    const url = path.startsWith("http") ? path : `${API}${path}`;
    for (let attempt = 1; ; attempt += 1) {
      this.requests += 1;
      const response = await fetch(url, {
        method,
        headers: {
          Authorization: `Bearer ${this.bearer()}`,
          ...(body ? { "Content-Type": "application/json" } : {}),
        },
        body: body ? JSON.stringify(body) : undefined,
      });
      if (response.status === 204) return null;
      const text = await response.text();
      const json = text ? JSON.parse(text) : null;
      if (response.ok) return json;

      const retryable = response.status === 429 || response.status >= 500;
      if (retryable && attempt < 6) {
        const wait = Number(response.headers.get("retry-after")) || 2 ** attempt;
        this.log(`  … ${response.status} sur ${method} ${path}, nouvel essai dans ${wait} s`);
        await new Promise((done) => setTimeout(done, wait * 1000));
        continue;
      }
      const details = (json?.errors ?? []).map((e) => `${e.code ?? e.status}: ${e.detail ?? e.title}`).join(" ; ");
      const error = new Error(`${method} ${path} → ${response.status} ${details || text}`);
      error.status = response.status;
      throw error;
    }
  }

  get(path) {
    return this.request("GET", path);
  }

  post(path, body) {
    return this.request("POST", path, body);
  }

  /** Toutes les pages d'une liste, et les ressources `included` à côté, indexées par type et id. */
  async getAll(path) {
    const data = [];
    const included = new Map();
    let next = path;
    while (next) {
      const page = await this.get(next);
      data.push(...(page.data ?? []));
      for (const item of page.included ?? []) included.set(`${item.type}/${item.id}`, item);
      next = page.links?.next ?? null;
    }
    return { data, included };
  }
}
