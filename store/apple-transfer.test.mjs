/**
 * La migration des comptes Apple se vérifie sans réseau : `node --test store/`.
 *
 * Ce qu'on fige : le secret qu'Apple attend (sinon `invalid_client`, sans autre détail), la
 * lecture de l'export Supabase, et un SQL qui ne laisse rien entrer qu'un identifiant Apple.
 */

import assert from "node:assert/strict";
import { generateKeyPairSync, verify } from "node:crypto";
import { test } from "node:test";
import {
  credentialProblems,
  makeClientSecret,
  migrationSql,
  pool,
  readIdentities,
  readTransfers,
} from "./lib/apple-transfer.mjs";

const USER = "6f1c2b0e-8a7d-4c3b-9e21-0d5f4a6b7c8d";
const OTHER = "0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d";

test("le secret est un JWT ES256 signé pour appleid.apple.com, au nom de l'app", () => {
  const { privateKey, publicKey } = generateKeyPairSync("ec", { namedCurve: "P-256" });
  const secret = makeClientSecret({ teamId: "ABCDE12345", keyId: "KEY1234567", privateKey, now: 1_000 });
  const [header, payload, signature] = secret.split(".");
  assert.deepEqual(JSON.parse(Buffer.from(header, "base64url")), { alg: "ES256", kid: "KEY1234567", typ: "JWT" });
  const claims = JSON.parse(Buffer.from(payload, "base64url"));
  assert.equal(claims.iss, "ABCDE12345");
  assert.equal(claims.sub, "com.micabo.ios");
  assert.equal(claims.aud, "https://appleid.apple.com");
  assert.ok(claims.exp > claims.iat && claims.exp - claims.iat <= 180 * 24 * 3600);
  const valid = verify(
    "sha256",
    Buffer.from(`${header}.${payload}`),
    { key: publicKey, dsaEncoding: "ieee-p1363" },
    Buffer.from(signature, "base64url"),
  );
  assert.ok(valid);
});

test("le Team ID et le Key ID se vérifient avant l'appel", () => {
  assert.deepEqual(credentialProblems({ teamId: "ABCDE12345", keyId: "KEY1234567" }), []);
  assert.equal(credentialProblems({ teamId: "abc", keyId: "KEY1234567" }).length, 1);
  assert.equal(credentialProblems({ teamId: "ABCDE12345", keyId: "ABCDE12345" }).length, 1);
});

test("l'export de Supabase se lit, guillemets et colonnes dans le désordre compris", () => {
  const csv = `"provider_id","user_id"\r\n"001234.abcdef0123456789.0042","${USER}"\r\n\r\n`;
  const [row] = readIdentities(csv);
  assert.equal(row.userId, USER);
  assert.equal(row.sub, "001234.abcdef0123456789.0042");
  assert.throws(() => readIdentities(`user_id,provider_id\nnot-a-uuid,001234.ab.0042\n`), /UUID/);
  assert.throws(() => readIdentities(`user_id,email\n${USER},x@y.z\n`), /colonne introuvable/);
});

test("le fichier de passage se relit", () => {
  const rows = readTransfers(`user_id,transfer_sub\n${USER},760417.ebbf12acbc78e1be1668ba852d492d8a.1827\n`);
  assert.equal(rows[0].transferSub, "760417.ebbf12acbc78e1be1668ba852d492d8a.1827");
  assert.throws(() => readTransfers(`user_id,transfer_sub\n${USER},'; drop table x; --\n`), /transfer_sub/);
});

test("le SQL porte chaque compte, et rien d'autre qu'un identifiant Apple", () => {
  const sql = migrationSql(
    [
      { userId: USER, sub: "820417.faa325acbc78e1be1668ba852d492d8a.0219", email: "ep9ks2tnph@privaterelay.appleid.com" },
      { userId: OTHER, sub: "820417.0123.0001", email: null },
    ],
    { generatedAt: "2026-10-14" },
  );
  assert.match(sql, /2 compte\(s\)/);
  assert.match(sql, new RegExp(`'${USER}'::uuid, '820417\\.faa325acbc78e1be1668ba852d492d8a\\.0219', 'ep9ks2tnph@privaterelay\\.appleid\\.com'`));
  assert.match(sql, new RegExp(`'${OTHER}'::uuid, '820417\\.0123\\.0001', null`));
  // La dernière requête est l'état : c'est elle que l'éditeur SQL affiche.
  assert.match(sql.trim(), /order by etat desc, m\.user_id;$/);
  assert.throws(() => migrationSql([{ userId: USER, sub: "x' or '1'='1", email: null }]), /sub invalide/);
  assert.throws(() => migrationSql([{ userId: USER, sub: "820417.a.1", email: "a'b@c.d" }]), /adresse invalide/);
  assert.throws(() => migrationSql([]), /aucun compte/);
});

test("le pool garde l'ordre et isole les échecs", async () => {
  const results = await pool([3, 1, 2, 0], 2, async (n) => {
    await new Promise((done) => setTimeout(done, n * 5));
    if (n === 2) throw new Error("non");
    return n * 10;
  });
  assert.deepEqual(
    results.map((r) => (r.ok ? r.value : r.error.message)),
    [30, 10, "non", 0],
  );
});
