import { describe, expect, it } from "vitest";

import * as review from "./app-store-review";
import { APP_STORE_REVIEW_EMAIL, isAppStoreReviewEmail, isAppleAddress } from "./app-store-review";

describe("isAppStoreReviewEmail", () => {
  it("reconnaît l'adresse des notes, sans tenir compte de la casse", () => {
    expect(isAppStoreReviewEmail(APP_STORE_REVIEW_EMAIL)).toBe(true);
    expect(isAppStoreReviewEmail("  Review@Apple.com  ")).toBe(true);
  });

  it("n'ouvre pas le compte partagé à une variante", () => {
    expect(isAppStoreReviewEmail("review2@apple.com")).toBe(false);
    expect(isAppStoreReviewEmail("appreview@apple.com")).toBe(false);
    expect(isAppStoreReviewEmail("review@apple.com.attaquant.fr")).toBe(false);
    expect(isAppStoreReviewEmail(null)).toBe(false);
  });
});

describe("isAppleAddress", () => {
  it("reconnaît les variantes qu'un relecteur invente, pour qu'aucun lien ne parte", () => {
    // `review2@apple.com` a demandé un lien le 5 septembre, et il a rebondi.
    expect(isAppleAddress("review2@apple.com")).toBe(true);
    expect(isAppleAddress("app.review@apple.com")).toBe(true);
    expect(isAppleAddress("REVIEW-3@APPLE.COM")).toBe(true);
  });

  it("s'arrête au domaine d'Apple", () => {
    expect(isAppleAddress("review@icloud.com")).toBe(false);
    expect(isAppleAddress("review@apple.com.attaquant.fr")).toBe(false);
    expect(isAppleAddress("review@notapple.com")).toBe(false);
    expect(isAppleAddress("eleve@micabo.app")).toBe(false);
    expect(isAppleAddress("apple.com")).toBe(false);
    expect(isAppleAddress("@apple.com")).toBe(false);
    expect(isAppleAddress(null)).toBe(false);
    expect(isAppleAddress("")).toBe(false);
  });
});

describe("le module partagé avec le navigateur", () => {
  it("ne porte aucun mot de passe", () => {
    // Le mot de passe se lit côté serveur (`APP_STORE_REVIEW_PASSWORD`) : un export de plus
    // ici repartirait dans le paquet JavaScript de chaque page de connexion.
    expect(Object.keys(review).sort()).toEqual([
      "APP_STORE_REVIEW_EMAIL",
      "isAppStoreReviewEmail",
      "isAppleAddress",
    ]);
  });
});
