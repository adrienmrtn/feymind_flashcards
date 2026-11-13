import SwiftUI

// MARK: - Le pays

/// **« Enchanté, {prénom} ! Tu étudies dans quel pays ? »**
///
/// Le pays passe devant la classe, et cet ordre est tout l'intérêt de l'écran : ce sont les
/// filières, les examens, les matières et le barème du pays choisi qui deviennent les
/// réponses des questions suivantes.
///
/// **Une liste à drapeaux, le pays du téléphone en tête et déjà choisi** : dans presque tous
/// les cas, la bonne réponse est celle que le téléphone connaît, et un appui avance. **La
/// recherche couvre le monde entier** : un pays de la liste s'y retrouve, les autres aussi,
/// et ceux dont on connaît le système scolaire (l'Autriche, le Brésil, l'Arabie saoudite…)
/// ouvrent leurs propres filières.
struct CountryStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onboardingStill) private var still

    @State private var query = ""
    @FocusState private var isSearching: Bool

    private var ask: String {
        guard let name = model.displayName.nilIfBlank else { return i18n.t("ios.onb5.q.country") }
        return i18n.t("ios.onb10.q.country", ["name": name])
    }

    private var isQuerying: Bool {
        query.nilIfBlank != nil
    }

    private var matches: [WorldCountry] {
        WorldCountries.matches(query, locale: i18n.locale)
    }

    /// Les pays de la liste, celui du téléphone d'abord. « Autre pays » n'y est pas : c'est
    /// la recherche.
    private var listed: [SchoolingCountry] {
        let guessed = SchoolingCountry.guessed()
        let rest = SchoolingCountry.allCases.filter { $0 != guessed && $0 != .other }
        return (guessed == .other ? [] : [guessed]) + rest
    }

    var body: some View {
        OnbQuestion(ask, mood: .happy, anchored: false) {
            VStack(spacing: OnbLayout.rowGap) {
                searchField

                if isQuerying {
                    results
                } else {
                    // Un pays trouvé par la recherche à un passage précédent reste en tête,
                    // choisi.
                    if model.country == .other, let custom = model.customCountry {
                        V3OptionRow(custom.name, emoji: custom.flag, isSelected: true) {
                            model.advance()
                        }
                    }
                    ForEach(listed) { country in
                        V3OptionRow(
                            country.localizedName(locale: i18n.locale),
                            emoji: country.flag,
                            isSelected: model.country == country
                        ) {
                            choose(country)
                        }
                    }
                }
            }

            OnbKeyboardRoom(isActive: model.step == .country)
        }
    }

    // MARK: La recherche

    private var searchField: some View {
        let placeholder = i18n.t("ios.countryPlaceholder")
        return HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(V3Font.label)
                .foregroundStyle(V3Color.ink3)
                .accessibilityHidden(true)

            if still {
                Text(placeholder)
                    .font(V3Font.body)
                    .foregroundStyle(V3Color.ink3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField("", text: $query, prompt: Text(placeholder).foregroundStyle(V3Color.ink3))
                    .font(V3Font.body)
                    .foregroundStyle(V3Color.ink)
                    .tint(V3Color.accent)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($isSearching)
                    .submitLabel(.search)
                    .accessibilityLabel(Text(placeholder))
            }

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(V3Font.body)
                        .foregroundStyle(V3Color.ink3)
                }
                .buttonStyle(MicaboPressableButtonStyle())
                .accessibilityLabel(Text(i18n.t("ios.clearSearch")))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(V3Color.soft, in: Capsule())
    }

    @ViewBuilder
    private var results: some View {
        if matches.isEmpty {
            Text(i18n.t("ios.countryNone"))
                .font(V3Font.body)
                .foregroundStyle(V3Color.ink2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
        } else {
            ForEach(matches) { country in
                V3OptionRow(country.name, emoji: country.flag, isSelected: false) {
                    choose(country)
                }
            }
        }
    }

    private func choose(_ country: SchoolingCountry) {
        model.select(country: country)
        model.advance()
    }

    private func choose(_ country: WorldCountry) {
        model.select(worldCountry: country)
        isSearching = false
        model.advance()
    }
}

// MARK: - La filière

/// **« Tu es dans quelle filière ? »**
///
/// « Lycée » ne dit pas ce qu'on étudie : un élève de terminale technologique et un élève de
/// terminale générale n'ont ni les mêmes matières, ni la même épreuve. L'écran ne s'affiche
/// que dans les pays décrits assez finement pour qu'il ait de vraies réponses
/// (`SchoolSystem`) ; ailleurs, il se saute et le palier large suffit.
struct SchoolTypeStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnbQuestion(i18n.t("ios.onb10.q.schoolType")) {
            VStack(spacing: OnbLayout.rowGap) {
                ForEach(model.tracks) { track in
                    V3OptionRow(track.title, icon: track.tier.icon, isSelected: model.track?.id == track.id) {
                        model.track = track
                        model.advance()
                    }
                }
            }
        }
    }
}

// MARK: - L'année

/// **« En quelle classe ? »** Elle décide des examens et des matières proposés ensuite, et du
/// niveau d'écriture des leçons. Après le bac, on ne parle plus de classe : « Tu es en quelle
/// année ? ».
struct SchoolYearStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var years: [SchoolYear] {
        model.track?.years ?? []
    }

    /// Au collège et au lycée, une classe ; après, une année.
    private var ask: String {
        switch model.track?.tier {
        case .lowerSecondary, .upperSecondary, nil: i18n.t("ios.onb10.q.year")
        default: i18n.t("ios.onb10.q.yearHigher")
        }
    }

    var body: some View {
        OnbQuestion(ask) {
            VStack(spacing: OnbLayout.rowGap) {
                ForEach(years) { year in
                    V3OptionRow(year.title, isSelected: model.year?.id == year.id) {
                        model.year = year
                        model.advance()
                    }
                }
            }
        }
    }
}

// MARK: - Le palier

/// **« Tu en es où dans tes études ? »** Le palier large, dans les termes du pays. Il ne se
/// pose qu'aux pays dont on ne connaît pas les filières.
struct LevelStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnbQuestion(i18n.t("ios.onb5.q.level")) {
            VStack(spacing: OnbLayout.rowGap) {
                ForEach(model.country.stages) { stage in
                    V3OptionRow(stage.localizedTitle, icon: stage.tier.icon, isSelected: model.stage == stage) {
                        model.stage = stage
                        model.advance()
                    }
                }
            }
        }
    }
}
