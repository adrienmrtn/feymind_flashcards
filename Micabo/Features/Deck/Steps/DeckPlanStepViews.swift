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
            OnboardingAnswerList(DeckPurpose.allCases) { purpose in
                OnboardingChoiceRow(
                    title: i18n.t(purpose.titleKey),
                    emoji: purpose.emoji,
                    subtitle: i18n.t(purpose.subtitleKey),
                    isSelected: setup.purpose == purpose,
                    fillsHeight: true
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
            subtitle: i18n.t("ios.deckSetup.grade.hint"),
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

    private var label: String {
        switch setup.confidence {
        case ..<0.2: i18n.t("ios.deckSetup.confidence.none")
        case ..<0.45: i18n.t("ios.deckSetup.confidence.little")
        case ..<0.7: i18n.t("ios.deckSetup.confidence.some")
        case ..<0.9: i18n.t("ios.deckSetup.confidence.most")
        default: i18n.t("ios.deckSetup.confidence.all")
        }
    }

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.deckSetup.confidence"),
            animatesTitle: true,
            expandsContent: true
        ) {
            VStack(spacing: MicaboSpacing.xl) {
                Spacer(minLength: 0)

                Text("\(Int((setup.confidence * 100).rounded()))")
                    .font(MicaboFont.ui(64, weight: .bold))
                    .foregroundStyle(MicaboColor.accent)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(OnboardingMotion.tap, value: setup.confidence)

                Text(label)
                    .font(MicaboFont.ui(16, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)

                Slider(value: $setup.confidence, in: 0...1)
                    .tint(MicaboColor.accent)
                    .padding(.horizontal, MicaboSpacing.xs)

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
/// Les crans sont empilés du plus bas en bas au plus haut en haut, et le remplissage suit le
/// pouce. Un curseur horizontal aurait fait le même travail ; celui-ci fait comprendre le
/// sens de la progression sans une ligne de texte, et c'est la seule raison pour laquelle il
/// existe.
struct VerticalGradePicker: View {
    let ticks: [GradeTick]
    @Binding var score: Int

    private var selectedIndex: Int {
        ticks.firstIndex { $0.score == score } ?? ticks.firstIndex { $0.score >= score } ?? 0
    }

    var body: some View {
        GeometryReader { proxy in
            let rowHeight = max(28, proxy.size.height / CGFloat(max(1, ticks.count)))

            VStack(spacing: 0) {
                ForEach(Array(ticks.enumerated().reversed()), id: \.element.id) { index, tick in
                    row(tick, isSelected: index == selectedIndex, isFilled: index <= selectedIndex)
                        .frame(height: rowHeight)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // Le haut de la pile est la note la plus haute : on inverse.
                        let fromTop = value.location.y / rowHeight
                        let index = ticks.count - 1 - Int(fromTop.rounded(.down))
                        guard ticks.indices.contains(index) else { return }
                        guard ticks[index].score != score else { return }
                        score = ticks[index].score
                        Haptics.selection()
                    }
            )
        }
    }

    private func row(_ tick: GradeTick, isSelected: Bool, isFilled: Bool) -> some View {
        HStack(spacing: 12) {
            Text(tick.label)
                .font(MicaboFont.ui(isSelected ? 22 : 15, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? MicaboColor.ink : MicaboColor.inkTertiary)
                .frame(width: 78, alignment: .trailing)
                .monospacedDigit()

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isFilled ? MicaboColor.accent : MicaboColor.stroke)
                .frame(height: isSelected ? 14 : 8)
                .opacity(isFilled ? 1 : 0.7)
        }
        .padding(.horizontal, MicaboSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(OnboardingMotion.tap, value: isSelected)
    }
}
