import SwiftUI

/// **La barre du haut d'un parcours** : une flèche de retour de 36 pt, la jauge de 8 pt, et
/// ce que l'écran pose à droite (`trailing`). 44 pt de haut, marges de 20 pt.
///
/// - `onBack` absent : pas de flèche, la jauge part du bord.
/// - `progress` absent : pas de jauge, `trailing` reste calé à droite.
///
/// La flèche se retourne en arabe. Sur un fond plein, `.v3Tint(.white)` blanchit la flèche et
/// la jauge.
struct V3TopBar<Trailing: View>: View {
    private let progress: Double?
    private let onBack: (() -> Void)?
    private let trailing: Trailing

    @Environment(\.v3Tint) private var tint

    init(progress: Double?, onBack: (() -> Void)?, @ViewBuilder trailing: () -> Trailing) {
        self.progress = progress
        self.onBack = onBack
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 14) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "arrow.backward")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(tint ?? V3Color.ink)
                        .frame(width: V3Metric.backSize, height: V3Metric.backSize)
                        // La cible reste celle du doigt — 44 pt — sans déplacer la jauge : la
                        // case garde ses 36 pt dans la mise en page.
                        .padding(4)
                        .contentShape(Rectangle())
                        .padding(-4)
                }
                .buttonStyle(MicaboPressableButtonStyle())
                .accessibilityLabel(Text(L10n.t("app.common.back", locale: .resolved())))
            }
            if let progress {
                V3ProgressBar(value: progress)
            } else {
                Spacer(minLength: 0)
            }
            trailing
        }
        .padding(.horizontal, V3Metric.screenMargin)
        .frame(minHeight: V3Metric.topBarHeight)
    }
}

extension V3TopBar where Trailing == EmptyView {
    /// La barre sans rien à droite.
    init(progress: Double?, onBack: (() -> Void)?) {
        self.init(progress: progress, onBack: onBack) { EmptyView() }
    }
}
