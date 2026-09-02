import { LEGAL_CONTACT } from "./legal";

/** Un retour : un bug ou une idée. */
export type FeedbackKind = "bug" | "idea";

export const FEEDBACK_MAX = 4000;
export const FEEDBACK_DAILY_CAP = 5;

export function feedbackSubject(kind: FeedbackKind): string {
  return kind === "bug" ? "Bug — Micabo" : "Idée — Micabo";
}

export function isFeedbackKind(value: string): value is FeedbackKind {
  return value === "bug" || value === "idea";
}

export function cleanFeedbackMessage(value: string): string | null {
  const message = value.trim();
  if (message.length < 1 || message.length > FEEDBACK_MAX) return null;
  return message;
}

/** La boîte `/app/retours` : uniquement le compte `team@micabo.app`. */
export function canReadInbox(email: string | null | undefined): boolean {
  return email?.trim().toLowerCase() === LEGAL_CONTACT.toLowerCase();
}

export interface InboxRow {
  id: string;
  kind: FeedbackKind;
  message: string;
  source: "web" | "ios";
  authorLabel: string;
  createdAt: string;
  readAt: string | null;
}
