import SwiftData
import SwiftUI

/// **Le plan d'un deck, avec ce qu'on en sait.**
///
/// C'est l'écran qui rend visibles les deux lots précédents : sans lui, la table `Chapter`
/// existe, les cartes neuves entrent dans l'ordre du plan, et rien ne le montre.
///
/// Chaque rangée dit trois choses, et pas une de plus : de quoi parle le chapitre, où en
/// est l'étudiant, et combien de cartes il porte. Un chapitre s'ouvre pour être lu ; un
/// appui long sur son bouton le fait réviser seul, sans faire repasser les huit autres.
///
/// **Le pourcentage est calculé ici, pas stocké.** Il dépend de l'état de répétition
/// espacée, qui bouge à chaque carte notée : une colonne `mastery` en base serait fausse
/// dès la première session et il faudrait l'invalider à chaque écriture. Les journaux sont
/// lus **une fois** pour tout le deck (`recentLogsByCard`), pas une fois par chapitre.
struct DeckChaptersView: View {
    @Bindable var course: Course

    @Environment(\.modelContext) private var modelContext
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// Les pourcentages, calculés à l'apparition et après chaque session.
    ///
    /// En `@State` et non recalculés dans le corps : `masteryPercent` parcourt toutes les
    /// cartes de chaque chapitre, et le faire à chaque évaluation de vue rendrait le
    /// défilement d'un deck de deux cents cartes saccadé.
    @State private var progress: [UUID: ChapterReadout] = [:]
    @State private var reviewing: Chapter?

    struct ChapterReadout: Equatable {
        var percent: Int
        var state: ChapterState
        var cardCount: Int
        var dueCount: Int
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.sm) {
            header

            if course.orderedChapters.isEmpty {
                emptyPlan
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(course.orderedChapters.enumerated()), id: \.element.id) { index, chapter in
                        chapterRow(chapter, number: index + 1)
                        if index < course.orderedChapters.count - 1 {
                            MicaboHairline(inset: 72)
                        }
                    }
                }
                .micaboGroup()

                looseCardsNote
            }
        }
        .onAppear(perform: reload)
        .fullScreenCover(item: $reviewing) { chapter in
            StudyView(source: .chapter(chapter), mode: .scheduled)
                .onDisappear(perform: reload)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            MicaboSectionCaption(text: i18n.t("ios.deck.chapters"))
            Spacer(minLength: MicaboSpacing.xs)
            if !course.orderedChapters.isEmpty {
                Text(i18n.t("ios.deck.learnedPercent", ["percent": "\(deckPercent)"]))
                    .font(MicaboFont.ui(13, weight: .semibold))
                    .foregroundStyle(MicaboColor.accent)
            }
        }
    }

    /// Le pourcentage du deck entier.
    ///
    /// La moyenne est pondérée par le nombre de cartes, et non la moyenne des pourcentages
    /// de chapitre : un chapitre de trois cartes su par cœur ne doit pas peser autant qu'un
    /// chapitre de quarante à peine entamé.
    private var deckPercent: Int {
        let readouts = course.orderedChapters.compactMap { progress[$0.id] }
        let cards = readouts.reduce(0) { $0 + $1.cardCount }
        guard cards > 0 else { return 0 }
        let weighted = readouts.reduce(0) { $0 + $1.percent * $1.cardCount }
        return Int((Double(weighted) / Double(cards)).rounded())
    }

    private func chapterRow(_ chapter: Chapter, number: Int) -> some View {
        let readout = progress[chapter.id]
        return NavigationLink(value: chapter) {
            MicaboRow(
                tile: tile(for: readout?.state ?? .untouched, number: number),
                title: chapter.title.nilIfBlank ?? i18n.t("ios.deck.untitledChapter", ["number": "\(number)"]),
                subtitle: subtitle(for: readout),
                accessory: .chevron
            )
        }
        .buttonStyle(MicaboRowButtonStyle())
        .contextMenu {
            Button {
                reviewing = chapter
            } label: {
                Label(
                    i18n.t("ios.deck.reviewChapter"),
                    systemImage: "arrow.triangle.2.circlepath"
                )
            }
            .disabled((readout?.cardCount ?? 0) == 0)
        }
    }

    /// La tuile dit l'état avant que le sous-titre ne le chiffre : un chapitre su porte une
    /// coche verte, les autres leur numéro. C'est ce qui permet de lire un plan de neuf
    /// chapitres d'un coup d'œil, sans lire un seul pourcentage.
    private func tile(for state: ChapterState, number: Int) -> MicaboTile {
        switch state {
        case .learned:
            MicaboTile(
                glyph: .symbol("checkmark"),
                background: MicaboColor.positiveSoft,
                tint: MicaboColor.positive
            )
        case .inProgress:
            MicaboTile(
                glyph: .symbol("\(number).circle.fill"),
                background: MicaboColor.accentSoft,
                tint: MicaboColor.accent
            )
        case .untouched:
            MicaboTile(
                glyph: .symbol("\(number).circle"),
                background: MicaboColor.surfaceMuted,
                tint: MicaboColor.inkTertiary
            )
        }
    }

    private func subtitle(for readout: ChapterReadout?) -> String {
        guard let readout, readout.cardCount > 0 else {
            return i18n.t("ios.deck.noCards")
        }
        let cards = i18n.t("ios.deck.cardCount", ["count": "\(readout.cardCount)"])
        switch readout.state {
        case .untouched:
            return i18n.t("ios.deck.notStarted") + " · " + cards
        case .learned:
            return i18n.t("ios.deck.learned") + " · " + cards
        case .inProgress:
            return i18n.t("ios.deck.percentAndCards", [
                "percent": "\(readout.percent)",
                "cards": cards
            ])
        }
    }

    /// **Les cartes que le plan ne revendique pas.**
    ///
    /// Elles existent pour une raison historique — les cartes d'avant la refonte n'ont pas
    /// de chapitre, et on n'en a pas inventé — et la seule chose honnête à en faire est de
    /// les montrer. Les taire donnerait un deck dont les chapitres annoncent quatre-vingts
    /// cartes quand la liste en contient cent vingt.
    @ViewBuilder
    private var looseCardsNote: some View {
        let loose = course.looseCards.count
        if loose > 0 {
            Text(i18n.t("ios.deck.looseCards", ["count": "\(loose)"]))
                .font(MicaboFont.ui(12, weight: .regular))
                .foregroundStyle(MicaboColor.inkTertiary)
                .padding(.horizontal, MicaboSpacing.xs)
        }
    }

    private var emptyPlan: some View {
        Text(i18n.t("ios.deck.noPlan"))
            .font(MicaboFont.ui(13, weight: .regular))
            .foregroundStyle(MicaboColor.inkSecondary)
            .padding(.horizontal, MicaboSpacing.xs)
    }

    private func reload() {
        let chapters = course.orderedChapters
        guard !chapters.isEmpty else {
            progress = [:]
            return
        }
        // Une seule lecture des journaux pour tout le deck. Une par chapitre ferait neuf
        // requêtes sur `review_logs` à chaque ouverture.
        let logs = ExamReadiness.recentLogsByCard(in: modelContext)
        let now = Date()
        var next: [UUID: ChapterReadout] = [:]
        for chapter in chapters {
            let cards = chapter.orderedCards
            let percent = ChapterProgress.percent(of: chapter, logs: logs, now: now)
            next[chapter.id] = ChapterReadout(
                percent: percent,
                state: ChapterProgress.state(of: chapter, percent: percent),
                cardCount: cards.count,
                dueCount: cards.reduce(0) { $0 + ($1.isDue(at: now) ? 1 : 0) }
            )
        }
        progress = next
    }
}
