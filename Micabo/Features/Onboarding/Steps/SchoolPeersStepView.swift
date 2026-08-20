import SwiftUI

/// Preuve sociale après le choix d'établissement : le titre se lit d'abord,
/// puis l'effectif apparaît, puis le bouton.
///
/// L'écran ne s'affiche que si l'établissement a été **choisi dans la liste**
/// (`OnboardingModel.hasRecognizedInstitution`) : autrement le parcours le saute,
/// puisqu'on ne saurait pas de qui on parle. Le chiffre annoncé reste petit et
/// stable pour un même établissement.
struct SchoolPeersStepView: View {
    @Environment(OnboardingModel.self) private var model

    private let titleWords = ["Tu", "n'es", "pas", "seul."]

    @State private var titleRead = 0
    @State private var showCount = false
    @State private var showCTA = false
    @State private var peers = 0

    private var schoolLabel: String {
        let name = model.institutionName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let name, !name.isEmpty {
            return name
        }
        return "ton établissement"
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                Text("COMMUNAUTÉ")
                    .font(MicaboFont.eyebrow)
                    .tracking(1.6)
                    .foregroundStyle(MicaboColor.accent)

                titleLine
                    .fixedSize(horizontal: false, vertical: true)

                if showCount {
                    countBlock
                        .transition(.opacity.combined(with: .offset(y: 12)))
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, MicaboSpacing.lg)

            MicaboBottomBar {
                if showCTA {
                    OnboardingContinueButton {
                        model.advance()
                    }
                    .transition(.opacity.combined(with: .offset(y: 8)))
                }
            }
        }
        .onAppear(perform: start)
    }

    private var titleLine: Text {
        var result = Text("")
        for index in titleWords.indices {
            let isRead = index < titleRead
            let piece = index == titleWords.count - 1 ? titleWords[index] : titleWords[index] + " "
            result = result + Text(piece)
                .font(MicaboFont.hanken(32, weight: isRead ? .bold : .regular))
                .foregroundStyle(isRead ? MicaboColor.ink : MicaboColor.inkTertiary)
        }
        return result.tracking(-0.6)
    }

    private var countBlock: some View {
        VStack(spacing: 8) {
            Text("\(peers)")
                .font(MicaboFont.hanken(72, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(-2.5)
                .monospacedDigit()

            (
                Text(peers > 1 ? "personnes de " : "personne de ")
                + Text(schoolLabel).font(MicaboFont.hanken(16, weight: .semibold))
                + Text(peers > 1 ? " utilisent déjà Micabo pour étudier." : " utilise déjà Micabo pour étudier.")
            )
            .font(MicaboFont.hanken(16, weight: .medium))
            .foregroundStyle(MicaboColor.inkSecondary)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, MicaboSpacing.sm)
    }

    /// Garde-fou : si l'écran est atteint sans établissement reconnu, il ne s'affiche
    /// pas plus longtemps qu'une image et laisse la place à la suite.
    private func start() {
        // Résolu maintenant : lire l'environnement depuis un bloc différé n'est pas sûr.
        let flow = model

        guard let institutionId = flow.institutionId?.nilIfBlank else {
            DispatchQueue.main.async { flow.advance() }
            return
        }

        if peers == 0 {
            peers = SchoolPeers.count(forInstitutionId: institutionId)
        }

        playSequence()
    }

    private func playSequence() {
        for index in titleWords.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28 + Double(index) * 0.16) {
                titleRead = index + 1
            }
        }

        let afterTitle = 0.28 + Double(titleWords.count) * 0.16 + 0.35
        DispatchQueue.main.asyncAfter(deadline: .now() + afterTitle) {
            withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.5)) {
                showCount = true
            }
            Haptics.soft()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + afterTitle + 0.7) {
            withAnimation(.easeOut(duration: 0.35)) {
                showCTA = true
            }
        }
    }
}

/// Effectif annoncé pour un établissement reconnu : de 1 à 10 personnes, jamais plus.
/// Le chiffre est dérivé de l'identifiant, donc identique d'un lancement à l'autre —
/// un nombre qui change à chaque passage se remarque tout de suite.
enum SchoolPeers {
    static let maximum = 10

    static func count(forInstitutionId id: String) -> Int {
        let checksum = id.unicodeScalars.reduce(0) { partial, scalar in
            (partial + Int(scalar.value)) % 9_973
        }
        return checksum % maximum + 1
    }
}
