import { LEGAL_CONTACT } from "./legal";

/** Un retour part chez `LEGAL_CONTACT`. Le même sujet des deux côtés. */
export type FeedbackKind = "bug" | "idea";

export function feedbackSubject(kind: FeedbackKind): string {
  return kind === "bug" ? "Bug — Micabo" : "Idée — Micabo";
}

export function feedbackMailto(kind: FeedbackKind, message: string): string {
  const body = message.trim();
  return `mailto:${LEGAL_CONTACT}?subject=${encodeURIComponent(feedbackSubject(kind))}&body=${encodeURIComponent(body)}`;
}
