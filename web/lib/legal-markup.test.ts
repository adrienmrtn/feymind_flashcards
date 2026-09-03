import { describe, expect, it } from "vitest";

import { CATALOGS, fr } from "./i18n/catalogs";
import { lookup, type MessageTree } from "./i18n/format";
import { UI_LOCALES } from "./i18n/locales";
import { makeTranslator } from "./i18n/translate";
import { LEGAL_CONTACT, LEGAL_EDITOR, LEGAL_IOS_BUNDLE } from "./legal";

describe("les pages de droit", () => {
  it("gardent les liens comme des jetons que t() n'avale pas", () => {
    for (const locale of UI_LOCALES) {
      const tree = CATALOGS[locale] as unknown as MessageTree;
      const intro = lookup(tree, "legal.privacy.intro1");
      const contact = lookup(tree, "legal.privacy.intro2");
      expect(intro, locale).toContain("[[site]]");
      expect(intro, locale).not.toContain("{site}");
      expect(contact, locale).toContain("[[contact]]");
      expect(contact, locale).toContain("{editor}");
    }
  });

  it("pose l'éditeur et le bundle, et laisse le lien e-mail au rendu", () => {
    const t = makeTranslator("fr", fr as unknown as MessageTree, fr as unknown as MessageTree);
    const filled = t("legal.privacy.intro2", {
      editor: LEGAL_EDITOR,
      bundle: LEGAL_IOS_BUNDLE,
    });
    expect(filled).toContain(LEGAL_EDITOR);
    expect(filled).toContain("[[contact]]");
    expect(filled).not.toContain(LEGAL_CONTACT);
  });
});
