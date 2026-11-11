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
    @Environment(\.onboardingStill) private var still

    /// Les rendus posent l'écran à son état final : la semaine cochée, la notification là.
    private var shownChecked: Int { still ? Self.days : checked }
    private var landed: Bool { still || hasLanded }

    private static let days = 7

    private func t(_ key: String) -> String {
        i18n.t(key)
    }

    /// Ce que l'étudiant verra vraiment, et non un nombre d'exemple.
    private var dueCount: Int {
        DailyLoad.newCardsPerDay(dailyMinutes: model.minutesPerDay)
    }

    /// La question de Mika : à l'heure choisie à l'écran d'avant, quand il y en a une.
    private var askTitle: String {
        guard let hour = model.studyHour else { return t("ios.onb7.notif.askAny") }
        return i18n.t("ios.onb7.notif.ask", ["hour": ProfileSummaryStepView.hourText(hour, locale: i18n.locale)])
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
            // **Mika demande, à l'heure qu'on vient de choisir** (lot 7) : « Ne loupe jamais un
            // jour. » n'était pas une question, et le rond qui suivait ouvrait la boîte d'iOS
            // sans qu'on ait rien demandé. Maintenant c'est un petit oui, à une question claire.
            title: askTitle,
            subtitle: t("ios.notifSub"),
            // Hors défilement : les ressorts qui centrent la scène n'ont pas de hauteur
            // dans un `ScrollView`.
            scrolls: false,
            expandsContent: true
        ) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 16) {
                    weekCard
                    banner
                    proofLine
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        } footer: {
            // Le rond fléché active le rappel ; à gauche, une sortie franche pour qui n'en
            // veut pas : on avance sans ouvrir la boîte du système, qu'iOS ne laisse poser
            // qu'une fois — elle reste disponible pour plus tard, dans les réglages.
            HStack(spacing: MicaboSpacing.md) {
                Button {
                    guard !isAsking else { return }
                    model.advance()
                } label: {
                    Text(t("ios.notif.skip"))
                        .font(MicaboFont.ui(15, weight: .bold))
                        .foregroundStyle(OnboardingPalette.gray)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MicaboPressableButtonStyle(dimming: true, feedback: .light))
                .disabled(isAsking)

                Spacer(minLength: 0)

                OnboardingArrowButton(isEnabled: !isAsking, isLoading: isAsking, fillsWidth: false) {
                    Task { await ask() }
                }
            }
        }
        .task { await play() }
    }

    // MARK: - La semaine

    /// **La série, comme dans l'app** : la flamme 3D et le compte, puis sept jours qui
    /// s'allument l'un après l'autre, chacun d'une petite flamme, aujourd'hui cerclé.
    private var weekCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                MicaboIconView(icon: .flame, size: 52)
                    .scaleEffect(shownChecked == Self.days ? 1.08 : 1)
                    .animation(MicaboMotion.quick, value: checked)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(shownChecked)")
                        .font(MicaboFont.number(34))
                        .foregroundStyle(MicaboColor.flameInk)
                        .contentTransition(.numericText())
                        .monospacedDigit()
                    Text(i18n.t("ios.notif.streakUnit"))
                        .font(MicaboFont.ui(13.5, weight: .bold))
                        .foregroundStyle(MicaboColor.flameInk.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 0)
            }
            .animation(OnboardingMotion.select, value: checked)

            HStack(spacing: 6) {
                ForEach(0..<Self.days, id: \.self) { index in
                    day(index)
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(colors: [MicaboColor.warmWashStart, MicaboColor.warmWashEnd], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(MicaboColor.warmWashStroke, lineWidth: 1.5))
        .micaboElevation(.card)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(i18n.t("ios.notif.streak", ["count": "\(shownChecked)"]))
    }

    private func day(_ index: Int) -> some View {
        let isChecked = index < shownChecked
        let isToday = index == Self.days - 1

        return VStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(isChecked
                        ? AnyShapeStyle(LinearGradient(colors: [MicaboColor.flame.opacity(0.85), MicaboColor.flame], startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(MicaboColor.flameTrack))

                if isChecked {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
            }
            .frame(width: 36, height: 36)
            .overlay {
                if isToday {
                    Circle()
                        .strokeBorder(MicaboColor.flame, lineWidth: 2)
                        .padding(-4)
                }
            }
            .scaleEffect(isChecked ? 1 : 0.9)

            Text(dayInitials[index])
                .font(MicaboFont.ui(11.5, weight: .bold))
                .foregroundStyle(isChecked ? MicaboColor.flameInk : MicaboColor.warmProse)
        }
        .frame(maxWidth: .infinity)
        .animation(MicaboMotion.quick, value: isChecked)
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
                        .foregroundStyle(OnboardingPalette.gray)

                    Spacer(minLength: 0)

                    Text(t("ios.notifNow"))
                        .font(MicaboFont.ui(11.5, weight: .regular))
                        .foregroundStyle(OnboardingPalette.gray)
                }

                Text(i18n.t("ios.notifCardTitle", ["count": "\(dueCount)"]))
                    .font(MicaboFont.ui(15, weight: .semibold))
                    .foregroundStyle(OnboardingPalette.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                // Le temps choisi deux écrans plus tôt, et pas « dix minutes » pour tout le monde.
                Text(i18n.t("ios.onb7.notif.body", ["n": "\(model.minutesPerDay)"]))
                    .font(MicaboFont.ui(14, weight: .regular))
                    .foregroundStyle(OnboardingPalette.gray)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
        .micaboElevation(.card)
        .opacity(landed ? 1 : 0)
        .offset(y: landed ? 0 : -18)
        .animation(OnboardingMotion.enter, value: hasLanded)
        .accessibilityElement(children: .combine)
    }

    /// **Ce qu'on promet, et rien de plus** : un seul rappel par jour, qu'on coupe quand on
    /// veut. Il y avait là « les élèves révisent 2× plus souvent avec les rappels » : un
    /// chiffre que rien ne sourçait (lot 7).
    private var proofLine: some View {
        OnboardingAccentText(
            template: i18n.t("ios.onb7.notif.one"),
            size: 15,
            alignment: .leading,
            color: OnboardingPalette.gray
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(landed ? 1 : 0)
        .animation(OnboardingMotion.enter.delay(0.15), value: hasLanded)
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
