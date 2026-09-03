import { describe, expect, it } from "vitest";

import { APP_STORE_REVIEW_EMAIL, isAppStoreReviewEmail } from "./app-store-review";

describe("isAppStoreReviewEmail", () => {
  it("reconnaît l'adresse d'Apple, sans tenir compte de la casse", () => {
    expect(isAppStoreReviewEmail(APP_STORE_REVIEW_EMAIL)).toBe(true);
    expect(isAppStoreReviewEmail("  Review@Apple.com  ")).toBe(true);
    expect(isAppStoreReviewEmail("review@icloud.com")).toBe(false);
    expect(isAppStoreReviewEmail("eleve@micabo.app")).toBe(false);
    expect(isAppStoreReviewEmail(null)).toBe(false);
    expect(isAppStoreReviewEmail("")).toBe(false);
  });
});
