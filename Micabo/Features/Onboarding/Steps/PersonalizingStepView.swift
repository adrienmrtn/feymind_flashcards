import Combine
import SwiftUI

/// Génération du parcours. Purement visuel — les réponses sont déjà enregistrées — mais il
/// ne doit jamais laisser croire que l'app a gelé.
///
/// **Les quatre étapes citent les vraies réponses.** Elles disaient « lecture de tes
/// réponses », « calibrage des intervalles » : des verbes sans objet, qu'on aurait pu
/// afficher à n'importe qui. Elles disent maintenant la matière et l'année, l'examen et
/// dans combien de jours, le rythme en cartes, et le chemin d'une note à l'autre. Un
/// chargement qui montre ce qu'il charge est un chargement qu'on croit.
///
/// La mascotte est là, et c'est l'une de ses deux apparitions : elle réfléchit pendant
/// que ça se construit, elle se redresse quand c'est fini. C'est le seul écran où elle
/// **fait** quelque chose.
///
/// **Le chargement dure cinq secondes**, et c'est un plancher, pas une approximation. Un
/// écran qui annonce qu'il construit un parcours puis disparaît en une seconde n'a rien
/// construit. Quatre phases lisibles, un anneau qui fait son tour complet, et on a vu le
/// travail se faire.
///
/// **La fin ne se saute pas d'elle-même.** C'est l'étudiant qui appuie. Le bouton occupe sa
/// place depuis le début, en attente, pour que rien ne saute quand il s'active.
struct PersonalizingStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private struct Phase {
        let headline: String
        let step: String
    }

    private var phases: [Phase] {
        let summary = OnboardingSummary(model: model, locale: i18n.locale)
        let steps = [
            i18n.t("ios.build.read", ["subject": summary.subject, "level": summary.level]),
            i18n.t("ios.build.exam", ["exam": summary.examName, "days": "\(summary.examDays)"]),
            i18n.t("ios.build.pace", ["n": "\(summary.cardsPerDay)"]),
            i18n.t("ios.build.route", ["from": summary.fromGrade, "to": summary.toGrade]),
        ]
        return steps.enumerated().map { index, step in
            Phase(headline: i18n.t("onboarding.parcoursWorking\(index + 1)"), step: step)
        }
    }

    /// Durée du chargement, en secondes. Un plancher, et il est verrouillé par un test :
    /// un écran de génération qui passe en une seconde n'a rien généré aux yeux de
    /// personne.
    static let duration = 5.0

    @State private var elapsed = 0.0
    @State private var completed = 0
    @State private var didRing = false

    /// Statique : recréé à chaque `body`, le publisher s'annulait et l'anneau restait à zéro.
    private static let ticker = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    /// **Le chargement ne monte pas au métronome.**
    ///
    /// Une barre parfaitement linéaire se lit comme une animation, pas comme un travail : l'œil
    /// repère la vitesse constante en une seconde et cesse d'y croire. Un vrai calcul avance
    /// par à-coups - une lecture instantanée, un palier où quelque chose attend, un saut quand
    /// le lot tombe, et une fin qui traîne. C'est ce profil-là qu'on rejoue.
    private static let curve: [(at: Double, reached: Double)] = [
        (0.00, 0.00),
        (0.07, 0.19),
        (0.21, 0.24),
        (0.33, 0.51),
        (0.45, 0.56),
        (0.61, 0.79),
        (0.80, 0.84),
        (0.93, 0.97),
        (1.00, 1.00),
    ]

    private var progress: Double {
        let time = min(1, elapsed / Self.duration)
        var previous = Self.curve[0]
        for point in Self.curve.dropFirst() {
            if time <= point.at {
                let span = point.at - previous.at
                let ratio = span > 0 ? (time - previous.at) / span : 1
                return previous.reached + (point.reached - previous.reached) * ratio
            }
            previous = point
        }
        return 1
    }

    private var isDone: Bool {
        completed >= phases.count
    }

    private var current: Phase {
        phases[min(completed, phases.count - 1)]
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 22) {
                Spacer(minLength: 0)

                MicaboMascot(mood: isDone ? .proud : .thinking, size: 96)

                // La hauteur est réservée : les quatre phrases n'ont pas le même nombre de
                // lignes, et un titre qui se recompose fait sauter l'anneau.
                Text(isDone ? i18n.t("onboarding.parcoursDone") : current.headline)
                    .font(MicaboFont.ui(24, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(MicaboColor.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 64, alignment: .center)
                    .contentTransition(.opacity)
                    .animation(.easeOut(duration: 0.28), value: current.headline)

                ring

                stepList

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, MicaboSpacing.screen)

            MicaboBottomBar(background: MicaboColor.canvas) {
                OnboardingContinueButton(
                    title: i18n.t("ios.discoverPath"),
                    // Éteint pendant le travail, et pas seulement inerte : un bouton à
                    // l'encre pleine qui avale les appuis pendant cinq secondes se lit
                    // comme un bouton cassé.
                    isEnabled: isDone,
                    isLoading: !isDone,
                    loadingTitle: i18n.t("onboarding.parcoursBusyBtn"),
                    isShiny: isDone
                ) {
                    model.advance()
                }
            }
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
        .onReceive(Self.ticker) { _ in
            tick()
        }
    }

    // MARK: - Anneau

    /// L'anneau fait son tour en même temps que le parcours se construit, et le pourcentage
    /// compte image par image : c'est la seule chose que cet écran a à dire.
    private var ring: some View {
        ZStack {
            Circle()
                .stroke(MicaboColor.track, lineWidth: 11)

            Circle()
                .trim(from: 0, to: max(0.005, progress))
                .stroke(MicaboColor.accent, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 100)) %")
                .font(MicaboFont.number(34))
                .foregroundStyle(MicaboColor.ink)
                .tracking(-1.2)
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(width: 128, height: 128)
        .accessibilityElement()
        .accessibilityLabel(i18n.t("ios.generatingPath"))
        .accessibilityValue("\(Int(progress * 100)) %")
    }

    // MARK: - Étapes

    private var stepList: some View {
        MicaboOutlineCard(padding: EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)) {
            VStack(spacing: 0) {
                ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                    HStack(spacing: 13) {
                        marker(isDone: index < completed, isActive: index == completed)

                        Text(phase.step)
                            .font(MicaboFont.ui(14.5, weight: index == completed ? .semibold : .regular))
                            .foregroundStyle(index <= completed ? MicaboColor.ink : MicaboColor.inkTertiary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 10)

                    if index < phases.count - 1 {
                        MicaboHairline(inset: 41)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func marker(isDone: Bool, isActive: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isDone ? MicaboColor.positiveSoft : (isActive ? MicaboColor.accentSoft : MicaboColor.surfaceMuted))

            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(MicaboColor.positive)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            } else if isActive {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.62)
                    .tint(MicaboColor.accent)
            }
        }
        .frame(width: 28, height: 28)
        .animation(OnboardingMotion.shift, value: isDone)
    }

    // MARK: - Déroulé

    private func tick() {
        guard elapsed < Self.duration else { return }
        elapsed = min(Self.duration, elapsed + 1.0 / 60.0)

        let reached = min(phases.count, Int(progress * Double(phases.count)))
        if reached > completed {
            withAnimation(.easeOut(duration: 0.25)) {
                completed = reached
            }
            Haptics.tick()
        }

        if elapsed >= Self.duration, !didRing {
            didRing = true
            Haptics.success()
        }
    }
}

// MARK: - Le résumé des réponses

/// **Ce que le parcours sait de l'élève, écrit en mots.**
///
/// Deux écrans le lisent — la construction, puis « ton parcours est prêt » — et ils
/// doivent dire exactement la même chose. Le calculer une fois ici plutôt que deux fois
/// dans deux vues est ce qui empêche l'un d'annoncer « Terminale » et l'autre « Lycée ».
struct OnboardingSummary {
    let subject: String
    let level: String
    let examName: String
    let examDays: Int
    let cardsPerDay: Int
    let fromGrade: String
    let toGrade: String
    let subjectCount: Int

    init(model: OnboardingModel, locale: UiLocale) {
        let sheet = model.demoSheet
        subject = model.primarySubject ?? sheet.subjectName
        level = model.year?.title ?? model.stage?.localizedTitle ?? model.country.localizedName(locale: locale)

        let exam = model.demoExam
        examName = exam.name
        examDays = exam.daysLeft()

        cardsPerDay = DailyLoad.newCardsPerDay(dailyMinutes: OnboardingPreferences.dailyMinutes)

        let scale = DesiredGradeScale.for(model.country)
        if let current = model.currentScore, current >= TargetScore.min {
            fromGrade = scale.label(for: current)
        } else {
            fromGrade = L10n.t("ios.averageBelowShort", locale: locale)
        }
        if let target = model.targetScore {
            toGrade = scale.label(for: target)
        } else {
            toGrade = scale.max
        }

        subjectCount = model.subjects.count
    }
}
