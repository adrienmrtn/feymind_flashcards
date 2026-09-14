import SwiftUI

/// **Le rappel quotidien, montré avant d'être demandé.**
///
/// Le parcours a porté un écran de rappels qui demandait « on te rappelle au bon moment ? »
/// sans rien demander au système : il notait une intention que personne ne relisait, et il
/// laissait croire qu'on avait dit oui à quelque chose. Il a été retiré pour cette raison,
/// et la bonne — une autorisation se demande quand elle sert.
///
/// Celui-ci fait l'inverse de son prédécesseur sur le seul point qui comptait : **il ouvre
/// la vraie boîte de dialogue d'iOS.** Ce qui le précède n'est donc pas une question, c'est
/// une réponse à la question que le système va poser trois secondes plus tard, et à laquelle
/// iOS ne laisse répondre qu'une fois : *à quoi ça va ressembler ?* On montre donc la
/// notification elle-même, avec le nombre de cartes que l'étudiant vient de planifier.
///
/// **Le nombre n'est pas un décor.** `DailyLoad` le calcule depuis le rythme choisi deux
/// écrans plus tôt : c'est ce qu'il verra vraiment demain matin. Un aperçu qui montrerait
/// « 12 cartes » à tout le monde serait une maquette, et une maquette dans un parcours est
/// une promesse qu'on ne tient pas.
///
/// Sa place est après la preuve sociale et avant le passage de relais : l'étudiant vient de
/// voir que d'autres s'y tiennent, on lui montre ce qui l'aidera à s'y tenir, puis on lui
/// passe la main. Demander avant qu'il ait vu le produit, c'était l'ancienne erreur.
struct NotificationsStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// Vrai le temps que la boîte du système soit à l'écran : le bouton ne doit pas
    /// pouvoir être appuyé deux fois pendant qu'iOS attend une réponse.
    @State private var isAsking = false
    /// Déclenche l'entrée de la notification. Elle ne se rejoue pas : une animation qui
    /// recommence à chaque retour sur l'écran cesse d'être une démonstration et devient un
    /// décor.
    @State private var hasLanded = false

    private func t(_ key: String, _ fallback: String) -> String {
        i18n?.t(key) ?? fallback
    }

    /// Ce que l'étudiant verra vraiment, et non un nombre d'exemple.
    private var dueCount: Int {
        DailyLoad.newCardsPerDay(dailyMinutes: OnboardingPreferences.dailyMinutes)
    }

    var body: some View {
        OnboardingScaffold(
            title: t("ios.notifTitle", "Ne loupe jamais un jour."),
            subtitle: t("ios.notifSubtitle", "Un rappel par jour, à l'heure où tu révises. Rien d'autre."),
            animatesTitle: true,
            expandsContent: true
        ) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                notificationStack
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
        .task {
            guard !hasLanded else { return }
            // Un temps mort avant l'entrée : la notification doit arriver **après** que le
            // titre s'est écrit, sinon les deux animations se disputent l'œil.
            try? await Task.sleep(for: .milliseconds(260))
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                hasLanded = true
            }
            Haptics.light()
        }
    }

    // MARK: - La pile de notifications

    /// La notification, et les deux qui dorment dessous.
    ///
    /// La pile est celle d'iOS — chaque carte plus étroite et plus basse que celle du
    /// dessus — et elle dit en une image ce qu'aucune phrase ne dirait aussi vite : il y en
    /// aura d'autres, une par jour. Elles n'ont pas de contenu propre : une pile de trois
    /// notifications lisibles se lirait comme trois rappels le même matin.
    private var notificationStack: some View {
        ZStack {
            ghost(scale: 0.86, offset: 30, opacity: 0.35, delay: 0.16)
            ghost(scale: 0.93, offset: 15, opacity: 0.6, delay: 0.08)
            banner
        }
        .padding(.horizontal, MicaboSpacing.xs)
    }

    private func ghost(scale: CGFloat, offset: CGFloat, opacity: Double, delay: Double) -> some View {
        RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous)
            .fill(MicaboColor.surface)
            .frame(height: 88)
            .micaboElevation(.row)
            .scaleEffect(x: scale, y: 1, anchor: .center)
            .offset(y: hasLanded ? offset : -40)
            .opacity(hasLanded ? opacity : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.78).delay(delay), value: hasLanded)
    }

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

                    Text(t("ios.notifNow", "maintenant"))
                        .font(MicaboFont.ui(11.5, weight: .regular))
                        .foregroundStyle(MicaboColor.inkTertiary)
                }

                Text(i18n?.t("ios.notifCardTitle", ["count": "\(dueCount)"])
                    ?? "Il te reste \(dueCount) cartes à réviser")
                    .font(MicaboFont.ui(15, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(t("ios.notifCardBody", "Dix minutes, et ta série tient."))
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
        // Elle tombe du haut et dépasse d'un cheveu avant de se poser : c'est le geste
        // d'une notification qui arrive, pas celui d'une vue qui apparaît.
        .offset(y: hasLanded ? 0 : -110)
        .opacity(hasLanded ? 1 : 0)
        .scaleEffect(hasLanded ? 1 : 0.94)
        .accessibilityElement(children: .combine)
    }

    // MARK: - La vraie demande

    /// Ouvre la boîte du système, puis avance quoi qu'elle réponde.
    ///
    /// Un refus n'arrête pas le parcours et ne déclenche aucun rattrapage : rien dans
    /// Micabo ne dépend des notifications, et redemander est de toute façon impossible.
    private func ask() async {
        guard !isAsking else { return }
        isAsking = true
        await NotificationPermission.request()
        isAsking = false
        model.advance()
    }
}
