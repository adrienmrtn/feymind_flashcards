import { describe, expect, it } from "vitest";

import { callbackFailureMessage, oauthFailureMessage } from "./oauth";

describe("oauthFailureMessage", () => {
  it("laisse passer un refus Google tel quel", () => {
    expect(oauthFailureMessage("google", "popup_closed")).toBe("popup_closed");
  });

  it("traduit un Apple mal branché", () => {
    expect(oauthFailureMessage("apple", "Unacceptable audience in id_token")).toMatch(
      /lien par courriel/,
    );
  });

  it("traduit un secret OAuth Apple manquant", () => {
    expect(
      oauthFailureMessage(
        "apple",
        '{"code":400,"error_code":"validation_failed","msg":"Unsupported provider: missing OAuth secret"}',
      ),
    ).toMatch(/secret OAuth manquant/);
  });
});

describe("callbackFailureMessage", () => {
  it("ne met plus un échec Google sur le dos d'Apple", () => {
    expect(callbackFailureMessage(null, "access_denied")).toBe("access_denied");
    expect(callbackFailureMessage("google", "redirect_uri_mismatch")).toBe("redirect_uri_mismatch");
  });

  it("traduit un lien ouvert dans un autre navigateur", () => {
    expect(
      callbackFailureMessage(null, "invalid request: both auth code and code verifier should be non-empty"),
    ).toMatch(/même navigateur|navigateur où/);
  });

  it("reconnaît encore un Apple mal branché sans fournisseur", () => {
    expect(callbackFailureMessage(null, "Unacceptable audience in id_token")).toMatch(/lien par courriel/);
  });
});
