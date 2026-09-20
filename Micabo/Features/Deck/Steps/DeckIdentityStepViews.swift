import SwiftUI

/// **La matière du deck.**
///
/// Elle est proposée avant d'être cherchée : un étudiant de terminale générale à qui l'on
/// montre ses huit matières répond en un geste, là où un champ de recherche vide le laisse
/// deviner ce que l'app accepte. Le catalogue complet reste dessous, pour tout le reste.
///
/// La matière n'est pas décorative : elle part à la génération et décide des consignes
/// d'écriture. Une fiche de droit ne s'écrit pas comme une fiche de SVT, et c'est cette
/// réponse-là qui le dit — à l'import ordinaire, le modèle devait la deviner sur le texte.
struct DeckSubjectStepView: View {
    @Bindable var setup: DeckSetup
    var onNext: () -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var query = ""

    private var suggested: [String] {
        SchoolSubjects.suggested(
            stage: OnboardingPreferences.educationStage,
            country: OnboardingPreferences.schoolingCountry
        )
    }

    /// Ce que la recherche rend, ou les matières du niveau quand on n'a rien tapé.
    private var shown: [String] {
        guard let needle = query.nilIfBlank else { return suggested }
        let folded = needle.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return SubjectCatalog.allSubjects.filter {
            $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .contains(folded)
        }
    }

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.deckSetup.subject"),
            animatesTitle: true
        ) {
            VStack(spacing: MicaboSpacing.sm) {
                DeckSearchField(
                    text: $query,
                    placeholder: i18n.t("ios.deckSetup.subject.search")
                )

                MicaboFlowLayout(spacing: 8) {
                    ForEach(shown, id: \.self) { subject in
                        OnboardingChoiceChip(
                            title: subject,
                            emoji: SubjectCatalog.emoji(for: subject),
                            isSelected: setup.subject == subject
                        ) {
                            setup.subject = subject
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Aucune matière du catalogue ne correspond : on accepte ce qui a été tapé.
                // Refuser « Œnologie » parce qu'elle n'est pas dans une liste écrite à Paris
                // serait dire à cet étudiant que son cours n'existe pas.
                if let typed = query.nilIfBlank, shown.isEmpty {
                    OnboardingChoiceRow(
                        title: typed,
                        emoji: "✨",
                        isSelected: setup.subject == typed
                    ) {
                        setup.subject = typed
                    }
                }
            }
        } footer: {
            OnboardingContinueButton(isEnabled: setup.hasSubject, action: onNext)
        }
    }
}

/// **Le nom du deck.**
///
/// Proposé, pas demandé à vide : la matière vient d'être choisie, et c'est déjà un nom
/// acceptable. L'étudiant qui a trois decks d'histoire le changera ; celui qui n'en a qu'un
/// appuie sur continuer.
struct DeckNameStepView: View {
    @Bindable var setup: DeckSetup
    var onNext: () -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @FocusState private var isFocused: Bool

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.deckSetup.name"),
            animatesTitle: true
        ) {
            VStack(spacing: MicaboSpacing.sm) {
                DeckSearchField(
                    text: $setup.name,
                    placeholder: setup.subject ?? i18n.t("ios.deckSetup.name.placeholder"),
                    icon: nil,
                    capitalization: .sentences,
                    isFocused: $isFocused
                )

                if let subject = setup.subject?.nilIfBlank, setup.name.nilIfBlank == nil {
                    OnboardingChoiceRow(
                        title: subject,
                        emoji: SubjectCatalog.emoji(for: subject),
                        isSelected: false
                    ) {
                        setup.name = subject
                    }
                }
            }
            .onAppear { isFocused = true }
        } footer: {
            OnboardingContinueButton(isEnabled: setup.hasName, action: onNext)
        }
    }
}

/// **Avec des documents, ou sans.**
///
/// Deux réponses, donc deux tuiles côte à côte : empilées, la première se lirait comme la
/// bonne réponse et la seconde comme un repli. Elles ne sont pas de même nature — l'une lit
/// le cours de l'étudiant, l'autre l'écrit — et elles méritent d'être comparées d'un regard.
struct DeckSourceStepView: View {
    @Bindable var setup: DeckSetup
    var onNext: () -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var subject: String {
        setup.subject?.nilIfBlank ?? i18n.t("ios.deckSetup.thisSubject")
    }

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.deckSetup.source"),
            animatesTitle: true,
            expandsContent: true
        ) {
            VStack(spacing: 10) {
                OnboardingChoiceRow(
                    title: i18n.t("ios.deckSetup.source.materials"),
                    emoji: "📄",
                    isSelected: setup.source == .materials,
                    fillsHeight: true,
                    rank: 0
                ) {
                    setup.source = .materials
                }

                OnboardingChoiceRow(
                    title: i18n.t("ios.deckSetup.source.ai", ["subject": subject]),
                    emoji: "✨",
                    isSelected: setup.source == .generated,
                    fillsHeight: true,
                    rank: 1
                ) {
                    setup.source = .generated
                }
            }
        } footer: {
            OnboardingContinueButton(isEnabled: setup.source != nil, action: onNext)
        }
    }
}

/// **Ce qu'on veut apprendre, précisément.**
///
/// Cet écran n'existe que sur la branche sans document, et c'est lui qui la rend utilisable.
/// « Écris-moi un cours de géographie de troisième » produit un survol de quarante pages que
/// personne ne révisera ; « la mondialisation et ses acteurs » produit un cours. Le champ est
/// donc une vraie question, avec une sortie franche en dessous pour qui veut tout.
struct DeckTopicStepView: View {
    @Bindable var setup: DeckSetup
    var onNext: () -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @FocusState private var isFocused: Bool

    private var subject: String {
        setup.subject?.nilIfBlank ?? i18n.t("ios.deckSetup.thisSubject")
    }

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.deckSetup.topic", ["subject": subject]),
            animatesTitle: true
        ) {
            VStack(spacing: MicaboSpacing.sm) {
                DeckSearchField(
                    text: $setup.topic,
                    placeholder: i18n.t("ios.deckSetup.topic.placeholder"),
                    icon: nil,
                    capitalization: .sentences,
                    isFocused: $isFocused
                )
            }
            .onAppear { isFocused = true }
        } footer: {
            VStack(spacing: 10) {
                OnboardingContinueButton(
                    isEnabled: setup.topic.nilIfBlank != nil,
                    action: onNext
                )

                // **« Tout apprendre » est une réponse, pas un abandon.** Elle envoie une
                // chaîne vide, que le serveur lit comme « tout le programme de la matière ».
                Button {
                    setup.topic = ""
                    onNext()
                } label: {
                    Text(i18n.t("ios.deckSetup.topic.everything"))
                        .font(MicaboFont.ui(14, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                }
                .buttonStyle(MicaboPressableButtonStyle(dimming: true, feedback: .selection))
            }
        }
    }
}

// MARK: - Le champ

/// Un champ de saisie à la forme du parcours : le même fond, le même rayon, le même filet
/// que les rangées de réponse. Un `TextField` nu au milieu de tuiles arrondies se lit comme
/// un élément d'un autre écran.
struct DeckSearchField: View {
    @Binding var text: String
    var placeholder: String
    var icon: String? = "magnifyingglass"
    var capitalization: TextInputAutocapitalization = .never
    var isFocused: FocusState<Bool>.Binding? = nil

    @FocusState private var localFocus: Bool

    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(MicaboColor.inkTertiary)
            }

            field
                .font(MicaboFont.ui(16, weight: .medium))
                .foregroundStyle(MicaboColor.ink)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled()
                .submitLabel(.done)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(MicaboColor.inkTertiary)
                }
                .buttonStyle(MicaboPressableButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
    }

    /// Le focus est optionnel : la plupart des écrans veulent le clavier tout de suite, celui
    /// de la matière non — il montre d'abord les matières du niveau, et ouvrir le clavier
    /// par-dessus les cacherait.
    @ViewBuilder
    private var field: some View {
        if let isFocused {
            TextField(placeholder, text: $text)
                .focused(isFocused)
        } else {
            TextField(placeholder, text: $text)
                .focused($localFocus)
        }
    }
}
