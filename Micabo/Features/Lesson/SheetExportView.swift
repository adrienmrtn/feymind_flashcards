import PDFKit
import SwiftUI

/// **La fiche de la leçon, en PDF** (`docs/supports.md`) : écrite sur l'appareil à
/// l'ouverture (`SheetExporter`), puis partagée — Fichiers, Messages, AirDrop, l'imprimante.
struct SheetExportView: View {
    let digest: LessonDigest
    var tone: LessonTone = .yellow

    @Environment(\.dismiss) private var dismiss
    @State private var file: URL?
    @State private var pages = 0
    @State private var failed = false

    var body: some View {
        VStack(spacing: 0) {
            RevisionModeHeader(mode: .export, lessonTitle: digest.title) { dismiss() }
            SheetExportCard(title: digest.title, themes: digest.themes.count, pages: pages, ready: file != nil, failed: failed, tone: tone) {
                if let file {
                    ShareLink(item: file) {
                        Label(L10n.t("ios.sup.export.share", locale: .resolved()), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(LessonPrimaryButtonStyle(tint: MicaboColor.accent))
                }
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, 8)
            Spacer(minLength: 0)
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
        .task { await write() }
    }

    private func write() async {
        guard file == nil else { return }
        // Un instant pour que la feuille finisse de monter avant le travail de mise en page.
        try? await Task.sleep(for: .milliseconds(150))
        do {
            let url = try SheetExporter.export(digest)
            pages = PDFDocument(url: url)?.pageCount ?? 0
            file = url
        } catch {
            failed = true
        }
    }
}

/// La carte de la fiche : sa page de garde en miniature, ce qu'elle contient, et le bouton.
struct SheetExportCard<Action: View>: View {
    let title: String
    let themes: Int
    let pages: Int
    let ready: Bool
    var failed = false
    let tone: LessonTone
    @ViewBuilder let action: Action

    var body: some View {
        VStack(spacing: 18) {
            // La page de garde, dessinée : un titre, quelques lignes.
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(MicaboFont.ui(15, weight: .black))
                    .foregroundStyle(Color(hex: 0x050507))
                    .lineLimit(2)
                ForEach(0..<6, id: \.self) { line in
                    Capsule()
                        .fill(line == 0 ? MicaboBrand.blue.opacity(0.7) : Color.black.opacity(0.12))
                        .frame(width: line == 0 ? 90 : CGFloat([150, 130, 160, 120, 140][(line - 1) % 5]), height: 6)
                }
            }
            .padding(18)
            .frame(width: 200, height: 250, alignment: .topLeading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: Color.black.opacity(0.12), radius: 18, y: 10)
            .rotationEffect(.degrees(-3))
            .padding(.vertical, 10)
            .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(L10n.t(failed ? "ios.sup.export.failed" : (ready ? "ios.sup.export.ready" : "ios.sup.export.writing"), locale: .resolved()))
                    .font(MicaboFont.ui(20, weight: .black))
                    .foregroundStyle(MicaboColor.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.t("ios.sup.export.detail", locale: .resolved(), vars: [
                    "themes": String(themes),
                    "pages": String(max(1, pages)),
                ]))
                .font(MicaboFont.ui(14, weight: .semibold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .multilineTextAlignment(.center)
                .opacity(ready ? 1 : 0)
            }
            if ready {
                action
            } else if !failed {
                ProgressView().tint(MicaboColor.accent)
                    .frame(height: 54)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(tone.pale, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
