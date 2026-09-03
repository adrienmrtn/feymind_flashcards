import Foundation

/// Lexique de l'app. Trois règles, valables de l'onboarding aux réglages.
///
/// Les chaînes passent par `L10n` : une seule source avec le web (`copy.*`).
enum MicaboCopy {
  static func cards(_ count: Int, locale: UiLocale = .resolved()) -> String {
    L10n.t("copy.cards", locale: locale, vars: ["count": "\(count)"])
  }

  static func courses(_ count: Int, locale: UiLocale = .resolved()) -> String {
    L10n.t("copy.courses", locale: locale, vars: ["count": "\(count)"])
  }

  static func reviewButton(count: Int, locale: UiLocale = .resolved()) -> String {
    if count > 0 {
      return L10n.t("copy.reviewCount", locale: locale, vars: ["cards": cards(count, locale: locale)])
    }
    return L10n.t("copy.review", locale: locale)
  }

  static func sheetButton(locale: UiLocale = .resolved()) -> String {
    L10n.t("copy.sheetButton", locale: locale)
  }

  static func cardsButton(locale: UiLocale = .resolved()) -> String {
    L10n.t("copy.cardsButton", locale: locale)
  }

  static func audience(views: Int, adopts: Int, locale: UiLocale = .resolved()) -> String {
    L10n.t(
      "copy.audience",
      locale: locale,
      vars: ["views": "\(views)", "adopts": "\(adopts)"]
    )
  }

  static func audience(of course: SharedCourseRecord, locale: UiLocale = .resolved()) -> String {
    audience(views: course.view_count ?? 0, adopts: course.adopt_count ?? 0, locale: locale)
  }

  static func audience(of course: Course, locale: UiLocale = .resolved()) -> String {
    audience(views: course.viewCount, adopts: course.adoptCount, locale: locale)
  }

  static func practiceReview(locale: UiLocale = .resolved()) -> String {
    L10n.t("copy.practiceReview", locale: locale)
  }

  static func practiceReviewHint(locale: UiLocale = .resolved()) -> String {
    L10n.t("copy.practiceReviewHint", locale: locale)
  }

  static func heldBackNew(_ count: Int, locale: UiLocale = .resolved()) -> String {
    L10n.t("copy.heldBackNew", locale: locale, vars: ["count": "\(count)"])
  }
}
