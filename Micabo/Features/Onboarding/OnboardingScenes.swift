import SwiftUI

/// **Les visuels des écrans d'ouverture.**
///
/// La première version de ce fichier portait trois scènes animées — une feuille qui
/// devenait des cartes, un anneau de compte à rebours, une carte qui se retournait. Elles
/// bougeaient, et on ne comprenait pas ce qu'elles montraient : trop d'objets, trop de
/// mouvements en même temps, et aucun ne ressemblait à ce que l'app affiche vraiment.
///
/// Ce qui est là maintenant vient des applications de référence (Growth, Gizmo) : **des
/// tuiles**, grandes, avec un emoji et trois mots, qui entrent l'une après l'autre. On lit
/// quatre formats de document en une seconde parce qu'ils sont posés comme quatre objets,
/// pas racontés. Et elles vivent — chacune respire légèrement, à son rythme — sans que rien
/// ne demande à être déchiffré.
enum OnboardingScene {
    /// Deux colonnes, comme la grille des decks : les tuiles de l'accueil et celles de l'app
    /// sont le même objet.
    static let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]
}

// MARK: - Une tuile

/// **Une grande tuile pastel, un emoji, un libellé.**
///
/// Elle respire : un balancement de trois points sur trois secondes, décalé d'une tuile à
/// l'autre pour que la grille ne monte pas et ne descende pas d'un bloc. C'est assez pour
/// qu'un écran ne soit pas une image fixe, et pas assez pour qu'on regarde le mouvement
/// plutôt que le texte.
struct OnboardingTile: View {
    let emoji: String
    let title: String
    let pastel: Color
    var badge: String?
    /// Le rang dans la grille : règle l'entrée en cascade et le décalage de la respiration.
    var rank: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lifted = false

    var body: some View {
        let lift: CGFloat = lifted ? -3 : 3
        let wake: Double = Double(rank) * 0.4

        return VStack(alignment: .leading, spacing: 12) {
            Text(emoji)
                .font(.system(size: 38))
                .frame(height: 44)

            Text(title)
                .font(MicaboFont.ui(14.5, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .lineSpacing(1)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .background(pastel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if let badge {
                Text(badge)
                    .font(MicaboFont.ui(10, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(MicaboColor.accent)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(MicaboColor.canvas.opacity(0.85), in: Capsule())
                    .padding(10)
            }
        }
        .offset(y: lift)
        .onboardingAppear(index: 3 + rank, stagger: OnboardingMotion.rowStagger)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true).delay(wake)) {
                lifted = true
            }
        }
    }
}

// MARK: - Le calendrier

/// **Un mois, un jour entouré, et le compte à rebours qui bat.**
///
/// C'est ce que la page des dates affirme — « tu poses tes dates » — montré tel que l'app le
/// montre : un calendrier, la date de l'épreuve en violet, et la pastille J-12 qu'on
/// retrouve sur chaque deck. Le trait qui relie aujourd'hui à l'épreuve se trace sous les
/// yeux, et c'est le seul mouvement de la page : la durée qui sépare les deux.
struct OnboardingCalendarScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @State private var drawn = false
    @State private var pulse = false

    private var pulseScale: CGFloat { pulse ? 1.06 : 1 }

    /// Un mois qui commence un lundi, avec aujourd'hui le 3 et l'épreuve le 15.
    private static let today = 3
    private static let exam = 15
    private static let days = 28

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text(i18n.t("ios.intro.sampleMonth"))
                    .font(MicaboFont.ui(15, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                Spacer(minLength: 0)
                MicaboCountdownPill(days: Self.exam - Self.today)
                    .scaleEffect(pulseScale)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
                ForEach(1...Self.days, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
        .padding(18)
        .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .shadow(color: MicaboColor.ink.opacity(0.05), radius: 14, y: 6)
        .accessibilityHidden(true)
        .onAppear(perform: start)
    }

    @ViewBuilder
    private func dayCell(_ day: Int) -> some View {
        let isToday = day == Self.today
        let isExam = day == Self.exam
        let isBetween = day > Self.today && day < Self.exam

        Text("\(day)")
            .font(MicaboFont.ui(13, weight: isExam || isToday ? .heavy : .medium))
            .foregroundStyle(isExam ? MicaboColor.onInk : (isToday ? MicaboColor.accent : MicaboColor.inkSecondary))
            .monospacedDigit()
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background {
                if isExam {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(MicaboColor.accent)
                        .scaleEffect(drawn ? 1 : 0.6)
                        .opacity(drawn ? 1 : 0)
                } else if isToday {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(MicaboColor.accent, lineWidth: 1.6)
                } else if isBetween {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(MicaboColor.accentWash)
                        .opacity(drawn ? 1 : 0)
                }
            }
    }

    private func start() {
        guard !reduceMotion else {
            drawn = true
            return
        }
        withAnimation(OnboardingMotion.enter.delay(0.5)) {
            drawn = true
        }
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true).delay(1.2)) {
            pulse = true
        }
    }
}
