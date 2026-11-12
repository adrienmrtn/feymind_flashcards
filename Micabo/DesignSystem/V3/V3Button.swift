import SwiftUI

/// Les quatre boutons V3.
///
/// - `accent` : **le** bouton principal d'un écran — aplat bleu, lèvre de 5 pt.
/// - `white` : le même, blanc, pour un fond plein (une story).
/// - `ink` : le même, marine, pour un fond clair et coloré (la story jaune).
/// - `ghost` : l'action discrète sous le principal (« Plus tard », « J'ai déjà un compte ») :
///   du texte, 48 pt, sans fond ni lèvre.
enum V3ButtonKind {
    case accent
    case white
    case ink
    case ghost
}

/// **Le bouton V3** : pleine largeur, 58 pt, 18 pt Black, une lèvre de 5 pt qui s'enfonce à
/// l'appui avec un retour haptique. Un seul bouton principal par écran, en bas, toujours au
/// même endroit.
///
/// Le libellé passe à la ligne en allemand ou en très grand texte : le bouton grandit, il ne
/// coupe pas. `isLoading` remplace le libellé par un indicateur sans changer la taille du
/// bouton, et le rend inerte. Éteint (`isEnabled` faux), il passe au gris.
///
/// Sur un fond plein, le `ghost` prend la couleur donnée par `.v3Tint(.white)`.
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
        kind: V3ButtonKind = .accent,
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
                        .font(.system(size: 17, weight: .black))
                }
                Text(title)
            }
        }
        .buttonStyle(V3ButtonStyle(kind: kind, isEnabled: isEnabled, isLoading: isLoading))
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(Text(title))
    }
}

/// Le style du bouton V3, pour un `Button` dont l'écran compose lui-même le libellé.
struct V3ButtonStyle: ButtonStyle {
    var kind: V3ButtonKind = .accent
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

/// Le dessin du bouton V3. Une vue à part : un style de bouton ne lit pas l'environnement.
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

    private var fill: Color {
        switch kind {
        case .accent: isLive ? V3Color.accent : V3Color.line
        case .white: Color.white
        case .ink: V3Color.storyNavy
        case .ghost: Color.clear
        }
    }

    private var lipColor: Color {
        switch kind {
        case .accent: isLive ? V3Color.accentDeep : V3Color.lip
        case .white: V3Color.storyNavy.opacity(0.18)
        case .ink: Color.black
        case .ghost: Color.clear
        }
    }

    private var foreground: Color {
        switch kind {
        case .accent: isLive ? V3Color.onAccent : V3Color.ink3
        case .white: V3Color.storyNavy
        case .ink: Color.white
        case .ghost: tint ?? V3Color.ink2
        }
    }

    var body: some View {
        if kind == .ghost {
            ghost
        } else {
            solid
        }
    }

    private var content: some View {
        label
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .opacity(isLoading ? 0 : 1)
            .overlay {
                if isLoading {
                    ProgressView().tint(foreground)
                }
            }
    }

    private var solid: some View {
        let shape = RoundedRectangle(cornerRadius: V3Metric.radiusButton, style: .continuous)
        let lip = V3Metric.buttonLip
        let sunk: CGFloat = isPressed && isLive ? lip : 0
        return content
            .font(V3Font.button)
            .foregroundStyle(foreground)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: V3Metric.buttonHeight)
            .background {
                ZStack {
                    shape.fill(lipColor).offset(y: lip - sunk)
                    shape.fill(fill)
                    if kind == .ink {
                        shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    }
                }
            }
            .offset(y: sunk)
            .padding(.bottom, lip)
            .opacity(isLive || kind == .accent ? 1 : 0.5)
            .contentShape(shape)
            .animation(MicaboPress.animation(isPressed: isPressed), value: isPressed)
            .animation(MicaboMotion.quick, value: isLive)
            .micaboPressFeedback(isPressed: isPressed, feedback: .medium)
            .hoverEffect(.highlight)
    }

    private var ghost: some View {
        content
            .font(V3Font.ghost)
            .foregroundStyle(foreground)
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: V3Metric.ghostHeight)
            .contentShape(Rectangle())
            .opacity(isLive ? (isPressed ? 0.55 : 1) : 0.4)
            .animation(MicaboPress.animation(isPressed: isPressed), value: isPressed)
            .micaboPressFeedback(isPressed: isPressed, feedback: .light)
    }
}

private struct V3TintKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

extension EnvironmentValues {
    /// La couleur des éléments V3 discrets posés sur un fond plein : le bouton `ghost`, le
    /// chevron et la jauge de `V3TopBar`.
    var v3Tint: Color? {
        get { self[V3TintKey.self] }
        set { self[V3TintKey.self] = newValue }
    }
}

extension View {
    /// Sur un fond plein (une story), donne leur couleur au bouton `ghost`, au chevron de
    /// retour et à la jauge : `.v3Tint(.white)` sur le bleu, `.v3Tint(V3Color.storyNavy)` sur
    /// le jaune.
    func v3Tint(_ color: Color?) -> some View {
        environment(\.v3Tint, color)
    }
}
