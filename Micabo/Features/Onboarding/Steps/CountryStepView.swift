import SwiftUI

/// Où l'étudiant est scolarisé. **C'est la première question du parcours.**
///
/// Elle passe devant « tu en es où ? », et cet ordre est tout l'intérêt de l'écran : ce sont
/// les paliers du pays choisi qui deviennent les réponses de la question suivante. « Les
/// attendus du bac » ne veut rien dire pour un lycéen belge, un étudiant québécois ne passe
/// pas de concours de première année de santé, au Québec « baccalauréat » désigne un diplôme
/// universitaire, et proposer « Prépa » ou « PASS » à un Américain ne lui laisse aucune
/// réponse juste. Poser le niveau d'abord obligeait à servir les mêmes sept réponses
/// françaises à tout le monde.
///
/// **Un menu déroulant, et le pays de l'appareil déjà dedans.** Vingt-cinq pastilles à
/// drapeau ne tenaient pas sur un écran : il fallait défiler pour voir la sienne, alors que
/// dans presque tous les cas la bonne réponse est celle que le téléphone connaît déjà. Le
/// menu la montre choisie, on appuie sur Continuer, et la liste n'apparaît qu'à qui en a
/// besoin. Le pays de l'appareil est pré-choisi — plus la France pour tout le monde, sans
/// quoi un iPhone anglais n'ouvrirait que des lycées français à l'écran suivant.
///
/// **« Autre pays » n'est plus une impasse.** La pastille rendait un « ailleurs » qui ne
/// disait rien de plus que le silence : on ne savait ni où était l'étudiant, ni combien
/// d'entre eux venaient du même endroit. Elle ouvre maintenant un champ de recherche sur tous
/// les pays du monde, et le bouton attend qu'on en ait choisi un.
struct CountryStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var query = ""
    @FocusState private var isSearching: Bool

    private var matches: [WorldCountry] {
        guard model.customCountry == nil else { return [] }
        return WorldCountries.matches(query, locale: i18n.locale)
    }

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.countryTitle"),
            titleSize: 26,
            scrolls: true,
            animatesTitle: true
        ) {
            VStack(alignment: .leading, spacing: 14) {
                dropdown

                if model.country == .other {
                    elsewherePicker
                        .transition(.opacity.combined(with: .offset(y: -6)))
                }
            }
            .animation(OnboardingMotion.shift, value: model.country)
            .animation(OnboardingMotion.shift, value: model.customCountry)
        } footer: {
            OnboardingContinueButton(isEnabled: model.hasAnsweredCountry) {
                model.advance()
            }
        }
    }

    /// **Le menu.** Un `Picker` en ligne dans un `Menu` : c'est ce qui donne la liste
    /// cochée du système sous un bouton qu'on dessine soi-même — la forme d'une réponse
    /// choisie, filet violet compris, avec le chevron double qui dit qu'elle se change.
    private var dropdown: some View {
        Menu {
            Picker(
                selection: Binding(
                    get: { model.country },
                    set: { select($0) }
                )
            ) {
                ForEach(SchoolingCountry.allCases) { country in
                    Text("\(country.flag)  \(country.localizedName(locale: i18n.locale))")
                        .tag(country)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 13) {
                Text(flag(for: model.country))
                    .font(.system(size: 24))

                Text(title(for: model.country))
                    .font(MicaboFont.ui(16, weight: .semibold))
                    .foregroundStyle(MicaboColor.accent)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MicaboColor.accent)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .background(MicaboColor.accentWash, in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous)
                    .strokeBorder(MicaboColor.accent, lineWidth: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .light))
        .accessibilityLabel(i18n.t("ios.countryTitle"))
        .accessibilityValue(title(for: model.country))
    }

    /// La ligne « Autre pays » porte le pays choisi une fois qu'il l'est : elle cesse
    /// alors d'être une catégorie pour devenir une réponse.
    private func title(for country: SchoolingCountry) -> String {
        guard country == .other, let custom = model.customCountry else {
            return country.localizedName(locale: i18n.locale)
        }
        return custom.name
    }

    private func flag(for country: SchoolingCountry) -> String {
        guard country == .other, let custom = model.customCountry else { return country.flag }
        return custom.flag
    }

    private func select(_ country: SchoolingCountry) {
        Haptics.selection()
        withAnimation(OnboardingMotion.tap) {
            model.select(country: country)
        }
        if country == .other, model.customCountry == nil {
            query = ""
            // La recherche prend le clavier d'elle-même : demander « Autre pays » puis
            // devoir viser un champ est un appui de plus pour la même intention.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { isSearching = true }
        } else {
            isSearching = false
        }
    }

    // MARK: - La recherche mondiale

    @ViewBuilder
    private var elsewherePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let custom = model.customCountry {
                chosen(custom)
            } else {
                searchField

                if !matches.isEmpty {
                    resultsList
                } else if query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 {
                    Text(i18n.t("ios.countryNone"))
                        .font(MicaboFont.ui(12, weight: .regular))
                        .foregroundStyle(MicaboColor.inkTertiary)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)

            TextField(i18n.t("ios.countryPlaceholder"), text: $query)
                .font(MicaboFont.ui(16, weight: .medium))
                .foregroundStyle(MicaboColor.ink)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($isSearching)
                .submitLabel(.done)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(MicaboColor.inkTertiary)
                }
                .buttonStyle(MicaboPressableButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous)
                .strokeBorder(isSearching ? MicaboColor.ink : MicaboColor.stroke, lineWidth: isSearching ? 1.6 : 1)
        }
    }

    private var resultsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(matches.enumerated()), id: \.element.id) { index, country in
                Button {
                    choose(country)
                } label: {
                    HStack(spacing: 12) {
                        Text(country.flag)
                            .font(.system(size: 20))

                        Text(country.name)
                            .font(MicaboFont.ui(15, weight: .medium))
                            .foregroundStyle(MicaboColor.ink)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MicaboRowButtonStyle(feedback: .selection))

                if index < matches.count - 1 {
                    Rectangle()
                        .fill(MicaboColor.stroke)
                        .frame(height: 1)
                        .padding(.leading, 46)
                }
            }
        }
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
    }

    private func chosen(_ country: WorldCountry) -> some View {
        HStack(spacing: 10) {
            Text(country.flag)
                .font(.system(size: 20))

            Text(country.name)
                .font(MicaboFont.ui(15, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)

            Spacer(minLength: 0)

            Button {
                Haptics.light()
                withAnimation(OnboardingMotion.tap) {
                    model.customCountry = nil
                }
                query = ""
                isSearching = true
            } label: {
                Text(i18n.t("ios.countryChange"))
                    .font(MicaboFont.ui(13, weight: .semibold))
                    .foregroundStyle(MicaboColor.accent)
            }
            .buttonStyle(MicaboPressableButtonStyle())
        }
        .padding(12)
        .background(MicaboColor.positiveSoft, in: RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous))
    }

    private func choose(_ country: WorldCountry) {
        isSearching = false
        query = ""
        withAnimation(OnboardingMotion.tap) {
            model.customCountry = country
        }
    }
}
