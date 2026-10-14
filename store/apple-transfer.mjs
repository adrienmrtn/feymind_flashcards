#!/usr/bin/env node
/**
 * **Garder les comptes « Se connecter avec Apple » quand Micabo change de compte développeur.**
 *
 *   node store/apple-transfer.mjs check
 *       vérifie la clé : Apple rend-il un jeton de migration ?
 *   node store/apple-transfer.mjs transfer --target <TEAM_ID> apple-users.csv > apple-transfer.csv
 *       **ancienne** équipe, avant l'acceptation (ou jusqu'à 60 jours après)
 *   node store/apple-transfer.mjs exchange apple-transfer.csv > apple-migration.sql
 *       **nouvelle** équipe, après l'acceptation et avant 60 jours
 *
 * Variables, celles de l'équipe qui lance la commande : `APPLE_TEAM_ID`, `APPLE_KEY_ID`,
 * `APPLE_PRIVATE_KEY` (le contenu du `.p8` d'une clé **Sign in with Apple**, developer.apple.com
 * → Keys). `APPLE_CLIENT_ID` change l'identifiant présenté à Apple (par défaut `com.micabo.ios`).
 *
 * `apple-users.csv` vient de Supabase → SQL Editor, bouton « Export → CSV », sur :
 *
 *   select user_id, provider_id from auth.identities where provider = 'apple';
 *
 * Aucun de ces fichiers n'entre dans le dépôt : le premier contient les identifiants Apple des
 * élèves. La marche complète, et l'ordre des étapes : `docs/transfert-app-store.md`.
 */

import { readFileSync } from "node:fs";
import {
  AppleMigration,
  DEFAULT_CLIENT_ID,
  credentialProblems,
  migrationSql,
  pool,
  readIdentities,
  readTransfers,
} from "./lib/apple-transfer.mjs";

const log = (line) => process.stderr.write(`${line}\n`);

function fail(message) {
  log(`✗ ${message}`);
  process.exit(1);
}

function client() {
  const teamId = (process.env.APPLE_TEAM_ID ?? "").trim();
  const keyId = (process.env.APPLE_KEY_ID ?? "").trim();
  const privateKey = process.env.APPLE_PRIVATE_KEY ?? "";
  const problems = credentialProblems({ teamId, keyId });
  if (!privateKey.trim()) problems.push("APPLE_PRIVATE_KEY est vide (le contenu du fichier .p8)");
  if (problems.length) fail(problems.join("\n  "));
  const clientId = (process.env.APPLE_CLIENT_ID ?? DEFAULT_CLIENT_ID).trim();
  log(`Équipe ${teamId}, clé ${keyId}, identifiant ${clientId}`);
  return new AppleMigration({ teamId, keyId, privateKey, clientId, log });
}

/** Les échecs, ligne par ligne, puis un code de sortie qui ne laisse pas passer un oubli. */
function report(rows, results, label) {
  const failed = results.flatMap((result, at) => (result.ok ? [] : [{ row: rows[at], error: result.error }]));
  for (const { row, error } of failed) log(`  ✗ ligne ${row.line} (${row.userId}) : ${error.message}`);
  log(`${results.length - failed.length}/${results.length} ${label}.`);
  if (failed.length) {
    log("Les lignes en échec ne sont pas dans la sortie. Relancer la même commande plus tard : elle est rejouable.");
    process.exitCode = 2;
  }
}

const [command, ...rest] = process.argv.slice(2);
const option = (name) => {
  const at = rest.indexOf(name);
  return at >= 0 ? rest.splice(at, 2)[1] : undefined;
};

try {
  switch (command) {
    case "check": {
      await client().token();
      log("✓ Apple accepte la clé : la migration pourra se faire avec elle.");
      break;
    }

    case "transfer": {
      const target = option("--target");
      if (!/^[A-Z0-9]{10}$/.test(target ?? "")) fail("--target <TEAM_ID> : le Team ID du compte qui reçoit l'app");
      if (!rest[0]) fail("le CSV exporté de Supabase (user_id, provider_id)");
      const rows = readIdentities(readFileSync(rest[0], "utf8"));
      const apple = client();
      if (apple.credentials.teamId === target) fail("--target est l'équipe qui lance la commande : il faut celle qui reçoit l'app");
      const results = await pool(rows, 4, (row) => apple.transferSub(row.sub, target));
      process.stdout.write("user_id,transfer_sub\n");
      results.forEach((result, at) => {
        if (result.ok) process.stdout.write(`${rows[at].userId},${result.value}\n`);
      });
      report(rows, results, "identifiants de passage");
      break;
    }

    case "exchange": {
      if (!rest[0]) fail("le CSV écrit par `transfer` (user_id, transfer_sub)");
      const rows = readTransfers(readFileSync(rest[0], "utf8"));
      const apple = client();
      const results = await pool(rows, 4, (row) => apple.exchange(row.transferSub));
      const migrated = results.flatMap((result, at) =>
        result.ok ? [{ userId: rows[at].userId, sub: result.value.sub, email: result.value.email }] : [],
      );
      report(rows, results, "comptes échangés");
      if (migrated.length === 0) fail("aucun compte échangé : pas de SQL à écrire");
      process.stdout.write(migrationSql(migrated));
      break;
    }

    default:
      fail("commande : check, transfer ou exchange — voir l'en-tête de store/apple-transfer.mjs");
  }
} catch (error) {
  // `invalid_client` : la clé, le Key ID ou le Team ID ne vont pas ensemble, ou la clé n'a
  // pas la capacité Sign in with Apple. Apple n'en dit pas plus.
  fail(error.message);
}
