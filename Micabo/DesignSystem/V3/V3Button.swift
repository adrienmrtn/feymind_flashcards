import SwiftUI

/// Les quatre boutons de l'app (V3.3).
///
/// - `primary` : **le** bouton principal d'un écran — une pilule blanche au texte marine, sur
///   une lèvre discrète de 4 pt qui s'enfonce à l'appui (en thème clair : une pilule encre au
///   texte blanc).
/// - `secondary` : l'autre action, à égalité de taille — une pilule surface à filet.
/// - `offer` : le bouton d'une offre — une pilule jaune au texte brun très sombre, lèvre ocre.
/// - `ghost` : l'action discrète sous le principal (« Plus tard ») : du texte secondaire, 44 pt.
///
/// **La forme et la couleur du bouton principal ne sont pas écrites ici** : elles se lisent
/// dans `V3Color.cta`, `ctaLip`, `ctaInk`, `V3Metric.radiusButton`, `buttonHeight`, `buttonLip`
/// et `V3Font.button`. Les changer là change tous les boutons de l'app, ceux d'avant le lot 10
/// compris.
///
/// `accent`, `white` et `ink` sont les noms des premières versions : ils valent `primary`.
enum V3ButtonKind {
    case primary
    case secondary
    case offer
    case ghost

    /// Les anciens noms du bouton principal.
    static let accent = V3ButtonKind.primary
    static let white = V3ButtonKind.primary
    static let ink = V3ButtonKind.primary
}

/// **Le bouton de l'app** : une pilule pleine largeur de 56 pt au moins, libellé en Sofia Sans
/// Condensed Black de 21 pt. Le principal est posé sur une lèvre qui s'enfonce à l'appui, avec
/// un retour haptique. Un seul bouton principal par écran, en bas, toujours au même endroit.
///
/// Le libellé passe à la ligne en allemand ou en très grand texte : le bouton grandit, il ne
/// coupe pas. `isLoading` remplace le libellé par un indicateur sans changer la taille du
/// bouton, et le rend inerte. Éteint (`isEnabled` faux), il passe en surface, texte gris.
struct V3Button: View {
    private let title: String
    private let systemImage: String?
    private let kind: V3ButtonKind
    private let isEnabled: Bool
    private let isLoading: Bool
    private let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        kind: V3ButtonKind = .primary,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.kind = kind
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .black))
                }
                Text(title)
            }
        }
        .buttonStyle(V3ButtonStyle(kind: kind, isEnabled: isEnabled, isLoading: isLoading))
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(Text(title))
    }
}

/// Le style du bouton de l'app, pour un `Button` dont l'écran compose lui-même le libellé.
struct V3ButtonStyle: ButtonStyle {
    var kind: V3ButtonKind = .primary
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        V3ButtonFace(
            label: configuration.label,
            kind: kind,
            enabled: isEnabled,
            isLoading: isLoading,
            fullWidth: fullWidth,
            isPressed: configuration.isPressed
        )
    }
}

/// **Le dessin d'un bouton plein** : le fond, la lèvre dessous, et l'enfoncement. `V3Button` et
/// les boutons d'avant le lot 10 (`MicaboPrimaryFill`) le partagent : il n'y a qu'un dessin de
/// bouton dans l'app, et sa forme vient de `V3Metric`.
struct V3ButtonPlate<Label: View>: View {
    let label: Label
    var fill: Color
    var lipColor: Color
    var foreground: Color
    var font: Font = V3Font.button
    var fullWidth: Bool = true
    var minHeight: CGFloat = V3Metric.buttonHeight
    /// La lèvre : celle du bouton principal, ou 0 pour un bouton à plat.
    var lip: CGFloat = V3Metric.buttonLip
    var border: Color?
    var isPressed: Bool
    var feedback: Haptics.Press = .medium

    var body: some View {
        // Le rayon ne dépasse jamais la moitié de la hauteur d'un bouton d'une ligne : un
        // libellé qui passe à la ligne garde ses coins au lieu de s'étirer en gélule.
        let shape = RoundedRectangle(
            cornerRadius: min(V3Metric.radiusButton, V3Metric.buttonHeight / 2),
            style: .continuous
        )
        let sunk: CGFloat = isPressed ? lip : 0
        return label
            .font(font)
            .tracking(V3Tracking.button)
            .foregroundStyle(foreground)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: minHeight)
            .background {
                ZStack {
                    if lip > 0 {
                        shape.fill(lipColor).offset(y: lip - sunk)
                    }
                    shape.fill(fill)
                    if let border {
                        shape.strokeBorder(border, lineWidth: V3Metric.border)
                    }
                }
            }
            .offset(y: sunk)
            .padding(.bottom, lip)
            .opacity(isPressed && lip == 0 ? 0.8 : 1)
            .contentShape(shape)
            .animation(MicaboPress.animation(isPressed: isPressed), value: isPressed)
            .micaboPressFeedback(isPressed: isPressed, feedback: feedback)
            .hoverEffect(.highlight)
    }
}

/// Le dessin du bouton, selon son genre. Une vue à part : un style de bouton ne lit pas
/// l'environnement.
private struct V3ButtonFace<Label: View>: View {
    let label: Label
    var kind: V3ButtonKind
    var enabled: Bool
    var isLoading: Bool
    var fullWidth: Bool
    var isPressed: Bool

    @Environment(\.isEnabled) private var environmentEnabled
    @Environment(\.v3Tint) private var tint

    /// Vrai tant que le bouton répond : ni éteint par l'écran, ni éteint par un parent. Un
    /// bouton qui charge garde sa couleur, il n'est pas « éteint ».
    private var isLive: Bool { enabled && (environmentEnabled || isLoading) }

    private var foreground: Color {
        guard isLive else { return V3Color.ink3 }
        switch kind {
        case .primary: return V3Color.ctaInk
        case .secondary: return V3Color.ink
        case .offer: return V3Color.onYellow
        case .ghost: return tint ?? V3Color.ink2
        }
    }

    private var content: some View {
        label
            .opacity(isLoading ? 0 : 1)
            .overlay {
                if isLoading {
                    ProgressView().tint(foreground)
                }
            }
    }

    var body: some View {
        switch kind {
        case .primary:
            V3ButtonPlate(
                label: content,
                fill: isLive ? V3Color.cta : V3Color.surface,
                lipColor: isLive ? V3Color.ctaLip : V3Color.line,
                foreground: foreground,
                fullWidth: fullWidth,
                isPressed: isPressed && isLive
            )
        case .offer:
            V3ButtonPlate(
                label: content,
                fill: isLive ? V3Color.yellow : V3Color.surface,
                lipColor: isLive ? V3Color.yellowDeep : V3Color.line,
                foreground: foreground,
                fullWidth: fullWidth,
                isPressed: isPressed && isLive
            )
        case .secondary:
            V3ButtonPlate(
                label: content,
                fill: V3Color.surface,
                lipColor: Color.clear,
                foreground: foreground,
                font: V3Font.buttonSecondary,
                fullWidth: fullWidth,
                lip: 0,
                border: V3Color.line,
                isPressed: isPressed && isLive,
                feedback: .light
            )
        case .ghost:
            content
                .font(V3Font.ghost)
                .foregroundStyle(foreground)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: V3Metric.ghostHeight)
                .contentShape(Rectangle())
                .opacity(isLive ? (isPressed ? 0.55 : 1) : 0.4)
                .animation(MicaboPress.animation(isPressed: isPressed), value: isPressed)
                .micaboPressFeedback(isPressed: isPressed, feedback: .light)
        }
    }
}

private struct V3TintKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

extension EnvironmentValues {
    /// La couleur des éléments discrets posés sur un fond plein : le bouton `ghost`, la flèche
    /// et la jauge de `V3TopBar`.
    var v3Tint: Color? {
        get { self[V3TintKey.self] }
        set { self[V3TintKey.self] = newValue }
    }
}

extension View {
    /// Sur un fond plein, donne leur couleur au bouton `ghost`, à la flèche de retour et à la
    /// jauge : `.v3Tint(.white)` sur une image ou un aplat sombre.
    func v3Tint(_ color: Color?) -> some View {
        environment(\.v3Tint, color)
    }
}
