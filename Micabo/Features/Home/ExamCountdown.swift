import SwiftUI

/// **Le compte à rebours d'un examen**, dans la langue de l'app : « J-12 », « noch 12 Tage »,
/// « Demain », « Aujourd'hui ». Le même sur la Home, sur une leçon et dans l'onglet Leçons.
///
/// Le nom de l'examen est celui que l'élève lui a donné : il suit son pays et son niveau,
/// jamais un nom écrit ici.
enum ExamCountdown {
    static func label(daysLeft: Int, locale: UiLocale = .resolved()) -> String {
        switch daysLeft {
        case ...0: L10n.t("ios.cal.today", locale: locale)
        case 1: L10n.t("ios.cal.tomorrow", locale: locale)
        default: L10n.t("ios.pol.home.countdown", locale: locale, vars: ["n": "\(daysLeft)"])
        }
    }

    /// « Histoire · J-12 » : le nom, puis le compte à rebours.
    ///
    /// De droite à gauche, un nom en lettres latines et un chiffre se mélangent avec l'arabe :
    /// chaque morceau est isolé (FSI … PDI) et garde son ordre, et la marque de droite à gauche
    /// (RLM) en tête donne le sens de la ligne.
    static func line(name: String, daysLeft: Int, locale: UiLocale = .resolved()) -> String {
        let parts = [name.trimmingCharacters(in: .whitespacesAndNewlines), label(daysLeft: daysLeft, locale: locale)]
            .filter { !$0.isEmpty }
        if locale.isRightToLeft {
            return "\u{200F}" + parts.map { "\u{2068}\($0)\u{2069}" }.joined(separator: " · ")
        }
        return parts.joined(separator: " · ")
    }
}

/// **La pastille d'un examen** : une toque et « Histoire · J-12 », en jaune sur son lavis — le
/// jaune est la couleur de l'examen dans toute l'app. La même sur la Home, au-dessus de Mika,
/// et dans l'en-tête d'une leçon.
///
/// Sans examen (`isInvitation`), elle devient une invitation discrète, en tertiaire et sans
/// fond : « Ajouter mon examen ».
struct ExamPillLabel: View {
    let text: String
    var isInvitation = false

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: isInvitation ? "plus" : "graduationcap.fill")
                .accessibilityHidden(true)
            Text(text)
                .monospacedDigit()
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(V3Font.caption.weight(.bold))
        .foregroundStyle(isInvitation ? V3Color.ink3 : V3Color.yellowInk)
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .background(isInvitation ? Color.clear : V3Color.yellowWash, in: Capsule())
        .contentShape(Capsule())
        .accessibilityElement(children: .combine)
    }
}
