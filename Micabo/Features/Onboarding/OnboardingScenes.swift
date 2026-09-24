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

/// **Un mois, et trois épreuves qui se posent dessus, l'une après l'autre.**
///
/// C'est ce que la page affirme — « pose les dates de tes examens » — montré tel que l'app
/// le fait : un calendrier, et sur trois de ses jours l'emoji d'une matière dans son pastel,
/// avec en dessous la liste des épreuves et leur compte à rebours. Elles arrivent une par
/// une, à un rythme de main qui pose, puis la scène se vide et recommence. Le calendrier
/// à une seule date en violet ne disait qu'une chose ; celui-ci dit qu'on en pose autant
/// qu'on en a, et qu'elles ont un nom.
struct OnboardingCalendarScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private struct SampleExam {
        let day: Int
        let emoji: String
        let titleKey: String
        let pastel: Int
    }

    /// Un mois qui commence un lundi, aujourd'hui le 3.
    private static let today = 3
    private static let days = 28
    private static let exams: [SampleExam] = [
        SampleExam(day: 9, emoji: "🧬", titleKey: "ios.intro.exam1", pastel: 1),
        SampleExam(day: 15, emoji: "🏛️", titleKey: "ios.intro.exam2", pastel: 0),
        SampleExam(day: 24, emoji: "📐", titleKey: "ios.intro.exam3", pastel: 3),
    ]

    /// Le nombre d'épreuves déjà posées.
    @State private var placed = 0

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                HStack {
                    Text(i18n.t("ios.intro.sampleMonth"))
                        .font(MicaboFont.ui(15, weight: .bold))
                        .foregroundStyle(MicaboColor.ink)

                    Spacer(minLength: 0)

                    if let first = Self.exams.first, placed > 0 {
                        MicaboCountdownPill(days: first.day - Self.today)
                            .transition(.opacity)
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                    ForEach(1...Self.days, id: \.self) { day in
                        dayCell(day)
                    }
                }
            }
            .padding(16)
            .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(MicaboColor.stroke, lineWidth: 1)
            }
            .shadow(color: MicaboColor.ink.opacity(0.05), radius: 14, y: 6)

            VStack(spacing: 8) {
                ForEach(Array(Self.exams.enumerated()), id: \.offset) { index, exam in
                    examRow(exam, index: index)
                }
            }
        }
        .animation(OnboardingMotion.select, value: placed)
        .accessibilityHidden(true)
        .task { await cycle() }
    }

    /// Le rang d'une épreuve dans l'ordre où elles se posent, ou nil si ce jour n'en a pas.
    private func exam(on day: Int) -> (index: Int, exam: SampleExam)? {
        guard let index = Self.exams.firstIndex(where: { $0.day == day }) else { return nil }
        return (index, Self.exams[index])
    }

    @ViewBuilder
    private func dayCell(_ day: Int) -> some View {
        let isToday = day == Self.today

        if let found = exam(on: day), found.index < placed {
            Text(found.exam.emoji)
                .font(.system(size: 15))
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(
                    MicaboColor.pastel(at: found.exam.pastel),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .transition(.scale(scale: 0.4).combined(with: .opacity))
        } else {
            Text("\(day)")
                .font(MicaboFont.ui(13, weight: isToday ? .heavy : .medium))
                .foregroundStyle(isToday ? MicaboColor.accent : MicaboColor.inkSecondary)
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background {
                    if isToday {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(MicaboColor.accent, lineWidth: 1.6)
                    }
                }
        }
    }

    /// Une épreuve posée : son emoji sur son pastel, son nom, et dans combien de jours.
    private func examRow(_ exam: SampleExam, index: Int) -> some View {
        let isPlaced = index < placed
        let alpha: Double = isPlaced ? 1 : 0
        let rise: CGFloat = isPlaced ? 0 : 8

        return HStack(spacing: 12) {
            Text(exam.emoji)
                .font(.system(size: 17))
                .frame(width: 36, height: 36)
                .background(
                    MicaboColor.pastel(at: exam.pastel),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )

            Text(i18n.t(exam.titleKey))
                .font(MicaboFont.ui(14.5, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .lineLimit(1)

            Spacer(minLength: 8)

            MicaboCountdownPill(days: exam.day - Self.today)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .opacity(alpha)
        .offset(y: rise)
    }

    /// Les épreuves se posent une par une, la scène tient, puis se vide et recommence.
    /// Dans `.task` : annulé avec la vue.
    @MainActor
    private func cycle() async {
        guard !reduceMotion else {
            placed = Self.exams.count
            return
        }
        try? await Task.sleep(for: .milliseconds(500))
        while !Task.isCancelled {
            for step in 1...Self.exams.count {
                placed = step
                Haptics.tick()
                try? await Task.sleep(for: .milliseconds(720))
                guard !Task.isCancelled else { return }
            }
            try? await Task.sleep(for: .milliseconds(2600))
            guard !Task.isCancelled else { return }
            placed = 0
            try? await Task.sleep(for: .milliseconds(520))
        }
    }
}
