#!/usr/bin/env node
/**
 * **Préparer une version de l'App Store**, sans la soumettre : la version existe (créée au
 * besoin), le dernier build traité de ce numéro y est attaché, et « Nouveautés » est rempli
 * dans chaque langue de la fiche. Il ne reste qu'à relire et à appuyer sur « Soumettre ».
 *
 *     ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_PRIVATE_KEY=… \
 *       node store/app-store-release.mjs --version 1.11 [--build 158] [--apply]
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
  console.error("--version manque, par ex. --version 1.11");
  process.exit(1);
}

/** « Nouveautés » par langue de fiche ; une langue absente d'ici reçoit l'anglais. */
const WHATS_NEW = {
  fr: "Tes leçons, tes quiz et tes flashcards s'écrivent maintenant toujours dans la langue de l'app. Traductions revues dans toutes les langues, corrections et améliorations.",
  en: "Your lessons, quizzes and flashcards are now always written in the app's language. Translations reviewed in every language, plus fixes and improvements.",
  es: "Tus lecciones, cuestionarios y flashcards ahora se escriben siempre en el idioma de la app. Traducciones revisadas en todos los idiomas, correcciones y mejoras.",
  de: "Deine Lektionen, Quiz und Karteikarten werden jetzt immer in der Sprache der App geschrieben. Übersetzungen in allen Sprachen überarbeitet, Fehlerbehebungen und Verbesserungen.",
  it: "Le tue lezioni, i quiz e le flashcard ora sono sempre scritti nella lingua dell'app. Traduzioni riviste in tutte le lingue, correzioni e miglioramenti.",
  pt: "As tuas lições, quizzes e flashcards passam a ser sempre escritos na língua da app. Traduções revistas em todas as línguas, correções e melhorias.",
  "pt-BR": "Suas lições, quizzes e flashcards agora são sempre escritos no idioma do app. Traduções revisadas em todos os idiomas, correções e melhorias.",
  nl: "Je lessen, quizzen en flashcards worden nu altijd in de taal van de app geschreven. Vertalingen in alle talen nagekeken, verbeteringen en oplossingen.",
  tr: "Derslerin, testlerin ve bilgi kartların artık her zaman uygulamanın dilinde yazılıyor. Tüm dillerde çeviriler gözden geçirildi, düzeltmeler ve iyileştirmeler.",
  hr: "Tvoje lekcije, kvizovi i kartice sada su uvijek napisani na jeziku aplikacije. Prijevodi provjereni na svim jezicima, ispravci i poboljšanja.",
  ru: "Твои уроки, тесты и карточки теперь всегда пишутся на языке приложения. Переводы проверены на всех языках, исправления и улучшения.",
  fi: "Oppituntisi, visasi ja muistikorttisi kirjoitetaan nyt aina sovelluksen kielellä. Käännökset tarkistettu kaikilla kielillä, korjauksia ja parannuksia.",
  cs: "Tvoje lekce, kvízy a kartičky se teď vždy píšou v jazyce aplikace. Překlady zkontrolované ve všech jazycích, opravy a vylepšení.",
  pl: "Twoje lekcje, quizy i fiszki są teraz zawsze pisane w języku aplikacji. Tłumaczenia sprawdzone we wszystkich językach, poprawki i ulepszenia.",
  el: "Τα μαθήματα, τα κουίζ και οι κάρτες σου γράφονται πλέον πάντα στη γλώσσα της εφαρμογής. Αναθεωρημένες μεταφράσεις σε όλες τις γλώσσες, διορθώσεις και βελτιώσεις.",
  ro: "Lecțiile, testele și cardurile tale sunt acum scrise mereu în limba aplicației. Traduceri revizuite în toate limbile, corecturi și îmbunătățiri.",
  no: "Leksjonene, quizene og kortene dine skrives nå alltid på appens språk. Oversettelser gjennomgått på alle språk, rettelser og forbedringer.",
  uk: "Твої уроки, тести й картки тепер завжди пишуться мовою застосунку. Переклади перевірено всіма мовами, виправлення та покращення.",
  sv: "Dina lektioner, quiz och flashcards skrivs nu alltid på appens språk. Översättningar granskade på alla språk, rättningar och förbättringar.",
  da: "Dine lektioner, quizzer og flashcards skrives nu altid på appens sprog. Oversættelser gennemgået på alle sprog, rettelser og forbedringer.",
  ar: "دروسك واختباراتك وبطاقاتك تُكتب الآن دائمًا بلغة التطبيق. مراجعة الترجمات في كل اللغات، مع إصلاحات وتحسينات.",
  sl: "Tvoje lekcije, kvizi in kartice so zdaj vedno napisani v jeziku aplikacije. Prevodi pregledani v vseh jezikih, popravki in izboljšave.",
  sk: "Tvoje lekcie, kvízy a kartičky sa teraz vždy píšu v jazyku aplikácie. Preklady skontrolované vo všetkých jazykoch, opravy a vylepšenia.",
  hu: "A leckéid, kvízeid és kártyáid mostantól mindig az alkalmazás nyelvén készülnek. Átnézett fordítások minden nyelven, javítások és fejlesztések.",
  he: "השיעורים, החידונים והכרטיסיות שלך נכתבים עכשיו תמיד בשפת האפליקציה. תרגומים נבדקו בכל השפות, תיקונים ושיפורים.",
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
