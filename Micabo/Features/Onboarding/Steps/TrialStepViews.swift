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

    static func milestones(
        from date: Date = .now,
        calendar: Calendar = .current,
        locale: UiLocale = .fr
    ) -> [Milestone] {
        let dateText = billingDateText(from: date, calendar: calendar, locale: locale)
        return [
            Milestone(
                title: L10n.t("ios.accountCreated", locale: locale),
                detail: L10n.t("ios.trialCreatedDetail", locale: locale),
                systemImage: "checkmark",
                tone: .done
            ),
            Milestone(
                title: L10n.t("ios.trialToday", locale: locale),
                detail: L10n.t("ios.trialTodayDetail", locale: locale),
                systemImage: "lock.open.fill",
                tone: .current
            ),
            Milestone(
                title: L10n.t("ios.trialDay2", locale: locale),
                detail: L10n.t("ios.trialDay2Detail", locale: locale),
                systemImage: "bell.fill",
                tone: .upcoming
            ),
            Milestone(
                title: L10n.t("ios.trialLast", locale: locale, vars: ["n": "\(freeDays)"]),
                detail: L10n.t("ios.trialLastDetail", locale: locale, vars: ["date": dateText]),
                systemImage: "star.fill",
                tone: .upcoming
            )
        ]
    }

    /// Le jour du premier prélèvement, écrit comme on le dirait : « 28 août ».
    static func billingDateText(
        from date: Date = .now,
        calendar: Calendar = .current,
        locale: UiLocale = .fr
    ) -> String {
        let billingDate = calendar.date(byAdding: .day, value: freeDays, to: date) ?? date
        let formatter = DateFormatter()
        formatter.locale = locale.foundation
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

    private var milestones: [TrialTimeline.Milestone] {
        TrialTimeline.milestones(locale: i18n.locale)
    }

    @State private var revealedCount = 0
    @State private var showsAction = false
    @State private var didStart = false

    private var stepDelay: Double { 0.34 }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    Text(i18n.t("ios.trialHow"))
                        .font(OnboardingPalette.title(32))
                        .foregroundStyle(MicaboColor.ink)
                        .tracking(-0.6)
                        .lineSpacing(-1)
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

            OnboardingArrowBar {
                model.advance()
            }
            .opacity(showsAction ? 1 : 0)
            .allowsHitTesting(showsAction)
        }
        .onboardingChromeInset()
        .background(OnboardingPalette.white.ignoresSafeArea())
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
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(iconColor)
                    .frame(width: 46, height: 46)
                    .background(discColor, in: Circle())
                    .background(Circle().fill(discColor.opacity(0.55)).offset(y: 3))
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
                    .font(MicaboFont.ui(18, weight: .heavy))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(milestone.detail)
                    .font(MicaboFont.ui(14.5, weight: .regular))
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

/// **La promesse du rappel, montrée telle qu'elle arrivera.**
///
/// Le réveil 3D vacille sur son halo, ses ondes battent ; dessous, la notification de la
/// veille tombe sur l'écran — « Ton essai se termine demain », avec la date du premier
/// prélèvement —, puis la phrase se lit mot à mot et les deux garanties se posent. On ne
/// promet pas un rappel : on le fait voir. Le bouton n'arrive qu'une fois la phrase lue.
struct TrialReminderStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onboardingStill) private var still

    @State private var bannerIn = false
    @State private var chipsIn = false
    @State private var showsAction = false

    var body: some View {
        VStack(spacing: 0) {
            OnboardingCenteredScroll {
                VStack(spacing: 24) {
                    ReminderAlarm()

                    ReminderBanner(dateText: TrialTimeline.billingDateText(locale: i18n.locale))
                        .opacity(bannerIn || still ? 1 : 0)
                        .offset(y: bannerIn || still ? 0 : -26)
                        .scaleEffect(bannerIn || still ? 1 : 0.94)

                    OnboardingReadingText(
                        template: i18n.t("ios.trialReminder"),
                        size: 26,
                        wordDelay: 0.13,
                        startDelay: 0.9,
                        onFinish: {
                            withAnimation(OnboardingMotion.enter) { chipsIn = true }
                            withAnimation(OnboardingMotion.enter.delay(0.25)) { showsAction = true }
                        }
                    )

                    // Côte à côte quand elles tiennent, l'une sous l'autre sinon : en allemand
                    // ou en turc, deux pastilles sur une ligne débordaient.
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { chips }
                        VStack(spacing: 8) { chips }
                    }
                    .opacity(chipsIn || still ? 1 : 0)
                    .offset(y: chipsIn || still ? 0 : 10)
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.vertical, MicaboSpacing.md)
            }

            OnboardingArrowBar {
                model.advance()
            }
            .opacity(showsAction || still ? 1 : 0)
            .allowsHitTesting(showsAction)
        }
        .onboardingChromeInset()
        .background(OnboardingPalette.white.ignoresSafeArea())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.spring(duration: 0.55, bounce: 0.35)) { bannerIn = true }
                Haptics.light()
            }
        }
    }

    @ViewBuilder
    private var chips: some View {
        chip("creditcard.fill", i18n.t("ios.trialReminder.free"))
        chip("hand.tap.fill", i18n.t("ios.trialReminder.cancel"))
    }

    private func chip(_ symbol: String, _ title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MicaboColor.correct)
            Text(title)
                .font(MicaboFont.ui(13, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background(MicaboColor.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
    }
}

/// Le réveil 3D, sur son halo, avec deux ondes de chaque côté qui battent doucement : il
/// vacille sur sa base, il ne sonne pas — le rappel est pour dans deux jours.
private struct ReminderAlarm: View {
    @State private var shown = false
    @State private var sway = false
    @State private var wave = false
    @Environment(\.onboardingStill) private var still
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let isShown = shown || still
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [MicaboColor.accent.opacity(0.22), MicaboColor.accent.opacity(0)], center: .center, startRadius: 4, endRadius: 86))
                .frame(width: 172, height: 172)

            ForEach([-1.0, 1.0], id: \.self) { side in
                ForEach(0..<2, id: \.self) { ring in
                    // Un arc centré à neuf heures ; retourné, le même à trois heures.
                    Circle()
                        .trim(from: 0.42, to: 0.58)
                        .stroke(MicaboColor.accent.opacity(0.55), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        .frame(width: CGFloat(110 + ring * 30), height: CGFloat(110 + ring * 30))
                        .rotationEffect(.degrees(side < 0 ? 0 : 180))
                        .opacity(wave || still ? (ring == 0 ? 0.9 : 0.45) : 0.15)
                        .scaleEffect(wave ? 1.04 : 0.96)
                }
            }

            MicaboIconView(icon: .alarm, size: 84)
                .shadow(color: MicaboColor.accent.opacity(0.25), radius: 16, y: 10)
                .rotationEffect(.degrees(sway ? 7 : -7), anchor: .bottom)
        }
        .frame(height: 150)
        .scaleEffect(isShown ? 1 : 0.5)
        .opacity(isShown ? 1 : 0)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.spring(duration: 0.55, bounce: 0.45)) { shown = true }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true).delay(0.3)) { sway = true }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true).delay(0.3)) { wave = true }
        }
    }
}

/// **La notification de la veille**, telle qu'iOS l'affichera : l'icône de l'app, « dans
/// 2 j », le titre et la date du premier prélèvement.
private struct ReminderBanner: View {
    let dateText: String

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MicaboBrandMark(size: 40)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("MICABO")
                        .font(MicaboFont.ui(11.5, weight: .bold))
                        .tracking(MicaboTracking.caps)
                        .foregroundStyle(MicaboColor.inkSecondary)
                    Spacer(minLength: 0)
                    Text(i18n.t("ios.trialReminder.when"))
                        .font(MicaboFont.ui(11.5, weight: .medium))
                        .foregroundStyle(MicaboColor.inkTertiary)
                }

                Text(i18n.t("ios.trialReminder.cardTitle"))
                    .font(MicaboFont.ui(15.5, weight: .heavy))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(i18n.t("ios.trialReminder.cardBody", ["date": dateText]))
                    .font(MicaboFont.ui(14, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
        .micaboElevation(.card)
        .accessibilityElement(children: .combine)
    }
}
