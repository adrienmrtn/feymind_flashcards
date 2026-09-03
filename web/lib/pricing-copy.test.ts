import { pricing } from "@micabo/core";
import { describe, expect, it } from "vitest";

import { tr } from "./i18n/catalogs";
import { fr } from "./i18n/catalogs/fr";
import type { MessageTree } from "./i18n/format";
import { makeTranslator } from "./i18n/translate";
import {
  planRenewalCopy,
  planTitle,
  presentmentFor,
  trialBadge,
} from "./pricing-copy";

const tFr = makeTranslator("fr", fr as unknown as MessageTree, fr as unknown as MessageTree);
const tTr = makeTranslator("tr", tr as unknown as MessageTree, fr as unknown as MessageTree);

describe("pricing-copy", () => {
  it("traduit les cartes d'offre", () => {
    expect(planTitle(tFr, pricing.YEARLY)).toBe("Annuel");
    expect(planTitle(tTr, pricing.YEARLY)).toBe("Yıllık");
    expect(planTitle(tTr, pricing.WEEKLY)).toBe("Haftalık");
    expect(trialBadge(tTr, pricing.YEARLY)).toBe("3 gün ücretsiz");
    expect(trialBadge(tFr, pricing.WEEKLY)).toBeNull();
    expect(planRenewalCopy(tTr, pricing.WEEKLY, "TRY")).toBe("İstediğin an iptal");
    expect(planRenewalCopy(tFr, pricing.YEARLY, "EUR")).toMatch(/69,99/);
  });

  it("montre la livre quand la langue est le turc", () => {
    expect(presentmentFor("tr")).toBe("TRY");
    expect(presentmentFor("fr")).toBe("EUR");
    expect(presentmentFor("fr", "tr")).toBe("TRY");
    expect(presentmentFor("tr-TR", "fr")).toBe("TRY");
    expect(planRenewalCopy(tTr, pricing.YEARLY, "TRY")).toMatch(/₺|TRY|3.?899/);
  });
});
