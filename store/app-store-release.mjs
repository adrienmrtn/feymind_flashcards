#!/usr/bin/env node
/**
 * **Préparer une version de l'App Store**, sans la soumettre : la version existe (créée au
 * besoin), le dernier build traité de ce numéro y est attaché, et « Nouveautés » est rempli
 * dans chaque langue de la fiche. Il ne reste qu'à relire et à appuyer sur « Soumettre ».
 *
 *     ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_PRIVATE_KEY=… \
 *       node store/app-store-release.mjs --version 1.12 [--apply]
 *
 * Sans `--apply`, il dit seulement ce qu'il ferait. Workflow : « Version App Store ». Les
 * secrets sont ceux de la grille de prix
 * (docs/revenuecat.md, §15).
 */
import { appendFileSync } from "node:fs";
import { AppStoreConnect, credentialProblems } from "./lib/asc.mjs";

const args = process.argv.slice(2);
const apply = args.includes("--apply");
const option = (name) => {
  const index = args.indexOf(name);
  return index >= 0 ? args[index + 1]?.trim() : undefined;
};
const versionString = option("--version");
const wantedBuild = option("--build") || null;
const bundleId = "com.micabo.ios";
const log = (...parts) => console.log(...parts);

if (!versionString) {
  console.error("--version manque, par ex. --version 1.12");
  process.exit(1);
}

/** « Nouveautés » par langue de fiche ; une langue absente d'ici reçoit l'anglais. */
const WHATS_NEW = {
  fr: "Un démarrage plus fluide, des prix toujours affichés dans ta devise, et une connexion plus fiable (lien par e-mail, Apple, Google). Ta leçon offerte n'est plus perdue si la création est interrompue. Corrections et améliorations.",
  en: "A smoother start, prices always shown in your currency, and more reliable sign-in (email link, Apple, Google). Your free lesson is no longer lost if creating it is interrupted. Fixes and improvements.",
  es: "Un inicio más fluido, precios siempre en tu moneda y un inicio de sesión más fiable (enlace por correo, Apple, Google). Tu lección gratis ya no se pierde si se interrumpe su creación. Correcciones y mejoras.",
  de: "Ein flüssigerer Start, Preise immer in deiner Währung und eine zuverlässigere Anmeldung (E-Mail-Link, Apple, Google). Deine kostenlose Lektion geht nicht mehr verloren, wenn die Erstellung unterbrochen wird. Fehlerbehebungen und Verbesserungen.",
  it: "Un avvio più fluido, prezzi sempre nella tua valuta e un accesso più affidabile (link via email, Apple, Google). La tua lezione gratuita non si perde più se la creazione viene interrotta. Correzioni e miglioramenti.",
  pt: "Um início mais fluido, preços sempre na tua moeda e um início de sessão mais fiável (link por email, Apple, Google). A tua lição grátis já não se perde se a criação for interrompida. Correções e melhorias.",
  "pt-BR": "Um início mais fluido, preços sempre na sua moeda e um login mais confiável (link por e-mail, Apple, Google). Sua lição grátis não se perde mais se a criação for interrompida. Correções e melhorias.",
  nl: "Een soepelere start, prijzen altijd in je eigen valuta en betrouwbaarder inloggen (e-maillink, Apple, Google). Je gratis les gaat niet meer verloren als het maken wordt onderbroken. Verbeteringen en oplossingen.",
  tr: "Daha akıcı bir başlangıç, fiyatlar her zaman kendi para biriminde ve daha güvenilir giriş (e-posta bağlantısı, Apple, Google). Oluşturma yarıda kalırsa ücretsiz dersin artık kaybolmuyor. Düzeltmeler ve iyileştirmeler.",
  hr: "Glađi početak, cijene uvijek u tvojoj valuti i pouzdanija prijava (poveznica e-poštom, Apple, Google). Tvoja besplatna lekcija više se ne gubi ako se izrada prekine. Ispravci i poboljšanja.",
  ru: "Более плавный старт, цены всегда в твоей валюте и более надёжный вход (ссылка по почте, Apple, Google). Бесплатный урок больше не теряется, если создание прервалось. Исправления и улучшения.",
  fi: "Sujuvampi aloitus, hinnat aina omassa valuutassasi ja luotettavampi kirjautuminen (sähköpostilinkki, Apple, Google). Ilmainen oppituntisi ei enää katoa, jos sen luominen keskeytyy. Korjauksia ja parannuksia.",
  cs: "Plynulejší start, ceny vždy ve tvé měně a spolehlivější přihlášení (odkaz e-mailem, Apple, Google). Tvoje lekce zdarma se už neztratí, když se vytváření přeruší. Opravy a vylepšení.",
  pl: "Płynniejszy start, ceny zawsze w twojej walucie i pewniejsze logowanie (link e-mailem, Apple, Google). Darmowa lekcja nie przepada już, gdy tworzenie zostanie przerwane. Poprawki i ulepszenia.",
  el: "Πιο ομαλή αρχή, τιμές πάντα στο νόμισμά σου και πιο αξιόπιστη σύνδεση (σύνδεσμος email, Apple, Google). Το δωρεάν μάθημά σου δεν χάνεται πια αν διακοπεί η δημιουργία του. Διορθώσεις και βελτιώσεις.",
  ro: "Un început mai fluid, prețuri mereu în moneda ta și o conectare mai sigură (link pe e-mail, Apple, Google). Lecția ta gratuită nu se mai pierde dacă crearea ei e întreruptă. Corecturi și îmbunătățiri.",
  no: "En jevnere start, priser alltid i din valuta og mer pålitelig innlogging (e-postlenke, Apple, Google). Gratisleksjonen din går ikke lenger tapt hvis opprettelsen avbrytes. Rettelser og forbedringer.",
  uk: "Плавніший старт, ціни завжди у твоїй валюті та надійніший вхід (посилання поштою, Apple, Google). Безкоштовний урок більше не губиться, якщо створення перервалося. Виправлення та покращення.",
  sv: "En smidigare start, priser alltid i din valuta och säkrare inloggning (e-postlänk, Apple, Google). Din gratislektion försvinner inte längre om skapandet avbryts. Rättningar och förbättringar.",
  da: "En glattere start, priser altid i din valuta og mere pålidelig login (link på mail, Apple, Google). Din gratis lektion går ikke længere tabt, hvis oprettelsen afbrydes. Rettelser og forbedringer.",
  ar: "بداية أكثر سلاسة، وأسعار تظهر دائمًا بعملتك، وتسجيل دخول أكثر موثوقية (رابط بالبريد، Apple، Google). لم يعد درسك المجاني يضيع إذا انقطع إنشاؤه. إصلاحات وتحسينات.",
  sl: "Bolj gladek začetek, cene vedno v tvoji valuti in zanesljivejša prijava (povezava po e-pošti, Apple, Google). Brezplačna lekcija se ne izgubi več, če se ustvarjanje prekine. Popravki in izboljšave.",
  sk: "Plynulejší štart, ceny vždy v tvojej mene a spoľahlivejšie prihlásenie (odkaz e-mailom, Apple, Google). Tvoja lekcia zadarmo sa už nestratí, keď sa vytváranie preruší. Opravy a vylepšenia.",
  hu: "Gördülékenyebb kezdés, árak mindig a saját pénznemedben, és megbízhatóbb bejelentkezés (e-mailes link, Apple, Google). Az ingyenes leckéd már nem vész el, ha a létrehozás megszakad. Javítások és fejlesztések.",
  he: "התחלה חלקה יותר, מחירים תמיד במטבע שלך והתחברות אמינה יותר (קישור במייל, Apple, Google). השיעור החינמי שלך כבר לא הולך לאיבוד אם היצירה נקטעת. תיקונים ושיפורים.",
};

function whatsNewFor(locale) {
  return WHATS_NEW[locale] ?? WHATS_NEW[locale.split("-")[0]] ?? WHATS_NEW.en;
}

// ── La connexion ────────────────────────────────────────────────────────────────────────

for (const name of ["ASC_KEY_ID", "ASC_PRIVATE_KEY"]) {
  if (!process.env[name]?.trim()) {
    console.error(`${name} manque. Voir docs/revenuecat.md, §15.`);
    process.exit(1);
  }
}
const credentials = { keyId: process.env.ASC_KEY_ID.trim(), issuerId: (process.env.ASC_ISSUER_ID ?? "").trim() };
const shapeProblems = credentialProblems(credentials);
if (shapeProblems.length) {
  console.error("Les secrets App Store Connect n'ont pas la bonne forme :\n- " + shapeProblems.join("\n- "));
  process.exit(1);
}
const asc = new AppStoreConnect({ ...credentials, privateKey: process.env.ASC_PRIVATE_KEY, log });

const app = (await asc.get(`/v1/apps?filter[bundleId]=${bundleId}&limit=1`)).data?.[0];
if (!app) {
  console.error(`Aucune app ${bundleId} dans App Store Connect.`);
  process.exit(1);
}
log(`App : ${app.attributes?.name} (${app.id})`);

// ── Le build ────────────────────────────────────────────────────────────────────────────

const builds = (
  await asc.get(
    `/v1/builds?filter[app]=${app.id}&filter[preReleaseVersion.version]=${encodeURIComponent(versionString)}` +
      `&filter[processingState]=VALID&filter[expired]=false&sort=-uploadedDate&limit=20`,
  )
).data ?? [];
const build = wantedBuild ? builds.find((candidate) => candidate.attributes?.version === wantedBuild) : builds[0];
if (!build) {
  console.error(
    `Aucun build ${versionString}${wantedBuild ? ` (${wantedBuild})` : ""} traité et valide. Builds : ` +
      (builds.map((candidate) => candidate.attributes?.version).join(", ") || "aucun"),
  );
  process.exit(1);
}
log(`Build : ${versionString} (${build.attributes?.version}), reçu ${build.attributes?.uploadedDate}`);

// ── La version ──────────────────────────────────────────────────────────────────────────

const EDITABLE = new Set(["PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY"]);
const stateOf = (version) => version.attributes?.appVersionState ?? version.attributes?.appStoreState;
const versions = (await asc.getAll(`/v1/apps/${app.id}/appStoreVersions?filter[platform]=IOS&limit=50`)).data;
let version = versions.find((candidate) => candidate.attributes?.versionString === versionString);
const steps = [];

if (version && !EDITABLE.has(stateOf(version))) {
  console.error(`La version ${versionString} est ${stateOf(version)} : elle ne se modifie plus.`);
  process.exit(1);
}
const other = versions.find((candidate) => candidate !== version && EDITABLE.has(stateOf(candidate)));
if (!version && other) {
  console.error(
    `La version ${other.attributes?.versionString} est déjà en préparation : Apple n'en accepte qu'une. ` +
      `La renommer en ${versionString} dans App Store Connect, ou la supprimer, puis relancer.`,
  );
  process.exit(1);
}

if (!version) {
  steps.push(`créer la version ${versionString} avec le build ${build.attributes?.version}`);
  if (apply) {
    version = (
      await asc.post("/v1/appStoreVersions", {
        data: {
          type: "appStoreVersions",
          attributes: { platform: "IOS", versionString },
          relationships: {
            app: { data: { type: "apps", id: app.id } },
            build: { data: { type: "builds", id: build.id } },
          },
        },
      })
    ).data;
  }
} else {
  const current = (await asc.get(`/v1/appStoreVersions/${version.id}/build`)).data;
  if (current?.id !== build.id) {
    steps.push(`attacher le build ${build.attributes?.version} (à la place de ${current?.attributes?.version ?? "aucun"})`);
    if (apply) {
      await asc.request("PATCH", `/v1/appStoreVersions/${version.id}/relationships/build`, {
        data: { type: "builds", id: build.id },
      });
    }
  } else {
    steps.push(`build ${build.attributes?.version} déjà attaché`);
  }
}

// ── « Nouveautés », langue par langue ───────────────────────────────────────────────────

const rows = [];
if (version) {
  const localizations = (await asc.getAll(`/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=50`)).data;
  for (const localization of localizations) {
    const locale = localization.attributes?.locale;
    const text = whatsNewFor(locale);
    const same = localization.attributes?.whatsNew === text;
    rows.push(`| ${locale} | ${same ? "déjà à jour" : apply ? "rempli" : "à remplir"} | ${text.slice(0, 60)}… |`);
    if (!same && apply) {
      await asc.request("PATCH", `/v1/appStoreVersionLocalizations/${localization.id}`, {
        data: { type: "appStoreVersionLocalizations", id: localization.id, attributes: { whatsNew: text } },
      });
    }
  }
} else {
  rows.push("| (toutes) | à remplir une fois la version créée | — |");
}

const report = [
  `### App Store — version ${versionString}${apply ? "" : " (simulation)"}`,
  "",
  ...steps.map((step) => `- ${step}`),
  "",
  "| Langue | Nouveautés | Texte |",
  "| --- | --- | --- |",
  ...rows,
  "",
  apply
    ? "Prête. Reste à faire dans App Store Connect : relire, puis « Ajouter pour vérification » et « Soumettre »."
    : "Rien n'est envoyé. Relancer avec --apply.",
].join("\n");
log(report);
if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${report}\n`);
