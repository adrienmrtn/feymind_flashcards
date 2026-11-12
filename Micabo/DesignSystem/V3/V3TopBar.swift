import SwiftUI

/// **La barre du haut d'un parcours V3** : un chevron de retour de 40 pt, la jauge de 10 pt,
/// et ce que l'écran pose à droite (`trailing`). 44 pt de haut, marges de 20 pt.
///
/// - `onBack` absent : pas de chevron, la jauge part du bord.
/// - `progress` absent : pas de jauge, `trailing` reste calé à droite.
///
/// Le chevron se retourne en arabe. Sur un fond plein, `.v3Tint(.white)` blanchit le chevron
/// et la jauge.
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
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 19, weight: .black))
                        .foregroundStyle(tint ?? V3Color.ink)
                        .frame(width: V3Metric.backSize, height: V3Metric.backSize)
                        .contentShape(Rectangle())
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
