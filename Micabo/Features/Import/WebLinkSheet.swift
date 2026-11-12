import SwiftUI

/// **Coller le lien d'une page web** (`docs/supports.md`). La page est récupérée et nettoyée
/// sur l'appareil (`WebPageImportService`) ; un lien YouTube collé ici part par le support
/// YouTube, qui lit les sous-titres.
struct WebLinkSheet: View {
    let onDone: (String) -> Void

    @State private var link: String
    @FocusState private var focused: Bool

    init(link: String = "", onDone: @escaping (String) -> Void) {
        _link = State(initialValue: link)
        self.onDone = onDone
    }

    private var isValid: Bool { WebPageImportService.url(from: link) != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                SourceIcon(kind: .web, size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("ios.sup.web.title", locale: .resolved()))
                        .font(MicaboFont.subtitle)
                        .foregroundStyle(MicaboColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.t("ios.sup.web.sub", locale: .resolved()))
                        .font(MicaboFont.ui(14, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(MicaboColor.inkTertiary)
                TextField(L10n.t("ios.sup.web.placeholder", locale: .resolved()), text: $link)
                    .font(MicaboFont.ui(17, weight: .medium))
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .focused($focused)
                    .onSubmit { if isValid { onDone(link) } }
                    // Une adresse se lit de gauche à droite, même dans une app en arabe.
                    .environment(\.layoutDirection, .leftToRight)
                if !link.isEmpty {
                    Button {
                        link = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(MicaboColor.inkTertiary)
                    }
                    .buttonStyle(MicaboPressableButtonStyle())
                    .accessibilityLabel(Text(L10n.t("ios.sup.web.clear", locale: .resolved())))
                }
            }
            .padding(16)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous).strokeBorder(isValid ? MicaboColor.accent : MicaboColor.stroke, lineWidth: 1.5))

            Label {
                Text(L10n.t("ios.sup.web.privacy", locale: .resolved()))
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "lock.fill")
            }
            .font(MicaboFont.ui(13, weight: .semibold))
            .foregroundStyle(MicaboColor.inkSecondary)

            HStack(spacing: 10) {
                Button(L10n.t("lesson.import.paste", locale: .resolved())) {
                    if let pasted = UIPasteboard.general.string { link = pasted }
                }
                .buttonStyle(MicaboSecondaryButtonStyle())
                Button(L10n.t("lesson.import.add", locale: .resolved())) { onDone(link) }
                    .buttonStyle(LessonPrimaryButtonStyle(tint: MicaboColor.accent, enabled: isValid))
                    .disabled(!isValid)
            }
        }
        .padding(MicaboSpacing.screen)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(MicaboColor.canvas.ignoresSafeArea())
        .onAppear { focused = true }
    }
}
