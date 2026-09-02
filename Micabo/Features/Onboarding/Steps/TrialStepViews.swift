import Foundation
import SwiftUI

/// Les quatre moments de l'essai, du compte créé au premier prélèvement.
///
/// La chronologie est calculée à partir d'une date reçue en paramètre plutôt que lue
/// depuis `Date.now` au fond d'une vue : c'est ce qui permet de vérifier la date de
/// premier prélèvement sans attendre trois jours.
enum TrialTimeline {
    /// Durée de l'essai, et seule source de vérité à ce sujet dans le parcours : la date
    /// annoncée sur la chronologie et celle facturée par la boutique doivent être la même.
    static let freeDays = 3

    enum Tone {
        /// Ce qui est déjà fait.
        case done
        /// Ce qui commence maintenant.
        case current
        /// Ce qui arrivera.
        case upcoming
    }

    struct Milestone: Identifiable {
        /// Le libellé fait l'identité. Un `UUID()` tiré à la construction changerait à
        /// chaque recomposition de l'écran, et la cascade repartirait de zéro sous les yeux.
        var id: String { title }
        let title: String
        let detail: String
        let systemImage: String
        let tone: Tone
    }

    static func milestones(from date: Date = .now, calendar: Calendar = .current) -> [Milestone] {
        [
            Milestone(
                title: "Compte créé",
                detail: "Ton profil est prêt, tes réponses sont enregistrées.",
                systemImage: "checkmark",
                tone: .done
            ),
            Milestone(
                title: "Aujourd'hui : essaie Micabo Pro",
                detail: "Cours illimités, cartes générées, révisions : tout est ouvert.",
                systemImage: "lock.open.fill",
                tone: .current
            ),
            Milestone(
                title: "Jour 2 : rappel avant la fin",
                detail: "On te prévient par notification. Résiliable en quinze secondes.",
                systemImage: "bell.fill",
                tone: .upcoming
            ),
            Milestone(
                title: "Jour \(freeDays) : fin de l'essai",
                detail: "Ton abonnement démarrera le \(billingDateText(from: date, calendar: calendar)).",
                systemImage: "star.fill",
                tone: .upcoming
            )
        ]
    }

    /// Le jour du premier prélèvement, écrit comme on le dirait : « 28 août ».
    static func billingDateText(from date: Date = .now, calendar: Calendar = .current) -> String {
        let billingDate = calendar.date(byAdding: .day, value: freeDays, to: date) ?? date
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.calendar = calendar
        // Le fuseau vient du calendrier, et pas du système : sans lui, un minuit calculé à
        // Paris s'écrit « la veille » dès que l'appareil est réglé plus à l'ouest.
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("d MMMM")
        return formatter.string(from: billingDate)
    }
}

/// La chronologie de l'essai gratuit.
///
/// Le seul écran du parcours qui **répond à une question qu'on ne pose jamais à voix
/// haute** : quand est-ce qu'on me prélève ? Y répondre avant le paywall coûte un écran et
/// évite les trois jours d'inquiétude qui font annuler un essai dès la première minute.
///
/// Les quatre étapes arrivent l'une après l'autre, et le filet qui les relie pousse en même
/// temps que celle qu'il annonce : c'est le geste de la ligne qui se trace, pas quatre
/// blocs qui s'allument. Le bouton n'apparaît qu'après la dernière — on ne fait pas défiler
/// une chronologie qu'on n'a pas fini de dessiner.
struct TrialOfferStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private let milestones = TrialTimeline.milestones()

    @State private var revealedCount = 0
    @State private var showsAction = false
    @State private var didStart = false

    private var stepDelay: Double { 0.34 }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    Text(i18n?.t("ios.trialHow") ?? "Comment marche\nton essai gratuit")
                        .font(MicaboFont.hanken(34, weight: .bold))
                        .foregroundStyle(MicaboColor.ink)
                        .tracking(-0.9)
                        .lineSpacing(-2)
                        .fixedSize(horizontal: false, vertical: true)
                        .onboardingAppear(index: 0)

                    VStack(spacing: 0) {
                        ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                            TrialMilestoneRow(
                                milestone: milestone,
                                isLast: index == milestones.count - 1,
                                isRevealed: index < revealedCount,
                                // Le filet sous une étape se trace au moment où la
                                // suivante se pose : la ligne conduit le regard au lieu de
                                // l'attendre.
                                isConnectorRevealed: index + 1 < revealedCount
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, MicaboSpacing.xl)
                .padding(.bottom, MicaboSpacing.lg)
            }
            .scrollIndicators(.hidden)

            MicaboBottomBar {
                OnboardingContinueButton(title: i18n?.t("ios.ready") ?? "Je suis prêt") {
                    model.advance()
                }
                .opacity(showsAction ? 1 : 0)
                .allowsHitTesting(showsAction)
            }
        }
        .onAppear(perform: reveal)
    }

    private func reveal() {
        guard !didStart else { return }
        didStart = true

        for index in milestones.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(index) * stepDelay) {
                withAnimation(OnboardingMotion.enter) {
                    revealedCount = index + 1
                }
                Haptics.tick()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(milestones.count) * stepDelay) {
            withAnimation(OnboardingMotion.enter) {
                showsAction = true
            }
        }
    }
}

private struct TrialMilestoneRow: View {
    let milestone: TrialTimeline.Milestone
    let isLast: Bool
    let isRevealed: Bool
    let isConnectorRevealed: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                Image(systemName: milestone.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 42, height: 42)
                    .background(discColor, in: Circle())
                    .scaleEffect(isRevealed ? 1 : 0.55)
                    .opacity(isRevealed ? 1 : 0)

                if !isLast {
                    Capsule()
                        .fill(connectorColor)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 4)
                        .scaleEffect(y: isConnectorRevealed ? 1 : 0, anchor: .top)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title)
                    .font(MicaboFont.hanken(17, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(milestone.detail)
                    .font(MicaboFont.hanken(14.5, weight: .regular))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
            .padding(.bottom, isLast ? 0 : 26)
            .opacity(isRevealed ? 1 : 0)
            .offset(y: isRevealed ? 0 : 10)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// Le vert pour ce qui est acquis, l'encre pour ce qui commence, le sable pour ce qui
    /// n'est pas encore arrivé : la chronologie se lit sans lire les libellés.
    private var discColor: Color {
        switch milestone.tone {
        case .done: MicaboColor.accent
        case .current: MicaboColor.ink
        case .upcoming: MicaboColor.surfaceSunken
        }
    }

    private var iconColor: Color {
        switch milestone.tone {
        case .done, .current: MicaboColor.onInk
        case .upcoming: MicaboColor.surface
        }
    }

    private var connectorColor: Color {
        milestone.tone == .done ? MicaboColor.accent.opacity(0.35) : MicaboColor.strokeStrong
    }
}

/// La promesse du rappel, seule sur sa page.
///
/// Un écran, une phrase, une image. La phrase se met en gras mot à mot pour accompagner la
/// lecture — c'est l'inquiétude qu'on désamorce ici, et une inquiétude se désamorce en se
/// faisant lire en entier, pas en survolant un paragraphe. La cloche se balance derrière,
/// et le bouton n'arrive qu'une fois le dernier mot posé.
struct TrialReminderStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var showsAction = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: MicaboSpacing.lg)

            OnboardingWordByWordTitle(
                text: "Tu recevras un rappel\n1 jour avant la fin\nde ton essai.",
                size: 29,
                alignment: .center,
                wordDelay: 0.13,
                startDelay: 0.25
            ) {
                withAnimation(OnboardingMotion.enter) {
                    showsAction = true
                }
            }
            .padding(.horizontal, MicaboSpacing.screen)

            // L'écart entre la phrase et la cloche est fixe, et les vides qui l'entourent
            // sont élastiques : la phrase et son image forment un seul objet, qu'un ressort
            // posé entre les deux ferait s'écarter sur les grands téléphones.
            Color.clear.frame(height: 40)

            SwayingBell()

            // Deux vides sous l'objet contre un au-dessus : il se pose ainsi un tiers
            // au-dessus du centre, là où le regard tombe.
            Spacer(minLength: MicaboSpacing.lg)
            Spacer(minLength: 0)

            MicaboBottomBar {
                OnboardingContinueButton(title: i18n?.t("ios.tryFree") ?? "Essayer gratuitement") {
                    model.advance()
                }
                .opacity(showsAction ? 1 : 0)
                .allowsHitTesting(showsAction)
            }
        }
    }
}

/// Cloche qui se balance, sans jamais s'arrêter.
///
/// Elle **se balance** au lieu de sonner : la version précédente partait en six secousses
/// de ressort, ce qui dit « ça sonne maintenant » alors que l'écran promet une notification
/// dans deux jours. Un balancement lent dit « on y pense pour toi », et il ne réclame pas
/// l'attention pendant qu'on lit la phrase du dessus.
private struct SwayingBell: View {
    @State private var hasLanded = false
    @State private var isSwaying = false

    var body: some View {
        Image(systemName: "bell.fill")
            .font(.system(size: 116, weight: .regular))
            .foregroundStyle(MicaboColor.cautionVivid)
            // Le pivot est en haut : une cloche tourne autour de son attache, pas autour de
            // son centre.
            .rotationEffect(.degrees(isSwaying ? 10 : -10), anchor: .top)
            .scaleEffect(hasLanded ? 1 : 0.72)
            .opacity(hasLanded ? 1 : 0)
            .accessibilityHidden(true)
            .onAppear(perform: start)
    }

    private func start() {
        withAnimation(OnboardingMotion.shift.delay(0.1)) {
            hasLanded = true
        }
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true).delay(0.1)) {
            isSwaying = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            Haptics.tick()
        }
    }
}
