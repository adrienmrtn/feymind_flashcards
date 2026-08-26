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
/// Des pastilles à drapeau : un drapeau se reconnaît avant qu'on ait lu le nom. La France est
/// pré-choisie parce que c'est le cas de la grande majorité, et c'est ce que l'app supposait
/// déjà en silence.
///
/// **« Autre pays » n'est plus une impasse.** La pastille rendait un « ailleurs » qui ne
/// disait rien de plus que le silence : on ne savait ni où était l'étudiant, ni combien
/// d'entre eux venaient du même endroit. Elle ouvre maintenant un champ de recherche sur tous
/// les pays du monde, et le bouton attend qu'on en ait choisi un.
struct CountryStepView: View {
    @Environment(OnboardingModel.self) private var model

    @State private var query = ""
    @FocusState private var isSearching: Bool

    private var matches: [WorldCountry] {
        guard model.customCountry == nil else { return [] }
        return WorldCountries.matches(query)
    }

    var body: some View {
        OnboardingScaffold(
            title: "Tu étudies où ?",
            titleSize: 32,
            // Vingt-cinq pays en pastilles ne tiennent pas sur un écran : il défile plutôt
            // que de rogner une réponse.
            scrolls: true,
            animatesTitle: true
        ) {
            VStack(alignment: .leading, spacing: 14) {
                MicaboFlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(SchoolingCountry.allCases) { country in
                        OnboardingChoiceChip(
                            title: title(for: country),
                            emoji: flag(for: country),
                            isSelected: model.country == country
                        ) {
                            select(country)
                        }
                    }
                }

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

    /// La pastille « Autre pays » porte le pays choisi une fois qu'il l'est : elle cesse
    /// alors d'être une catégorie pour devenir une réponse.
    private func title(for country: SchoolingCountry) -> String {
        guard country == .other, let custom = model.customCountry else { return country.name }
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
                    Text("Aucun pays de ce nom.")
                        .font(MicaboFont.hanken(12, weight: .regular))
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

            TextField("Ex. Brésil, Japon, Sénégal…", text: $query)
                .font(MicaboFont.hanken(16, weight: .medium))
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
                            .font(MicaboFont.hanken(15, weight: .medium))
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
                .font(MicaboFont.hanken(15, weight: .semibold))
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
                Text("Changer")
                    .font(MicaboFont.hanken(13, weight: .semibold))
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
