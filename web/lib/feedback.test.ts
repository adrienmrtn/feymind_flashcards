import { readFileSync } from "node:fs";
import { resolve } from "node:path";

import { describe, expect, it } from "vitest";

import { LEGAL_CONTACT } from "./legal";
import { feedbackMailto, feedbackSubject } from "./feedback";

const mail = readFileSync(resolve(__dirname, "../../Micabo/Services/MicaboMail.swift"), "utf8");

describe("feedbackMailto", () => {
  it("écrit vers team@micabo.app", () => {
    expect(LEGAL_CONTACT).toBe("team@micabo.app");
    const href = feedbackMailto("bug", "La carte ne se retourne pas");
    expect(href.startsWith("mailto:team@micabo.app?")).toBe(true);
    expect(href).toContain("subject=Bug");
    expect(href).toContain(encodeURIComponent("La carte ne se retourne pas"));
  });

  it("prend le même destinataire et les mêmes sujets que l'iPhone", () => {
    expect(mail).toContain(`static let team = "${LEGAL_CONTACT}"`);
    expect(mail).toContain(`"${feedbackSubject("bug")}"`);
    expect(mail).toContain(`"${feedbackSubject("idea")}"`);
  });
});
