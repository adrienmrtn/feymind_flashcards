import SwiftUI

// MARK: - Les cinq écrans d'ouverture
//
// Ils remplacent onze écrans qui racontaient une méthode — la courbe de l'oubli, la
// répétition espacée, Feynman, la préparation d'une épreuve — avant d'avoir montré une
// seule fois ce que l'app fait. Ceux-ci décrivent le parcours réel, dans l'ordre où on le
// vivra : tu déposes tes supports, tu poses tes dates, ça devient des fiches et des cartes,
// et voilà ce qu'il y a autour.
//
// Chacun porte une seule phrase et une seule image. Un écran d'ouverture se traverse en
// deux secondes ; tout ce qui demande à être lu deux fois y est perdu. Les titres s'écrivent
// d'un bloc, sans animation mot à mot : celle-là est réservée aux questions, où elle donne
// le rythme d'une conversation.
//
// Le premier des cinq, l'accroche, vit dans `WelcomeStepView` : il porte le paquet de
// cartes animé et la sortie « j'ai déjà un compte », qui n'a sa place qu'au tout début.

/// « Tu déposes tes supports. »
///
/// Quatre tuiles, comme la grille des decks : un PDF, des photos, un Word, une vidéo. On
/// les lit en une seconde parce qu'elles sont posées comme quatre objets, et elles entrent
/// l'une après l'autre.
struct UploadStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private static let formats: [(emoji: String, key: String)] = [
        ("📄", "ios.intro.format.pdf"),
        ("📸", "ios.intro.format.photo"),
        ("📝", "ios.intro.format.word"),
        ("🎬", "ios.intro.format.video"),
    ]

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.intro.upload"),
            expandsContent: true
        ) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                LazyVGrid(columns: OnboardingScene.columns, spacing: 12) {
                    ForEach(Array(Self.formats.enumerated()), id: \.offset) { index, format in
                        OnboardingTile(
                            emoji: format.emoji,
                            title: i18n.t(format.key),
                            pastel: MicaboColor.pastel(at: index),
                            rank: index
                        )
                    }
                }

                Spacer(minLength: 0)
            }
        } footer: {
            OnboardingContinueButton { model.advance() }
        }
    }
}

/// « Tu poses tes dates. »
///
/// Un calendrier, la date de l'épreuve en violet, la pastille du compte à rebours : ce que
/// l'app montre vraiment, et rien d'autre. La carte à trois lignes de légende qui vivait ici
/// expliquait ce que le calendrier montre.
struct DatesStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.intro.dates"),
            expandsContent: true
        ) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                OnboardingCalendarScene()
                    .onboardingAppear(index: 3)
                Spacer(minLength: 0)
            }
        } footer: {
            OnboardingContinueButton { model.advance() }
        }
    }
}

/// « Ça devient un cours, rangé. »
struct TurnsIntoStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.intro.turnsInto"),
            expandsContent: true
        ) {
            VStack(spacing: MicaboSpacing.md) {
                Spacer(minLength: 0)
                IntroPlanCard()
                Spacer(minLength: 0)
            }
        } footer: {
            OnboardingContinueButton { model.advance() }
        }
    }
}

/// « Et ce qu'il faut autour. »
///
/// **Le mode audio est annoncé alors qu'il n'existe pas encore**, et c'est un choix
/// assumé : il est décidé, il est en construction, et le promettre ici cadre l'attente au
/// bon endroit plutôt que de le faire découvrir comme une surprise. Ce qui serait
/// malhonnête serait de le montrer comme disponible — il porte donc sa mention.
struct SmartFeaturesStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private static let features: [(emoji: String, key: String, soon: Bool)] = [
        ("🎧", "ios.intro.feature.audio", true),
        ("📝", "ios.intro.feature.mock", false),
        ("🔘", "ios.intro.feature.quiz", false),
        ("💡", "ios.intro.feature.explain", false),
    ]

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.intro.features"),
            expandsContent: true
        ) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                LazyVGrid(columns: OnboardingScene.columns, spacing: 12) {
                    ForEach(Array(Self.features.enumerated()), id: \.offset) { index, feature in
                        OnboardingTile(
                            emoji: feature.emoji,
                            title: i18n.t(feature.key),
                            pastel: MicaboColor.pastel(at: index + 1),
                            badge: feature.soon ? i18n.t("ios.intro.soon") : nil,
                            rank: index
                        )
                    }
                }

                Spacer(minLength: 0)
            }
        } footer: {
            OnboardingContinueButton(title: i18n.t("ios.intro.setup"), isShiny: true) {
                model.advance()
            }
        }
    }
}

// MARK: - Les vignettes

/// Un plan de deck : quatre chapitres, deux sus, un entamé.
private struct IntroPlanCard: View {
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Les pourcentages **visés** par l'animation. La carte part de zéro partout et les
    /// rejoint un chapitre après l'autre, en boucle : un plan de travail qui se remplit sous
    /// les yeux dit ce qu'une capture d'écran de plan rempli ne dit pas — que c'est le
    /// travail qui le remplit.
    private static let rows: [(key: String, percent: Int)] = [
        ("ios.intro.chapter1", 100),
        ("ios.intro.chapter2", 100),
        ("ios.intro.chapter3", 45),
        ("ios.intro.chapter4", 0),
    ]

    /// Le nombre de chapitres déjà remplis. Il monte de zéro à quatre, marque un temps, et
    /// repart.
    @State private var reached = 0

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(Self.rows.enumerated()), id: \.offset) { index, row in
                let shown = index < reached ? row.percent : 0
                let isDone = shown >= 90

                HStack(spacing: 12) {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "\(index + 1).circle")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(isDone ? MicaboColor.positive : MicaboColor.inkTertiary)
                        .contentTransition(.symbolEffect(.replace))

                    Text(i18n.t(row.key))
                        .font(MicaboFont.ui(15, weight: .medium))
                        .foregroundStyle(MicaboColor.ink)

                    Spacer(minLength: 0)

                    Text("\(shown) %")
                        .font(MicaboFont.ui(13, weight: .semibold))
                        .foregroundStyle(shown > 0 ? MicaboColor.accent : MicaboColor.inkTertiary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .onboardingAppear(index: index)

                if index < Self.rows.count - 1 {
                    MicaboHairline(inset: 48)
                }
            }
        }
        .task { await cycle() }
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
    }

    /// Dans `.task` : annulé avec la vue, pas une boucle qui lui survit.
    @MainActor
    private func cycle() async {
        guard !reduceMotion else {
            reached = Self.rows.count
            return
        }
        while !Task.isCancelled {
            for step in 0...Self.rows.count {
                withAnimation(.easeOut(duration: 0.45)) { reached = step }
                try? await Task.sleep(for: .milliseconds(620))
                guard !Task.isCancelled else { return }
            }
            try? await Task.sleep(for: .milliseconds(1400))
            withAnimation(.easeOut(duration: 0.35)) { reached = 0 }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }
}
