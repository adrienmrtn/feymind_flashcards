import { MIKA_ALLOWANCE } from "./allowance";

/**
 * **Mika, dans la leçon : la porte et les bornes.** Jumeau de `MikaQuota` et `MikaLimits`
 * côté Swift ; les nombres sont ceux du serveur (`supabase/functions/_shared/mika.ts`).
 *
 * Une question offerte, puis Pro ; pour un abonné, un plafond par jour qu'on ne voit pas tant
 * qu'on ne l'atteint pas. La question offerte ne se consomme qu'une fois la réponse arrivée :
 * une panne de réseau ne doit pas brûler la seule question de quelqu'un.
 */

export const MIKA_LIMITS = {
  /** Les derniers tours envoyés au modèle. */
  turns: 8,
  /** La longueur d'un message. */
  messageCharacters: 1_500,
  /** La longueur du document joint. */
  attachmentCharacters: 16_000,
} as const;

export type MikaRole = "user" | "mika";

export interface MikaTurn {
  role: MikaRole;
  text: string;
}

export type MikaGate = "allowed" | "paywall" | "dailyCapReached";

export function mikaGate(state: { isPro: boolean; freeQuestionUsed: boolean; askedToday: number }): MikaGate {
  if (state.isPro) {
    return state.askedToday < MIKA_ALLOWANCE.proMessagesPerDay ? "allowed" : "dailyCapReached";
  }
  return !state.freeQuestionUsed && MIKA_ALLOWANCE.freeQuestions > 0 ? "allowed" : "paywall";
}

/** Les derniers tours, chacun borné : ce qui part au serveur. */
export function mikaTurns(messages: readonly MikaTurn[]): MikaTurn[] {
  return messages
    .slice(-MIKA_LIMITS.turns)
    .map((turn) => ({ role: turn.role, text: turn.text.slice(0, MIKA_LIMITS.messageCharacters) }));
}

/** Le jour, dans le calendrier de l'élève : le plafond se remet à minuit chez lui. */
export function dayStamp(now = new Date()): string {
  return `${now.getFullYear()}-${now.getMonth() + 1}-${now.getDate()}`;
}
