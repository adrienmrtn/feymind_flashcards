import SwiftUI

/// Écran 12 : choix des matières. Sélection multiple, catalogue volontairement large.
struct SubjectsStepView: View {
    @Environment(OnboardingModel.self) private var model

    private struct Family: Identifiable {
        let id = UUID()
        let name: String
        let subjects: [String]
    }

    private let families: [Family] = [
        Family(name: "Sciences", subjects: [
            "Mathématiques", "Physique", "Chimie", "SVT", "Statistiques", "Astronomie", "Géologie"
        ]),
        Family(name: "Santé", subjects: [
            "Médecine", "Pharmacie", "Soins infirmiers", "Kinésithérapie", "Anatomie", "Nutrition"
        ]),
        Family(name: "Sciences humaines", subjects: [
            "Histoire", "Géographie", "Philosophie", "Sociologie", "Psychologie", "Sciences politiques"
        ]),
        Family(name: "Langues", subjects: [
            "Anglais", "Espagnol", "Allemand", "Italien", "Portugais", "Japonais",
            "Chinois", "Arabe", "Russe", "Latin & grec", "Français"
        ]),
        Family(name: "Droit & économie", subjects: [
            "Droit", "Économie", "Comptabilité", "Finance", "Management", "Marketing"
        ]),
        Family(name: "Technique", subjects: [
            "Informatique", "Algorithmique", "Réseaux", "Électronique", "Mécanique",
            "Génie civil", "Architecture"
        ]),
        Family(name: "Et aussi", subjects: [
            "Arts", "Musique", "Cinéma", "Sport & STAPS", "Code de la route", "Culture générale"
        ])
    ]

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Question 3 sur 3",
            title: "Tu révises quoi ?",
            titleSize: 28,
            animatesTitle: true
        ) {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(families) { family in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(family.name.uppercased())
                            .font(MicaboFont.hanken(10, weight: .semibold))
                            .tracking(1.4)
                            .foregroundStyle(MicaboColor.inkTertiary)

                        MicaboFlowLayout(spacing: 8, lineSpacing: 8) {
                            ForEach(family.subjects, id: \.self) { subject in
                                SubjectChip(
                                    title: subject,
                                    // L'emoji d'une matière vient d'où viennent ceux des
                                    // cours : une table unique, et pas une deuxième liste à
                                    // maintenir en parallèle de celle-ci.
                                    emoji: CourseEmoji.derive(subject: subject, title: subject),
                                    isSelected: model.subjects.contains(subject)
                                ) {
                                    toggle(subject)
                                }
                            }
                        }
                    }
                }
            }
        } footer: {
            OnboardingContinueButton(
                title: model.subjects.isEmpty ? "Choisis au moins une matière" : "Continuer",
                isEnabled: !model.subjects.isEmpty
            ) {
                model.advance()
            }
        }
    }

    private func toggle(_ subject: String) {
        Haptics.selection()
        withAnimation(OnboardingMotion.tap) {
            if model.subjects.contains(subject) {
                model.subjects.remove(subject)
            } else {
                model.subjects.insert(subject)
            }
        }
    }
}

private struct SubjectChip: View {
    let title: String
    var emoji: String?
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                } else if let emoji {
                    Text(emoji)
                        .font(.system(size: 13))
                }
                Text(title)
                    .font(MicaboFont.hanken(13, weight: .medium))
            }
            .foregroundStyle(isSelected ? MicaboColor.onInk : Color(hex: 0x4A463F))
            .padding(.vertical, 9)
            .padding(.horizontal, 13)
            .background(isSelected ? MicaboColor.ink : MicaboColor.surface, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : MicaboColor.strokeStrong, lineWidth: 1)
            }
            .scaleEffect(isSelected ? 1.03 : 1)
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false))
    }
}
