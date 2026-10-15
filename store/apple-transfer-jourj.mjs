#!/usr/bin/env node
/**
 * **Le jour J du transfert, branché directement sur Supabase.**
 *
 * `store/apple-transfer.mjs` fait la même migration avec des fichiers CSV et un SQL à coller.
 * Ici, rien ne passe par un fichier : les identifiants de passage et les nouveaux
 * identifiants vivent dans une table de travail, `transfert_apple.passages`, hors des schémas
 * exposés par l'API. Une session qui n'a que la clé de l'ancienne équipe et une autre qui n'a
 * que celle de la nouvelle peuvent ainsi se passer le relais.
 *
 *   status                 lecture seule : fournisseur Apple, table de travail, comptes Apple
 *   apple off | apple on   coupe ou rallume la connexion Apple dans Supabase
 *   stage                  ANCIENNE équipe (SIWA_ADRIEN_*), cible SIWA_VIK_TEAM_ID :
 *                          exporte les identités Apple et range leur identifiant de passage
 *   exchange               NOUVELLE équipe (SIWA_VIK_*) : range le nouveau `sub` et la
 *                          nouvelle adresse relais de chaque compte
 *   secret                 NOUVELLE équipe : pose dans Supabase le secret OAuth du site
 *                          (Service ID com.micabo.ios.service, six mois), sans rallumer Apple
 *   migrate                réécrit les identités Apple d'après la table, puis compte les états
 *
 * L'accès à Supabase passe par l'API de gestion ; le jeton est ajouté par le proxy de
 * l'environnement (secret réseau sur api.supabase.com). Le `fetch` de Node ne passe par ce
 * proxy que si on le lui demande : dans une session cloud, lancer avec `NODE_USE_ENV_PROXY=1`,
 * sinon Supabase répond 401 « No access token provided ». Aucune commande n'affiche de secret.
 */

import {
  APPLE_ID,
  AppleMigration,
  EMAIL,
  UUID,
  literal,
  makeClientSecret,
  migrationReport,
  migrationStatements,
  pool,
} from "./lib/apple-transfer.mjs";

const REF = process.env.SUPABASE_PROJECT_REF ?? "khuzodsrznanzhwlbjbx";
const SUPABASE = `https://api.supabase.com/v1/projects/${REF}`;
const TABLE = "transfert_apple.passages";
const WEB_CLIENT_ID = "com.micabo.ios.service";
const BATCH = 400;

const log = (line) => process.stderr.write(`${line}\n`);
function fail(message) {
  log(`✗ ${message}`);
  process.exit(1);
}

async function supabase(method, path, body) {
  const response = await fetch(`${SUPABASE}${path}`, {
    method,
    headers: { "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  if (!response.ok) throw new Error(`Supabase ${method} ${path} → ${response.status} ${text.slice(0, 300)}`);
  return text ? JSON.parse(text) : null;
}

const sql = (query) => supabase("POST", "/database/query", { query });

/** Les réglages Apple, sans jamais renvoyer le secret lui-même. */
async function appleSettings() {
  const config = await supabase("GET", "/config/auth");
  return {
    enabled: config.external_apple_enabled,
    clientIds: config.external_apple_client_id,
    secretSet: Boolean(config.external_apple_secret),
  };
}

function team(prefix) {
  const teamId = (process.env[`${prefix}_TEAM_ID`] ?? "").trim();
  const keyId = (process.env[`${prefix}_KEY_ID`] ?? "").trim();
  const privateKey = process.env[`${prefix}_P8`] ?? "";
  if (!/^[A-Z0-9]{10}$/.test(teamId)) fail(`${prefix}_TEAM_ID n'est pas un Team ID (10 caractères)`);
  if (!/^[A-Z0-9]{10}$/.test(keyId)) fail(`${prefix}_KEY_ID n'est pas un Key ID (10 caractères)`);
  if (!privateKey.trim()) fail(`${prefix}_P8 est vide`);
  return { teamId, keyId, privateKey };
}

async function ensureTable() {
  await sql(`create schema if not exists transfert_apple;
revoke all on schema transfert_apple from anon, authenticated;
create table if not exists ${TABLE} (
  user_id uuid primary key,
  transfer_sub text not null,
  new_sub text,
  new_email text,
  staged_at timestamptz not null default now(),
  exchanged_at timestamptz
);
alter table ${TABLE} enable row level security;
select 1;`);
}

function batches(items) {
  const out = [];
  for (let at = 0; at < items.length; at += BATCH) out.push(items.slice(at, at + BATCH));
  return out;
}

function report(results, label) {
  const failed = results.filter((result) => !result.ok);
  const reasons = new Map();
  for (const { error } of failed) reasons.set(error.message, (reasons.get(error.message) ?? 0) + 1);
  for (const [reason, count] of reasons) log(`  ✗ ${count} × ${reason}`);
  log(`${results.length - failed.length}/${results.length} ${label}.`);
  if (failed.length) process.exitCode = 2;
}

const [command, argument] = process.argv.slice(2);

try {
  switch (command) {
    case "status": {
      log(`Apple dans Supabase : ${JSON.stringify(await appleSettings())}`);
      const [identities] = await sql(`select count(*)::int as n from auth.identities where provider = 'apple'`);
      log(`Identités Apple : ${identities.n}`);
      const [exists] = await sql(`select to_regclass('${TABLE}') is not null as present`);
      if (exists.present) {
        const [counts] = await sql(`select count(*)::int as lignes,
  count(new_sub)::int as echangees,
  count(new_email)::int as adresses_relais
from ${TABLE}`);
        log(`Table de travail : ${JSON.stringify(counts)}`);
      } else {
        log("Table de travail : absente");
      }
      break;
    }

    case "apple": {
      if (argument !== "on" && argument !== "off") fail("apple on | apple off");
      await supabase("PATCH", "/config/auth", { external_apple_enabled: argument === "on" });
      log(`Apple dans Supabase : ${JSON.stringify(await appleSettings())}`);
      break;
    }

    case "stage": {
      const target = (process.env.SIWA_VIK_TEAM_ID ?? "").trim();
      if (!/^[A-Z0-9]{10}$/.test(target)) fail("SIWA_VIK_TEAM_ID : le Team ID de l'équipe qui reçoit l'app");
      const apple = new AppleMigration({ ...team("SIWA_ADRIEN"), log });
      if (apple.credentials.teamId === target) fail("l'équipe cible est l'équipe d'origine");
      await ensureTable();
      const identities = await sql(`select i.user_id, i.provider_id
from auth.identities i
left join ${TABLE} p on p.user_id = i.user_id
where i.provider = 'apple' and p.user_id is null`);
      log(`${identities.length} identité(s) Apple sans identifiant de passage.`);
      for (const row of identities) {
        if (!UUID.test(row.user_id) || !APPLE_ID.test(row.provider_id)) fail(`identité inattendue pour ${row.user_id}`);
      }
      const results = await pool(identities, 4, (row) => apple.transferSub(row.provider_id, target));
      const staged = results.flatMap((result, at) => {
        if (!result.ok) return [];
        if (!APPLE_ID.test(result.value)) throw new Error(`transfer_sub inattendu pour ${identities[at].user_id}`);
        return [`(${literal(identities[at].user_id)}::uuid, ${literal(result.value)})`];
      });
      for (const chunk of batches(staged)) {
        await sql(`insert into ${TABLE} (user_id, transfer_sub) values ${chunk.join(", ")}
on conflict (user_id) do update set transfer_sub = excluded.transfer_sub;
select 1;`);
      }
      report(results, "identifiants de passage rangés");
      const [total] = await sql(`select count(*)::int as n from ${TABLE}`);
      log(`Table de travail : ${total.n} ligne(s).`);
      break;
    }

    case "exchange": {
      const apple = new AppleMigration({ ...team("SIWA_VIK"), log });
      const rows = await sql(`select user_id, transfer_sub from ${TABLE} where new_sub is null`);
      log(`${rows.length} compte(s) à échanger.`);
      const results = await pool(rows, 4, (row) => apple.exchange(row.transfer_sub));
      const exchanged = results.flatMap((result, at) => {
        if (!result.ok) return [];
        const { sub, email } = result.value;
        if (!APPLE_ID.test(sub)) throw new Error(`sub inattendu pour ${rows[at].user_id}`);
        if (email != null && !EMAIL.test(email)) throw new Error(`adresse inattendue pour ${rows[at].user_id}`);
        return [`(${literal(rows[at].user_id)}::uuid, ${literal(sub)}::text, ${literal(email)}::text)`];
      });
      for (const chunk of batches(exchanged)) {
        await sql(`update ${TABLE} p
set new_sub = v.new_sub, new_email = v.new_email, exchanged_at = now()
from (values ${chunk.join(", ")}) as v(user_id, new_sub, new_email)
where p.user_id = v.user_id;
select 1;`);
      }
      report(results, "comptes échangés");
      break;
    }

    case "secret": {
      const { teamId, keyId, privateKey } = team("SIWA_VIK");
      const apple = new AppleMigration({ teamId, keyId, privateKey, log });
      const seconds = 180 * 86400;
      const jwt = makeClientSecret({ ...apple.credentials, clientId: WEB_CLIENT_ID, seconds });
      await supabase("PATCH", "/config/auth", { external_apple_secret: jwt });
      const expires = new Date(Date.now() + seconds * 1000).toISOString().slice(0, 10);
      log(`Secret OAuth Apple posé (équipe ${teamId}, clé ${keyId}, ${WEB_CLIENT_ID}), expire le ${expires}.`);
      log(`Apple dans Supabase : ${JSON.stringify(await appleSettings())}`);
      break;
    }

    case "migrate": {
      const [ready] = await sql(`select count(*)::int as lignes, count(new_sub)::int as echangees from ${TABLE}`);
      log(`Table de travail : ${ready.lignes} ligne(s), ${ready.echangees} échangée(s).`);
      if (ready.echangees === 0) fail("aucun compte échangé : rien à migrer");
      await sql(`begin;
${migrationStatements(TABLE)}
commit;
select 1;`);
      const states = await sql(`select etat, count(*)::int as n from (${migrationReport(TABLE)}) s group by etat order by etat`);
      log(`États : ${states.map((s) => `${s.etat} ${s.n}`).join(" · ")}`);
      const doubles = await sql(`select user_id, autre_compte from (${migrationReport(TABLE)}) s where etat = 'en double'`);
      for (const d of doubles) log(`  en double : ${d.user_id} → second compte ${d.autre_compte}`);
      break;
    }

    default:
      fail("commande : status, apple on|off, stage, exchange, secret ou migrate — voir l'en-tête du fichier");
  }
} catch (error) {
  fail(error.message);
}
