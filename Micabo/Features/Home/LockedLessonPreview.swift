import SwiftUI

/// **« Mika a lu ton cours. Ta leçon est prête à être créée ! »** : l'écran d'un élève dont la
/// leçon offerte a servi et qui vient d'envoyer des supports.
///
/// Tout ce qui s'y coche **s'est vraiment passé** : les supports ont été lus sur l'appareil
/// (PDFKit, OCR, transcription, sous-titres) au moment où ils ont été déposés dans la barre, et
/// les chiffres viennent de ce texte-là (`LessonReadSummary`). Rien ne prétend que le serveur
/// écrit déjà : la dernière ligne, « Écriture de ta leçon », porte un cadenas, et le serveur
/// refuserait de toute façon la leçon avant l'achat (`free_limit`, `import_pro`).
///
/// Une fois la lecture cochée, le paywall `lessonReady` s'ouvre par-dessus (`onRevealed`).
/// Refermé, l'aperçu reste, avec « Débloquer ma leçon » pour le rouvrir et la croix pour sortir.
struct LockedLessonPreview: View {
    let summary: LessonReadSummary
    let onUnlock: () -> Void
    let onClose: () -> Void
    /// Appelé une fois, quand la lecture est cochée : c'est là que le paywall s'ouvre.
    let onRevealed: () -> Void

    /// Les lignes cochées, une à une.
    @State private var ticked = 0
    @State private var revealed = false

    /// Ce qui a été lu, dans l'ordre où on le coche. Une vidéo, un audio ou un texte collé
    /// n'ont pas de pages : la ligne ne s'écrit pas.
    private var rows: [String] {
        var rows = [
            L10n.t("ios.conv.locked.supports", locale: .resolved(), vars: ["count": String(summary.supports)]),
        ]
        if summary.pages > 0 {
            rows.append(L10n.t("ios.conv.locked.pages", locale: .resolved(), vars: ["count": String(summary.pages)]))
        }
        rows.append(L10n.t("ios.conv.locked.words", locale: .resolved(), vars: ["count": String(summary.words)]))
        return rows
    }

    var body: some View {
        VStack(spacing: 0) {
            closeBar
            ScrollView {
                VStack(spacing: 22) {
                    MikaMascot(mood: revealed ? .happy : .think, size: revealed ? 120 : 150)
                        .animation(.spring(duration: 0.45), value: revealed)
                    Text(revealed
                        ? L10n.t("ios.conv.locked.title", locale: .resolved())
                        : L10n.t("ios.conv.locked.reading", locale: .resolved()))
                        .font(MicaboFont.title)
                        .foregroundStyle(MicaboColor.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12)
                        .contentTransition(.opacity)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, text in
                            stepRow(text, done: index < ticked, active: index == ticked && !revealed)
                        }
                        lockedRow
                    }
                    .padding(.horizontal, 20)

                    if revealed {
                        previewCard
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            if revealed {
                VStack(spacing: 10) {
                    Button(action: onUnlock) {
                        Label(L10n.t("ios.conv.locked.unlock", locale: .resolved()), systemImage: "lock.open.fill")
                    }
                    .buttonStyle(LessonPrimaryButtonStyle())
                    Text(L10n.t("ios.conv.locked.note", locale: .resolved()))
                        .font(MicaboFont.ui(13, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.bottom, 16)
                .transition(.opacity)
            }
        }
        .task { await play() }
    }

    // MARK: Les morceaux

    private var closeBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(MicaboPressableButtonStyle())
            .accessibilityLabel(Text(L10n.t("lesson.circle.close", locale: .resolved())))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private func stepRow(_ text: String, done: Bool, active: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(done ? MicaboColor.correct : active ? MicaboColor.accentSoft : MicaboColor.surfaceSunken)
                    .frame(width: 30, height: 30)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(MicaboColor.onInk)
                } else if active {
                    ProgressView()
                        .controlSize(.small)
                        .tint(MicaboColor.accent)
                }
            }
            Text(text)
                .font(MicaboFont.ui(17, weight: done || active ? .heavy : .bold))
                .foregroundStyle(done || active ? MicaboColor.ink : MicaboColor.inkTertiary)
            Spacer(minLength: 0)
        }
        .animation(.spring(duration: 0.35), value: done)
    }

    /// La seule étape qui n'a pas eu lieu, et qui le dit : l'écriture, avec Pro.
    private var lockedRow: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LessonTone.yellow.pale)
                    .frame(width: 30, height: 30)
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LessonTone.yellow.ink)
            }
            Text(L10n.t("ios.conv.locked.writing", locale: .resolved()))
                .font(MicaboFont.ui(17, weight: .bold))
                .foregroundStyle(revealed ? MicaboColor.ink : MicaboColor.inkTertiary)
            Spacer(minLength: 0)
        }
    }

    /// Ce que Mika a lu : le titre deviné, et les premières lignes, floutées sous un cadenas.
    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("ios.conv.locked.previewCaption", locale: .resolved()))
                .font(MicaboFont.small)
                .tracking(MicaboTracking.caps)
                .textCase(.uppercase)
                .foregroundStyle(MicaboColor.inkSecondary)
            if !summary.title.isEmpty {
                Text(summary.title)
                    .font(MicaboFont.label)
                    .foregroundStyle(MicaboColor.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            ZStack {
                VStack(alignment: .leading, spacing: 8) {
                    if summary.previewLines.isEmpty {
                        ForEach(0..<4, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(MicaboColor.surfaceSunken)
                                .frame(height: 12)
                                .padding(.trailing, CGFloat(index % 2) * 60)
                        }
                    } else {
                        ForEach(Array(summary.previewLines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(MicaboFont.ui(15, weight: .medium))
                                .foregroundStyle(MicaboColor.inkSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .blur(radius: 5)
                .accessibilityHidden(true)

                Image(systemName: "lock.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(LessonTone.yellow.ink)
                    .frame(width: 48, height: 48)
                    .background(LessonTone.yellow.pale, in: Circle())
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .micaboElevation(.card)
    }

    // MARK: Le déroulé

    /// Coche ce qui a été lu, au rythme d'une lecture, puis montre l'aperçu et ouvre le
    /// paywall. Une vue refermée en route annule la tâche : rien ne s'ouvre derrière elle.
    @MainActor
    private func play() async {
        guard !revealed else { return }
        for index in rows.indices {
            try? await Task.sleep(for: .milliseconds(650))
            if Task.isCancelled { return }
            withAnimation(.spring(duration: 0.35)) { ticked = index + 1 }
            Haptics.selection()
        }
        try? await Task.sleep(for: .milliseconds(450))
        if Task.isCancelled { return }
        withAnimation(.spring(duration: 0.5)) { revealed = true }
        Haptics.success()
        try? await Task.sleep(for: .milliseconds(1_100))
        if Task.isCancelled { return }
        onRevealed()
    }
}
