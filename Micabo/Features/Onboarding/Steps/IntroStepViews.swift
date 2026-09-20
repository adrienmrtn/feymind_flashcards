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

/// « Tu commences par déposer tes supports », avec les formats acceptés.
///
/// Les pastilles ne sont pas décoratives : elles répondent à la seule question que se pose
/// quelqu'un à cet instant, qui est « est-ce que mes trucs à moi rentrent là-dedans ». Un
/// PDF de prof, des photos du tableau, un cours Word, une vidéo — la réponse est oui, et
/// elle se lit sans texte.
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
            VStack(spacing: 10) {
                Spacer(minLength: 0)

                ForEach(Array(Self.formats.enumerated()), id: \.offset) { index, format in
                    HStack(spacing: 14) {
                        Text(format.emoji)
                            .font(.system(size: 26))

                        Text(i18n.t(format.key))
                            .font(MicaboFont.ui(16, weight: .medium))
                            .foregroundStyle(MicaboColor.ink)

                        Spacer(minLength: 0)

                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(MicaboColor.positive)
                    }
                    .padding(.vertical, 15)
                    .padding(.horizontal, 16)
                    .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                            .strokeBorder(MicaboColor.stroke, lineWidth: 1)
                    }
                    .onboardingAppear(index: index)
                }

                Spacer(minLength: 0)
            }
        } footer: {
            OnboardingContinueButton { model.advance() }
        }
    }
}

/// « Puis tu poses tes dates d'épreuve et tes objectifs. »
struct DatesStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.intro.dates"),
            expandsContent: true
        ) {
            VStack(spacing: MicaboSpacing.md) {
                Spacer(minLength: 0)
                IntroCountdownCard()
                Spacer(minLength: 0)
            }
        } footer: {
            OnboardingContinueButton { model.advance() }
        }
    }
}

/// « Tes supports deviennent des fiches et des cartes, rangées. »
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

/// « Avec ce qu'il faut autour pour t'aider. »
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
            VStack(spacing: 10) {
                Spacer(minLength: 0)

                ForEach(Array(Self.features.enumerated()), id: \.offset) { index, feature in
                    HStack(spacing: 14) {
                        Text(feature.emoji)
                            .font(.system(size: 24))

                        Text(i18n.t(feature.key))
                            .font(MicaboFont.ui(15.5, weight: .medium))
                            .foregroundStyle(MicaboColor.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)

                        if feature.soon {
                            Text(i18n.t("ios.intro.soon"))
                                .font(MicaboFont.ui(11, weight: .bold))
                                .foregroundStyle(MicaboColor.accent)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 9)
                                .background(MicaboColor.accentSoft, in: Capsule())
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                            .strokeBorder(MicaboColor.stroke, lineWidth: 1)
                    }
                    .onboardingAppear(index: index)
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

/// Un compte à rebours d'épreuve, posé comme il l'est dans un deck.
private struct IntroCountdownCard: View {
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var progress: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text("🧪")
                    .font(.system(size: 26))

                VStack(alignment: .leading, spacing: 1) {
                    Text(i18n.t("ios.intro.sampleDeck"))
                        .font(MicaboFont.ui(15, weight: .semibold))
                        .foregroundStyle(MicaboColor.ink)
                    Text(i18n.t("ios.intro.sampleExam"))
                        .font(MicaboFont.ui(12, weight: .regular))
                        .foregroundStyle(MicaboColor.inkTertiary)
                }

                Spacer(minLength: 0)

                Text("J-12")
                    .font(MicaboFont.number(17, weight: .bold))
                    .foregroundStyle(MicaboColor.accent)
                    .monospacedDigit()
            }

            MicaboProgressBar(progress: progress, tint: MicaboColor.accent, track: MicaboColor.stroke)
                .frame(height: 6)

            Text(i18n.t("ios.intro.samplePace"))
                .font(MicaboFont.ui(12.5, weight: .medium))
                .foregroundStyle(MicaboColor.inkSecondary)
        }
        .padding(MicaboSpacing.md)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .onAppear {
            withAnimation(OnboardingMotion.shift.delay(0.3)) { progress = 0.42 }
        }
    }
}

/// Un plan de deck : quatre chapitres, deux sus, un entamé.
private struct IntroPlanCard: View {
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private static let rows: [(key: String, percent: Int)] = [
        ("ios.intro.chapter1", 100),
        ("ios.intro.chapter2", 100),
        ("ios.intro.chapter3", 45),
        ("ios.intro.chapter4", 0),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(Self.rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 12) {
                    Image(systemName: row.percent >= 90 ? "checkmark.circle.fill" : "\(index + 1).circle")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(row.percent >= 90 ? MicaboColor.positive : MicaboColor.inkTertiary)

                    Text(i18n.t(row.key))
                        .font(MicaboFont.ui(15, weight: .medium))
                        .foregroundStyle(MicaboColor.ink)

                    Spacer(minLength: 0)

                    Text("\(row.percent) %")
                        .font(MicaboFont.ui(13, weight: .semibold))
                        .foregroundStyle(row.percent > 0 ? MicaboColor.accent : MicaboColor.inkTertiary)
                        .monospacedDigit()
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .onboardingAppear(index: index)

                if index < Self.rows.count - 1 {
                    MicaboHairline(inset: 48)
                }
            }
        }
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
    }
}
