import SwiftUI

/// **Pour quoi tu révises ce deck.**
///
/// La réponse ne change pas le rythme — c'est la date qui s'en charge, et elle seule. Elle
/// décide de deux choses : si la question de la note visée se pose, et dans quels mots on
/// demandera la date. « C'est quand, ton examen ? » posé à quelqu'un qui n'en passe pas est
/// la meilleure façon d'obtenir une date au hasard.
struct DeckPurposeStepView: View {
    @Bindable var setup: DeckSetup
    var onNext: () -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.deckSetup.purpose"),
            animatesTitle: true,
            expandsContent: true
        ) {
            OnboardingAnswerList(DeckPurpose.allCases) { rank, purpose in
                OnboardingChoiceRow(
                    title: i18n.t(purpose.titleKey),
                    emoji: purpose.emoji,
                    isSelected: setup.purpose == purpose,
                    fillsHeight: true,
                    rank: rank
                ) {
                    setup.purpose = purpose
                }
            }
        } footer: {
            OnboardingContinueButton(isEnabled: setup.purpose != nil, action: onNext)
        }
    }
}

/// **La note visée.**
///
/// Elle ne change rien au plan, et elle est posée quand même. Ce n'est pas une inconséquence :
/// dire à voix haute où l'on veut arriver est la seule chose qu'un chiffre décoratif fait
/// vraiment, et c'est ce que font les applications de sport avec un poids cible. Ce qui
/// serait malhonnête serait de laisser croire qu'elle intensifie le travail — l'écran ne le
/// dit nulle part.
///
/// Le curseur est celui des moyennes du parcours d'accueil : la note en grand, une piste
/// dessous, le pouce qui glisse. La colonne de crans qui vivait ici se lisait ; celui-ci
/// se règle.
struct DeckGradeStepView: View {
    @Bindable var setup: DeckSetup
    var onNext: () -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var choices: [GradeTick] { setup.scale.choices }

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.deckSetup.grade"),
            // Hors défilement : voir `CurrentAverageStepView`, les ressorts qui centrent le
            // curseur n'ont pas de hauteur dans un `ScrollView`.
            scrolls: false,
            expandsContent: true
        ) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                GradeWheel(
                    choices: choices,
                    score: Binding(
                        get: { setup.targetScore },
                        set: { if let value = $0 { setup.targetScore = value } }
                    ),
                    fallbackIndex: choices.firstIndex { $0.score == setup.targetScore },
                    label: i18n.t("ios.deckSetup.grade")
                )
                Spacer(minLength: 0)
                Spacer(minLength: 0)
            }
        } footer: {
            OnboardingContinueButton(action: onNext)
        }
    }
}

/// **La date, et ce qu'elle fait.**
///
/// L'écran annonce l'effet pendant qu'on choisit : le nombre de cartes neuves par jour
/// s'affiche sous le calendrier et bouge avec la date. C'est la seule façon honnête de poser
/// cette question — sinon l'étudiant choisit une date sans savoir ce qu'elle engage, et
/// découvre le lendemain une session de quarante cartes.
///
/// Le deck n'a pas encore de cartes à ce stade : le compte annoncé repose sur l'estimation
/// de `DeckBuilder`, et l'écran le dit (« environ »). Mentir d'un chiffre exact qui bougera
/// serait pire que d'annoncer un ordre de grandeur juste.
struct DeckDeadlineStepView: View {
    @Bindable var setup: DeckSetup
    var onNext: () -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// Deux semaines : assez loin pour qu'un plan existe, assez près pour qu'on le corrige.
    private static let defaultOffset = 14

    @State private var date: Date = Calendar.current.date(
        byAdding: .day,
        value: DeckDeadlineStepView.defaultOffset,
        to: Date()
    ) ?? Date()

    /// L'estimation du volume du deck, avant qu'il n'existe. Elle sert uniquement à montrer
    /// l'ordre de grandeur du rythme.
    private var estimatedCards: Int {
        guard setup.source == .materials else { return 45 }
        let length = setup.materials.reduce(0) { $0 + ($1.document?.text.count ?? 0) }
        return DeckBuilder.cardCount(forContextLength: min(length, 30_000), chapters: 6)
    }

    private var readout: DeckPace.Readout {
        DeckPace.readout(remaining: estimatedCards, deadline: date)
    }

    var body: some View {
        OnboardingScaffold(
            title: i18n.t(setup.purpose?.deadlineQuestionKey ?? "ios.deckSetup.examDate"),
            animatesTitle: true
        ) {
            VStack(spacing: MicaboSpacing.md) {
                DatePicker(
                    "",
                    selection: $date,
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(MicaboColor.accent)
                .labelsHidden()
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                        .fill(MicaboColor.surface)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                        .strokeBorder(MicaboColor.stroke, lineWidth: 1)
                }

                paceNote
            }
        } footer: {
            OnboardingContinueButton {
                setup.deadline = date
                onNext()
            }
        }
    }

    /// Ce que la date change, écrit pendant qu'on la choisit : le chiffre, et rien sous le
    /// chiffre. La ligne qui expliquait s'il était serré ou confortable disait ce que le
    /// chiffre dit déjà.
    private var paceNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MicaboColor.accent)
            Text(i18n.t("ios.deckSetup.pace", ["count": "\(readout.perDay)"]))
                .font(MicaboFont.ui(15, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(MicaboColor.accentSoft, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        .animation(OnboardingMotion.tap, value: readout)
    }
}

/// **L'auto-évaluation.**
///
/// Décorative, et assumée comme telle. Personne ne sait ce qu'il sait — c'est précisément
/// pourquoi on révise, et c'est pourquoi rien dans le plan n'en dépend. Elle est posée parce
/// qu'elle fait faire à l'étudiant la seule chose utile qu'on puisse lui demander avant de
/// commencer : regarder son cours en face.
struct DeckConfidenceStepView: View {
    @Bindable var setup: DeckSetup
    var onNext: () -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// **Cinq réponses, pas cent.**
    ///
    /// L'écran affichait un nombre de soixante-quatre points entre zéro et cent, et un
    /// curseur continu dessous. Personne ne connaît « trente-sept pour cent » d'un cours :
    /// la question porte sur une impression, et lui demander deux chiffres significatifs la
    /// rend plus difficile sans la rendre plus juste. Pire, le chiffre était le gros de
    /// l'écran et la phrase le petit — alors que c'est la phrase qui est la réponse.
    ///
    /// Les cinq crans sont ceux que les seuils découpaient déjà. Ils ne perdent donc rien :
    /// `setup.confidence` valait de toute façon une de ces cinq tranches pour qui devait s'en
    /// servir.
    private static let steps: [(key: String, confidence: Double)] = [
        ("ios.deckSetup.confidence.none", 0),
        ("ios.deckSetup.confidence.little", 0.25),
        ("ios.deckSetup.confidence.some", 0.5),
        ("ios.deckSetup.confidence.most", 0.75),
        ("ios.deckSetup.confidence.all", 1),
    ]

    /// Un emoji par cran, du doute à la fête : la réponse se lit avant la phrase.
    private static let faces = ["😶‍🌫️", "🤔", "🙂", "😎", "🤩"]

    /// Le cran le plus proche de la valeur enregistrée.
    ///
    /// Une boucle plutôt qu'un `min` à fermeture sur `enumerated()` : la version courte
    /// faisait résoudre au compilateur un tableau de tuples, deux `abs` sur des membres
    /// nommés, un chaînage optionnel et un `??`, pour une comparaison de cinq valeurs. Elle
    /// était plus dense, pas plus claire.
    private var index: Int {
        var best = 0
        var bestGap = Double.infinity
        for (rank, step) in Self.steps.enumerated() {
            let gap = abs(step.confidence - setup.confidence)
            if gap < bestGap {
                bestGap = gap
                best = rank
            }
        }
        return best
    }

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.deckSetup.confidence"),
            expandsContent: true
        ) {
            VStack(spacing: MicaboSpacing.xl) {
                Spacer(minLength: 0)

                Text(Self.faces[index])
                    .font(.system(size: 88))
                    .id(index)
                    .transition(.opacity)
                    .animation(OnboardingMotion.tap, value: index)
                    .accessibilityHidden(true)

                Text(i18n.t(Self.steps[index].key))
                    .font(MicaboFont.ui(26, weight: .bold))
                    .tracking(-0.4)
                    .foregroundStyle(OnboardingPalette.ink)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .id(index)
                    .transition(.opacity)
                    .animation(OnboardingMotion.tap, value: index)

                VStack(spacing: 10) {
                    Slider(
                        value: Binding(
                            get: { Double(index) },
                            set: { value in
                                let rank = Int(value.rounded())
                                guard Self.steps.indices.contains(rank) else { return }
                                guard Self.steps[rank].confidence != setup.confidence else { return }
                                Haptics.selection()
                                setup.confidence = Self.steps[rank].confidence
                            }
                        ),
                        in: 0...Double(Self.steps.count - 1),
                        step: 1
                    )
                    .tint(OnboardingPalette.ink)

                    // Les deux bouts nommés : un curseur à cinq crans sans bornes écrites
                    // laisse deviner dans quel sens il monte.
                    HStack {
                        Text(i18n.t(Self.steps.first?.key ?? ""))
                        Spacer(minLength: MicaboSpacing.sm)
                        Text(i18n.t(Self.steps.last?.key ?? ""))
                    }
                    .font(MicaboFont.ui(12, weight: .medium))
                    .foregroundStyle(MicaboColor.inkTertiary)
                }
                .padding(.horizontal, MicaboSpacing.xs)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(i18n.t("ios.deckSetup.confidence"))
                .accessibilityValue(i18n.t(Self.steps[index].key))

                Spacer(minLength: 0)
            }
        } footer: {
            OnboardingContinueButton(action: onNext)
        }
    }
}
