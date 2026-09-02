import { readFileSync } from "node:fs";
import { resolve } from "node:path";

import { describe, expect, it } from "vitest";

import { LEGAL_CONTACT } from "./legal";
import {
  canReadInbox,
  cleanFeedbackMessage,
  FEEDBACK_MAX,
  feedbackSubject,
  isFeedbackKind,
} from "./feedback";

const mail = readFileSync(resolve(__dirname, "../../Micabo/Services/MicaboMail.swift"), "utf8");

describe("feedback", () => {
  it("réserve la boîte à team@micabo.app", () => {
    expect(LEGAL_CONTACT).toBe("team@micabo.app");
    expect(canReadInbox("team@micabo.app")).toBe(true);
    expect(canReadInbox("TEAM@micabo.app")).toBe(true);
    expect(canReadInbox(" autre@micabo.app ")).toBe(false);
    expect(canReadInbox(null)).toBe(false);
  });

  it("refuse un message vide ou trop long", () => {
    expect(cleanFeedbackMessage("   ")).toBeNull();
    expect(cleanFeedbackMessage("ok")).toBe("ok");
    expect(cleanFeedbackMessage("x".repeat(FEEDBACK_MAX + 1))).toBeNull();
  });

  it("garde les mêmes kinds et sujets que l'iPhone", () => {
    expect(isFeedbackKind("bug")).toBe(true);
    expect(isFeedbackKind("idea")).toBe(true);
    expect(isFeedbackKind("other")).toBe(false);
    expect(mail).toContain(`static let team = "${LEGAL_CONTACT}"`);
    expect(mail).toContain(`"${feedbackSubject("bug")}"`);
    expect(mail).toContain(`"${feedbackSubject("idea")}"`);
  });
});
