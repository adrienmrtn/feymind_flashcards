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
  view_count: 0,
  adopt_count: 0,
  user_id: USER_ID,
  deleted_at: null,
  created_at: iso(day(-40 + index * 6)),
  updated_at: iso(day(-3 - index)),
  raw_text: "Texte brut du cours importé.",
  context_text: "",
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
].map((row) => ({ ...row, user_id: USER_ID, answers: [] }));

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

export const tables = {
  courses,
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
