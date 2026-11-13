import SwiftUI

// Ce que la Home partage avec d'autres écrans : l'heure qu'il est et le prénom (le paywall),
// le compte à rebours et la barre fine (le Calendrier), les mesures du Mika en demi de la
// Concentration.

// MARK: - Le moment et le prénom

/// **Le moment de la journée et le prénom**, pour la phrase de la Home : « Bonjour », « Salut »
/// ou « Bonsoir », et le prénom donné au parcours d'accueil.
enum HomeGreeting {
    enum Moment: String {
        case morning
        case day
        case evening
        case night
    }

    static func moment(hour: Int) -> Moment {
        switch hour {
        case 5..<12: .morning
        case 12..<18: .day
        case 18..<23: .evening
        default: .night
        }
    }

    /// Le prénom : le premier mot de ce que l'élève a donné, rien s'il n'a rien donné.
    static func firstName(_ raw: String?) -> String? {
        guard let raw = raw?.nilIfBlank else { return nil }
        return raw.split(whereSeparator: \.isWhitespace).first.map(String.init)
    }
}

// MARK: - Les mesures du Mika en demi

/// Les mesures du Mika qui dépasse d'un bouton, gardées pour l'écran de la Concentration, qui
/// le pose de la même façon (`FocusScreen`). La Home, elle, montre Mika en entier.
enum HomePlanHero {
    /// Mika en demi, derrière le haut du bouton (`MikaPeek.card`).
    static let mikaSize: CGFloat = MikaPeek.card
    /// La coupe passe sous le bord du bouton.
    static let mikaSink: CGFloat = 3
    /// Le retrait de Mika depuis le bord droit du bouton : loin de son coin arrondi.
    static let mikaInset: CGFloat = 8
    /// La place que Mika prend à droite du texte.
    static let mikaReserve: CGFloat = MikaPeek.card + 12
}

// MARK: - Le compte à rebours et la barre fine

/// **Le compte à rebours d'un examen**, dans sa pastille bleue : le nombre de jours en blanc,
/// « jours » dessous. Le même sur Home et dans le Calendrier.
struct HomeCountdownBadge: View {
    let daysLeft: Int
    var side: CGFloat = 58

    var body: some View {
        VStack(spacing: -1) {
            if daysLeft <= 0 {
                Text(L10n.t("ios.cal.examToday", locale: .resolved()))
                    .font(MicaboFont.ui(side * 0.21, weight: .black))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
            } else {
                Text("\(daysLeft)")
                    .font(MicaboFont.number(side * 0.41))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(L10n.t(daysLeft == 1 ? "ios.cal.dayLeft" : "ios.cal.daysLeft", locale: .resolved()))
                    .font(MicaboFont.ui(side * 0.18, weight: .black))
                    .opacity(0.88)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 4)
        .frame(width: side, height: side)
        .background(MicaboStage.fill, in: RoundedRectangle(cornerRadius: side * 0.28, style: .continuous))
        .shadow(color: MicaboBrand.blue.opacity(0.25), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
    }
}

/// Une barre de progression fine : la piste, et le bleu de l'accent jusqu'au pourcentage.
struct HomeBar: View {
    let percent: Int
    var track: Color = HomePalette.track
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(MicaboColor.accent)
                    .frame(width: max(height, proxy.size.width * CGFloat(min(100, max(0, percent))) / 100))
            }
        }
        .frame(height: height)
    }
}
