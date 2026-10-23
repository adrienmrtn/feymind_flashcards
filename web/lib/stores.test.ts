import { describe, expect, it } from "vitest";

import { APP_STORE_LISTING, PLAY_STORE_LISTING, ratingListings, storePlatform } from "@/components/profile/stores";

describe("« Nous noter », dans la bonne boutique", () => {
  const ANDROID = "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0 Mobile Safari/537.36";
  const IPHONE = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1";
  const DESKTOP = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15";

  it("reconnaît Android, l'iPhone, et le reste", () => {
    expect(storePlatform(ANDROID)).toBe("android");
    expect(storePlatform(IPHONE)).toBe("ios");
    expect(storePlatform(DESKTOP)).toBe("other");
    expect(storePlatform(null)).toBe("other");
  });

  it("mène à Google Play sur Android, à l'App Store sur iPhone, aux deux ailleurs", () => {
    expect(ratingListings("android")).toEqual([{ store: "android", href: PLAY_STORE_LISTING }]);
    expect(ratingListings("ios")).toEqual([{ store: "ios", href: APP_STORE_LISTING }]);
    expect(ratingListings("other").map((entry) => entry.store)).toEqual(["ios", "android"]);
  });

  it("n'épingle aucune vitrine de pays", () => {
    expect(APP_STORE_LISTING).toBe("https://apps.apple.com/app/micabo/id6806651497");
    expect(PLAY_STORE_LISTING).toBe("https://play.google.com/store/apps/details?id=com.micabo.app");
  });
});
