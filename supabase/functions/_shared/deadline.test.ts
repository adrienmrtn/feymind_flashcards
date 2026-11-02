import { assertEquals } from "jsr:@std/assert@1";

import {
  attemptTimeout,
  CLIENT_TIMEOUT_MS,
  deadlineIn,
  earliest,
  MIN_ATTEMPT_MS,
  remainingMs,
  REQUEST_BUDGET_MS,
} from "./deadline.ts";

/**
 * L'échéance existe pour une seule raison : qu'une requête qui enchaîne plusieurs appels au
 * modèle échoue **elle-même**, avant l'horloge de la plateforme, pour que son `catch` rende ce
 * qu'elle a pris. Ces tests tiennent les trois règles qui le garantissent.
 */

Deno.test("l'échéance d'une requête tient sous l'horloge de la plateforme", () => {
  // 150 secondes, moins de quoi rendre la leçon réservée et répondre.
  assertEquals(REQUEST_BUDGET_MS <= 140_000, true);
  assertEquals(deadlineIn(REQUEST_BUDGET_MS, 1_000), 1_000 + REQUEST_BUDGET_MS);
});

Deno.test("l'échéance d'une requête tient sous l'attente des clients", () => {
  // Le site et l'app raccrochent à 120 s : la réponse doit partir avant, avec de quoi rendre
  // la leçon réservée, répondre, et laisser au site le temps d'écrire le cours.
  assertEquals(CLIENT_TIMEOUT_MS, 120_000);
  assertEquals(REQUEST_BUDGET_MS <= CLIENT_TIMEOUT_MS - 10_000, true);
  // Pas au point d'empêcher un plan et son second essai : chacun prend dix à quarante secondes.
  assertEquals(REQUEST_BUDGET_MS >= 90_000, true);
});

Deno.test("un essai prend le plus court de son délai et du temps qui reste", () => {
  const now = 1_000_000;
  // Au début de la requête : son propre délai.
  assertEquals(attemptTimeout(100_000, now + REQUEST_BUDGET_MS, now), 100_000);
  // Après la passe visuelle et un premier plan : ce qui reste, pas deux minutes de plus.
  assertEquals(attemptTimeout(120_000, now + 40_000, now), 40_000);
  // Sans échéance, rien ne change.
  assertEquals(attemptTimeout(120_000, undefined, now), 120_000);
});

Deno.test("un essai qui n'a plus le temps d'aboutir n'est pas lancé", () => {
  const now = 1_000_000;
  assertEquals(attemptTimeout(120_000, now + MIN_ATTEMPT_MS - 1, now), null);
  assertEquals(attemptTimeout(120_000, now - 10, now), null);
  assertEquals(remainingMs(now - 10, now), 0);
  assertEquals(remainingMs(undefined, now), Number.POSITIVE_INFINITY);
});

Deno.test("la plus proche de deux échéances l'emporte", () => {
  assertEquals(earliest(10, 20), 10);
  assertEquals(earliest(undefined, 20), 20);
  assertEquals(earliest(10, undefined), 10);
  assertEquals(earliest(undefined, undefined), undefined);
});
