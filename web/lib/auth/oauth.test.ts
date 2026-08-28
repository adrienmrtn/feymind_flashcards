import { describe, expect, it } from "vitest";

import { oauthFailureMessage } from "./oauth";

describe("oauthFailureMessage", () => {
  it("laisse passer un refus Google tel quel", () => {
    expect(oauthFailureMessage("google", "popup_closed")).toBe("popup_closed");
  });

  it("traduit un Apple mal branché", () => {
    expect(oauthFailureMessage("apple", "Unacceptable audience in id_token")).toMatch(
      /lien par courriel/,
    );
  });
});
