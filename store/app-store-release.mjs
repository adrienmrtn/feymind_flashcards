#!/usr/bin/env node
/**
 * **Préparer une version de l'App Store**, sans la soumettre : la version existe (créée au
 * besoin), le dernier build traité de ce numéro y est attaché, et « Nouveautés » est rempli
 * dans chaque langue de la fiche. Il ne reste qu'à relire et à appuyer sur « Soumettre ».
 *
 *     ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_PRIVATE_KEY=… \
 *       node store/app-store-release.mjs --version 1.10 [--build 157] [--apply]
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
  console.error("--version manque, par ex. --version 1.10");
  process.exit(1);
}

/** « Nouveautés » par langue de fiche ; une langue absente d'ici reçoit l'anglais. */
const WHATS_NEW = {
  fr: "Tes cours te suivent partout : iPhone, Android et micabo.app, avec le même compte. Un cours commencé sans compte te suit quand tu en crées un. Corrections et améliorations.",
  en: "Your courses follow you everywhere: iPhone, Android and micabo.app, with the same account. A course started without an account comes with you when you sign up. Fixes and improvements.",
  es: "Tus cursos te siguen a todas partes: iPhone, Android y micabo.app, con la misma cuenta. Un curso empezado sin cuenta te sigue cuando creas una. Correcciones y mejoras.",
  de: "Deine Kurse begleiten dich überall: iPhone, Android und micabo.app, mit demselben Konto. Ein ohne Konto begonnener Kurs bleibt erhalten, wenn du eines erstellst. Fehlerbehebungen und Verbesserungen.",
  it: "I tuoi corsi ti seguono ovunque: iPhone, Android e micabo.app, con lo stesso account. Un corso iniziato senza account ti segue quando ne crei uno. Correzioni e miglioramenti.",
  pt: "Os teus cursos acompanham-te em todo o lado: iPhone, Android e micabo.app, com a mesma conta. Um curso começado sem conta acompanha-te quando crias uma. Correções e melhorias.",
  "pt-BR": "Seus cursos te acompanham em todo lugar: iPhone, Android e micabo.app, com a mesma conta. Um curso começado sem conta vem junto quando você cria uma. Correções e melhorias.",
  nl: "Je cursussen gaan overal mee: iPhone, Android en micabo.app, met hetzelfde account. Een cursus die je zonder account begon, gaat mee als je er een aanmaakt. Verbeteringen en oplossingen.",
  tr: "Derslerin her yerde seninle: iPhone, Android ve micabo.app, aynı hesapla. Hesapsız başladığın bir ders, hesap oluşturduğunda seninle gelir. Düzeltmeler ve iyileştirmeler.",
  hr: "Tvoji tečajevi prate te posvuda: iPhone, Android i micabo.app, s istim računom. Tečaj započet bez računa ide s tobom kad ga izradiš. Ispravci i poboljšanja.",
  ru: "Твои курсы всегда с тобой: iPhone, Android и micabo.app, с одним аккаунтом. Курс, начатый без аккаунта, сохранится, когда ты его создашь. Исправления и улучшения.",
  fi: "Kurssisi kulkevat mukanasi: iPhone, Android ja micabo.app samalla tilillä. Ilman tiliä aloitettu kurssi säilyy, kun luot tilin. Korjauksia ja parannuksia.",
  cs: "Tvoje kurzy tě provází všude: iPhone, Android i micabo.app, se stejným účtem. Kurz začatý bez účtu ti zůstane, když si účet vytvoříš. Opravy a vylepšení.",
  pl: "Twoje kursy są z tobą wszędzie: iPhone, Android i micabo.app, na jednym koncie. Kurs zaczęty bez konta zostaje z tobą, gdy je założysz. Poprawki i ulepszenia.",
  el: "Τα μαθήματά σου σε ακολουθούν παντού: iPhone, Android και micabo.app, με τον ίδιο λογαριασμό. Ένα μάθημα που ξεκίνησες χωρίς λογαριασμό έρχεται μαζί σου όταν δημιουργήσεις έναν. Διορθώσεις και βελτιώσεις.",
  ro: "Cursurile tale te urmează peste tot: iPhone, Android și micabo.app, cu același cont. Un curs început fără cont rămâne cu tine când îți faci unul. Corecturi și îmbunătățiri.",
  no: "Fagene dine følger deg overalt: iPhone, Android og micabo.app, med samme konto. Et fag du startet uten konto blir med når du lager en. Rettelser og forbedringer.",
  uk: "Твої курси завжди з тобою: iPhone, Android і micabo.app, з одним акаунтом. Курс, розпочатий без акаунта, залишиться, коли ти його створиш. Виправлення та покращення.",
  sv: "Dina kurser följer med dig överallt: iPhone, Android och micabo.app, med samma konto. En kurs du började utan konto följer med när du skapar ett. Rättningar och förbättringar.",
  da: "Dine fag følger dig overalt: iPhone, Android og micabo.app, med samme konto. Et fag, du startede uden konto, følger med, når du opretter en. Rettelser og forbedringer.",
  ar: "دروسك ترافقك في كل مكان: iPhone وAndroid وmicabo.app، بالحساب نفسه. الدرس الذي بدأته دون حساب يبقى معك عندما تنشئ حسابًا. إصلاحات وتحسينات.",
  sl: "Tvoji tečaji so s tabo povsod: iPhone, Android in micabo.app, z istim računom. Tečaj, začet brez računa, ostane s tabo, ko ga ustvariš. Popravki in izboljšave.",
  sk: "Tvoje kurzy ťa sprevádzajú všade: iPhone, Android aj micabo.app, s rovnakým účtom. Kurz začatý bez účtu ti zostane, keď si účet vytvoríš. Opravy a vylepšenia.",
  hu: "A kurzusaid mindenhová elkísérnek: iPhone, Android és micabo.app, ugyanazzal a fiókkal. A fiók nélkül elkezdett kurzus megmarad, amikor fiókot hozol létre. Javítások és fejlesztések.",
  he: "הקורסים שלך איתך בכל מקום: iPhone, Android ו-micabo.app, עם אותו חשבון. קורס שהתחלת בלי חשבון נשאר איתך כשאתה יוצר חשבון. תיקונים ושיפורים.",
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
