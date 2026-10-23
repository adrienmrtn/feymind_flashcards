/**
 * **Le test qui empêche les deux clients de dire deux choses.**
 *
 * Le gratuit existe deux fois : `src/entitlement.ts` et `src/lesson/allowance.ts` pour le
 * web, `LessonAllowance`, `MikaAllowance` et `ProAccess` pour l'app. Les tests de chacun
 * vérifient déjà leurs propres nombres — mais ils les vérifient **séparément**, donc rien
 * n'empêchait le web d'offrir deux leçons et l'iPhone une seule. Le symptôme n'a rien
 * d'évident : personne ne signale un bug qui lui donne plus.
 *
 * Ici on relit le Swift et on compare. Une divergence tombe au prochain `pnpm test`.
 */

import { readdirSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

import * as discount from "../src/discount";
import { ASSUME_PRO_WITHOUT_ROW, ENTITLEMENT_ID, FREE_LESSON_TIER, LIFETIME_PRO_EMAILS } from "../src/entitlement";
import { EXTRA_ALLOWANCE, MIKA_ALLOWANCE, hasUsedFreeLesson, isImportSource, lessonGate } from "../src/lesson/allowance";
import { MAX_COMPOSER_CHARACTERS, MAX_COMPOSER_IMAGES, MAX_SUPPORTS } from "../src/lesson/composer";
import { MIKA_LIMITS } from "../src/lesson/mika";
import {
  BASE_PRICES,
  DISCOUNT_YEARLY,
  FREE_TRIAL_DAYS,
  REGIONAL_PRICES,
  WEEKLY,
  YEARLY,
  discountSavingsPercent,
  presentmentFor,
  regionalPricesFor,
} from "../src/pricing";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "../../../..");

const swift = (path: string) => readFileSync(resolve(repoRoot, "Micabo", path), "utf8");
const proAccess = swift("Services/ProAccess.swift");
const composer = swift("Features/Home/LessonComposer.swift");
const purchases = swift("Features/Paywall/PaywallPurchases.swift");
const catalog = swift("Features/Paywall/PaywallCatalog.swift");
const discountOffer = swift("Features/Paywall/DiscountOffer.swift");

/** La valeur d'un `static let` Swift, telle qu'elle est écrite. */
function swiftConstant(source: string, name: string): string {
  const found = source.match(new RegExp(`static let ${name}[^=\\n]*=\\s*([^\\n]+)`));
  if (!found?.[1]) throw new Error(`\`${name}\` introuvable dans le Swift`);
  return found[1].trim().replace(/\s*\/\/.*$/, "");
}

/** Un nombre Swift, avec ses séparateurs de milliers (`60_000`). */
function swiftNumber(source: string, name: string): number {
  return Number(swiftConstant(source, name).replace(/_/g, ""));
}

describe("le gratuit, des deux côtés", () => {
  it("traite pareil quelqu'un sans ligne dans entitlements", () => {
    // **La divergence la plus coûteuse du produit.** À `true` d'un côté et `false` de
    // l'autre, le site fait payer et le téléphone offre.
    expect(swiftConstant(proAccess, "assumeProWithoutRow")).toBe(String(ASSUME_PRO_WITHOUT_ROW));
  });

  it("offre une leçon, depuis un sujet ou un texte collé, et pas depuis un import", () => {
    // `LessonAllowance.gate` : Pro passe ; un import ouvre le paywall ; sinon la première
    // leçon est offerte. Les cours de démonstration, de la bibliothèque et les paquets ne
    // comptent pas, comme côté serveur (`begin_lesson`).
    const allowance = composer.slice(composer.indexOf("enum LessonAllowance"));
    expect(allowance).toContain("if isPro { return nil }");
    expect(allowance).toContain("if source.isImport { return .generateCourse }");
    expect(allowance).toContain("![.sample, .library, .deck].contains(course.source)");

    expect(FREE_LESSON_TIER.lessons).toBe(1);
    expect(FREE_LESSON_TIER.importsAllowed).toBe(false);
    expect(lessonGate({ isPro: true, source: "pdf", courses: [] })).toBeNull();
    expect(lessonGate({ isPro: false, source: "pdf", courses: [] })).toBe("import_pro");
    expect(lessonGate({ isPro: false, source: "topic", courses: [] })).toBeNull();
    expect(lessonGate({ isPro: false, source: "text", courses: [{ source: "text", isFromLibrary: false }] })).toBe("free_limit");
    for (const source of ["sample", "library", "deck"]) {
      expect(hasUsedFreeLesson([{ source, isFromLibrary: false }]), source).toBe(false);
    }
    expect(hasUsedFreeLesson([{ source: "pdf", isFromLibrary: true }])).toBe(false);
    expect(isImportSource("topic")).toBe(false);
    expect(isImportSource("text")).toBe(false);
    for (const source of ["pdf", "photo", "audio", "youtube", "docx", "mixed"] as const) {
      expect(isImportSource(source), source).toBe(true);
    }
  });

  it("laisse Mika répondre au même nombre de questions", () => {
    // Une question offerte, puis un plafond par jour pour Pro : le serveur tient les mêmes
    // nombres (`_shared/mika.ts`), et chaque client refuse avant l'appel.
    expect(swiftNumber(proAccess, "freeQuestions")).toBe(MIKA_ALLOWANCE.freeQuestions);
    expect(swiftNumber(proAccess, "proMessagesPerDay")).toBe(MIKA_ALLOWANCE.proMessagesPerDay);
    expect(FREE_LESSON_TIER.mikaQuestions).toBe(MIKA_ALLOWANCE.freeQuestions);
    expect(MIKA_LIMITS.turns).toBeGreaterThan(0);
  });

  it("offre un entraînement et un examen blanc, puis Pro", () => {
    // `begin_extra` tient la porte (migration `lesson_extras`) ; le site l'annonce.
    expect(FREE_LESSON_TIER.practiceSets).toBe(EXTRA_ALLOWANCE.freePractice);
    expect(FREE_LESSON_TIER.mockExams).toBe(EXTRA_ALLOWANCE.freeExams);
    expect(EXTRA_ALLOWANCE.freePractice).toBe(1);
    expect(EXTRA_ALLOWANCE.freeExams).toBe(1);
  });

  it("accepte autant de supports, de caractères et d'images que l'app", () => {
    // La barre de Home : cinq supports, soixante mille caractères, six images. Un site qui
    // accepterait un sixième PDF enverrait une demande que le serveur coupe sans le dire.
    expect(swiftNumber(composer, "maximumSupports")).toBe(MAX_SUPPORTS);
    expect(swiftNumber(composer, "maximumCharacters")).toBe(MAX_COMPOSER_CHARACTERS);
    expect(swiftNumber(composer, "maximumImages")).toBe(MAX_COMPOSER_IMAGES);
  });

  it("lit le même entitlement RevenueCat", () => {
    // Trois endroits nomment cette chaîne : ici, le Swift, et le webhook. Un nom qui
    // diverge donne un abonné que personne ne reconnaît.
    expect(swiftConstant(purchases, "id")).toBe(`"${ENTITLEMENT_ID}"`);
  });

  it("offre Pro à vie aux mêmes adresses développeur", () => {
    for (const email of LIFETIME_PRO_EMAILS) {
      expect(proAccess).toContain(`"${email}"`);
    }
  });

  it("et le serveur les reconnaît aussi, dans la porte SQL", () => {
    // Sans elle, l'app ouvrait Pro et `begin_lesson` répondait `import_pro`. La dernière
    // définition de `is_lifetime_pro` doit nommer chaque adresse des clients, et rien de plus.
    const migrations = resolve(repoRoot, "supabase/migrations");
    const latest = readdirSync(migrations)
      .filter((name) => name.endsWith(".sql"))
      .sort()
      .map((name) => readFileSync(resolve(migrations, name), "utf8"))
      .filter((sql) => sql.includes("function public.is_lifetime_pro"))
      .at(-1);
    expect(latest).toBeDefined();
    const listed = [...(latest ?? "").matchAll(/'([^']+@[^']+)'/g)].map((match) => match[1]);
    expect([...listed].sort()).toEqual([...LIFETIME_PRO_EMAILS].sort());
  });
});

describe("le branchement RevenueCat de l'app", () => {
  it("n'ouvre Pro que sur un achat confirmé", () => {
    // `unavailable` veut dire « je n'ai pas pu vendre ». L'accepter comme un achat ferait
    // de chaque panne de réseau un abonnement gratuit — c'est ce que faisaient les deux
    // paywalls tant qu'aucune boutique n'existait. Le paywall de fin de session est parti
    // avec l'onglet Réviser (refonte « parcours ») : il reste celui de l'app.
    for (const file of ["Features/Paywall/PaywallFlowView.swift"]) {
      expect(swift(file)).not.toContain("case .purchased, .unavailable:");
    }
  });

  it("compile sans le paquet, et s'allume avec", () => {
    // Le paquet s'ajoute dans Xcode. Sans ce garde, le dépôt ne compilerait plus entre
    // l'écriture de ce fichier et l'ouverture de Xcode.
    expect(purchases).toContain("#if canImport(RevenueCat)");
  });

  it("identifie par l'auth.users.id de Supabase, jamais un anonyme", () => {
    // C'est **la** ligne du droit multiplateforme : un achat parti sous un
    // `$RCAnonymousID` se fait refuser par le webhook (422).
    expect(purchases).toContain("Purchases.shared.logIn(wanted)");
    expect(purchases).toContain("uuidString.lowercased()");
  });
});

describe("l'offre cadeau, des deux côtés", () => {
  it("compte les mêmes appuis et la même durée d'offre", () => {
    // Une pastille qui dirait 12 h sur le site et 24 h sur le téléphone ferait douter du
    // prix lui-même : ce sont les nombres d'une promesse, pas d'un réglage.
    expect(swiftConstant(discountOffer, "taps")).toBe(String(discount.taps));
    expect(swiftConstant(discountOffer, "windowSeconds")).toBe(String(discount.windowSeconds));
    expect(swiftConstant(discountOffer, "restSeconds")).toBe(String(discount.restSeconds));
  });

  it("ne pose plus de minuterie sur le paywall, ni d'un côté ni de l'autre", () => {
    // Le décompte au centième a quitté les deux paywalls : posé sur un prix, il demande de
    // décider vite plutôt que de décider. Le garde tient des deux côtés parce qu'un
    // formateur qui survit finit par retrouver une vue.
    //
    // La languette, elle, garde son décompte à la seconde (`countdown`) : elle ne vend
    // rien, elle rappelle que la fenêtre court encore.
    expect(discountOffer).not.toContain("preciseCountdown");
    expect(discountOffer).not.toContain('"%02d : %02d : %02d . %02d"');
    expect(discount).not.toHaveProperty("preciseCountdown");
    expect(discount).not.toHaveProperty("remainingMillis");
  });

  it("annonce le prix prélevé, et pas un mensuel, sur l'offre cadeau", () => {
    // Le cadeau disait « 3,30 € / mois » avec l'annuel juste dessous : deux chiffres pour
    // une seule somme, dont celui qu'on retenait n'était pas celui qui part. Chaque client
    // écrit sa somme annuelle, et rien d'autre.
    //
    // Les deux clients affichent la même somme : 29,99 € en France, −40 % sur l'annuel.
    expect(catalog).toContain("price: 29.99");
    expect(DISCOUNT_YEARLY.price).toBe(29.99);
    expect(discountOffer).not.toContain("monthlyPrice");
    expect(DISCOUNT_YEARLY).not.toHaveProperty("monthlyPrice");
  });

  it("affiche la grille de l'app, prix et essais compris", () => {
    // Le site annonçait 69,99 € / 7,99 € / 39,99 € pendant que l'app vendait 49,99 € /
    // 4,99 € / 29,99 €. Chaque offre web doit dire le prix et l'essai du `PaywallCatalog`.
    const swiftPlan = (name: string) => {
      const block = catalog.match(new RegExp(`static let ${name} = PaywallPlan\\(([\\s\\S]*?)\\n    \\)`))?.[1] ?? "";
      const trial = block.match(/trialDays: (\w+)/)?.[1];
      return {
        productId: block.match(/productID: "([^"]+)"/)?.[1],
        price: Number(block.match(/price: ([\d.]+)/)?.[1]),
        trialDays: trial === "freeTrialDays" ? FREE_TRIAL_DAYS : Number(trial),
      };
    };
    for (const [name, plan] of [
      ["yearly", YEARLY],
      ["weekly", WEEKLY],
      ["discount", DISCOUNT_YEARLY],
    ] as const) {
      expect(swiftPlan(name)).toEqual({
        productId: plan.productId,
        price: plan.price,
        trialDays: plan.trialDays,
      });
    }

    // Le repli de l'app est la grille de base du site : la France, et tout pays non nommé.
    expect({ ...BASE_PRICES.amounts, currency: BASE_PRICES.currency }).toEqual({
      yearly: swiftPlan("yearly").price,
      weekly: swiftPlan("weekly").price,
      yearly_discount: swiftPlan("discount").price,
      currency: "EUR",
    });
  });

  it("vend le même produit, sur le même entitlement", () => {
    expect(discountOffer).toContain("PaywallCatalog.discount");
    expect(DISCOUNT_YEARLY.productId).toBe("com.micabo.app.pro.yearly.discount");
  });

  it("fait tomber le cadeau quand un paywall se referme sans achat, sans attendre de cours", () => {
    // Le déclencheur a changé de place des deux côtés : ce n'est plus le premier import mais
    // la croix du paywall (`paywallClosed`). Un seuil de cours qui divergerait ferait offrir
    // le tarif réduit sur le téléphone et pas sur le site, au même compte.
    expect(swiftNumber(discountOffer, "giftAfterCourses")).toBe(discount.giftAfterCourses);
    expect(discountOffer).toContain("static func paywallClosed(");
    expect(discountOffer).toContain('static let pending = "micabo.discount.pending"');
    expect(swift("Features/Paywall/PaywallFlowView.swift")).toContain("DiscountOffer.paywallClosed(");
    expect(discount.shouldPresentGift({ isPaid: false, courseCount: 0, seen: false, startedAt: null, now: 0 })).toBe(true);
    expect(discount.shouldPresentGift({ isPaid: true, courseCount: 0, seen: false, startedAt: null, now: 0 })).toBe(false);
  });

  it("n'ouvre Pro que sur un achat confirmé, comme les autres paywalls", () => {
    const flow = readFileSync(
      resolve(repoRoot, "Micabo/Features/Paywall/DiscountFlowView.swift"),
      "utf8",
    );
    expect(flow).not.toContain("case .purchased, .unavailable:");
  });
});

/**
 * **La grille pays par pays.** `PaywallCatalog.swift` n'écrit que la France : chaque autre
 * pays vient de `store/pricing.json`, que l'action « Grille de prix iOS » pose dans App Store
 * Connect et que `store/grid.test.mjs` relie au Swift. Le site doit dire, pour chaque pays
 * nommé, la devise et les trois montants de cette grille.
 */
describe("les prix pays par pays, des deux côtés", () => {
  type Tier = {
    tier: string;
    label: string;
    rule?: "price" | "usd" | "equalize";
    from?: string;
    territory?: string;
    territories?: string[];
    currency?: string;
    prices?: Record<"weekly" | "yearly" | "discount", string>;
  };
  const grid = JSON.parse(readFileSync(resolve(repoRoot, "store/pricing.json"), "utf8")) as {
    products: Record<"weekly" | "yearly" | "discount", { trial: string | null }>;
    base: Tier;
    tiers: Tier[];
  };

  /** App Store Connect parle ISO alpha-3 ; le site, Vercel et les navigateurs alpha-2. */
  const ALPHA2: Record<string, string> = {
    FRA: "FR", USA: "US", CAN: "CA", AUS: "AU", CHE: "CH", BEL: "BE", LUX: "LU", DEU: "DE",
    AUT: "AT", NLD: "NL", IRL: "IE", FIN: "FI", ESP: "ES", ITA: "IT", PRT: "PT", GRC: "GR",
    SVK: "SK", SVN: "SI", HRV: "HR", EST: "EE", LVA: "LV", LTU: "LT", POL: "PL", CZE: "CZ",
    HUN: "HU", ROU: "RO", BGR: "BG", TUR: "TR", BRA: "BR", MEX: "MX", ARG: "AR", COL: "CO",
    CHL: "CL", PER: "PE", MAR: "MA", DZA: "DZ", TUN: "TN", SEN: "SN", CIV: "CI", EGY: "EG",
    IDN: "ID", PHL: "PH", VNM: "VN", PAK: "PK", NGA: "NG", IND: "IN",
  };
  const alpha2 = (code: string) => {
    const found = ALPHA2[code];
    if (!found) throw new Error(`${code} : pays de store/pricing.json inconnu du test, à ajouter`);
    return found;
  };

  const trialDays = (key: "weekly" | "yearly" | "discount") =>
    grid.products[key].trial === "THREE_DAYS" ? 3 : grid.products[key].trial === null ? 0 : NaN;

  const priced = (territory: string): Tier =>
    territory === grid.base.territory
      ? grid.base
      : grid.tiers.find((tier) => tier.territories?.includes(territory)) ?? grid.base;

  /**
   * Ce que le site doit afficher dans un pays : les montants écrits ; pour un pays aligné sur
   * un équivalent Apple (`equalize`), ceux du pays de référence ; pour un prix en dollars
   * (`usd`), ces dollars-là.
   */
  function expected(territory: string) {
    let tier = priced(territory);
    if (tier.rule === "equalize") tier = priced(tier.from!);
    const currency = tier.rule === "usd" ? "USD" : tier.currency!;
    return {
      currency,
      amounts: {
        yearly: Number(tier.prices!.yearly),
        weekly: Number(tier.prices!.weekly),
        yearly_discount: Number(tier.prices!.discount),
      },
    };
  }

  const named = [grid.base.territory!, ...grid.tiers.flatMap((tier) => tier.territories ?? [])];

  it("affiche, dans chaque pays nommé, la devise et les trois prix de l'App Store", () => {
    for (const territory of named) {
      const web = regionalPricesFor(alpha2(territory));
      expect({ currency: web.currency, amounts: web.amounts }, territory).toEqual(expected(territory));
    }
  });

  it("ne nomme pas un pays que la grille ignore, et retombe sur la France ailleurs", () => {
    const webCountries = REGIONAL_PRICES.flatMap((prices) => prices.countries).sort();
    expect(webCountries).toEqual(named.map(alpha2).sort());
    expect(new Set(webCountries).size).toBe(webCountries.length);
    for (const elsewhere of ["JP", "GB", "SE", "DK", "CY", "MT", null]) {
      expect(regionalPricesFor(elsewhere)).toBe(BASE_PRICES);
    }
    expect(expected("XXX")).toEqual({ currency: "EUR", amounts: BASE_PRICES.amounts });
  });

  it("offre l'essai de l'app, et rien au tarif réduit", () => {
    expect(trialDays("yearly")).toBe(FREE_TRIAL_DAYS);
    expect(trialDays("weekly")).toBe(FREE_TRIAL_DAYS);
    expect(trialDays("discount")).toBe(DISCOUNT_YEARLY.trialDays);
    for (const prices of REGIONAL_PRICES) expect(prices.trialDays, prices.label).toBe(FREE_TRIAL_DAYS);
  });

  it("annonce la remise du cadeau calculée sur les prix du pays : −40 % partout", () => {
    // `DiscountOffer.swift` passe par `PaywallCatalog.savings`, sur les prix de la boutique.
    expect(discountOffer).toContain("PaywallCatalog.savings(of: plan, against: reference)");
    for (const prices of REGIONAL_PRICES) {
      expect(discountSavingsPercent(presentmentFor(prices.countries[0])), prices.label).toBe(40);
    }
  });

  it("et Google Play dit pareil, à deux pays près", () => {
    type PlayState = {
      common: { pricing: { territory_prices: Record<string, { amount_micros: number; currency: string }> } };
      store_state: { base_plans: Record<string, { auto_renewing_base_plan_type: { billing_period_duration: string }; offers?: object }> };
    };
    const play = JSON.parse(readFileSync(resolve(repoRoot, "store/play-subscriptions.json"), "utf8")) as {
      desired_states: PlayState[];
    };
    const planOf = (state: PlayState) => {
      const [key, plan] = Object.entries(state.store_state.base_plans)[0]!;
      if (plan.auto_renewing_base_plan_type.billing_period_duration === "P1W") return "weekly";
      return key === "yearly" && plan.offers ? "yearly" : "yearly_discount";
    };
    const diverging = new Set<string>();
    for (const state of play.desired_states) {
      const plan = planOf(state);
      for (const [country, price] of Object.entries(state.common.pricing.territory_prices)) {
        const web = regionalPricesFor(country);
        const same = web.currency === price.currency && web.amounts[plan] === price.amount_micros / 1e6;
        if (!same) diverging.add(country);
      }
    }
    // **Chypre et Malte** sont au palier C sur Play (39,99 €) mais absents de la grille
    // App Store, qui leur vend donc l'équivalent du prix français (49,99 €). Le site suit
    // l'App Store. Toute autre divergence est une erreur de grille.
    expect([...diverging].sort()).toEqual(["CY", "MT"]);
  });
});
