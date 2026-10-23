import { describe, expect, it } from "vitest";

import { catalogFor, en } from "@/lib/i18n/catalogs";
import type { MessageTree } from "@/lib/i18n/format";
import type { UiLocale } from "@/lib/i18n/locales";
import { makeTranslator } from "@/lib/i18n/translate";

import { callbackFailureMessage, oauthFailureMessage } from "./oauth";

function translatorFor(locale: UiLocale) {
  return makeTranslator(locale, catalogFor(locale) as unknown as MessageTree, en as unknown as MessageTree);
}

const fr = translatorFor("fr");
const tr = translatorFor("tr");

describe("oauthFailureMessage", () => {
  it("laisse passer un refus Google tel quel", () => {
    expect(oauthFailureMessage(fr, "google", "popup_closed")).toBe("popup_closed");
  });

  it("traduit un Apple mal branché", () => {
    expect(oauthFailureMessage(fr, "apple", "Unacceptable audience in id_token")).toMatch(
      /lien par courriel/,
    );
  });

  it("traduit un secret OAuth Apple manquant", () => {
    expect(
      oauthFailureMessage(
        fr,
        "apple",
        '{"code":400,"error_code":"validation_failed","msg":"Unsupported provider: missing OAuth secret"}',
      ),
    ).toMatch(/secret OAuth manquant/);
  });
});

describe("callbackFailureMessage", () => {
  it("ne met plus un échec Google sur le dos d'Apple", () => {
    expect(callbackFailureMessage(fr, null, "access_denied")).toBe("access_denied");
    expect(callbackFailureMessage(fr, "google", "redirect_uri_mismatch")).toBe("redirect_uri_mismatch");
  });

  it("traduit un lien ouvert dans un autre navigateur", () => {
    expect(
      callbackFailureMessage(fr, null, "invalid request: both auth code and code verifier should be non-empty"),
    ).toMatch(/même navigateur|navigateur où/);
  });

  it("reconnaît encore un Apple mal branché sans fournisseur", () => {
    expect(callbackFailureMessage(fr, null, "Unacceptable audience in id_token")).toMatch(/lien par courriel/);
  });
});

describe("messages d'échec traduits", () => {
  it("parlent la langue de la page, pas le français pour tout le monde", () => {
    const apple = oauthFailureMessage(tr, "apple", "Unacceptable audience in id_token");
    expect(apple).not.toMatch(/courriel/);
    expect(apple).toBe(tr("app.errors.appleNotWired"));
    expect(callbackFailureMessage(tr, null, "code verifier missing")).toBe(tr("app.errors.linkOtherBrowser"));
  });
});
