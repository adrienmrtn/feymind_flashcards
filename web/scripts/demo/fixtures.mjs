// Données fictives d'un étudiant, pour le mode démonstration local (voir server.mjs).
// Rien ici n'est du vrai contenu : c'est un jeu de données assez réaliste pour que chaque
// écran de l'app connectée ait quelque chose à montrer.

const USER_ID = "11111111-1111-4111-8111-111111111111";
const DAY = 86_400_000;
const now = new Date();
const today = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 12);

function iso(date) {
  return date.toISOString();
}
function day(offset) {
  return new Date(today.getTime() + offset * DAY);
}
function dateOnly(date) {
  return date.toISOString().slice(0, 10);
}
function uuid(seed) {
  const hex = (seed * 2654435761 >>> 0).toString(16).padStart(8, "0");
  return `${hex}-0000-4000-8000-${hex}${hex.slice(0, 4)}`;
}
let seed = 7;
function rand() {
  seed = (seed * 16807) % 2147483647;
  return (seed - 1) / 2147483646;
}

/** Assez de matière pour qu'un examen blanc se compose sur le mode démonstration. */
const CONTEXT = [
  "L'eau circule en permanence entre les océans, l'atmosphère et les continents.",
  "Ce cycle est alimenté par l'énergie du Soleil, qui provoque l'évaporation de l'eau des océans.",
  "La vapeur se condense en altitude et forme les nuages, puis retombe en précipitations.",
  "Sur les continents, l'eau ruisselle vers les rivières ou s'infiltre pour rejoindre les nappes phréatiques.",
  "Les océans portent 97 % de l'eau de la planète, les glaciers 2 %, les eaux souterraines 0,7 %.",
  "Le temps de résidence va de quelques jours dans l'atmosphère à trois mille ans dans les océans.",
  "La quantité totale d'eau sur Terre ne change pas : elle change seulement d'état et de réservoir.",
].join(" ");

const courses = [
  { id: uuid(1), title: "Le cycle de l'eau", subject: "SVT", emoji: "💧", cards: 42, done: 0.85 },
  { id: uuid(2), title: "La Révolution française", subject: "Histoire", emoji: "🏛️", cards: 58, done: 0.55 },
  { id: uuid(3), title: "Fonctions dérivées", subject: "Mathématiques", emoji: "📐", cards: 36, done: 0.3 },
  { id: uuid(4), title: "Photosynthèse et respiration", subject: "SVT", emoji: "🌿", cards: 30, done: 0.1 },
  { id: uuid(5), title: "Present perfect vs past simple", subject: "Anglais", emoji: "🇬🇧", cards: 24, done: 0.0 },
].map((course, index) => ({
  ...course,
  summary: `Fiche de ${course.subject.toLowerCase()} : ${course.title.toLowerCase()}.`,
  accent_hex: null,
  source: index % 2 ? "pdf" : "text",
  visibility: index === 0 ? "school" : "private",
  is_from_library: false,
  // Le rangement : deux cours de SVT dans un dossier, le reste à la racine.
  folder_id: index === 0 || index === 3 ? uuid(700) : null,
  view_count: 0,
  adopt_count: 0,
  user_id: USER_ID,
  deleted_at: null,
  created_at: iso(day(-40 + index * 6)),
  updated_at: iso(day(-3 - index)),
  raw_text: "Texte brut du cours importé.",
  context_text: CONTEXT,
  sheet: sheetFor(course.title),
}));

function sheetFor(title) {
  return [
    { type: "heading", level: 1, text: title },
    {
      type: "paragraph",
      text: "L'eau circule en permanence entre les océans, l'atmosphère et les continents. Ce cycle est alimenté par l'énergie du Soleil, qui provoque l'==évaporation== de l'eau des océans.",
    },
    { type: "definition", term: "Évaporation", text: "Passage de l'eau de l'état liquide à l'état gazeux sous l'effet de la chaleur." },
    { type: "heading", level: 2, text: "Les étapes du cycle" },
    { type: "steps", title: "Dans l'ordre", items: ["Évaporation", "Condensation", "Précipitations", "Ruissellement et infiltration"] },
    { type: "callout", tone: "essentiel", text: "La quantité totale d'eau sur Terre ne change pas : elle change seulement d'état et de réservoir." },
    { type: "table", title: "Les réservoirs", headers: ["Réservoir", "Part"], rows: [["Océans", "97 %"], ["Glaciers", "2 %"], ["Eaux souterraines", "0,7 %"]] },
    { type: "chart", title: "Temps de résidence", unit: "ans", bars: [{ label: "Atmosphère", value: 0.03 }, { label: "Rivières", value: 0.05 }, { label: "Lacs", value: 10 }, { label: "Océans", value: 3000 }] },
    { type: "paragraph", text: "Les précipitations qui tombent sur les continents ruissellent vers les rivières ou s'infiltrent dans le sol pour rejoindre les nappes phréatiques." },
  ];
}

const FRONTS = [
  "Qu'est-ce que l'évaporation ?", "Quelle part de l'eau terrestre est dans les océans ?",
  "Que se passe-t-il lors de la condensation ?", "Définis le ruissellement.",
  "Quelle est la date de la prise de la Bastille ?", "Qui a rédigé la Déclaration des droits de l'homme ?",
  "Dérivée de x² ?", "Dérivée de sin(x) ?", "Que signifie f'(a) = 0 ?",
  "Équation de la photosynthèse ?", "Où se déroule la respiration cellulaire ?",
  "Quand utilise-t-on le present perfect ?", "Traduis : « Je vis ici depuis 2019 ».",
];

const cards = [];
let cardSeed = 100;
for (const course of courses) {
  for (let i = 0; i < course.cards; i++) {
    const progress = i / course.cards;
    let state, interval, due, lapses, reps;
    if (progress < course.done * 0.6) {
      state = "review"; interval = 12 + Math.round(rand() * 40); reps = 5 + Math.round(rand() * 6); lapses = rand() < 0.15 ? 1 : 0;
      due = day(Math.round(rand() * 14) - 2);
    } else if (progress < course.done) {
      state = rand() < 0.7 ? "review" : "relearning"; interval = 1 + Math.round(rand() * 5); reps = 2 + Math.round(rand() * 3); lapses = rand() < 0.5 ? 2 : 1;
      due = day(Math.round(rand() * 3) - 1);
    } else if (progress < course.done + 0.15) {
      state = "learning"; interval = 0; reps = 1; lapses = 0; due = day(0);
    } else {
      state = "new"; interval = 0; reps = 0; lapses = 0; due = day(0);
    }
    cards.push({
      id: uuid(cardSeed++),
      user_id: USER_ID,
      course_id: course.id,
      front: FRONTS[(i + cardSeed) % FRONTS.length],
      back: "Réponse de la carte, en une ou deux phrases.",
      hint: null,
      position: i,
      kind: i % 9 === 4 ? "choice" : "basic",
      choices: i % 9 === 4 ? ["Réponse A", "Réponse B", "Réponse C", "Réponse D"] : [],
      correct_choice_index: 0,
      is_suspended: false,
      state,
      due_date: iso(due),
      interval_days: interval,
      ease_factor: 2.5 - lapses * 0.2,
      repetitions: reps,
      lapses,
      step_index: 0,
      created_at: course.created_at,
      mask_x: 0, mask_y: 0, mask_width: 0, mask_height: 0,
      group_id: null, image_path: null, is_reversed: false, deleted_at: null,
    });
  }
}

const exams = [
  { id: uuid(900), name: "Partiel de SVT", offset: 9, course_ids: [courses[0].id, courses[3].id], kind: "written", starting_point: "mixed", intensity: "standard" },
  { id: uuid(901), name: "Contrôle d'histoire", offset: 23, course_ids: [courses[1].id], kind: "written", starting_point: "cold", intensity: "intense" },
  { id: uuid(902), name: "Bac blanc de maths", offset: 41, course_ids: [courses[2].id], kind: "written", starting_point: "cold", intensity: "standard" },
  { id: uuid(903), name: "Oral d'anglais", offset: -12, course_ids: [courses[4].id], kind: "oral", starting_point: "cold", intensity: "light" },
].map((exam) => ({
  id: exam.id,
  user_id: USER_ID,
  name: exam.name,
  exam_date: dateOnly(day(exam.offset)),
  intensity: exam.intensity,
  target_score: 75,
  course_ids: exam.course_ids,
  is_planned: true,
  kind: exam.kind,
  formats: [],
  chapter_ids: [],
  starting_point: exam.starting_point,
  deleted_at: null,
}));

// Journal de révision : 45 jours, avec des jours sautés et un rythme qui monte.
const review_logs = [];
let logSeed = 5000;
for (let offset = -45; offset <= 0; offset++) {
  const weekday = day(offset).getDay();
  const skip = rand() < (weekday === 0 ? 0.6 : 0.18);
  if (skip && offset !== 0) continue;
  const count = Math.round(8 + rand() * 26 + Math.max(0, offset + 45) * 0.4);
  for (let i = 0; i < count; i++) {
    const card = cards[Math.floor(rand() * cards.length)];
    const rating = rand() < 0.22 ? 1 : rand() < 0.3 ? 2 : rand() < 0.7 ? 3 : 4;
    review_logs.push({
      id: uuid(logSeed++),
      user_id: USER_ID,
      card_id: card.id,
      reviewed_at: iso(new Date(day(offset).getTime() + 6 * 3600_000 + i * 45_000)),
      rating,
      state_before: card.state === "new" ? "new" : "review",
      previous_interval_days: card.interval_days,
      new_interval_days: card.interval_days * 1.6,
      ease_after: card.ease_factor,
    });
  }
}

const mock_sessions = [
  { id: uuid(700), exam_id: exams[0].id, planned_for: dateOnly(day(-6)), minutes: 12, question_count: 20, correct_count: 11, started_at: iso(day(-6)), finished_at: iso(new Date(day(-6).getTime() + 12 * 60_000)) },
  { id: uuid(701), exam_id: exams[0].id, planned_for: dateOnly(day(-2)), minutes: 12, question_count: 20, correct_count: 14, started_at: iso(day(-2)), finished_at: iso(new Date(day(-2).getTime() + 11 * 60_000)) },
  { id: uuid(702), exam_id: exams[3].id, planned_for: dateOnly(day(-15)), minutes: 10, question_count: 15, correct_count: 12, started_at: iso(day(-15)), finished_at: iso(new Date(day(-15).getTime() + 10 * 60_000)) },
].map((row) => ({
  ...row,
  user_id: USER_ID,
  answers: [],
  questions: [],
  grades: [],
  debrief: null,
  with_audio: false,
}));

const profiles = [{
  id: USER_ID,
  display_name: "Camille",
  username: "camille",
  country_code: "fr",
  study_level: "lycee",
  subjects: ["SVT", "Histoire", "Mathématiques", "Anglais"],
  institution_name: "Lycée Henri-IV",
  institution_id: "fr-0750654",
  daily_minutes: 30,
  weekly_minutes: [30, 30, 30, 30, 20, 45, 0],
  sheet_length: "standard",
  sheet_language: "fr",
  tour_seen: ["plan", "reviser", "cours", "progres", "profil"],
  tour_skipped: true,
}];

const directory = [
  { id: USER_ID, username: "camille", institution_id: "fr-0750654", institution_name: "Lycée Henri-IV" },
  { id: uuid(801), username: "lea.m", institution_id: "fr-0750654", institution_name: "Lycée Henri-IV" },
  { id: uuid(802), username: "noah", institution_id: "fr-0750654", institution_name: "Lycée Henri-IV" },
  { id: uuid(803), username: "inès", institution_id: "fr-0750001", institution_name: "Lycée Louis-le-Grand" },
];

const friendships = [
  { requester_id: USER_ID, addressee_id: uuid(801), status: "accepted", created_at: iso(day(-20)) },
  { requester_id: uuid(802), addressee_id: USER_ID, status: "pending", created_at: iso(day(-1)) },
];

const entitlements = [{ user_id: USER_ID, is_pro: true, product_id: "micabo.pro.annual", store: "app_store", period_type: "normal", expires_at: iso(day(200)), will_renew: true }];

const availability_exceptions = [
  { user_id: USER_ID, day: dateOnly(day(4)), minutes: 0 },
  { user_id: USER_ID, day: dateOnly(day(5)), minutes: 0 },
  { user_id: USER_ID, day: dateOnly(day(16)), minutes: 90 },
];

export const USER = { id: USER_ID, email: "camille@micabo.test" };

const course_folders = [
  { id: uuid(700), user_id: USER_ID, parent_id: null, name: "SVT", emoji: "🧬", position: 0 },
  { id: uuid(701), user_id: USER_ID, parent_id: uuid(700), name: "Terminale", emoji: null, position: 0 },
  { id: uuid(702), user_id: USER_ID, parent_id: null, name: "Langues", emoji: "🗣️", position: 1 },
].map((folder) => ({
  ...folder,
  deleted_at: null,
  created_at: iso(day(-30)),
  updated_at: iso(day(-2)),
}));

// **Une leçon au nouveau format**, déjà écrite : son chemin, ses thèmes avec leurs notes et
// leurs questions des cinq formes, une progression entamée. C'est elle qu'on ouvre pour voir
// les étapes sans passer par une conversion.
const LESSON_ID = uuid(6);
const THEME_IDS = [uuid(61), uuid(62), uuid(63), uuid(64)];
const lesson = {
  id: LESSON_ID,
  title: "La Guerre froide",
  subject: "Histoire",
  emoji: "🧊",
  summary: "Deux blocs, un monde partagé, de 1947 à 1991.",
  accent_hex: null,
  source: "topic",
  visibility: "private",
  is_from_library: false,
  folder_id: null,
  view_count: 0,
  adopt_count: 0,
  user_id: USER_ID,
  deleted_at: null,
  created_at: iso(day(-4)),
  updated_at: iso(day(-1)),
  raw_text: "",
  context_text: "",
  sheet: null,
  language: "fr",
  tone: "blue",
  icon: "globe",
  last_opened_at: iso(day(-1)),
  path: {
    version: 1,
    icon: "globe",
    intro: {
      lines: ["Pourquoi deux alliés de 1945 deviennent **ennemis** en deux ans.", "Comment le monde se partage en **deux blocs**, sans guerre directe.", "Ce qui fait tomber le mur, puis l'URSS."],
      minutes: 25,
    },
    takeaways: [
      "La Guerre froide oppose deux **modèles**, pas deux armées sur un champ de bataille.",
      "La **dissuasion nucléaire** interdit l'affrontement direct : on se bat par alliés interposés.",
      "Berlin est le **symbole** du partage, de 1948 à 1989.",
      "La détente ne met pas fin à la rivalité : elle la rend vivable.",
      "L'URSS s'effondre de l'intérieur, en 1991, sans un coup de feu.",
    ],
    groups: [
      { name: "Les causes", themes: [0, 1] },
      { name: "Les crises", themes: [2, 3] },
    ],
    shortened: false,
    singleQuiz: false,
    status: "ready",
    symbols: ["globe", "flag", "wall", "handshake"],
  },
  progress: { done: ["intro", "notes:0"], inCircle: 0.4, quizScores: {}, missed: [], seconds: { notes: 540 }, finishedAt: null },
};
courses.push(lesson);

function q(theme, rank, question) {
  return { id: `${theme}:${rank}`, difficulty: 1 + (rank % 3), ...question };
}

const chapters = [
  {
    id: THEME_IDS[0], position: 0, title: "La rupture de 1947", icon: "globe", status: "ready",
    notes: {
      oneLiner: "En 1947, les **États-Unis** et l'**URSS** passent d'alliés à adversaires, chacun avec sa doctrine.",
      blocks: [
        { type: "subtitle", text: "Deux camps" },
        { type: "paragraph", text: "Les États-Unis défendent le **capitalisme** et la démocratie libérale ; l'URSS, le **communisme** et le parti unique. Les deux veulent étendre leur modèle." },
        { type: "callout", kind: "why", title: "Deux visions du monde", text: "Chacun croit que l'autre veut dominer l'Europe : la méfiance précède les actes." },
        { type: "definition", term: "Endiguement", text: "La politique américaine qui vise à **contenir** l'expansion soviétique, sans attaquer l'URSS." },
        { type: "dates", items: [{ date: "mars 1947", text: "Doctrine Truman : aide aux pays menacés" }, { date: "juin 1947", text: "Plan Marshall : 13 milliards pour l'Europe" }, { date: "oct. 1947", text: "Doctrine Jdanov : le monde en deux camps" }] },
        { type: "list", items: ["La doctrine Truman répond à la crise grecque.", "Le plan Marshall est refusé par l'URSS et ses satellites.", "Le Kominform coordonne les partis communistes."] },
      ],
      takeaways: ["1947 : deux doctrines, deux camps, plus de retour en arrière.", "L'endiguement est une politique de **défense**, pas d'attaque."],
    },
    quiz: { questions: [
      q(THEME_IDS[0], 0, { kind: "choice", prompt: "Que vise l'**endiguement** ?", choices: ["Envahir l'URSS", "Contenir l'expansion soviétique", "Partager Berlin", "Signer la paix"], answer: 1, why: "Contenir, pas attaquer : c'est toute la doctrine Truman." }),
      q(THEME_IDS[0], 1, { kind: "truefalse", prompt: "Le plan Marshall est accepté par l'URSS.", choices: ["Vrai", "Faux"], answer: 1, why: "L'URSS le refuse et l'interdit à ses satellites." }),
      q(THEME_IDS[0], 2, { kind: "gap", prompt: "La doctrine ____ affirme que le monde se partage en deux camps.", choices: ["Jdanov", "Truman", "Marshall", "Monroe"], answer: 0, why: "Jdanov, en octobre 1947, répond à Truman." }),
      q(THEME_IDS[0], 3, { kind: "order", prompt: "Remets ces événements de 1947 dans l'ordre.", choices: ["Doctrine Truman", "Plan Marshall", "Doctrine Jdanov"], answer: 0, why: "Mars, juin, octobre." }),
    ] },
  },
  {
    id: THEME_IDS[1], position: 1, title: "Le blocus de Berlin", icon: "fiole", status: "ready",
    notes: {
      oneLiner: "En 1948, Staline **bloque** Berlin-Ouest ; les Occidentaux répondent par un **pont aérien** de onze mois.",
      blocks: [
        { type: "paragraph", text: "Berlin, enclavée en zone soviétique, est coupée en quatre. Quand les Occidentaux créent le **Deutsche Mark**, Staline ferme routes et voies ferrées." },
        { type: "steps", items: ["Juin 1948 : réforme monétaire à l'Ouest.", "Blocus des accès terrestres à Berlin-Ouest.", "Pont aérien : un avion toutes les trois minutes.", "Mai 1949 : Staline lève le blocus."] },
        { type: "table", columns: ["Camp", "Réponse"], rows: [["URSS", "Blocus terrestre"], ["Occidentaux", "Pont aérien"], ["Résultat", "Deux Allemagnes en 1949"]] },
        { type: "quote", text: "Nous resterons à Berlin, quoi qu'il arrive.", author: "Harry Truman" },
        { type: "formula", latex: "277\\,000 \\text{ vols} \\approx 2{,}3 \\text{ Mt de fret}", caption: "Le pont aérien en chiffres" },
        { type: "callout", kind: "mistake", title: null, text: "Le **mur** ne date pas du blocus : il est construit en **1961**, treize ans plus tard." },
      ],
      takeaways: ["Le blocus échoue : le pont aérien tient onze mois.", "1949 : RFA à l'Ouest, RDA à l'Est."],
    },
    quiz: { questions: [
      q(THEME_IDS[1], 0, { kind: "choice", prompt: "Comment les Occidentaux répondent-ils au blocus ?", choices: ["Par un pont aérien", "Par une invasion", "En quittant Berlin", "Par un nouveau blocus"], answer: 0, why: "Un avion toutes les trois minutes, pendant onze mois." }),
      q(THEME_IDS[1], 1, { kind: "match", prompt: "Associe chaque date à son événement.", choices: ["1948", "1949", "1961"], matches: ["Blocus de Berlin", "Deux Allemagnes", "Construction du mur"], answer: 0, why: "Blocus, partition, puis le mur." }),
      q(THEME_IDS[1], 2, { kind: "choice", prompt: "Qu'est-ce qui déclenche le blocus ?", choices: ["La réforme monétaire à l'Ouest", "La mort de Staline", "La création de l'OTAN", "Le plan Marshall"], answer: 0, why: "Le Deutsche Mark, en juin 1948." }),
      q(THEME_IDS[1], 3, { kind: "truefalse", prompt: "Le blocus de Berlin dure onze mois.", choices: ["Vrai", "Faux"], answer: 0, why: "De juin 1948 à mai 1949." }),
    ] },
  },
  {
    id: THEME_IDS[2], position: 2, title: "La crise des missiles", icon: "ampoule", status: "ready",
    notes: {
      oneLiner: "En octobre 1962, des **missiles soviétiques à Cuba** mènent le monde au bord de la guerre nucléaire.",
      blocks: [
        { type: "paragraph", text: "Kennedy impose un **blocus naval** de Cuba. Treize jours de tension, puis Khrouchtchev retire les missiles contre la promesse de ne pas envahir l'île." },
        { type: "callout", kind: "remember", title: "La dissuasion", text: "Quand chacun peut détruire l'autre, personne n'attaque : c'est l'**équilibre de la terreur**." },
        { type: "example", text: "Le « téléphone rouge » entre Washington et Moscou est installé en 1963, pour éviter qu'un malentendu dégénère." },
      ],
      takeaways: ["Treize jours : le point le plus chaud de la Guerre froide.", "La crise ouvre la **détente**."],
    },
    quiz: { questions: [
      q(THEME_IDS[2], 0, { kind: "choice", prompt: "Que fait Kennedy face aux missiles à Cuba ?", choices: ["Un blocus naval", "Une invasion", "Rien", "Un bombardement"], answer: 0, why: "La « quarantaine » de l'île, sans attaque directe." }),
      q(THEME_IDS[2], 1, { kind: "gap", prompt: "La crise de Cuba a lieu en octobre ____.", choices: ["1962", "1956", "1968", "1973"], answer: 0, why: "Octobre 1962, treize jours." }),
      q(THEME_IDS[2], 2, { kind: "truefalse", prompt: "La crise se termine par le retrait des missiles soviétiques.", choices: ["Vrai", "Faux"], answer: 0, why: "Contre la promesse de ne pas envahir Cuba." }),
    ] },
  },
  {
    id: THEME_IDS[3], position: 3, title: "La chute du mur", icon: "loupe", status: "ready",
    notes: {
      oneLiner: "Le 9 novembre 1989, le **mur de Berlin** s'ouvre ; deux ans plus tard, l'URSS disparaît.",
      blocks: [
        { type: "paragraph", text: "Gorbatchev réforme l'URSS (**glasnost**, **perestroïka**) et renonce à intervenir chez ses satellites. Les régimes communistes tombent l'un après l'autre en 1989." },
        { type: "list", items: ["Juin 1989 : élections libres en Pologne.", "9 novembre 1989 : ouverture du mur.", "3 octobre 1990 : réunification allemande.", "25 décembre 1991 : dissolution de l'URSS."] },
        { type: "callout", kind: "tip", title: "Pour retenir", text: "1989 pour le mur, 1991 pour l'URSS : deux ans d'écart." },
      ],
      takeaways: ["La fin vient de l'intérieur du bloc de l'Est.", "1991 : fin de la Guerre froide."],
    },
    quiz: { questions: [
      q(THEME_IDS[3], 0, { kind: "choice", prompt: "Quand le mur de Berlin s'ouvre-t-il ?", choices: ["9 novembre 1989", "3 octobre 1990", "25 décembre 1991", "13 août 1961"], answer: 0, why: "Le 9 novembre 1989, un soir de conférence de presse ratée." }),
      q(THEME_IDS[3], 1, { kind: "order", prompt: "Remets dans l'ordre.", choices: ["Ouverture du mur", "Réunification allemande", "Dissolution de l'URSS"], answer: 0, why: "1989, 1990, 1991." }),
      q(THEME_IDS[3], 2, { kind: "choice", prompt: "Que signifie **glasnost** ?", choices: ["Transparence", "Reconstruction", "Révolution", "Endiguement"], answer: 0, why: "La transparence ; la perestroïka est la reconstruction." }),
    ] },
  },
].map((chapter) => ({ ...chapter, user_id: USER_ID, course_id: LESSON_ID, sheet: null, deleted_at: null, created_at: iso(day(-4)), updated_at: iso(day(-4)) }));

// Quelques cartes pour la leçon : trois neuves, deux dues, une question ratée.
let lessonCardSeed = 800;
for (const [index, [front, back, extra]] of [
  ["Qui annonce la doctrine de l'endiguement ?", "Truman, en mars 1947.", { state: "review", interval: 30, due: day(-1) }],
  ["Que vise l'**endiguement** ?", "Contenir, pas attaquer : c'est toute la doctrine Truman.", { kind: "choice", choices: ["Envahir l'URSS", "Contenir l'expansion soviétique", "Partager Berlin", "Signer la paix"], correct: 1, state: "learning", interval: 0, due: day(0) }],
  ["Combien de temps dure le blocus de Berlin ?", "Onze mois, de juin 1948 à mai 1949.", { state: "review", interval: 6, due: day(-2) }],
  ["Que signifie glasnost ?", "Transparence.", { state: "new" }],
  ["En quelle année l'URSS disparaît-elle ?", "1991.", { state: "new" }],
  ["Le téléphone rouge est installé en ____.", "1963", { kind: "cloze", state: "new" }],
].entries()) {
  cards.push({
    id: uuid(lessonCardSeed++), user_id: USER_ID, course_id: LESSON_ID, chapter_id: THEME_IDS[index % 4],
    front, back, hint: null, position: index,
    kind: extra.kind ?? "basic", choices: extra.choices ?? [], correct_choice_index: extra.correct ?? 0,
    is_suspended: false, state: extra.state, due_date: iso(extra.due ?? day(0)),
    interval_days: extra.interval ?? 0, ease_factor: 2.5, repetitions: extra.state === "new" ? 0 : 3, lapses: 0, step_index: 0,
    created_at: iso(day(-4)), mask_x: 0, mask_y: 0, mask_width: 0, mask_height: 0, group_id: null, image_path: null, is_reversed: false, deleted_at: null,
  });
}

export const tables = {
  courses,
  course_folders,
  flashcards: cards,
  exams,
  review_logs,
  mock_sessions,
  profiles,
  directory,
  friendships,
  entitlements,
  availability_exceptions,
  feedback: [],
  // La refonte « parcours » : les thèmes d'une leçon, et les tables de la porte du gratuit.
  // Vides au départ : un cours de démonstration est un ancien cours, qui se convertit à
  // l'ouverture et remplit `chapters` en mémoire.
  chapters,
  lesson_generations: [],
  lesson_extras: [],
};

export function rpc(name, args) {
  const sinceDays = Number(args?.since_days ?? 120);
  const since = day(-sinceDays).getTime();
  const logs = review_logs.filter((log) => new Date(log.reviewed_at).getTime() >= since);
  switch (name) {
    case "card_difficulty": {
      const map = new Map();
      for (const log of logs) {
        const row = map.get(log.card_id) ?? { card_id: log.card_id, reviews: 0, again_count: 0, hard_count: 0, last_rating: null, last_reviewed_at: null };
        row.reviews++;
        if (log.rating === 1) row.again_count++;
        if (log.rating === 2) row.hard_count++;
        if (!row.last_reviewed_at || row.last_reviewed_at < log.reviewed_at) {
          row.last_reviewed_at = log.reviewed_at;
          row.last_rating = log.rating;
        }
        map.set(log.card_id, row);
      }
      return [...map.values()];
    }
    case "review_daily_counts": {
      const map = new Map();
      for (const log of logs) {
        const key = log.reviewed_at.slice(0, 10);
        const row = map.get(key) ?? { day: key, passes: 0, again_count: 0 };
        row.passes++;
        if (log.rating === 1) row.again_count++;
        map.set(key, row);
      }
      return [...map.values()].sort((a, b) => (a.day < b.day ? -1 : 1));
    }
    case "review_throughput":
      return [{ cards: logs.length, seconds: logs.length * 42, cards_per_minute: 1.43, sessions: 30 }];
    case "count_flashcards_by_course":
      return (args?.p_courses ?? []).map((id) => ({ course_id: id, card_count: cards.filter((c) => c.course_id === id).length }));
    case "week_review_ranking":
      return [
        { user_id: uuid(801), username: "lea.m", passes: 212 },
        { user_id: USER_ID, username: "camille", passes: 168 },
        { user_id: uuid(802), username: "noah", passes: 97 },
      ];
    case "record_course_view":
    case "record_course_adopt":
      return null;
    // Les portes du gratuit (`begin_lesson`, `begin_extra`) : la démonstration est Pro, tout
    // passe. Le site ne les appelle pas lui-même, la fonction `generate-lesson` le fait.
    case "begin_lesson":
    case "begin_extra":
      return "ok";
    case "refund_extra":
    case "lesson_theme_call":
      return null;
    case "is_pro":
      return true;
    default:
      return [];
  }
}

/**
 * Les fonctions Edge, en dur.
 *
 * Le mode démonstration ne parle à aucun modèle : il rend une copie d'examen blanc et un
 * débriefing écrits à la main, assez réalistes pour que les écrans se regardent.
 */
export function edgeFunction(name, body) {
  // `generate-lesson`, étape « convert » : ce qu'un ancien cours reçoit pour devenir une leçon.
  // Le modèle n'est pas là ; on rend une conversion plausible, deux questions par chapitre.
  if (name === "generate-lesson" && body?.stage === "convert") {
    const chapters = Array.isArray(body.chapters) ? body.chapters : [];
    const size = chapters.length > 8 ? 3 : 2;
    const groups = [];
    for (let start = 0; start < chapters.length; start += size) {
      groups.push({ name: ["Les bases", "Les mécanismes", "Les chiffres", "Pour aller plus loin"][groups.length % 4], themes: chapters.slice(start, start + size).map((_, offset) => start + offset) });
    }
    return {
      conversion: {
        icon: "globe",
        intro: { lines: ["D'où vient l'eau qui tombe.", "Comment elle circule.", "Où elle finit."], minutes: 5 + chapters.length * 3 },
        takeaways: ["L'eau change d'état, jamais de quantité.", "Le Soleil est le moteur du cycle.", "Les océans portent 97 % de l'eau."],
        groups,
        chapters: chapters.map((chapter, index) => ({
          icon: ["globe", "fiole", "ampoule", "loupe"][index % 4],
          questions: CHOICES.slice(0, 3).map((question, number) => ({
            kind: "choice",
            prompt: `${chapter.title} — ${question.prompt}`,
            choices: question.choices,
            answer: question.answerIndex,
            why: question.why,
            difficulty: 1 + (number % 3),
          })),
          flashcards: chapter.needsCards ? [{ front: `Que retenir de « ${chapter.title} » ?`, back: "L'essentiel du chapitre, en une phrase." }] : [],
        })),
      },
    };
  }
  // `generate-lesson`, étape « plan » : un plan plausible, quatre thèmes, depuis le sujet ou le texte.
  if (name === "generate-lesson" && body?.stage === "plan") {
    const topic = typeof body.topic === "string" && body.topic.trim() ? body.topic.trim() : null;
    const title = topic ? topic.charAt(0).toUpperCase() + topic.slice(1) : "Le cycle de l'eau";
    return {
      plan: {
        title,
        subject: topic ? "Histoire" : "SVT",
        icon: topic ? "parchemin" : "globe",
        material: topic ? "topic" : "chapter",
        themes: [
          { title: "Les bases", icon: "livre-ouvert", symbol: "book.closed", points: ["Définitions", "Vocabulaire"], role: "ground" },
          { title: "Les mécanismes", icon: "fiole", symbol: "testtube.2", points: ["Causes", "Effets"], role: "mechanism" },
          { title: "Les chiffres", icon: "calculatrice", symbol: "number", points: ["Ordres de grandeur"], role: "ground" },
          { title: "Pour aller plus loin", icon: "fusee", symbol: "sparkles", points: ["Limites", "Débats"], role: "synthesis" },
        ],
        groups: [{ name: "Comprendre", themes: [0, 1] }, { name: "Mesurer", themes: [2, 3] }],
        intro: { lines: [`Ce que « ${title} » veut dire.`, "Comment ça marche, étape par étape.", "Les chiffres à retenir."], minutes: 22 },
        takeaways: ["Une idée simple, à savoir redire.", "Les mécanismes expliquent les chiffres.", "Les limites comptent autant que le modèle."],
        shortened: false,
        singleQuiz: false,
      },
      contextText: topic ? "" : String(body.text ?? "").slice(0, 60_000),
    };
  }

  // Étape « thème » : des notes courtes et quatre questions, avec un délai pour voir le chemin
  // se remplir rond après rond.
  if (name === "generate-lesson" && body?.stage === "theme") {
    const index = Number(body.themeIndex ?? 0);
    const titles = Array.isArray(body.themes) ? body.themes : [];
    const themeTitle = titles[index] ?? `Thème ${index + 1}`;
    const theme = {
      notes: {
        oneLiner: `**${themeTitle}** : l'idée en une phrase, pour commencer.`,
        blocks: [
          { type: "subtitle", text: "L'essentiel" },
          { type: "paragraph", text: `Ce thème explique **${themeTitle.toLowerCase()}** avec des mots simples et un exemple à chaque fois.` },
          { type: "list", items: ["Un premier point à retenir.", "Un deuxième, avec un **mot-clé**.", "Un troisième, plus court."] },
          { type: "callout", kind: index % 2 ? "tip" : "remember", title: null, text: "La règle que l'on oublie le plus souvent." },
        ],
        takeaways: [`${themeTitle} tient en une idée.`, "Un exemple vaut mieux qu'une définition."],
      },
      questions: [
        { kind: "choice", prompt: `Quelle idée résume « ${themeTitle} » ?`, choices: ["La bonne", "Une fausse", "Une autre fausse", "La dernière"], answer: 0, why: "C'est l'idée de la phrase d'ouverture.", difficulty: 1 },
        { kind: "truefalse", prompt: `« ${themeTitle} » se résume en une phrase.`, choices: ["Vrai", "Faux"], answer: 0, why: "C'est le principe des notes.", difficulty: 1 },
        { kind: "gap", prompt: "Un exemple vaut mieux qu'une ____.", choices: ["définition", "liste", "formule", "date"], answer: 0, why: "C'est la deuxième phrase à retenir.", difficulty: 2 },
        { kind: "order", prompt: "Remets les points dans l'ordre des notes.", choices: ["Le premier point", "Le deuxième point", "Le troisième point"], answer: 0, why: "L'ordre de la liste.", difficulty: 3 },
      ],
      flashcards: [
        { kind: "basic", front: `Que retenir de « ${themeTitle} » ?`, back: "Une idée simple, et un exemple." },
        { kind: "cloze", front: "Un exemple vaut mieux qu'une ____.", back: "définition" },
      ],
    };
    return new Promise((resolve) => setTimeout(() => resolve({ theme }), 1500 + index * 900));
  }

  // Étape « exam » : une copie de la taille demandée, qui alterne les leçons et les formes.
  if (name === "generate-lesson" && body?.stage === "exam") {
    const lessons = Array.isArray(body.lessons) ? body.lessons : [];
    const count = Math.max(6, Math.min(30, Number(body.count ?? 10)));
    const questions = [];
    for (let i = 0; i < count; i++) {
      const lesson = lessons.length ? i % lessons.length : 0;
      const themes = Array.isArray(lessons[lesson]?.themes) ? lessons[lesson].themes.length : 1;
      const theme = themes ? i % themes : 0;
      const themeTitle = lessons[lesson]?.themes?.[theme]?.title ?? "ce thème";
      const kind = ["choice", "truefalse", "gap", "choice", "order", "match"][i % 6];
      const base = { lesson, theme, why: `C'est ce que disent les notes de « ${themeTitle} ».`, difficulty: 1 + (i % 3) };
      if (kind === "truefalse") questions.push({ ...base, kind, prompt: `« ${themeTitle} » se résume en une idée.`, choices: ["Vrai", "Faux"], answer: 0 });
      else if (kind === "gap") questions.push({ ...base, kind, prompt: `Le thème « ${themeTitle} » tient en une ____.`, choices: ["idée", "liste", "formule", "date"], answer: 0 });
      else if (kind === "order") questions.push({ ...base, kind, prompt: "Remets les étapes dans l'ordre.", choices: ["Lire", "Comprendre", "Retenir"], answer: 0 });
      else if (kind === "match") questions.push({ ...base, kind, prompt: "Associe chaque terme à sa définition.", choices: ["Lire", "Comprendre", "Retenir"], matches: ["Parcourir le texte", "Saisir l'idée", "Garder en mémoire"], answer: 0 });
      else questions.push({ ...base, kind, prompt: `Question ${i + 1} sur « ${themeTitle} » : quelle idée la résume ?`, choices: ["La bonne", "Une fausse", "Une autre", "La dernière"], answer: 0 });
    }
    return new Promise((resolve) => setTimeout(() => resolve({ exam: { title: body.examTitle || "Examen blanc", questions } }), 1200));
  }

  // Étape « practice » : dix questions neuves, sur les thèmes demandés.
  if (name === "generate-lesson" && body?.stage === "practice") {
    const themes = Array.isArray(body.practiceThemes) ? body.practiceThemes : [];
    const count = Math.max(4, Math.min(20, Number(body.count ?? 10)));
    const stamp = Date.now() % 1000;
    const questions = Array.from({ length: count }, (_, i) => {
      const theme = themes.length ? i % themes.length : 0;
      const title = themes[theme]?.title ?? "ce thème";
      return i % 3 === 1
        ? { kind: "truefalse", prompt: `Nouvelle question ${stamp}-${i + 1} : « ${title} » a une idée centrale.`, choices: ["Vrai", "Faux"], answer: 0, why: "Toujours.", theme, difficulty: 1 + (i % 3) }
        : { kind: "choice", prompt: `Nouvelle question ${stamp}-${i + 1} sur « ${title} » ?`, choices: ["La bonne", "Une fausse", "Une autre", "La dernière"], answer: 0, why: "C'est dans les notes.", theme, difficulty: 1 + (i % 3) };
    });
    return new Promise((resolve) => setTimeout(() => resolve({ questions }), 1200));
  }

  // `transcribe-audio` : un enregistrement devient du texte.
  if (name === "transcribe-audio") {
    return { transcript: { text: "Bonjour à tous, aujourd'hui nous allons voir le cycle de l'eau. L'eau circule en permanence entre les océans, l'atmosphère et les continents, et ce cycle est alimenté par l'énergie du Soleil." } };
  }

  // `mika-chat` : Mika répond, et propose une carte quand il y a quelque chose à retenir.
  if (name === "mika-chat") {
    const turns = Array.isArray(body?.messages) ? body.messages : [];
    const last = turns[turns.length - 1]?.text ?? "";
    const title = body?.attachment?.title ?? "ta leçon";
    return {
      answer: {
        reply: `Sur « ${title} », voici l'essentiel : le **Soleil** chauffe l'eau des océans, elle s'évapore, se condense en nuages, puis retombe en pluie.\n\nTu m'as demandé : « ${last.slice(0, 80)} ». Dis-moi si tu veux un exemple.`,
        card: { front: "Qu'est-ce qui fournit l'énergie du cycle de l'eau ?", back: "Le rayonnement solaire : c'est lui qui provoque l'évaporation." },
      },
    };
  }

  if (name === "generate-mock") {
    const quota = body?.quota ?? { choice: 9, truefalse: 5, gap: 3, feynman: 3 };
    const questions = [];
    for (let i = 0; i < (quota.choice ?? 0); i++) {
      questions.push({
        kind: "choice",
        prompt: CHOICES[i % CHOICES.length].prompt,
        choices: CHOICES[i % CHOICES.length].choices,
        answerIndex: CHOICES[i % CHOICES.length].answerIndex,
        why: CHOICES[i % CHOICES.length].why,
      });
    }
    for (let i = 0; i < (quota.truefalse ?? 0); i++) {
      questions.push({ kind: "truefalse", ...TRUEFALSE[i % TRUEFALSE.length] });
    }
    for (let i = 0; i < (quota.gap ?? 0); i++) {
      questions.push({ kind: "gap", ...GAPS[i % GAPS.length] });
    }
    for (let i = 0; i < (quota.feynman ?? 0); i++) {
      questions.push({ kind: "feynman", ...FEYNMAN[i % FEYNMAN.length] });
    }
    return { questions };
  }

  if (name === "grade-mock") {
    return {
      grades: (body?.spoken ?? []).map((answer, index) => ({
        id: answer.id,
        score: [80, 45, 100][index % 3],
        comment:
          "Tu nommes bien les étapes, mais tu ne dis pas ce qui fournit l'énergie du cycle.",
      })),
      debrief: {
        headline: "Le vocabulaire est là ; les mécanismes tiennent moins bien.",
        strengths: [
          "Les quatre étapes du cycle sont sues dans l'ordre.",
          "Les proportions des réservoirs sont acquises.",
        ],
        gaps: [
          "Le moteur du cycle : l'énergie solaire n'est jamais citée.",
          "Condensation et précipitation sont confondues.",
        ],
        advice:
          "Reprends la page « les étapes du cycle » et redis-la à voix haute sans la fiche. Repasse un blanc dans trois jours.",
      },
    };
  }

  // La fiche d'un document importé. Sans elle, tout le parcours de création d'un plan
  // s'arrêtait au premier document : la fiche revenait vide et l'écriture échouait.
  if (name === "generate-course") {
    const title = (body?.title ?? "").trim() || "Cours importé";
    return {
      course: {
        title,
        emoji: "📘",
        subject: "svt",
        summary: `Fiche de démonstration : ${title.toLowerCase()}.`,
        sheet: {
          blocks: [
            { type: "heading", text: title },
            {
              type: "paragraph",
              text: "Ce paragraphe vient du faux Supabase : il tient lieu de fiche pour que le parcours aille jusqu'au bout.",
            },
            {
              type: "definition",
              term: "Notion clé",
              text: "La définition que le modèle aurait écrite, en une phrase.",
            },
            {
              type: "list",
              title: "Dans l'ordre",
              items: ["Première étape", "Deuxième étape", "Troisième étape"],
              ordered: true,
            },
          ],
        },
      },
    };
  }

  if (name === "generate-flashcards") {
    return {
      cards: Array.from({ length: 12 }, (_, index) => ({
        kind: index % 3 === 0 ? "choice" : index % 3 === 1 ? "cloze" : "basic",
        front: FRONTS[index % FRONTS.length],
        back: "Réponse de la carte, en une ou deux phrases.",
        choices: index % 3 === 0 ? ["Réponse A", "Réponse B", "Réponse C", "Réponse D"] : undefined,
        answerIndex: index % 3 === 0 ? 0 : undefined,
      })),
    };
  }

  return {};
}

const CHOICES = [
  {
    prompt: "Quelle part de l'eau terrestre est contenue dans les océans ?",
    choices: ["Environ 50 %", "Environ 72 %", "Environ 97 %", "Environ 99,5 %"],
    answerIndex: 2,
    why: "Les océans portent 97 % de l'eau de la planète ; les glaciers 2 %.",
  },
  {
    prompt: "Qu'est-ce qui fournit l'énergie du cycle de l'eau ?",
    choices: ["La rotation terrestre", "Le rayonnement solaire", "Le magnétisme", "Les marées"],
    answerIndex: 1,
    why: "C'est le Soleil qui provoque l'évaporation, donc tout le reste du cycle.",
  },
  {
    prompt: "Où l'eau réside-t-elle le plus longtemps ?",
    choices: ["Dans l'atmosphère", "Dans les rivières", "Dans les lacs", "Dans les océans"],
    answerIndex: 3,
    why: "Le temps de résidence océanique est de l'ordre de trois mille ans.",
  },
];

const TRUEFALSE = [
  {
    prompt: "La quantité totale d'eau sur Terre augmente chaque année.",
    answer: false,
    why: "Elle ne change pas : l'eau change d'état et de réservoir, pas de quantité.",
  },
  {
    prompt: "La condensation transforme la vapeur d'eau en gouttelettes.",
    answer: true,
    why: "C'est l'étape qui forme les nuages, juste après l'évaporation.",
  },
  {
    prompt: "Les eaux souterraines représentent plus du dixième de l'eau terrestre.",
    answer: false,
    why: "Elles en représentent environ 0,7 %.",
  },
];

const GAPS = [
  {
    prompt: "Le passage de l'eau de l'état liquide à l'état gazeux s'appelle l'…",
    answer: "évaporation",
    accepts: ["vaporisation"],
    why: "C'est la première étape du cycle, provoquée par la chaleur du Soleil.",
  },
  {
    prompt: "L'eau qui s'infiltre dans le sol rejoint les nappes …",
    answer: "phréatiques",
    accepts: [],
    why: "Le reste des précipitations ruisselle vers les rivières.",
  },
];

const FEYNMAN = [
  {
    prompt: "Explique le cycle de l'eau à quelqu'un qui ne l'a jamais vu.",
    expected:
      "Le Soleil évapore l'eau des océans, la vapeur se condense en nuages, retombe en précipitations, puis ruisselle ou s'infiltre avant de rejoindre les océans.",
  },
  {
    prompt: "Pourquoi la quantité d'eau sur Terre ne change-t-elle pas ?",
    expected: "C'est un cycle fermé : l'eau change d'état et de réservoir, jamais de quantité.",
  },
];
