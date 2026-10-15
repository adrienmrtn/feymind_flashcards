/**
 * **Les comptes « Se connecter avec Apple » d'une app qui change d'équipe développeur.**
 *
 * Apple donne à chaque utilisateur un identifiant (`sub`) et, s'il a masqué son adresse, une
 * adresse relais — **tous deux propres à l'équipe**. Quand Micabo passe d'un compte à
 * l'autre, le même iPhone présente un `sub` neuf : Supabase ne le reconnaît pas et ouvre un
 * compte vide. Les comptes à adresse réelle sont rattrapés par l'adresse ; ceux à adresse
 * masquée, non.
 *
 * Le pont, c'est le **transfer_sub** : l'ancienne équipe le tire de chaque `sub`, la nouvelle
 * l'échange contre son propre `sub` et sa propre adresse relais. Au-delà de **60 jours après
 * l'acceptation du transfert**, l'échange ferme pour de bon.
 *
 * Aucune dépendance, comme `asc.mjs` : un jeton ES256 signé avec `node:crypto`, et `fetch`.
 */

import { sign } from "node:crypto";
import { readPrivateKey } from "./asc.mjs";

const APPLE = "https://appleid.apple.com";

/** L'identifiant présenté à Apple : le bundle de l'app, celui que portent les jetons iOS. */
export const DEFAULT_CLIENT_ID = "com.micabo.ios";

export const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
/** `001234.0a1b…c9.1234` pour un `sub`, `760417.ebbf…8a.1827` pour un `transfer_sub`. */
export const APPLE_ID = /^[0-9A-Za-z][0-9A-Za-z._-]{0,254}$/;
const TEAM_ID = /^[A-Z0-9]{10}$/;
export const EMAIL = /^[^\s@'"\\]+@[^\s@'"\\]+\.[^\s@'"\\]+$/;

/**
 * **Ce qui se vérifie sans appeler Apple.** La confusion la plus fréquente : le Key ID de la
 * clé à la place du Team ID, ou l'inverse — les deux font dix caractères.
 */
export function credentialProblems({ teamId, keyId }) {
  const problems = [];
  if (!TEAM_ID.test(teamId ?? "")) problems.push("APPLE_TEAM_ID n'a pas la forme d'un Team ID (10 caractères, majuscules et chiffres)");
  if (!TEAM_ID.test(keyId ?? "")) problems.push("APPLE_KEY_ID n'a pas la forme d'un Key ID (10 caractères, majuscules et chiffres)");
  if (teamId && teamId === keyId) problems.push("APPLE_TEAM_ID et APPLE_KEY_ID sont identiques : l'un des deux est faux");
  return problems;
}

/**
 * Le `client_secret` d'Apple : un JWT ES256 signé avec la clé **Sign in with Apple** de
 * l'équipe (developer.apple.com → Keys), pas avec la clé d'API App Store Connect.
 */
export function makeClientSecret({
  teamId,
  keyId,
  privateKey,
  clientId = DEFAULT_CLIENT_ID,
  seconds = 24 * 3600,
  now = Math.floor(Date.now() / 1000),
}) {
  // Apple refuse un secret qui vit plus de six mois.
  if (seconds > 15_777_000) throw new Error("un client_secret Apple vit six mois au plus");
  const encode = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
  const header = encode({ alg: "ES256", kid: keyId, typ: "JWT" });
  const payload = encode({ iss: teamId, iat: now, exp: now + seconds, aud: APPLE, sub: clientId });
  const signature = sign("sha256", Buffer.from(`${header}.${payload}`), {
    key: privateKey,
    dsaEncoding: "ieee-p1363",
  }).toString("base64url");
  return `${header}.${payload}.${signature}`;
}

/**
 * Un CSV tel que l'éditeur SQL de Supabase l'exporte : une ligne d'en-tête, des valeurs
 * parfois entre guillemets. Les colonnes se trouvent par leur nom, dans n'importe quel ordre.
 */
export function parseCsv(text, columns) {
  const lines = text.split(/\r?\n/).filter((line) => line.trim() !== "");
  if (lines.length === 0) return [];
  const cells = (line) => line.split(",").map((cell) => cell.trim().replace(/^"(.*)"$/, "$1").trim());
  const header = cells(lines[0]).map((name) => name.toLowerCase());
  const index = {};
  for (const [key, names] of Object.entries(columns)) {
    index[key] = header.findIndex((name) => names.includes(name));
    if (index[key] < 0) throw new Error(`colonne introuvable : ${names.join(" ou ")} (en-tête lu : ${header.join(", ")})`);
  }
  return lines.slice(1).map((line, row) => {
    const values = cells(line);
    const record = {};
    for (const [key, at] of Object.entries(index)) {
      record[key] = values[at] ?? "";
    }
    record.line = row + 2;
    return record;
  });
}

/** Les lignes de l'export Supabase (`user_id`, `provider_id`), vérifiées une à une. */
export function readIdentities(text) {
  const rows = parseCsv(text, { userId: ["user_id"], sub: ["provider_id", "sub"] });
  for (const row of rows) {
    if (!UUID.test(row.userId)) throw new Error(`ligne ${row.line} : user_id n'est pas un UUID (${row.userId})`);
    if (!APPLE_ID.test(row.sub)) throw new Error(`ligne ${row.line} : provider_id n'a pas la forme d'un identifiant Apple`);
  }
  return rows;
}

/** Les lignes que `transfer` a écrites (`user_id`, `transfer_sub`), vérifiées une à une. */
export function readTransfers(text) {
  const rows = parseCsv(text, { userId: ["user_id"], transferSub: ["transfer_sub"] });
  for (const row of rows) {
    if (!UUID.test(row.userId)) throw new Error(`ligne ${row.line} : user_id n'est pas un UUID (${row.userId})`);
    if (!APPLE_ID.test(row.transferSub)) throw new Error(`ligne ${row.line} : transfer_sub n'a pas la forme attendue`);
  }
  return rows;
}

export function literal(value) {
  return value == null ? "null" : `'${String(value).replaceAll("'", "''")}'`;
}

/**
 * Les trois écritures de la migration, lues dans `relation` (`user_id`, `new_sub`,
 * `new_email`) : la table temporaire du SQL à coller, ou la table de travail du jour J.
 * Une ligne sans `new_sub` (échange pas encore fait) est ignorée.
 */
export function migrationStatements(relation) {
  return `-- Reconnecté avec une adresse réelle : la nouvelle identité est déjà sur le compte, l'ancienne part.
delete from auth.identities old
using ${relation} m
where m.new_sub is not null
  and old.provider = 'apple'
  and old.user_id = m.user_id
  and old.provider_id <> m.new_sub
  and exists (
    select 1 from auth.identities fresh
    where fresh.provider = 'apple' and fresh.provider_id = m.new_sub and fresh.user_id = m.user_id
  );

-- Personne ne s'est reconnecté : l'identité prend le nouvel identifiant, et la nouvelle adresse relais.
update auth.identities i
set provider_id = m.new_sub,
    identity_data = i.identity_data
      || jsonb_build_object('sub', m.new_sub, 'provider_id', m.new_sub)
      || case when m.new_email is null then '{}'::jsonb else jsonb_build_object('email', m.new_email) end,
    updated_at = now()
from ${relation} m
where m.new_sub is not null
  and i.provider = 'apple'
  and i.user_id = m.user_id
  and i.provider_id <> m.new_sub
  and not exists (
    select 1 from auth.identities taken
    where taken.provider = 'apple' and taken.provider_id = m.new_sub
  );

-- L'adresse du compte, quand c'était l'adresse relais de l'ancienne équipe : elle ne relaie plus rien.
update auth.users u
set email = m.new_email,
    updated_at = now()
from ${relation} m
where m.new_sub is not null
  and u.id = m.user_id
  and m.new_email is not null
  and u.email like '%@privaterelay.appleid.com'
  and u.email is distinct from m.new_email
  and not exists (select 1 from auth.users twin where twin.email = m.new_email and twin.id <> m.user_id);
`;
}

/** L'état de chaque compte. « en double » : un second compte s'est ouvert, à fusionner à la main. */
export function migrationReport(relation) {
  return `select m.user_id,
  case
    when mine.user_id is not null then 'migré'
    when other.user_id is not null then 'en double'
    else 'sans identité Apple'
  end as etat,
  other.user_id as autre_compte
from ${relation} m
left join auth.identities mine
  on mine.provider = 'apple' and mine.provider_id = m.new_sub and mine.user_id = m.user_id
left join auth.identities other
  on other.provider = 'apple' and other.provider_id = m.new_sub and other.user_id <> m.user_id
where m.new_sub is not null`;
}

/**
 * **Le SQL à coller dans Supabase → SQL Editor.** L'éditeur envoie le texte d'un bloc : tout
 * passe ou rien ne passe, et il affiche le résultat de la dernière requête — l'état de chaque
 * compte.
 *
 * Rejouable : une identité qui porte déjà son nouveau `sub` n'est plus touchée.
 *
 * Trois cas, dans l'ordre où le SQL les traite :
 * 1. **Personne ne s'est reconnecté** : l'identité Apple prend le nouveau `sub` (et la
 *    nouvelle adresse relais, s'il y en a une).
 * 2. **Reconnecté avec une adresse réelle** : Supabase a déjà rattaché une seconde identité
 *    Apple au même compte, par l'adresse. L'ancienne, devenue morte, est retirée.
 * 3. **Reconnecté avec une adresse masquée** : Supabase a ouvert un **second compte**. Le SQL
 *    n'y touche pas — fusionner deux comptes est une décision, pas une requête — et le
 *    signale « en double », avec l'identifiant de l'autre compte.
 */
export function migrationSql(rows, { generatedAt = new Date().toISOString() } = {}) {
  if (rows.length === 0) throw new Error("aucun compte à migrer");
  for (const row of rows) {
    if (!UUID.test(row.userId)) throw new Error(`user_id invalide : ${row.userId}`);
    if (!APPLE_ID.test(row.sub)) throw new Error(`sub invalide pour ${row.userId}`);
    if (row.email != null && !EMAIL.test(row.email)) throw new Error(`adresse invalide pour ${row.userId}`);
  }
  const values = rows
    .map((row) => `  (${literal(row.userId)}::uuid, ${literal(row.sub)}, ${literal(row.email ?? null)})`)
    .join(",\n");
  return `-- Migration « Se connecter avec Apple » vers la nouvelle équipe : ${rows.length} compte(s).
-- Générée le ${generatedAt} par store/apple-transfer.mjs. Rejouable.
-- À coller tel quel dans Supabase → SQL Editor → Run.

create temporary table apple_migration (
  user_id uuid primary key,
  new_sub text not null,
  new_email text
) on commit drop;

insert into apple_migration (user_id, new_sub, new_email) values
${values};

${migrationStatements("apple_migration")}
-- L'état de chaque compte. « en double » : un second compte s'est ouvert, à fusionner à la main.
${migrationReport("apple_migration")}
order by etat desc, m.user_id;
`;
}

/**
 * Le client des deux appels de migration. Le jeton d'accès vaut une heure ; on le refait au
 * bout de cinquante minutes.
 */
export class AppleMigration {
  constructor({ teamId, keyId, privateKey, clientId = DEFAULT_CLIENT_ID, log = console.error }) {
    this.credentials = { teamId: teamId.trim(), keyId: keyId.trim(), privateKey: readPrivateKey(privateKey), clientId };
    this.log = log;
    this.accessToken = null;
    this.accessTokenAt = 0;
  }

  secret() {
    return makeClientSecret(this.credentials);
  }

  async post(path, form, bearer) {
    for (let attempt = 1; ; attempt += 1) {
      const response = await fetch(`${APPLE}${path}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          ...(bearer ? { Authorization: `Bearer ${bearer}` } : {}),
        },
        body: new URLSearchParams(form),
      });
      const text = await response.text();
      let json = null;
      try {
        json = text ? JSON.parse(text) : null;
      } catch {
        // Apple répond parfois une page HTML sur une 5xx.
      }
      if (response.ok) return json;
      if ((response.status === 429 || response.status >= 500) && attempt < 6) {
        const wait = Number(response.headers.get("retry-after")) || 2 ** attempt;
        this.log(`  … ${response.status} sur ${path}, nouvel essai dans ${wait} s`);
        await new Promise((done) => setTimeout(done, wait * 1000));
        continue;
      }
      const error = new Error(`${path} → ${response.status} ${json?.error ?? text.slice(0, 200)}`);
      error.status = response.status;
      throw error;
    }
  }

  async token() {
    const now = Date.now();
    if (!this.accessToken || now - this.accessTokenAt > 50 * 60 * 1000) {
      const json = await this.post("/auth/token", {
        grant_type: "client_credentials",
        scope: "user.migration",
        client_id: this.credentials.clientId,
        client_secret: this.secret(),
      });
      this.accessToken = json.access_token;
      this.accessTokenAt = now;
    }
    return this.accessToken;
  }

  /** Côté **ancienne** équipe : le `sub` d'ici → l'identifiant de passage vers `target`. */
  async transferSub(sub, target) {
    const json = await this.post(
      "/auth/usermigrationinfo",
      { sub, target, client_id: this.credentials.clientId, client_secret: this.secret() },
      await this.token(),
    );
    if (!json?.transfer_sub) throw new Error("réponse sans transfer_sub");
    return json.transfer_sub;
  }

  /** Côté **nouvelle** équipe : l'identifiant de passage → le `sub` d'ici, et l'adresse relais. */
  async exchange(transferSub) {
    const json = await this.post(
      "/auth/usermigrationinfo",
      { transfer_sub: transferSub, client_id: this.credentials.clientId, client_secret: this.secret() },
      await this.token(),
    );
    if (!json?.sub) throw new Error("réponse sans sub");
    return { sub: json.sub, email: json.is_private_email ? json.email ?? null : null };
  }
}

/** Fait passer `items` dans `work`, `width` à la fois, en gardant l'ordre des résultats. */
export async function pool(items, width, work) {
  const results = new Array(items.length);
  let next = 0;
  async function lane() {
    while (next < items.length) {
      const at = next;
      next += 1;
      try {
        results[at] = { ok: true, value: await work(items[at], at) };
      } catch (error) {
        results[at] = { ok: false, error };
      }
    }
  }
  await Promise.all(Array.from({ length: Math.min(width, items.length) }, lane));
  return results;
}
