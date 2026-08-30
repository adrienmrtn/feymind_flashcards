import SwiftUI

/// Un bug ou une idée, envoyés à `team@micabo.app`.
///
/// Le bouton ouvre le courriel déjà adressé. On n'héberge pas de boîte.
struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var kind: MicaboMail.Kind = .bug
    @State private var message = ""

    private var ready: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
            MicaboScreenHeader(title: "Faire un retour", back: MicaboHeaderBack.close { dismiss() }) {
                Button("Envoyer", action: send)
                    .font(MicaboFont.hanken(15, weight: .semibold))
                    .foregroundStyle(ready ? MicaboColor.accent : MicaboColor.inkTertiary)
                    .disabled(!ready)
                    .buttonStyle(MicaboPressableButtonStyle())
            }

            VStack(alignment: .leading, spacing: 8) {
                MicaboSectionCaption(text: "C'est à propos de")
                MicaboRowGroup(rows: MicaboMail.Kind.allCases.map { option in
                    MicaboRow(
                        tile: MicaboTile(
                            glyph: .emoji(option == .bug ? "🪲" : "💡"),
                            background: option == .bug ? MicaboColor.cautionSoft : MicaboColor.infoSoft
                        ),
                        title: option.title,
                        accessory: kind == option ? .symbol("checkmark") : .none,
                        action: { kind = option }
                    )
                })
            }

            VStack(alignment: .leading, spacing: 8) {
                MicaboSectionCaption(text: "Ton message")
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $message)
                        .font(MicaboFont.body)
                        .scrollContentBackground(.hidden)
                        .padding(MicaboSpacing.sm)
                        .frame(minHeight: 180, alignment: .topLeading)

                    if message.isEmpty {
                        Text(kind.placeholder)
                            .font(MicaboFont.body)
                            .foregroundStyle(MicaboColor.inkTertiary)
                            .padding(MicaboSpacing.sm + 4)
                            .allowsHitTesting(false)
                    }
                }
                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
            }

            Text("Ça arrive chez \(MicaboMail.team).")
                .font(MicaboFont.micro)
                .foregroundStyle(MicaboColor.inkTertiary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, MicaboSpacing.xs)
        .padding(.bottom, MicaboSpacing.xxl)
        .micaboScreenBackground()
    }

    private func send() {
        guard ready, let url = MicaboMail.composeURL(kind: kind, message: message) else { return }
        openURL(url)
        dismiss()
    }
}
