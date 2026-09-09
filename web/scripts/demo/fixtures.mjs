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
