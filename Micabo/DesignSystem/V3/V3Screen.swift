import SwiftUI

/// **Le gabarit d'un écran V3** : la barre du haut (chevron + jauge), un contenu qui défile,
/// et un pied fixe — le bouton principal, toujours au même endroit.
///
/// - Le contenu a ses marges de 20 pt et s'aligne à gauche ; il occupe au moins toute la
///   hauteur libre, donc un `Spacer` y pousse bien vers le bas. S'il dépasse (très grand
///   texte, petit écran), il défile sous le pied, qui ne bouge pas.
/// - Le pied reste **au-dessus du clavier** : il est posé dans la zone sûre du bas, que le
///   clavier repousse. Ses éléments s'empilent à 8 pt (bouton principal, puis `ghost`).
/// - Sans `progress` ni `onBack`, pas de barre du haut. Sans pied (`footer` vide ou omis), le
///   contenu va jusqu'en bas : un choix unique avance tout seul.
///
/// Le fond est celui de la page (`V3Color.bg`).
struct V3Screen<Content: View, Footer: View>: View {
    private let progress: Double?
    private let onBack: (() -> Void)?
    private let content: Content
    private let footer: Footer

    init(
        progress: Double? = nil,
        onBack: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.progress = progress
        self.onBack = onBack
        self.content = content()
        self.footer = footer()
    }

    private var hasTopBar: Bool { progress != nil || onBack != nil }
    private var hasFooter: Bool { Footer.self != EmptyView.self }

    var body: some View {
        VStack(spacing: 0) {
            if hasTopBar {
                V3TopBar(progress: progress, onBack: onBack)
            }
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        content
                    }
                    .padding(.horizontal, V3Metric.screenMargin)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .topLeading)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if hasFooter {
                VStack(spacing: 8) {
                    footer
                }
                .padding(.horizontal, V3Metric.screenMargin)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
                .background(V3Color.bg.ignoresSafeArea(edges: .bottom))
            }
        }
        .background(V3Color.bg.ignoresSafeArea())
    }
}

extension V3Screen where Footer == EmptyView {
    /// Un écran sans pied : un choix unique, qui avance à l'appui.
    init(
        progress: Double? = nil,
        onBack: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(progress: progress, onBack: onBack, content: content, footer: { EmptyView() })
    }
}
