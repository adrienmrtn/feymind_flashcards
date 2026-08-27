/**
 * Le verrou du gratuit, et les offres.
 *
 * Les valeurs viennent de `MicaboTests/FreemiumTests.swift` et de
 * `MicaboTests/PaywallTests.swift`. Ces nombres sont les seuls du produit dont une dérive
 * silencieuse ne se verrait sur **aucun écran** : une fiche coupée à la moitié au lieu des sept
 * dixièmes reste une fiche coupée, et une session qui s'arrête à la quatrième carte reste une
 * session qui s'arrête. C'est le genre de bug qu'on ne découvre qu'en lisant les chiffres de
 * conversion.
 */

import { describe, expect, it } from "vitest";

import {
  ASSUME_PRO_WITHOUT_ROW,
  ENTITLEMENT_ID,
  FREE,
  FREE_TIER,
  PRO,
  canImportCourse,
  canPractice,
  hasReachedSessionLimit,
  isPaid,
  lockedSheetPercent,
  resolve,
  sheetLockIndex,
  splitSheet,
} from "../src/entitlement";
import {
  FREE_TRIAL_DAYS,
  PLANS,
  RECOMMENDED_PLAN,
  STUDENT_YEARLY,
  WEEKLY,
  YEARLY,
  annualCost,
  hasTrial,
  monthlyEquivalent,
  offersFor,
  planCaption,
  planFor,
  savingsPercent,
  yearlyFor,
} from "../src/pricing";

describe("le droit", () => {
  it("respecte la ligne quand il y en a une", () => {
    // C'est le changement de l'étape 5 : le droit ne se devine plus, il se lit. Un achat fait sur
    // l'iPhone referme donc le gratuit sur le web.
    expect(resolve({ isPro: true }).isPro).toBe(true);
    expect(resolve({ isPro: false }).isPro).toBe(false);
  });

  it("suit le réglage quand il n'y a aucune ligne", () => {
    // Le seul endroit du code où une décision de produit se cache : ce qu'on fait de quelqu'un
    // dont on ne sait rien. Aujourd'hui `true`, parce qu'il n'existe aucune façon de payer sur le
    // web - fermer enfermerait dehors sans porte de sortie.
    expect(resolve().isPro).toBe(ASSUME_PRO_WITHOUT_ROW);
    expect(resolve(null, undefined).isPro).toBe(ASSUME_PRO_WITHOUT_ROW);
  });

  it("ne confond pas un Pro deviné avec un abonnement payé", () => {
    // Sans cette distinction, le paywall croit que tout le monde a déjà payé
    // et ne s'ouvre jamais.
    expect(isPaid(resolve())).toBe(false);
    expect(isPaid(resolve({ isPro: true }))).toBe(true);
    expect(isPaid(resolve({ isPro: false }))).toBe(false);
    expect(isPaid(PRO)).toBe(true);
  });

  it("garde la trace du magasin, qui décide où « gérer mon abonnement » mène", () => {
    // Un bouton qui ouvre le mauvais magasin donne un écran vide et un message au support.
    const right = resolve({ isPro: true, store: "stripe" });
    expect(right.isPro).toBe(true);

    const fromPhone = resolve({ isPro: true, store: "app_store" });
    expect(fromPhone.store).toBe("app_store");
  });

  it("connaît le nom de l'entitlement fixé par docs/revenuecat.md", () => {
    expect(ENTITLEMENT_ID).toBe("pro");
  });
});

describe("les limites", () => {
  it("un cours, sept dixièmes de la fiche, cinq cartes", () => {
    expect(FREE_TIER.courses).toBe(1);
    expect(FREE_TIER.readableSheetRatio).toBeCloseTo(0.7, 4);
    expect(FREE_TIER.cardsPerSession).toBe(5);
    expect(FREE_TIER.allowsPractice).toBe(false);
  });

  it("le premier cours est gratuit", () => {
    expect(FREE_TIER.courses).toBeGreaterThan(0);
  });
});

describe("la coupure de la fiche", () => {
  it("tombe aux sept dixièmes des blocs", () => {
    expect(sheetLockIndex(10)).toBe(7);
    expect(sheetLockIndex(20)).toBe(14);
    // 9,8 s'arrondit à 10.
    expect(sheetLockIndex(14)).toBe(10);
  });

  it("laisse toujours quelque chose à lire d'une fiche courte", () => {
    expect(sheetLockIndex(0)).toBe(0);
    expect(sheetLockIndex(1)).toBe(1);
    expect(sheetLockIndex(2)).toBe(1);
    expect(sheetLockIndex(3)).toBe(2);

    for (let count = 1; count <= 60; count += 1) {
      const index = sheetLockIndex(count);
      expect(index).toBeGreaterThanOrEqual(1);
      expect(index).toBeLessThanOrEqual(count);
    }
  });

  it("garde chaque bloc exactement une fois, et dans l'ordre", () => {
    const blocks = Array.from({ length: 17 }, (_, index) => `bloc-${index}`);
    const { readable, locked } = splitSheet(blocks, FREE);

    expect(readable.length + locked.length).toBe(blocks.length);
    expect(readable.length).toBeGreaterThan(0);
    expect(locked.length).toBeGreaterThan(0);
    expect([...readable, ...locked]).toEqual(blocks);
  });

  it("l'abonné lit la fiche entière, et ne voit jamais de liste vide", () => {
    const blocks = ["a", "b", "c"];
    const { readable, locked } = splitSheet(blocks, PRO);

    expect(readable).toEqual(blocks);
    expect(locked).toEqual([]);
  });

  it("une fiche vide n'a rien à verrouiller", () => {
    expect(splitSheet([], FREE)).toEqual({ readable: [], locked: [] });
  });

  it("annonce ce qui reste à lire, calculé et non écrit", () => {
    expect(lockedSheetPercent()).toBe(30);
  });
});

describe("les portes", () => {
  it("la session s'arrête à la cinquième carte, et pas avant", () => {
    expect(hasReachedSessionLimit(FREE, 0)).toBe(false);
    // La cinquième carte se révise.
    expect(hasReachedSessionLimit(FREE, 4)).toBe(false);
    expect(hasReachedSessionLimit(FREE, 5)).toBe(true);
    expect(hasReachedSessionLimit(FREE, 12)).toBe(true);
    expect(hasReachedSessionLimit(PRO, 999)).toBe(false);
  });

  it("le deuxième import est refusé, le premier non", () => {
    expect(canImportCourse(FREE, [])).toBe(true);
    expect(canImportCourse(FREE, [{ isFromLibrary: false }])).toBe(false);
    expect(canImportCourse(PRO, [{ isFromLibrary: false }, { isFromLibrary: false }])).toBe(true);
  });

  it("un cours repris dans la bibliothèque ne consomme pas l'import gratuit", () => {
    // Il n'a rien coûté à produire : le faire compter ferait payer un import qu'on n'a pas fait.
    expect(canImportCourse(FREE, [{ isFromLibrary: true }])).toBe(true);
  });

  it("l'entraînement libre est derrière l'abonnement", () => {
    expect(canPractice(FREE)).toBe(false);
    expect(canPractice(PRO)).toBe(true);
  });
});

describe("l'arbitrage entre deux sources", () => {
  it("prend la plus généreuse", () => {
    // Le SDK et la table doivent s'accorder ; quand ils divergent, enfermer dehors un étudiant qui
    // paye est pire qu'une minute offerte.
    expect(resolve(FREE, PRO).isPro).toBe(true);
    expect(resolve(PRO, FREE).isPro).toBe(true);
  });

  it("ne rend pas Pro quand les deux sources disent non", () => {
    expect(resolve(FREE, FREE).isPro).toBe(false);
  });
});

describe("les offres", () => {
  it("sont deux, l'annuelle d'abord", () => {
    expect(PLANS.map((plan) => plan.kind)).toEqual(["yearly", "weekly"]);
    expect(RECOMMENDED_PLAN.kind).toBe("yearly");
    expect(planFor("weekly")).toEqual(WEEKLY);
  });

  it("ne vendent pas le même produit", () => {
    const identifiers = PLANS.map((plan) => plan.productId);
    expect(new Set(identifiers).size).toBe(identifiers.length);
  });

  it("se comparent sur douze mois", () => {
    expect(annualCost(YEARLY)).toBeCloseTo(83.88, 2);
    expect(annualCost(STUDENT_YEARLY)).toBeCloseTo(59.99, 2);
    // 7,99 € par semaine sur cinquante-deux semaines.
    expect(annualCost(WEEKLY)).toBeCloseTo(415.48, 2);
  });

  it("**calculent** leur pourcentage d'économie, et il vaut 80 au tarif plein", () => {
    // 83,88 contre 415,48. Le chiffre sort des deux prix, et il suivra le jour où l'un des deux
    // bouge. L'étudiant, lui, économise davantage - 86 - parce que son annuel est plus bas.
    expect(savingsPercent()).toBe(80);
    expect(savingsPercent(STUDENT_YEARLY)).toBe(86);
  });

  it("ramènent l'annuel au mois, et rien d'autre", () => {
    // L'espace avant l'euro est **insécable**, comme la typographie française l'exige : un prix
    // ne se coupe pas en fin de ligne entre le nombre et son symbole. Elle est normalisée à
    // U+00A0 par `priceText`, parce que `Intl` rend tantôt U+00A0 tantôt U+202F selon la version
    // d'ICU - et un prix qui ne s'espace pas pareil selon la machine est une différence qu'on
    // finit par chercher longtemps.
    const sixPerMonth = "6,99\u00a0€";
    const fourPerMonth = "4,99\u00a0€";

    expect(monthlyEquivalent(YEARLY)).toBe(sixPerMonth);
    expect(monthlyEquivalent(STUDENT_YEARLY)).toBe(fourPerMonth);
    expect(monthlyEquivalent(WEEKLY)).toBeNull();
    expect(planCaption(WEEKLY)).toBe("facturé chaque semaine");
    expect(planCaption(YEARLY)).toBe(`${sixPerMonth} / mois`);
  });

  it("offrent trois jours d'essai au tarif plein, et rien à l'étudiant", () => {
    expect(FREE_TRIAL_DAYS).toBe(3);
    expect(hasTrial(YEARLY)).toBe(true);
    expect(hasTrial(STUDENT_YEARLY)).toBe(false);
    expect(hasTrial(WEEKLY)).toBe(false);
  });

  it("permutent l'annuel quand on se déclare étudiant, sans inventer une troisième offre", () => {
    expect(yearlyFor(false)).toEqual(YEARLY);
    expect(yearlyFor(true)).toEqual(STUDENT_YEARLY);
    expect(offersFor(true).map((plan) => plan.price)).toEqual([59.99, 7.99]);
    expect(offersFor(false).map((plan) => plan.kind)).toEqual(["yearly", "weekly"]);
  });
});
