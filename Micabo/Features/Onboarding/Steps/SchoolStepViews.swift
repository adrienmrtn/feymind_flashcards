import SwiftUI

// MARK: - Ce que le parcours dit du pays

extension OnboardingModel {
    /// Le pays de l'élève, dans la langue de l'app : celui de la liste, ou celui de la recherche.
    func countryName(locale: UiLocale) -> String {
        if country == .other, let customCountry { return customCountry.name }
        return country.localizedName(locale: locale)
    }
}

// MARK: - Le pays

/// **« Tu étudies dans quel pays ? »**
///
/// Le pays passe devant la classe, et cet ordre est tout l'intérêt de l'écran : ce sont les
/// filières, les examens, les matières et le barème du pays choisi qui deviennent les
/// réponses des questions suivantes. Mika le dit, avec le prénom qu'il vient d'apprendre.
///
/// **Une liste à drapeaux, le pays du téléphone en tête et déjà choisi** ; **la recherche
/// couvre le monde entier**. Un appui coche, et la page part à la fin du ressort.
struct CountryStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onboardingStill) private var still

    @State private var query = ""
    @FocusState private var isSearching: Bool

    private var say: OnbSay {
        guard let name = model.displayName.nilIfBlank else {
            return OnbSay(i18n.t("ios.onb12.say.countryAny"), mood: .look)
        }
        return OnbSay(i18n.t("ios.onb12.say.country", ["name": name]), mood: .happy)
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
        OnbQuestion(i18n.t("ios.onb12.q.country"), say: say) {
            VStack(spacing: OnbLayout.rowGap) {
                searchField

                if isQuerying {
                    results
                } else {
                    if model.country == .other, let custom = model.customCountry {
                        OnbOption(title: custom.name, emoji: custom.flag, isSelected: true) {
                            model.advance()
                        }
                    }
                    ForEach(listed) { country in
                        OnbOption(
                            title: country.localizedName(locale: i18n.locale),
                            emoji: country.flag,
                            isSelected: model.country == country
                        ) {
                            choose(country)
                        }
                    }
                }
            }

            OnbKeyboardRoom(isActive: model.step == .country)
        } footer: {
            V3Button(i18n.t("common.continue"), isEnabled: model.hasAnsweredCountry) {
                isSearching = false
                model.advance()
            }
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
                OnbOption(title: country.name, emoji: country.flag, isSelected: false) {
                    choose(country)
                }
            }
        }
    }

    private func choose(_ country: SchoolingCountry) {
        OnbPick.choose(on: .country, model: model) {
            model.select(country: country)
        }
    }

    private func choose(_ country: WorldCountry) {
        isSearching = false
        OnbPick.choose(on: .country, model: model) {
            model.select(worldCountry: country)
        }
    }
}

// MARK: - La filière

/// **« Tu es dans quelle filière ? »** Mika reprend le pays : il en connaît les filières, les
/// examens et le barème. L'écran ne s'affiche que dans les pays décrits assez finement pour
/// qu'il ait de vraies réponses (`SchoolSystem`).
struct SchoolTypeStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnbQuestion(
            i18n.t("ios.onb12.q.schoolType"),
            say: OnbSay(i18n.t("ios.onb12.react.country", ["country": model.countryName(locale: i18n.locale)]), mood: .happy)
        ) {
            VStack(spacing: OnbLayout.rowGap) {
                ForEach(model.tracks) { track in
                    OnbOption(title: track.title, icon: track.tier.icon, isSelected: model.track?.id == track.id) {
                        OnbPick.choose(on: .schoolType, model: model) { model.track = track }
                    }
                }
            }
        } footer: {
            // Un appui suffit (la page part à la fin du ressort) ; le bouton reste à sa place,
            // le même que partout, pour qui revient sur l'écran.
            V3Button(i18n.t("common.continue"), isEnabled: model.track != nil) {
                model.advance()
            }
        }
    }
}

// MARK: - L'année

/// **« En quelle classe ? »** Elle décide des examens et des matières proposés ensuite, et du
/// niveau d'écriture des leçons. Après le bac, « En quelle année ? ». Mika reprend la filière.
struct SchoolYearStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var years: [SchoolYear] {
        model.track?.years ?? []
    }

    /// Au collège et au lycée, une classe ; après, une année.
    private var title: String {
        switch model.track?.tier {
        case .lowerSecondary, .upperSecondary, nil: i18n.t("ios.onb12.q.year")
        default: i18n.t("ios.onb12.q.yearHigher")
        }
    }

    private var say: OnbSay {
        guard let track = model.track else { return OnbSay(i18n.t("ios.onb12.say.level"), mood: .idle) }
        return OnbSay(i18n.t("ios.onb12.react.track", ["track": track.title]), mood: .happy)
    }

    var body: some View {
        OnbQuestion(title, say: say) {
            VStack(spacing: OnbLayout.rowGap) {
                ForEach(years) { year in
                    OnbOption(title: year.title, isSelected: model.year?.id == year.id) {
                        OnbPick.choose(on: .year, model: model) { model.year = year }
                    }
                }
            }
        } footer: {
            // Un appui suffit (la page part à la fin du ressort) ; le bouton reste à sa place,
            // le même que partout, pour qui revient sur l'écran.
            V3Button(i18n.t("common.continue"), isEnabled: model.year != nil) {
                model.advance()
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
        OnbQuestion(
            i18n.t("ios.onb12.q.level"),
            say: OnbSay(i18n.t("ios.onb12.react.countryAny", ["country": model.countryName(locale: i18n.locale)]), mood: .happy)
        ) {
            VStack(spacing: OnbLayout.rowGap) {
                ForEach(model.country.stages) { stage in
                    OnbOption(title: stage.localizedTitle, icon: stage.tier.icon, isSelected: model.stage == stage) {
                        OnbPick.choose(on: .level, model: model) { model.stage = stage }
                    }
                }
            }
        } footer: {
            // Un appui suffit (la page part à la fin du ressort) ; le bouton reste à sa place,
            // le même que partout, pour qui revient sur l'écran.
            V3Button(i18n.t("common.continue"), isEnabled: model.stage != nil) {
                model.advance()
            }
        }
    }
}
