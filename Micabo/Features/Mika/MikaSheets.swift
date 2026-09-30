import SwiftData
import SwiftUI

// MARK: - Choisir un cours

/// **La liste des cours, pour en choisir un** : à joindre à la conversation, ou pour y
/// ranger une carte que Mika a proposée. Lue à l'ouverture, pas observée : la feuille vit
/// deux secondes, et un `@Query` sur la table des cours coûterait à chaque écriture.
struct MikaCoursePicker: View {
    let title: String
    var onPick: (Course) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var courses: [Course] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MicaboSpacing.md) {
                header

                if courses.isEmpty {
                    Text(i18n.t("ios.mika.chat.noCourses"))
                        .font(MicaboFont.body)
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(courses.enumerated()), id: \.element.id) { index, course in
                            MicaboRow(
                                tile: MicaboTile(glyph: .emoji(course.emoji), background: MicaboColor.pastel(for: course.id)),
                                title: course.title,
                                subtitle: subtitle(course),
                                accessory: .chevron
                            ) {
                                onPick(course)
                            }

                            if index < courses.count - 1 {
                                MicaboHairline(inset: 64)
                            }
                        }
                    }
                    .micaboGroup()
                }
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, MicaboSpacing.md)
            .padding(.bottom, MicaboSpacing.xxl)
        }
        .scrollIndicators(.hidden)
        .micaboScreenBackground()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(MicaboRadius.sheet)
        .task { load() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: MicaboSpacing.sm) {
            Text(title)
                .font(MicaboFont.ui(24, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(MicaboColor.ink)

            Spacer(minLength: 0)

            MicaboCircleButton(systemImage: "xmark", size: 36, accessibilityTitle: L10n.t("app.a11y.close", locale: .resolved())) {
                dismiss()
            }
        }
    }

    private func subtitle(_ course: Course) -> String? {
        guard let subject = course.subject?.nilIfBlank else { return nil }
        return SubjectDisplay.subject(subject, locale: i18n.locale)
    }

    private func load() {
        let descriptor = FetchDescriptor<Course>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        courses = (try? modelContext.fetch(descriptor)) ?? []
    }
}

// MARK: - Joindre un document

/// **Les cases de dépôt de la création d'un deck, telles quelles**, et le texte lu sur
/// l'appareil devient la pièce jointe. Rien ne part au modèle avant la question, et jamais
/// une image : un PDF de cent pages coûte ce que coûtent ses seize mille premiers
/// caractères.
struct MikaDocumentSheet: View {
    var onAttach: (MikaAttachment) -> Void

    @State private var setup = DeckSetup()
    @Environment(\.dismiss) private var dismiss
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        DeckMaterialsStepView(setup: setup, usesArrow: true) {
            let text = setup.combinedText(limit: MikaLimits.attachmentCharacters)
            guard !text.isEmpty else { return }
            let title = setup.materials.first(where: \.isReady)?.document?.fileName
                ?? i18n.t("ios.mika.chat.documentTitle")
            onAttach(MikaAttachment(kind: .document, title: title, text: text))
        }
        .overlay(alignment: .topTrailing) {
            MicaboCircleButton(systemImage: "xmark", size: 36, accessibilityTitle: L10n.t("app.a11y.close", locale: .resolved())) {
                dismiss()
            }
            .padding(.top, MicaboSpacing.md)
            .padding(.trailing, MicaboSpacing.screen)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(MicaboRadius.sheet)
    }
}
