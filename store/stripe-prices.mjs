/**
 * **Les prix Stripe du site, posés d'après la grille des apps.**
 *
 * La grille vit dans `web/packages/core/src/pricing.ts` (`stripePriceSpecs`) et le test de
 * parité la relie à celle de l'App Store : ce script ne recopie aucun montant. Pour chaque
 * offre et chaque groupe de pays, il crée (ou retrouve) un produit Stripe d'identifiant fixe,
 * puis un prix récurrent qui porte le nom `micabo_<offre>_<groupe>` (`lookup_key`). C'est ce
 * nom que le site lit pour vendre : aucun `price_…` à recopier dans Vercel.
 *
 * Il se rejoue sans casse. Un prix déjà juste est laissé tel quel. Un prix qui a changé n'est
 * pas modifié (Stripe ne modifie pas le montant d'un prix) : un nouveau prix est créé, il
 * reprend le nom (`transfer_lookup_key`), et l'ancien est désactivé. Les abonnés en cours sur
 * l'ancien prix gardent le leur.
 *
 *     STRIPE_RESTRICTED_KEY=rk_… node --experimental-strip-types \
 *       --import ./scripts/ts-extensions.mjs store/stripe-prices.mjs [--apply]
 *
 * Sans `--apply`, il dit seulement ce qu'il ferait. La clé restreinte n'a besoin que de
 * l'écriture sur Products et Prices.
 */
import { appendFileSync } from "node:fs";

import { stripePriceSpecs } from "../web/packages/core/src/pricing.ts";

const KEY = process.env.STRIPE_RESTRICTED_KEY?.trim() ?? "";
const APPLY = process.argv.includes("--apply");

const PLAN_NAME = {
  yearly: "Annuel",
  weekly: "Hebdomadaire",
  yearly_discount: "Annuel, tarif réduit",
};

function cents(amount) {
  return Math.round(amount * 100);
}

async function stripe(method, path, form) {
  const body = form ? new URLSearchParams(form).toString() : undefined;
  const response = await fetch(`https://api.stripe.com/v1/${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${KEY}`,
      ...(body ? { "Content-Type": "application/x-www-form-urlencoded" } : {}),
    },
    body,
  });
  const json = await response.json().catch(() => ({}));
  if (!response.ok && response.status !== 404) {
    throw new Error(`${method} ${path} → ${response.status} ${json?.error?.message ?? ""}`);
  }
  return { status: response.status, json };
}

/** Le prix tel qu'on le veut, sous la forme de l'API (montants en centimes). */
function wanted(spec) {
  return {
    currency: spec.currency,
    unit_amount: cents(spec.amount),
    interval: spec.interval,
    options: Object.fromEntries(
      Object.entries(spec.currencyOptions).map(([code, value]) => [code, cents(value)]),
    ),
  };
}

/** Le prix existant dit-il exactement ce que dit la grille ? */
function matches(price, target) {
  if (!price || price.currency !== target.currency) return false;
  if (price.unit_amount !== target.unit_amount) return false;
  if (price.recurring?.interval !== target.interval || price.recurring?.interval_count !== 1) return false;
  if (price.tax_behavior !== "inclusive") return false;
  const options = price.currency_options ?? {};
  for (const [code, amount] of Object.entries(target.options)) {
    if (options[code]?.unit_amount !== amount) return false;
  }
  return true;
}

function priceForm(spec, productId, target) {
  const form = {
    product: productId,
    currency: target.currency,
    unit_amount: String(target.unit_amount),
    "recurring[interval]": target.interval,
    "recurring[interval_count]": "1",
    tax_behavior: "inclusive",
    lookup_key: spec.lookupKey,
    transfer_lookup_key: "true",
    nickname: `${PLAN_NAME[spec.plan]} · ${spec.group}`,
    "metadata[micabo_plan]": spec.plan,
    "metadata[micabo_group]": spec.group,
  };
  for (const [code, amount] of Object.entries(target.options)) {
    form[`currency_options[${code}][unit_amount]`] = String(amount);
    form[`currency_options[${code}][tax_behavior]`] = "inclusive";
  }
  return form;
}

async function main() {
  if (!KEY) {
    console.error("STRIPE_RESTRICTED_KEY manque : rien n'est lu ni écrit.");
    process.exit(1);
  }
  if (KEY.startsWith("sk_test") || KEY.startsWith("rk_test")) {
    console.log("Clé de test : les prix iront dans le mode test de Stripe.");
  }

  const rows = [];
  for (const spec of stripePriceSpecs()) {
    const productId = spec.lookupKey;
    const target = wanted(spec);

    const product = await stripe("GET", `products/${productId}`);
    if (product.status === 404) {
      if (APPLY) {
        await stripe("POST", "products", {
          id: productId,
          name: `Micabo Pro · ${PLAN_NAME[spec.plan]} (${spec.group})`,
          "metadata[micabo_plan]": spec.plan,
          "metadata[micabo_group]": spec.group,
        });
      }
    }

    const query = new URLSearchParams({ "lookup_keys[]": spec.lookupKey, limit: "1" });
    query.append("expand[]", "data.currency_options");
    const existing = (await stripe("GET", `prices?${query}`)).json?.data?.[0] ?? null;

    let action = "inchangé";
    let priceId = existing?.id ?? "";
    if (!matches(existing, target)) {
      action = existing ? "remplacé" : "créé";
      if (APPLY) {
        const created = await stripe("POST", "prices", priceForm(spec, productId, target));
        priceId = created.json.id;
        if (existing?.active) await stripe("POST", `prices/${existing.id}`, { active: "false" });
      } else {
        priceId = "(à créer)";
      }
    }

    const others = Object.entries(spec.currencyOptions)
      .map(([code, value]) => `${code.toUpperCase()} ${value}`)
      .join(", ");
    rows.push({ key: spec.lookupKey, action, priceId, main: `${spec.currency.toUpperCase()} ${spec.amount}`, others });
  }

  const lines = [
    `## Prix Stripe ${APPLY ? "posés" : "à poser (simulation)"}`,
    "",
    "| Nom (`lookup_key`) | Action | Prix | Montant | Autres devises |",
    "| --- | --- | --- | --- | --- |",
    ...rows.map((row) => `| \`${row.key}\` | ${row.action} | \`${row.priceId}\` | ${row.main} | ${row.others || "—"} |`),
  ];
  console.log(lines.join("\n"));
  if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${lines.join("\n")}\n`);
}

main().catch((error) => {
  console.error(error.message ?? error);
  process.exit(1);
});
