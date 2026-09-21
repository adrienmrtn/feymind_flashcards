import SwiftUI

/// **Le rappel quotidien, montré avant d'être demandé.**
///
/// Ce qui précède le bouton n'est pas une question, c'est une réponse à celle que le
/// système va poser trois secondes plus tard, et à laquelle iOS ne laisse répondre qu'une
/// fois : *à quoi ça sert ?* L'écran précédent montrait la notification elle-même — une
/// bannière qui tombait, deux fantômes dessous. C'était le moyen, pas le bénéfice : une
/// notification n'a jamais donné envie à personne d'en recevoir.
///
/// **Ce qu'on montre maintenant, c'est la semaine qui tient.** Sept jours qui se cochent
/// l'un après l'autre, une flamme qui compte, et seulement ensuite la notification qui
/// arrive — celle qui fera cocher le huitième. Le nombre de cartes qu'elle annonce n'est
/// pas un décor : `DailyLoad` le calcule depuis le rythme choisi deux écrans plus tôt.
///
/// **Il ouvre la vraie boîte de dialogue d'iOS.** Un refus n'arrête pas le parcours et ne
/// déclenche aucun rattrapage : rien dans Micabo ne dépend des notifications, et redemander
/// est de toute façon impossible.
struct NotificationsStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Vrai le temps que la boîte du système soit à l'écran : le bouton ne doit pas
    /// pouvoir être appuyé deux fois pendant qu'iOS attend une réponse.
    @State private var isAsking = false
    /// Les jours déjà cochés, de zéro à sept.
    @State private var checked = 0
    /// Déclenche l'entrée de la notification, une fois la semaine remplie. Elle ne se
    /// rejoue pas : une animation qui recommence à chaque retour sur l'écran cesse d'être
    /// une démonstration et devient un décor.
    @State private var hasLanded = false
    @State private var hasPlayed = false

    private static let days = 7

    private func t(_ key: String) -> String {
        i18n.t(key)
    }

    /// Ce que l'étudiant verra vraiment, et non un nombre d'exemple.
    private var dueCount: Int {
        DailyLoad.newCardsPerDay(dailyMinutes: OnboardingPreferences.dailyMinutes)
    }

    /// Les initiales des jours, dans la langue et l'ordre de la semaine de l'étudiant.
    private var dayInitials: [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = i18n.locale.foundation
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return (0..<Self.days).map { symbols[(first + $0) % symbols.count] }
    }

    var body: some View {
        OnboardingScaffold(
            title: t("ios.notifTitle"),
            // Hors défilement : les ressorts qui centrent la scène n'ont pas de hauteur
            // dans un `ScrollView`.
            scrolls: false,
            animatesTitle: true,
            expandsContent: true
        ) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 16) {
                    weekCard
                    banner
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        } footer: {
            OnboardingContinueButton(
                isEnabled: !isAsking,
                isLoading: isAsking,
                isShiny: true
            ) {
                Task { await ask() }
            }
        }
        .task { await play() }
    }

    // MARK: - La semaine

    /// Sept ronds qui se cochent, et la flamme qui compte avec eux.
    private var weekCard: some View {
        MicaboOutlineCard(padding: EdgeInsets(top: 18, leading: 16, bottom: 18, trailing: 16)) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 6) {
                    ForEach(0..<Self.days, id: \.self) { index in
                        day(index)
                    }
                }

                streakPill
            }
        }
    }

    private func day(_ index: Int) -> some View {
        let isChecked = index < checked
        let fill: Color = isChecked ? MicaboColor.accent : MicaboColor.surfaceMuted
        let pop: CGFloat = isChecked ? 1 : 0.86

        return VStack(spacing: 7) {
            ZStack {
                Circle().fill(fill)

                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(MicaboColor.onInk)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 34, height: 34)
            .scaleEffect(pop)

            Text(dayInitials[index])
                .font(MicaboFont.ui(11.5, weight: .semibold))
                .foregroundStyle(isChecked ? MicaboColor.ink : MicaboColor.inkTertiary)
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.34, dampingFraction: 0.6), value: isChecked)
    }

    /// La flamme et le compte, qui grandissent avec la semaine.
    private var streakPill: some View {
        HStack(spacing: 7) {
            Text("🔥")
                .font(.system(size: 15))
            Text(i18n.t("ios.notif.streak", ["count": "\(checked)"]))
                .font(MicaboFont.ui(13.5, weight: .bold))
                .foregroundStyle(MicaboColor.flameInk)
                .contentTransition(.numericText())
                .monospacedDigit()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 13)
        .background(MicaboColor.flameSoft, in: Capsule())
        .animation(.spring(response: 0.34, dampingFraction: 0.7), value: checked)
    }

    // MARK: - La notification

    /// Celle du lendemain matin, telle qu'iOS l'affichera. Elle tombe du haut et dépasse
    /// d'un cheveu avant de se poser : c'est le geste d'une notification qui arrive.
    private var banner: some View {
        HStack(alignment: .top, spacing: 12) {
            MicaboBrandMark(size: 38)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("MICABO")
                        .font(MicaboFont.ui(11.5, weight: .semibold))
                        .tracking(MicaboTracking.caps)
                        .foregroundStyle(MicaboColor.inkTertiary)

                    Spacer(minLength: 0)

                    Text(t("ios.notifNow"))
                        .font(MicaboFont.ui(11.5, weight: .regular))
                        .foregroundStyle(MicaboColor.inkTertiary)
                }

                Text(i18n.t("ios.notifCardTitle", ["count": "\(dueCount)"]))
                    .font(MicaboFont.ui(15, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(t("ios.notifCardBody"))
                    .font(MicaboFont.reading(14, weight: .regular))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous))
        .micaboElevation(.card)
        .offset(y: hasLanded ? 0 : -40)
        .opacity(hasLanded ? 1 : 0)
        .scaleEffect(hasLanded ? 1 : 0.94)
        .animation(.spring(response: 0.55, dampingFraction: 0.72), value: hasLanded)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Le déroulé

    /// La semaine se coche jour après jour, puis la notification arrive. Sans mouvement
    /// réduit, tout est posé d'un coup.
    @MainActor
    private func play() async {
        guard !hasPlayed else { return }
        hasPlayed = true

        guard !reduceMotion else {
            checked = Self.days
            hasLanded = true
            return
        }

        // Un temps mort avant le premier jour : la semaine doit se remplir **après** que le
        // titre s'est écrit, sinon les deux animations se disputent l'œil.
        try? await Task.sleep(for: .milliseconds(420))
        for day in 1...Self.days {
            guard !Task.isCancelled else { return }
            checked = day
            Haptics.tick()
            try? await Task.sleep(for: .milliseconds(150))
        }

        try? await Task.sleep(for: .milliseconds(260))
        guard !Task.isCancelled else { return }
        hasLanded = true
        Haptics.light()
    }

    // MARK: - La vraie demande

    /// Ouvre la boîte du système, puis avance quoi qu'elle réponde.
    private func ask() async {
        guard !isAsking else { return }
        isAsking = true
        await NotificationPermission.request()
        isAsking = false
        model.advance()
    }
}
