import { pricing } from "@micabo/core";
import { describe, expect, it } from "vitest";

import { tr } from "./i18n/catalogs";
import { fr } from "./i18n/catalogs/fr";
import type { MessageTree } from "./i18n/format";
import { makeTranslator } from "./i18n/translate";
import {
  planCaption,
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
    expect(trialBadge(tFr, pricing.WEEKLY)).toBe("3 jours gratuits");
    expect(trialBadge(tFr, pricing.DISCOUNT_YEARLY)).toBeNull();
    expect(planRenewalCopy(tTr, pricing.WEEKLY, presentmentFor("tr", "TR"))).toBe("İstediğin an iptal");
    expect(planRenewalCopy(tFr, pricing.YEARLY, presentmentFor("fr", "FR"))).toMatch(/49,99\u00a0€/);
  });

  it("montre les prix du pays, écrits dans la langue du site", () => {
    expect(presentmentFor("tr", "tr").prices.currency).toBe("TRY");
    expect(presentmentFor("fr").prices.currency).toBe("EUR");
    // Le pays décide de la devise, pas la langue : un Turc en interface française paie en
    // livres, un Français en interface turque en euros.
    expect(presentmentFor("fr", "tr").prices.currency).toBe("TRY");
    expect(presentmentFor("tr", "fr").prices.currency).toBe("EUR");
    expect(planRenewalCopy(tTr, pricing.YEARLY, presentmentFor("tr", "tr"))).toMatch(/1.?499,99/);
    expect(planRenewalCopy(tFr, pricing.YEARLY, presentmentFor("fr", "es"))).toMatch(/39,99\u00a0€/);
    expect(planCaption(tFr, pricing.YEARLY, presentmentFor("fr", "es"))).toMatch(/^3,33\u00a0€/);
  });
});
