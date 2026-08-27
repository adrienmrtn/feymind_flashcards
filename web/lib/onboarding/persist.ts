import { saveOnboarding, type SaveResult } from "@/lib/actions/onboarding";

import type { Answers } from "./store";

/**
 * Le pont entre les réponses gardées sur l'appareil et la ligne `profiles`.
 *
 * Le parcours n'écrit plus en base à chaque écran : il n'y a pas encore de session. Ce module
 * est le seul endroit qui **déverse** — à la connexion, au retour d'un fournisseur, et à
 * l'ouverture de l'app si les réponses n'avaient pas encore traversé.
 */

export const ANSWERS_KEY = "micabo.onboarding.answers";
export const PAYWALL_PENDING_KEY = "micabo.paywall.pending";
export const PAYWALL_DISMISSED_KEY = "micabo.paywall.dismissed";

export function readStoredAnswers(): Answers | null {
  if (typeof window === "undefined") return null;
  try {
    const stored = window.localStorage.getItem(ANSWERS_KEY);
    if (!stored) return null;
    return JSON.parse(stored) as Answers;
  } catch {
    return null;
  }
}

export function hasStoredAnswers(): boolean {
  const answers = readStoredAnswers();
  if (!answers) return false;
  return Boolean(
    answers.country ||
      answers.studyLevel ||
      (answers.subjects && answers.subjects.length > 0) ||
      answers.examDate ||
      answers.institutionId ||
      answers.institutionName,
  );
}

export function clearStoredAnswers(): void {
  try {
    window.localStorage.removeItem(ANSWERS_KEY);
  } catch {
    // Un stockage refusé ne doit pas empêcher d'entrer dans l'app.
  }
}

/**
 * Oublie ce que cet appareil savait du compte.
 *
 * Sans ça, recréer un compte avec la même adresse reposerait le parcours d'avant
 * (pays, matières, examen) et ce ne serait plus un compte neuf.
 */
export function forgetLocalAccount(): void {
  clearStoredAnswers();
  try {
    window.localStorage.removeItem(PAYWALL_PENDING_KEY);
    window.localStorage.removeItem(PAYWALL_DISMISSED_KEY);
    window.sessionStorage.removeItem("micabo.app.openCourse");
  } catch {
    // Voir plus haut.
  }
}

export function markPaywallPending(): void {
  try {
    window.localStorage.setItem(PAYWALL_PENDING_KEY, "1");
  } catch {
    // Voir plus haut.
  }
}

export function isPaywallPending(): boolean {
  try {
    return window.localStorage.getItem(PAYWALL_PENDING_KEY) === "1";
  } catch {
    return false;
  }
}

export function consumePaywallPending(): boolean {
  try {
    const pending = window.localStorage.getItem(PAYWALL_PENDING_KEY) === "1";
    if (pending) window.localStorage.removeItem(PAYWALL_PENDING_KEY);
    return pending;
  } catch {
    return false;
  }
}

export function isPaywallDismissed(): boolean {
  try {
    return window.localStorage.getItem(PAYWALL_DISMISSED_KEY) === "1";
  } catch {
    return false;
  }
}

export function markPaywallDismissed(): void {
  try {
    window.localStorage.setItem(PAYWALL_DISMISSED_KEY, "1");
    window.localStorage.removeItem(PAYWALL_PENDING_KEY);
  } catch {
    // Voir plus haut.
  }
}

/**
 * Écrit les réponses en base si une session existe, et prépare le paywall.
 *
 * Renvoie `anonymous` sans rien perdre : les réponses restent sur l'appareil.
 */
export async function persistStoredAnswers(): Promise<SaveResult> {
  const answers = readStoredAnswers();
  if (!answers || !hasStoredAnswers()) {
    return { status: "anonymous" };
  }

  const result = await saveOnboarding({
    country: answers.country,
    studyLevel: answers.studyLevel,
    subjects: answers.subjects,
    institutionId: answers.institutionId,
    institutionName: answers.institutionName,
    examDate: answers.examDate,
    examName: answers.examName,
  });

  if (result.status === "saved") {
    clearStoredAnswers();
    markPaywallPending();
  }

  return result;
}
