import SwiftUI

// MARK: - Les chiffres

/// **Les chiffres de preuve du parcours, tous au même endroit.**
///
/// Ils sont **provisoires** : ce sont des ordres de grandeur posés pour dessiner les écrans,
/// et ils doivent être remplacés par les vrais avant d'être montrés. Les avoir ici plutôt
/// que dans chaque écran, c'est ce qui permet de les remplacer d'un coup — et de savoir, en
/// relisant ce fichier, tout ce que le parcours affirme.
enum OnboardingProofFigures {
    /// La note App Store et le nombre d'avis.
    static let rating = 4.8
    static let reviews = 12_000
    /// Les élèves que Micabo a aidés.
    static let students = 45_000
    /// Ce qu'il reste d'un cours une semaine après, en relisant et en se testant.
    /// Karpicke & Roediger, Science, 2008.
    static let retainedByRereading = 36
    static let retainedByTesting = 80
    /// Le multiplicateur des rappels.
    static let reminderMultiplier = 2

    /// Un entier écrit dans la langue de l'élève : « 12 000 », « 12,000 », « 12.000 ».
    static func text(_ value: Int, locale: UiLocale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale.foundation
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func text(_ value: Double, locale: UiLocale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale.foundation
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - Le texte à chiffre coloré

/// **Une phrase noire, avec un passage en violet.** Le passage est marqué entre deux
/// astérisques doubles dans la chaîne traduite (`**14**`), pour que chaque langue décide
/// de sa place dans la phrase.
struct OnboardingAccentText: View {
    let template: String
    var size: CGFloat = 34
    var alignment: TextAlignment = .center
    var color: Color = OnboardingPalette.ink
    var accent: Color = OnboardingPalette.accent

    var body: some View {
        composed
            .font(OnboardingPalette.title(size))
            .tracking(-0.9)
            .lineSpacing(-2)
            .multilineTextAlignment(alignment)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var composed: Text {
        var result = Text("")
        var isAccent = false
        for (index, part) in template.components(separatedBy: "**").enumerated() {
            if index > 0 { isAccent.toggle() }
            result = result + Text(part).foregroundStyle(isAccent ? accent : color)
        }
        return result
    }
}

// MARK: - « On s'en occupe. »

/// **La réponse à ce qui inquiète**, juste après l'avoir demandé : l'inquiétude mise en
/// avant en titre, puis les deux barres — ce qu'il reste d'un cours une semaine après, en
/// le relisant et en se testant dessus. Le rouge et le vert n'existent que là.
struct ProofRetentionStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var headline: String {
        if let worry = model.leadWorry {
            return i18n.t("ios.proof.gotYou.named", ["worry": worry.echo(locale: i18n.locale)])
        }
        return i18n.t("ios.proof.gotYou")
    }

    var body: some View {
        OnboardingProofPage(
            headline: headline,
            caption: i18n.t("ios.journey.source")
        ) {
            OnboardingBarsChart(
                title: i18n.t("ios.proof.retention.caption"),
                bars: [
                    .init(label: i18n.t("ios.proof.retention.reread"), value: OnboardingProofFigures.retainedByRereading, tint: OnboardingPalette.chartBad),
                    .init(label: i18n.t("ios.proof.retention.testing"), value: OnboardingProofFigures.retainedByTesting, tint: OnboardingPalette.chartGood),
                ]
            )
        } onContinue: {
            model.advance()
        }
    }
}

// MARK: - La page de preuve

/// **Une phrase, une image, un rond.** Toutes les preuves ont cette forme : le titre
/// centré avec son passage en violet, la figure au milieu de ce qui reste, la légende grise
/// dessous.
struct OnboardingProofPage<Figure: View>: View {
    let headline: String
    var caption: String?
    @ViewBuilder var figure: () -> Figure
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Spacer(minLength: MicaboSpacing.lg)

                OnboardingAccentText(template: headline)
                    .padding(.horizontal, MicaboSpacing.screen)
                    .onboardingAppear(index: 1)

                Spacer(minLength: MicaboSpacing.xl)

                figure()
                    .padding(.horizontal, MicaboSpacing.screen)
                    .onboardingAppear(index: 3)

                if let caption {
                    Text(caption)
                        .font(MicaboFont.ui(14, weight: .regular))
                        .foregroundStyle(OnboardingPalette.gray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, MicaboSpacing.xl)
                        .padding(.top, MicaboSpacing.lg)
                        .onboardingAppear(index: 4)
                }

                Spacer(minLength: MicaboSpacing.lg)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            OnboardingArrowBar(action: onContinue)
                .onboardingAppear(index: 5)
        }
        .onboardingChromeInset()
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
    }
}

// MARK: - Les figures

/// Deux ou trois barres verticales, leur valeur écrite dedans, leur libellé dessous.
struct OnboardingBarsChart: View {
    struct Bar: Identifiable {
        var id: String { label }
        let label: String
        let value: Int
        let tint: Color
        var valueText: String?
        var valueInk: Color = OnboardingPalette.white
    }

    var title: String?
    let bars: [Bar]
    var maxValue: Int = 100
    /// La valeur écrite dans la barre. Sans elle, la hauteur dit tout.
    var showsValues: Bool = true

    /// Le temps que les barres mettent à monter : deux secondes, lentement, et le chiffre
    /// compte avec elles.
    static let riseDuration = 2.0
    /// La hauteur d'une barre avant qu'elle ne monte.
    private static let restingHeight: CGFloat = 12

    /// De zéro à un : la part du chemin que les barres ont faite. Une seule valeur animée
    /// pour la hauteur **et** le chiffre, qui montent donc ensemble.
    @State private var drawn: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title {
                Text(title)
                    .font(MicaboFont.ui(14, weight: .semibold))
                    .foregroundStyle(OnboardingPalette.gray)
            }

            HStack(alignment: .bottom, spacing: 18) {
                ForEach(bars) { bar in
                    VStack(spacing: 10) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(bar.tint)
                                .frame(height: Self.restingHeight + (height(for: bar) - Self.restingHeight) * drawn)

                            if showsValues {
                                if let text = bar.valueText {
                                    Text(text)
                                        .font(MicaboFont.ui(22, weight: .bold))
                                        .foregroundStyle(bar.valueInk)
                                        .monospacedDigit()
                                        .padding(.bottom, 14)
                                        .opacity(drawn > 0.15 ? 1 : 0)
                                } else {
                                    OnboardingCountingPercent(value: Double(bar.value) * Double(drawn), ink: bar.valueInk)
                                        .padding(.bottom, 14)
                                        .opacity(drawn > 0.15 ? 1 : 0)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)

                        Text(bar.label)
                            .font(MicaboFont.ui(13, weight: .semibold))
                            .foregroundStyle(OnboardingPalette.ink)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(height: 220, alignment: .bottom)
        }
        .padding(20)
        .background(OnboardingPalette.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onAppear {
            // **Les barres ne partent qu'une fois le glissement fini**, et pas avant : une
            // animation dans une animation se lit comme un tremblement. Le départ est donc
            // posté après la durée du glissement, plutôt que différé dans l'animation elle-même,
            // pour qu'aucune image de la montée ne tombe pendant que la page arrive. Puis
            // **deux secondes**, lentement et de plus en plus posées, le chiffre comptant avec
            // la barre. Elles se sentent partir, et se sentent se poser.
            DispatchQueue.main.asyncAfter(deadline: .now() + OnboardingMotion.slideDuration + 0.2) {
                Haptics.soft()
                withAnimation(.timingCurve(0.35, 0, 0.2, 1, duration: Self.riseDuration)) { drawn = 1 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + OnboardingMotion.slideDuration + 0.2 + Self.riseDuration - 0.1) {
                Haptics.light()
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func height(for bar: Bar) -> CGFloat {
        let fraction = CGFloat(bar.value) / CGFloat(max(1, maxValue))
        return max(56, 180 * fraction)
    }
}

/// **Un pourcentage qui compte.** La valeur est animable : quand elle va de zéro à
/// quatre-vingts en deux secondes, le texte passe par tous les nombres entre les deux, au
/// rythme de la barre qui monte sous lui. Un `Text` ordinaire sauterait de 0 à 80.
private struct OnboardingCountingPercent: View, Animatable {
    var value: Double
    var ink: Color

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("\(Int(value.rounded())) %")
            .font(MicaboFont.ui(22, weight: .bold))
            .foregroundStyle(ink)
            .monospacedDigit()
    }
}
