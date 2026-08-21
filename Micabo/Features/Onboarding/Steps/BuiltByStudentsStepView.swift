import SwiftUI

/// Écran 2 : d'où vient l'app, juste après l'accroche. Aucune question, aucun réglage —
/// on dit qui a fait Micabo et pour qui, puis on enchaîne.
///
/// Il arrive après l'écran d'encre : le crème revient, et la promesse de la méthode
/// prend le relais du paquet de cartes.
struct BuiltByStudentsStepView: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Par des étudiants",
            title: "Micabo a été conçu par des étudiants pour aider des millions d'élèves à apprendre de manière simple et ludique.",
            subtitle: "Découvre la méthode qu'utilisent les meilleurs étudiants.",
            titleSize: 24
        ) {
            MethodPromise()
        } footer: {
            OnboardingContinueButton {
                model.advance()
            }
        }
    }
}

/// Les trois traits de la méthode, découverts l'un après l'autre. Ils ne promettent rien
/// que le reste du parcours ne montre pas : les cartes, les sessions courtes, le rappel
/// posé au bon moment.
private struct MethodPromise: View {
    private struct Trait: Identifiable {
        let id = UUID()
        let symbol: String
        let label: String
    }

    private let traits: [Trait] = [
        Trait(symbol: "rectangle.on.rectangle.angled", label: "Tes cours deviennent des cartes"),
        Trait(symbol: "gamecontroller", label: "Des sessions courtes, presque un jeu"),
        Trait(symbol: "calendar.badge.clock", label: "Chaque rappel tombe au bon moment")
    ]

    @State private var shown = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("La méthode, en trois traits")
                .font(MicaboFont.hanken(14, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(Array(traits.enumerated()), id: \.element.id) { index, trait in
                HStack(spacing: 12) {
                    Image(systemName: trait.symbol)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(MicaboColor.accent)
                        .frame(width: 32, height: 32)
                        .background(MicaboColor.infoSoft, in: Circle())

                    Text(trait.label)
                        .font(MicaboFont.hanken(14, weight: .medium))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .opacity(index < shown ? 1 : 0)
                .offset(y: index < shown ? 0 : 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .micaboGroup()
        .onAppear(perform: revealTraits)
    }

    private func revealTraits() {
        for index in traits.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + Double(index) * 0.14) {
                withAnimation(.easeOut(duration: 0.3)) {
                    shown = index + 1
                }
            }
        }
    }
}
