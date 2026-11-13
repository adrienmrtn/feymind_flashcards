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
  fr: "Nouveau : gagne de l'XP à chaque révision, vise ton objectif du jour et affronte tes amis dans la ligue de la semaine. Scanne un exercice et Mika te l'explique pas à pas, lance le minuteur de concentration, et crée ta leçon offerte à partir d'une photo ou d'un PDF.",
  en: "New: earn XP every time you study, hit your daily goal and take on your friends in the weekly league. Scan an exercise and Mika explains it step by step, start the focus timer, and create your free lesson from a photo or a PDF.",
  es: "Novedad: gana XP cada vez que estudias, cumple tu objetivo del día y compite con tus amigos en la liga semanal. Escanea un ejercicio y Mika te lo explica paso a paso, activa el temporizador de concentración y crea tu lección gratis a partir de una foto o un PDF.",
  de: "Neu: Sammle XP bei jedem Lernen, erreiche dein Tagesziel und tritt in der Wochenliga gegen deine Freunde an. Scanne eine Aufgabe und Mika erklärt sie dir Schritt für Schritt, starte den Fokus-Timer und erstelle deine kostenlose Lektion aus einem Foto oder PDF.",
  it: "Novità: guadagna XP ogni volta che studi, raggiungi il tuo obiettivo del giorno e sfida i tuoi amici nella lega settimanale. Scansiona un esercizio e Mika te lo spiega passo dopo passo, avvia il timer di concentrazione e crea la tua lezione gratuita da una foto o un PDF.",
  pt: "Novidade: ganha XP sempre que estudas, cumpre o teu objetivo do dia e desafia os teus amigos na liga semanal. Digitaliza um exercício e o Mika explica-o passo a passo, inicia o temporizador de concentração e cria a tua lição grátis a partir de uma foto ou PDF.",
  "pt-BR": "Novidade: ganhe XP toda vez que estudar, bata sua meta do dia e enfrente seus amigos na liga semanal. Escaneie um exercício e o Mika explica passo a passo, use o timer de foco e crie sua lição grátis a partir de uma foto ou PDF.",
  nl: "Nieuw: verdien XP elke keer dat je leert, haal je dagdoel en neem het op tegen je vrienden in de weekcompetitie. Scan een opgave en Mika legt hem stap voor stap uit, start de focustimer en maak je gratis les van een foto of pdf.",
  tr: "Yeni: her çalışmada XP kazan, günlük hedefine ulaş ve haftalık ligde arkadaşlarınla yarış. Bir alıştırmayı tara, Mika sana adım adım açıklasın; odak zamanlayıcısını başlat ve ücretsiz dersini bir fotoğraftan ya da PDF'ten oluştur.",
  hr: "Novo: skupljaj XP svaki put kad učiš, ostvari dnevni cilj i natječi se s prijateljima u tjednoj ligi. Skeniraj zadatak i Mika ti ga objasni korak po korak, pokreni mjerač za fokus i napravi besplatnu lekciju iz fotografije ili PDF-a.",
  ru: "Новое: получай XP за каждое занятие, выполняй цель дня и соревнуйся с друзьями в недельной лиге. Отсканируй задачу — Мика объяснит её шаг за шагом, включай таймер концентрации и создавай бесплатный урок из фото или PDF.",
  fi: "Uutta: ansaitse XP:tä aina kun opiskelet, saavuta päivän tavoitteesi ja kilpaile kavereidesi kanssa viikkoliigassa. Skannaa tehtävä, niin Mika selittää sen vaihe vaiheelta, käynnistä keskittymisajastin ja luo ilmainen oppitunti kuvasta tai PDF:stä.",
  cs: "Novinka: získávej XP při každém učení, splň denní cíl a soupeř s kamarády v týdenní lize. Naskenuj příklad a Mika ti ho vysvětlí krok za krokem, spusť časovač soustředění a vytvoř si lekci zdarma z fotky nebo PDF.",
  pl: "Nowość: zdobywaj XP za każdą naukę, realizuj cel dnia i rywalizuj ze znajomymi w tygodniowej lidze. Zeskanuj zadanie, a Mika wyjaśni je krok po kroku, włącz minutnik skupienia i stwórz darmową lekcję ze zdjęcia lub PDF.",
  el: "Νέο: κέρδισε XP κάθε φορά που διαβάζεις, πέτυχε τον στόχο της ημέρας και αναμετρήσου με τους φίλους σου στην εβδομαδιαία λίγκα. Σκάναρε μια άσκηση και ο Mika σου την εξηγεί βήμα βήμα, ξεκίνα το χρονόμετρο συγκέντρωσης και φτιάξε το δωρεάν μάθημά σου από φωτογραφία ή PDF.",
  ro: "Nou: câștigă XP de fiecare dată când înveți, atinge-ți obiectivul zilei și întrece-te cu prietenii în liga săptămânii. Scanează un exercițiu și Mika ți-l explică pas cu pas, pornește cronometrul de concentrare și creează-ți lecția gratuită dintr-o poză sau un PDF.",
  no: "Nytt: tjen XP hver gang du øver, nå dagens mål og konkurrer med vennene dine i ukeligaen. Skann en oppgave, så forklarer Mika den steg for steg, start fokustimeren og lag gratisleksjonen din fra et bilde eller en PDF.",
  uk: "Нове: отримуй XP за кожне заняття, виконуй мету дня та змагайся з друзями в тижневій лізі. Скануй завдання — Міка пояснить його крок за кроком, вмикай таймер зосередження та створюй безкоштовний урок із фото чи PDF.",
  sv: "Nytt: tjäna XP varje gång du pluggar, nå ditt dagsmål och tävla mot dina vänner i veckoligan. Skanna en uppgift så förklarar Mika den steg för steg, starta fokustimern och skapa din gratislektion från ett foto eller en PDF.",
  da: "Nyt: optjen XP hver gang du læser, nå dit dagsmål og dyst mod dine venner i ugeligaen. Scan en opgave, så forklarer Mika den trin for trin, start fokustimeren og lav din gratis lektion ud fra et foto eller en PDF.",
  ar: "جديد: اكسب نقاط XP في كل مراجعة، وحقّق هدفك اليومي، ونافس أصدقاءك في دوري الأسبوع. امسح تمرينًا ضوئيًا وسيشرحه لك ميكا خطوة بخطوة، وشغّل مؤقّت التركيز، وأنشئ درسك المجاني من صورة أو ملف PDF.",
  sl: "Novo: zbiraj XP ob vsakem učenju, doseži dnevni cilj in se pomeri s prijatelji v tedenski ligi. Skeniraj nalogo in Mika ti jo razloži korak za korakom, zaženi časovnik za zbranost in ustvari brezplačno lekcijo iz fotografije ali PDF-ja.",
  sk: "Novinka: získavaj XP pri každom učení, splň denný cieľ a súťaž s kamarátmi v týždennej lige. Naskenuj príklad a Mika ti ho vysvetlí krok za krokom, spusti časovač sústredenia a vytvor si lekciu zadarmo z fotky alebo PDF.",
  hu: "Újdonság: szerezz XP-t minden tanulással, teljesítsd a napi célodat, és versenyezz a barátaiddal a heti ligában. Szkennelj be egy feladatot, és Mika lépésről lépésre elmagyarázza, indítsd el a fókuszidőzítőt, és készítsd el az ingyenes leckédet egy fotóból vagy PDF-ből.",
  he: "חדש: צברו XP בכל פעם שאתם לומדים, עמדו ביעד היומי והתחרו בחברים בליגה השבועית. סרקו תרגיל ומיקה יסביר אותו צעד אחר צעד, הפעילו את טיימר הריכוז וצרו את השיעור החינמי מתמונה או מ-PDF.",
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
