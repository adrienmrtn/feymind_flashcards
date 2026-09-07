import { describe, expect, it } from "vitest";

import { APP_STORE_REVIEW_EMAIL, isAppStoreReviewEmail } from "./app-store-review";

describe("isAppStoreReviewEmail", () => {
  it("reconnaît l'adresse d'Apple, sans tenir compte de la casse", () => {
    expect(isAppStoreReviewEmail(APP_STORE_REVIEW_EMAIL)).toBe(true);
    expect(isAppStoreReviewEmail("  Review@Apple.com  ")).toBe(true);
  });

  it("reconnaît les variantes qu'un relecteur invente, pour qu'aucun lien ne parte", () => {
    // `review2@apple.com` a demandé un lien le 5 septembre, et il a rebondi.
    expect(isAppStoreReviewEmail("review2@apple.com")).toBe(true);
    expect(isAppStoreReviewEmail("appreview@apple.com")).toBe(true);
    expect(isAppStoreReviewEmail("app.review@apple.com")).toBe(true);
    expect(isAppStoreReviewEmail("REVIEW-3@APPLE.COM")).toBe(true);
  });

  it("s'arrête au domaine d'Apple", () => {
    expect(isAppStoreReviewEmail("review@icloud.com")).toBe(false);
    expect(isAppStoreReviewEmail("review@apple.com.attaquant.fr")).toBe(false);
    expect(isAppStoreReviewEmail("review@notapple.com")).toBe(false);
    expect(isAppStoreReviewEmail("eleve@micabo.app")).toBe(false);
    expect(isAppStoreReviewEmail("apple.com")).toBe(false);
    expect(isAppStoreReviewEmail("@apple.com")).toBe(false);
    expect(isAppStoreReviewEmail(null)).toBe(false);
    expect(isAppStoreReviewEmail("")).toBe(false);
  });
});
