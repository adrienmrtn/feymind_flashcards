import { describe, expect, it } from "vitest";

import { catalogFor, en } from "@/lib/i18n/catalogs";
import type { MessageTree } from "@/lib/i18n/format";
import type { UiLocale } from "@/lib/i18n/locales";
import { makeTranslator } from "@/lib/i18n/translate";

import { callbackFailureMessage, emailLinkFailureMessage, oauthFailureMessage } from "./oauth";

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

describe("emailLinkFailureMessage", () => {
  it("traduit la limite de débit de GoTrue, par code ou par phrase", () => {
    const rate = fr("app.errors.emailRateLimit");
    expect(
      emailLinkFailureMessage(fr, {
        code: "over_email_send_rate_limit",
        message: "Email rate limit exceeded",
        status: 429,
      }),
    ).toBe(rate);
    expect(
      emailLinkFailureMessage(fr, {
        message: "For security purposes, you can only request this after 38 seconds.",
      }),
    ).toBe(rate);
    expect(emailLinkFailureMessage(fr, { message: "Too many requests", status: 429 })).toBe(rate);
    expect(rate).not.toMatch(/security purposes/i);
  });

  it("traduit un lien périmé", () => {
    expect(
      emailLinkFailureMessage(fr, { code: "otp_expired", message: "Email link is invalid or has expired" }),
    ).toBe(fr("app.errors.linkExpired"));
    expect(emailLinkFailureMessage(tr, { message: "Token has expired or is invalid" })).toBe(
      tr("app.errors.linkExpired"),
    );
  });

  it("laisse passer un refus inconnu, et ne rend jamais une chaîne vide", () => {
    expect(emailLinkFailureMessage(fr, { message: "Signups not allowed for otp" })).toBe(
      "Signups not allowed for otp",
    );
    expect(emailLinkFailureMessage(fr, { message: "" })).toBe(fr("app.errors.tryAgain"));
  });

  it("vaut aussi au retour du lien, par `error_code`", () => {
    expect(
      callbackFailureMessage(tr, null, "Email link is invalid or has expired", "otp_expired"),
    ).toBe(tr("app.errors.linkExpired"));
    expect(callbackFailureMessage(fr, null, "access_denied", "otp_expired")).toBe(
      fr("app.errors.linkExpired"),
    );
  });
});
