import SwiftUI

/// Un bug ou une idée, écrits en base. Plus de boîte mail à ouvrir.
struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthController.self) private var auth
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var kind: MicaboMail.Kind = .bug
    @State private var message = ""
    @State private var sending = false
    @State private var notice: String?

    private var ready: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !sending
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
            MicaboScreenHeader(title: i18n?.t("app.feedback.title") ?? "Faire un retour", back: MicaboHeaderBack.close { dismiss() }) {
                Button(i18n?.t("app.feedback.send") ?? "Envoyer", action: send)
                    .font(MicaboFont.hanken(15, weight: .semibold))
                    .foregroundStyle(ready ? MicaboColor.accent : MicaboColor.inkTertiary)
                    .disabled(!ready)
                    .buttonStyle(MicaboPressableButtonStyle())
            }

            VStack(alignment: .leading, spacing: 8) {
                MicaboSectionCaption(text: i18n?.t("ios.aboutTopic") ?? "C'est à propos de")
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
                MicaboSectionCaption(text: i18n?.t("app.feedback.messageLabel") ?? "Ton message")
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

            Text(notice ?? (i18n?.t("app.feedback.lead") ?? "Un bug, une idée…"))
                .font(MicaboFont.micro)
                .foregroundStyle(notice == nil ? MicaboColor.inkTertiary : MicaboColor.inkSecondary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, MicaboSpacing.xs)
        .padding(.bottom, MicaboSpacing.xxl)
        .micaboScreenBackground()
    }

    private func send() {
        let cleaned = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, let userId = auth.user?.id else { return }
        guard cleaned.count <= 4000 else {
            notice = i18n?.t("ios.feedbackTooLong") ?? L10n.t("ios.feedbackTooLong", locale: .resolved())
            return
        }
        sending = true
        notice = nil
        Task {
            do {
                let database = SupabaseDatabase(accessToken: { await auth.validAccessToken() })
                try await database.insert(
                    [FeedbackDraft(user_id: userId, kind: kind.rawValue, message: cleaned, source: "ios")],
                    into: "feedback"
                )
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    sending = false
                    notice = Self.notice(for: error)
                }
            }
        }
    }

    private static func notice(for error: Error) -> String {
        if let failure = error as? SupabaseDatabase.Failure,
           case .server(_, let message, let code) = failure,
           code == "42501" || message.localizedCaseInsensitiveContains("row-level security") {
            return L10n.t("ios.feedbackTooMany", locale: .resolved())
        }
        return L10n.t("ios.feedbackFailed", locale: .resolved())
    }
}

private struct FeedbackDraft: Encodable {
    let user_id: UUID
    let kind: String
    let message: String
    let source: String
}
