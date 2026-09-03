import { ReviewRating } from "@micabo/core";

import type { makeTranslator } from "./translate";
import type { UiLocale } from "./locales";
import { UI_LOCALE_META } from "./locales";

export type Translator = ReturnType<typeof makeTranslator>;

const RATING_KEYS: Record<ReviewRating, "again" | "hard" | "good" | "easy"> = {
  [ReviewRating.again]: "again",
  [ReviewRating.hard]: "hard",
  [ReviewRating.good]: "good",
  [ReviewRating.easy]: "easy",
};

export function reviewRatingLabel(t: Translator, rating: ReviewRating): string {
  return t(`app.session.rating.${RATING_KEYS[rating]}`);
}

export function copyCards(t: Translator, count: number): string {
  return t("copy.cards", { count });
}

export function copyCourses(t: Translator, count: number): string {
  return t("copy.courses", { count });
}

export function copyReviewButton(t: Translator, count: number): string {
  if (count <= 0) return t("copy.review");
  return t("copy.reviewCount", { cards: copyCards(t, count) });
}

export function copyHeldBackNew(t: Translator, count: number): string {
  return t("copy.heldBackNew", { count });
}

export function copyPracticeReview(t: Translator): string {
  return t("copy.practiceReview");
}

export function copyAlreadySubscribed(t: Translator): string {
  return t("copy.alreadySubscribed");
}

export function localeBcp47(locale: UiLocale): string {
  return UI_LOCALE_META[locale].bcp47;
}

export function formatWeekdayShort(date: Date, locale: UiLocale): string {
  return date.toLocaleDateString(localeBcp47(locale), { weekday: "short" }).replace(".", "");
}

export function formatDayMonth(iso: string, locale: UiLocale): string | null {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return null;
  return new Intl.DateTimeFormat(localeBcp47(locale), { day: "numeric", month: "long" }).format(
    date,
  );
}

export function copyExamCountdown(t: Translator, daysRemaining: number): string {
  if (daysRemaining < 0) return t("app.exams.countdown.past");
  if (daysRemaining === 0) return t("app.exams.countdown.today");
  if (daysRemaining === 1) return t("app.exams.countdown.tomorrow");
  return t("app.exams.countdown.inDays", { days: daysRemaining });
}

export function copyExamMarkTitle(t: Translator, name: string, daysRemaining: number): string {
  const label = name.trim() || t("app.exams.defaultName");
  if (daysRemaining < 0) return label;
  if (daysRemaining === 0) return t("app.exams.markTitle.today", { name: label });
  if (daysRemaining === 1) return t("app.exams.markTitle.tomorrow", { name: label });
  return t("app.exams.markTitle.inDays", { name: label, days: daysRemaining });
}

export function copyCourseSource(t: Translator, source: string): string {
  switch (source) {
    case "pdf":
      return t("app.course.source.pdf");
    case "photo":
      return t("app.course.source.photos");
    case "youtube":
      return t("app.course.source.video");
    case "docx":
      return t("app.course.source.word");
    case "deck":
      return t("app.course.source.deck");
    case "library":
      return t("app.course.source.adopted");
    default:
      return t("app.course.source.text");
  }
}

export function copySheetLengthTitle(
  t: Translator,
  length: "brief" | "standard" | "deep",
): string {
  if (length === "brief") return t("app.import.lengthBrief");
  if (length === "deep") return t("app.import.lengthDeep");
  return t("app.import.lengthStandard");
}

export function copyVisibilityTitle(
  t: Translator,
  value: "public" | "friends" | "private",
): string {
  return t(`app.course.visibility.${value}Title`);
}

export function copyVisibilityDetail(
  t: Translator,
  value: "public" | "friends" | "private",
): string {
  return t(`app.course.visibility.${value}Detail`);
}
