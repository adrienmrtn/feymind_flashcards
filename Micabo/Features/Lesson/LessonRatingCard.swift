import SwiftUI

/// **« Cette leçon t'a aidé ? »**, en petit : 👍 / 👎, les raisons d'un 👎 et un mot
/// facultatif, puis un merci. Voir `LessonRating`.
///
/// La carte ne bloque rien : elle se pose sous le contenu, se ferme d'une croix, et l'écran
/// reste utilisable autour d'elle.
struct LessonRatingCard: View {
    let course: Course
    let moment: LessonRating.Moment
    /// Rappelé quand la carte n'a plus rien à dire : fermée, ou le merci lu.
    var onFinished: () -> Void = {}

    private enum Phase: Equatable {
        case ask
        case reasons
        case thanks
    }

    @State private var phase: Phase = .ask
    @State private var reasons: Set<LessonRating.Reason> = []
    @State private var comment = ""
    @FocusState private var commentFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch phase {
            case .ask: ask
            case .reasons: reasonsForm
            case .thanks: thanks
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1))
        .micaboElevation(.card)
        .animation(.spring(duration: 0.35), value: phase)
    }

    // MARK: Les trois temps

    private var ask: some View {
        HStack(spacing: 12) {
            Text(L10n.t("ios.conv.rate.question", locale: .resolved()))
                .font(MicaboFont.ui(16, weight: .heavy))
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            thumb("👍", label: "ios.conv.rate.up") { rate(.up) }
            thumb("👎", label: "ios.conv.rate.down") {
                Haptics.selection()
                phase = .reasons
            }
            closeButton
        }
    }

    private var reasonsForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.t("ios.conv.rate.why", locale: .resolved()))
                    .font(MicaboFont.ui(16, weight: .heavy))
                    .foregroundStyle(MicaboColor.ink)
                Spacer(minLength: 4)
                closeButton
            }
            MicaboFlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(LessonRating.Reason.allCases) { reason in
                    MicaboSelectChip(
                        title: L10n.t(reason.titleKey, locale: .resolved()),
                        isSelected: reasons.contains(reason)
                    ) {
                        if reasons.contains(reason) {
                            reasons.remove(reason)
                        } else {
                            reasons.insert(reason)
                        }
                    }
                }
            }
            Button(L10n.t("ios.conv.rate.send", locale: .resolved())) {
                commentFocused = false
                rate(.down)
            }
            .buttonStyle(LessonPrimaryButtonStyle())
        }
    }

    private var thanks: some View {
        HStack(spacing: 12) {
            MikaMascot(mood: .happy, size: 44, frame: .circle)
                .frame(width: 44, height: 44)
            Text(L10n.t("ios.conv.rate.thanks", locale: .resolved()))
                .font(MicaboFont.ui(15, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .task {
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            onFinished()
        }
    }

    // MARK: Les boutons

    private func thumb(_ emoji: String, label key: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(emoji)
                .font(.system(size: 24))
                .frame(width: 48, height: 48)
                .background(MicaboColor.surfaceSunken, in: Circle())
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .soft))
        .accessibilityLabel(Text(L10n.t(key, locale: .resolved())))
    }

    private var closeButton: some View {
        Button(action: onFinished) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(MicaboColor.inkTertiary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(MicaboPressableButtonStyle())
        .accessibilityLabel(Text(L10n.t("lesson.circle.close", locale: .resolved())))
    }

    private func rate(_ value: LessonRating.Value) {
        // Un double appui sur 👍 envoyait deux notes : la statistique comptait l'élève deux fois.
        guard phase != .thanks else { return }
        LessonRating.send(value, reasons: Array(reasons), comment: comment, course: course, moment: moment)
        Haptics.success()
        phase = .thanks
    }
}
