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
/// Le curseur est **vertical**, et ce n'est pas une coquetterie : une note qu'on monte se
/// monte, et la jauge qui l'accompagne se remplit dans le même sens que la barre d'un
/// graphique de progression.
struct DeckGradeStepView: View {
    @Bindable var setup: DeckSetup
    var onNext: () -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var choices: [GradeTick] { setup.scale.choices }

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.deckSetup.grade"),
            animatesTitle: true,
            expandsContent: true
        ) {
            VerticalGradePicker(
                ticks: choices,
                score: $setup.targetScore
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    /// Ce que la date change, écrit pendant qu'on la choisit.
    private var paceNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MicaboColor.accent)
                Text(i18n.t("ios.deckSetup.pace", ["count": "\(readout.perDay)"]))
                    .font(MicaboFont.ui(15, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
            }

            Text(
                readout.isCrunch
                    ? i18n.t("ios.deckSetup.pace.crunch")
                    : i18n.t("ios.deckSetup.pace.quiet")
            )
            .font(MicaboFont.ui(12.5, weight: .regular))
            .foregroundStyle(MicaboColor.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
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

    private var index: Int {
        Self.steps
            .enumerated()
            .min { abs($0.element.confidence - setup.confidence) < abs($1.element.confidence - setup.confidence) }?
            .offset ?? 0
    }

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.deckSetup.confidence"),
            animatesTitle: true,
            expandsContent: true
        ) {
            VStack(spacing: MicaboSpacing.xl) {
                Spacer(minLength: 0)

                Text(i18n.t(Self.steps[index].key))
                    .font(MicaboFont.ui(26, weight: .bold))
                    .tracking(-0.4)
                    .foregroundStyle(MicaboColor.accent)
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
                    .tint(MicaboColor.accent)

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

// MARK: - Le curseur vertical

/// **Une note qu'on monte, en la montant.**
///
/// Les crans sont empilés du plus bas en bas au plus haut en haut, et celui qu'on choisit
/// grossit. Un curseur horizontal aurait fait le même travail ; celui-ci fait comprendre le
/// sens de la progression sans une ligne de texte.
///
/// **Les voisins s'éteignent par paliers.** Le cran choisi est en violet à trente-huit
/// points sur son lavis ; celui d'à côté est gris moyen, le suivant plus clair, le
/// troisième presque blanc. C'est ce dégradé qui donne la profondeur d'un rouleau de
/// sélection sans avoir à en simuler la perspective — et qui fait qu'on lit trois valeurs
/// au lieu de onze.
struct VerticalGradePicker: View {
    let ticks: [GradeTick]
    @Binding var score: Int

    /// Toutes les rangées font la même hauteur, y compris celle qu'on a choisie.
    ///
    /// C'est ce qui permet au calage du système de tomber juste : un rouleau dont la rangée
    /// centrale serait plus haute que les autres n'a pas de pas constant, et le point d'arrêt
    /// dérive d'un cran tous les trois tours. C'est donc le **texte** qui grossit au centre,
    /// pas la rangée.
    private static let rowHeight: CGFloat = 52

    /// La note au centre du rouleau, telle que le défilement la rapporte.
    ///
    /// Elle est distincte de `score` parce qu'elle appartient au `ScrollView` : c'est lui qui
    /// l'écrit pendant qu'on fait tourner la roue, et on la recopie dans la réponse. Les
    /// tenir dans la même variable ferait écrire la réponse par le défilement et repositionner
    /// le défilement par la réponse, en boucle.
    @State private var centred: Int?

    /// La note la plus haute en haut, comme sur la maquette.
    private var ordered: [GradeTick] { ticks.reversed() }

    /// L'encre d'un cran selon sa distance à celui qu'on a choisi.
    private func ink(distance: Int) -> Color {
        switch distance {
        case 0: MicaboColor.accent
        case 1: MicaboColor.gradeNear
        case 2: MicaboColor.gradeMid
        default: MicaboColor.gradeFar
        }
    }

    private func distance(of tick: GradeTick) -> Int {
        guard
            let here = ordered.firstIndex(where: { $0.score == tick.score }),
            let there = ordered.firstIndex(where: { $0.score == score })
        else { return 3 }
        return abs(here - there)
    }

    var body: some View {
        GeometryReader { proxy in
            // Le rembourrage qui met la première et la dernière note au centre : sans lui, le
            // barème ne peut pas se placer au milieu de l'écran et la roue s'arrête en butée.
            let inset = max(0, (proxy.size.height - Self.rowHeight) / 2)

            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(ordered) { tick in
                        row(tick)
                            .frame(height: Self.rowHeight)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .safeAreaPadding(.vertical, inset)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $centred, anchor: .center)
            .onAppear { centred = score }
            .onChange(of: centred) { _, value in
                guard let value, value != score else { return }
                Haptics.selection()
                score = value
            }
            .onChange(of: score) { _, value in
                // La réponse a changé ailleurs — on repositionne la roue sans la faire
                // réécrire la réponse : `centred` vaut déjà `value` quand c'est elle qui
                // vient de l'écrire, et la garde du dessus s'arrête là.
                if centred != value { centred = value }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func row(_ tick: GradeTick) -> some View {
        let gap = distance(of: tick)
        let isSelected = gap == 0

        return Text(tick.label)
            .font(MicaboFont.ui(isSelected ? 38 : 27, weight: isSelected ? .heavy : .bold))
            .tracking(isSelected ? -1.4 : -0.8)
            .foregroundStyle(ink(distance: gap))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
            .frame(height: Self.rowHeight)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous)
                        .fill(MicaboColor.accentWash)
                        .padding(.vertical, 2)
                }
            }
            .animation(OnboardingMotion.tap, value: isSelected)
    }
}
