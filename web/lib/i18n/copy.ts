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
