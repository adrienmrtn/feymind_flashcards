import "server-only";

import { DEFAULT_VISIBILITY, emptyProgress, normalizeClozeGap, type LessonPath, type QuizQuestion, type SheetBlock, type ThemeQuiz } from "@micabo/core";

import { revalidateUserData } from "@/lib/data/cache";
import type { Translator } from "@/lib/i18n/copy";
import { createClient } from "@/lib/supabase/server";

/**
 * **La leçon de démonstration** : le cycle de l'eau, en trois thèmes, offerte à qui arrive
 * sans rien à déposer. C'est l'ancien cours de démonstration du site devenu une leçon
 * (`docs/refonte-web.md`, lot 9) : un chemin prêt sans appel au modèle, des notes au format
 * d'avant (un chapitre = un thème, comme « Ouvrir sans attendre »), un quiz par thème, trois
 * flashcards. Elle est `source = "sample"` : elle ne compte pas pour la leçon offerte
 * (`hasUsedFreeLesson`), et elle s'ouvre dans « Reprendre » dès Home.
 *
 * Les textes viennent du catalogue `demo.*`, donc de la langue du site au moment du parcours.
 */
export const DEMO_LESSON_SOURCE = "sample";

interface DemoTheme {
  title: string;
  icon: string;
  sheet: SheetBlock[];
  questions: Omit<QuizQuestion, "id" | "matches" | "difficulty">[];
}

function heading(text: string): SheetBlock {
  return { type: "heading", level: 1, text };
}

function paragraph(text: string): SheetBlock {
  return { type: "paragraph", text };
}

/**
 * Le texte à trou porte « … », le marqueur du serveur et des apps (`CLOZE_GAP`) : le catalogue
 * l'écrit parfois en trois points, ramenés ici à un seul caractère. Le site écrivait `____`, que
 * l'iPhone et Android ne lisent pas comme un trou.
 */
function gapPrompt(text: string): string {
  return normalizeClozeGap(text);
}

export function demoThemes(t: Translator): DemoTheme[] {
  return [
    {
      title: t("demo.evap"),
      icon: "flamme",
      sheet: [heading(t("demo.evap")), paragraph(t("demo.raw2")), paragraph(t("demo.chartCaption"))],
      questions: [
        { kind: "choice", prompt: t("demo.card1Front"), choices: [t("demo.card1Back"), t("demo.card3Back"), t("demo.defTerm")], answer: 0, why: t("demo.card1Note") },
        { kind: "truefalse", prompt: t("demo.card1Note"), choices: [t("lesson.question.true"), t("lesson.question.false")], answer: 0, why: t("demo.chartCaption") },
      ],
    },
    {
      title: t("demo.cond"),
      icon: "fiole",
      sheet: [heading(t("demo.cond")), paragraph(t("demo.raw3")), paragraph(`**${t("demo.defTerm")}** : ${t("demo.defText")}`)],
      questions: [
        { kind: "choice", prompt: t("demo.card2Front"), choices: [t("demo.card2c1"), t("demo.card2c2"), t("demo.card2c3")], answer: 0, why: t("demo.card2Back") },
        { kind: "truefalse", prompt: t("demo.defText"), choices: [t("lesson.question.true"), t("lesson.question.false")], answer: 0, why: t("demo.card2Hint") },
      ],
    },
    {
      title: t("demo.precip"),
      icon: "globe",
      sheet: [heading(t("demo.precip")), paragraph(t("demo.raw4")), paragraph(t("demo.raw5"))],
      questions: [
        { kind: "gap", prompt: gapPrompt(t("demo.card3Front")), choices: [t("demo.card3Back"), t("demo.evap"), t("demo.cond"), t("demo.oceans")], answer: 0, why: t("demo.card3Note") },
        { kind: "order", prompt: t("demo.card4Front"), choices: [t("demo.evap"), t("demo.cond"), t("demo.precip")], answer: 0, why: t("demo.card4Back") },
      ],
    },
  ];
}

export function demoPath(t: Translator, themes: DemoTheme[]): LessonPath {
  return {
    version: 1,
    icon: "globe",
    intro: { lines: [t("demo.sheetHeading"), t("demo.raw1"), t("demo.chartCaption")], minutes: 8 },
    takeaways: [t("demo.card1Note"), t("demo.defText"), t("demo.card3Note"), t("demo.card4Back")],
    groups: [{ name: t("demo.sheetHeading"), themes: themes.map((_, index) => index) }],
    shortened: false,
    singleQuiz: true,
    status: "ready",
  };
}

/**
 * Écrit la leçon de démonstration pour `userId`, si elle n'a encore aucune leçon à elle.
 * Rend `true` quand une leçon a été écrite.
 */
export async function installDemoLesson(userId: string, t: Translator, language: string): Promise<boolean> {
  const supabase = await createClient();
  const { count } = await supabase.from("courses").select("id", { count: "exact", head: true }).eq("user_id", userId).is("deleted_at", null);
  if ((count ?? 0) > 0) return false;

  const now = new Date().toISOString();
  const lessonId = crypto.randomUUID();
  const themes = demoThemes(t);
  const rawText = ["raw1", "raw2", "raw3", "raw4", "raw5"].map((key) => t(`demo.${key}`)).join("\n\n");

  const { error: courseError } = await supabase.from("courses").insert({
    id: lessonId,
    user_id: userId,
    title: t("demo.courseTitle"),
    subject: "SVT",
    summary: "",
    emoji: null,
    source: DEMO_LESSON_SOURCE,
    source_file_name: null,
    fingerprint: null,
    raw_text: rawText,
    sheet: null,
    context_text: null,
    visibility: DEFAULT_VISIBILITY,
    language,
    tone: "blue",
    icon: "globe",
    last_opened_at: now,
    path: demoPath(t, themes),
    progress: emptyProgress(),
  });
  if (courseError) return false;

  const chapters = themes.map((theme, index) => ({ id: crypto.randomUUID(), theme, index }));
  const { error: chaptersError } = await supabase.from("chapters").insert(
    chapters.map(({ id, theme, index }) => {
      const quiz: ThemeQuiz = {
        questions: theme.questions.map((question, number) => ({ ...question, id: `${id}:${number}`, matches: [], difficulty: number + 1 })),
      };
      return {
        id,
        user_id: userId,
        course_id: lessonId,
        position: index,
        title: theme.title,
        icon: theme.icon,
        notes: null,
        sheet: { blocks: theme.sheet },
        quiz,
        status: "ready",
      };
    }),
  );
  if (chaptersError) return false;

  const cards = [
    { front: t("demo.card1Front"), back: t("demo.card1Back"), chapter: 0 },
    { front: t("demo.card2Front"), back: t("demo.card2Back"), chapter: 1 },
    { front: t("demo.card3Front"), back: t("demo.card3Back"), chapter: 2 },
  ];
  await supabase.from("flashcards").insert(
    cards.map((card, position) => ({
      id: crypto.randomUUID(),
      user_id: userId,
      course_id: lessonId,
      chapter_id: chapters[card.chapter]!.id,
      front: card.front,
      back: card.back,
      position,
      kind: "basic",
      state: "new",
      due_date: now,
    })),
  );

  revalidateUserData(userId, "courses");
  revalidateUserData(userId, "cards");
  return true;
}
