import SwiftUI

/// **Les jours où l'on ne révise pas.**
///
/// C'est l'écran `/commencer/repos` du site, à la case près. Un plan qui remplit les sept
/// jours de la semaine est un plan qu'on abandonne au premier dimanche manqué, parce qu'un
/// retard non prévu se lit comme un échec. Le poser ici, avant que quoi que ce soit ne soit
/// calculé, change la nature du dimanche : il n'est plus un jour perdu, il est un jour de
/// repos, et le reste de la semaine a été construit avec.
///
/// Une semaine, pas un calendrier : la question porte sur une **habitude**, et une habitude se
/// décrit en sept cases. Les dates viendront à la création d'un plan. Ne rien cocher est une
/// réponse : celui qui révise tous les jours continue sans rien dire.
///
/// La réponse part dans `profiles.weekly_minutes`, la colonne que le site lit pour son plan.
/// Tant que l'iPhone ne la posait pas, un compte créé ici et ouvert sur le site avait un plan
/// qui travaillait le dimanche, et l'inverse.
struct RestDaysStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var locale: UiLocale { i18n?.locale ?? .resolved() }

    var body: some View {
        OnboardingScaffold(
            title: L10n.t("onboarding.reposTitle", locale: locale),
            subtitle: L10n.t("onboarding.reposLead", locale: locale),
            titleSize: 28,
            animatesTitle: true
        ) {
            VStack(spacing: 20) {
                HStack(spacing: 8) {
                    ForEach(1...7, id: \.self) { iso in
                        dayCell(iso)
                    }
                }

                // La ligne garde sa hauteur vide ou pleine : sans ça, la grille saute d'un
                // cran dès qu'on touche une case.
                Text(countLabel)
                    .font(MicaboFont.hanken(13, weight: .medium))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .frame(height: 20)
                    .animation(OnboardingMotion.tap, value: model.restDays)
            }
            .padding(.top, 8)
        } footer: {
            OnboardingContinueButton {
                model.advance()
            }
        }
    }

    private var initials: [String] {
        MicaboCalendar.weekdayInitials(locale: locale)
    }

    private var countLabel: String {
        let count = model.restDays.count
        guard count > 0 else { return "" }
        return L10n.t("onboarding.reposCount", locale: locale, vars: ["count": "\(count)"])
    }

    /// Le jour choisi est **doux**, pas noir : sept cases pleines en encre font une grille de
    /// deuil, alors qu'on parle de repos. L'accent le dit mieux.
    private func dayCell(_ iso: Int) -> some View {
        let off = model.restDays.contains(iso)
        return Button {
            toggle(iso)
        } label: {
            VStack(spacing: 6) {
                Text(initials.indices.contains(iso - 1) ? initials[iso - 1] : "")
                    .font(MicaboFont.hanken(19, weight: .semibold))
                    .foregroundStyle(off ? MicaboColor.accent : MicaboColor.ink)
                Text("💤")
                    .font(.system(size: 20))
                    .opacity(off ? 1 : 0)
                    .scaleEffect(off ? 1 : 0.6)
                    .frame(height: 24)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 92)
            .background(off ? MicaboColor.accentSoft : MicaboColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(off ? MicaboColor.accent : MicaboColor.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
        .accessibilityLabel(initials.indices.contains(iso - 1) ? initials[iso - 1] : "")
        .accessibilityAddTraits(off ? .isSelected : [])
    }

    private func toggle(_ iso: Int) {
        withAnimation(OnboardingMotion.tap) {
            if model.restDays.contains(iso) {
                model.restDays.remove(iso)
            } else {
                model.restDays.insert(iso)
            }
        }
    }
}
