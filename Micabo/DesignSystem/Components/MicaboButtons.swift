import SwiftUI

/// Réaction à l'appui, commune à tous les boutons de l'app.
///
/// Un doigt posé doit se voir tout de suite : l'enfoncement part sur une courbe de
/// 80 ms, bien en dessous des 100 ms au-delà desquelles on croit que rien n'a été
/// enregistré. Le relâchement est un peu plus lent, pour qu'on le remarque.
enum MicaboPress {
    static let scale: CGFloat = 0.975
    static let opacity: Double = 0.92

    static func animation(isPressed: Bool) -> Animation {
        .easeOut(duration: isPressed ? 0.08 : 0.16)
    }
}

extension View {
    /// Enfoncement standard, à appliquer dans un `ButtonStyle`.
    ///
    /// C'est aussi **le seul endroit d'où part la vibration d'un appui**. La poser ici
    /// plutôt que dans chaque action est ce qui fait que tout ce qui se touche dans l'app
    /// répond au doigt : il n'y a pas de bouton sans style, donc il n'y a pas de bouton
    /// muet. Un écran qui aurait besoin d'un autre retour passe `feedback: .none` et le
    /// joue lui-même, au lieu d'en ajouter un second par-dessus celui-ci.
    func micaboPressEffect(
        isPressed: Bool,
        dimming: Bool = true,
        feedback: Haptics.Press = .light
    ) -> some View {
        scaleEffect(isPressed ? MicaboPress.scale : 1)
            .opacity(isPressed && dimming ? MicaboPress.opacity : 1)
            .animation(MicaboPress.animation(isPressed: isPressed), value: isPressed)
            .micaboPressFeedback(isPressed: isPressed, feedback: feedback)
    }

    /// Vibration à l'enfoncement, pour les styles qui dessinent leur appui autrement que
    /// par un enfoncement — une rangée qui se voile, un onglet qui s'allume.
    func micaboPressFeedback(isPressed: Bool, feedback: Haptics.Press = .light) -> some View {
        onChange(of: isPressed) { wasPressed, isPressed in
            guard isPressed, !wasPressed else { return }
            feedback.play()
        }
    }
}

extension Binding {
    /// La même liaison, qui vibre quand on l'écrit.
    ///
    /// Pour les contrôles du système — interrupteur, curseur, sélecteur — qui n'ont pas de
    /// style de bouton où accrocher un retour. Le faire ici plutôt qu'à chaque appel évite
    /// la moitié d'un réglage qui répond et l'autre moitié qui ne dit rien.
    func buzzing(_ feedback: Haptics.Press = .selection) -> Binding<Value> {
        Binding(
            get: { wrappedValue },
            set: { newValue in
                feedback.play()
                wrappedValue = newValue
            }
        )
    }
}

/// Les mesures communes aux boutons pleins et secondaires : celles de `V3Metric`.
enum MicaboButtonMetrics {
    /// La hauteur d'un bouton, partout la même. Un minimum, pas une hauteur : avec les grandes
    /// tailles de texte, le libellé pousse le bouton.
    static let height: CGFloat = V3Metric.buttonHeight
    /// La hauteur du bouton seul d'un parcours ou d'un paywall : la même.
    static let prominentHeight: CGFloat = V3Metric.buttonHeight
    /// Le rayon d'un bouton, principal comme secondaire.
    static let radius: CGFloat = V3Metric.radiusButton
}

/// **Le seul rendu d'un bouton principal**, que tous les styles « pleins » de l'app dessinent.
///
/// Il y en avait quatre — `MicaboPrimaryButtonStyle`, `MicaboBrandButtonStyle`,
/// `LessonPrimaryButtonStyle` et `MicaboActionButtonStyle` — et deux écrans voisins ne
/// montraient pas le même bouton pour la même chose. Ils gardent leurs noms et leurs
/// paramètres, et passent tous par ici.
///
/// **Depuis le lot 10, c'est le dessin de `V3Button`** (`V3ButtonPlate`) : la forme, la hauteur,
/// la lèvre et la police viennent de `V3Metric` et de `V3Font.button`, et la couleur du bouton
/// principal de `V3Color.cta`. Un écran d'avant le lot 10 montre donc le même bouton qu'un
/// écran neuf. Une autre teinte (`tint` : le vert d'une bonne réponse, le rouge d'une mauvaise)
/// garde sa couleur, sur une lèvre assombrie. `fontSize` n'est plus lu : la taille est celle de
/// la direction artistique.
struct MicaboPrimaryFill<Label: View>: View {
    let label: Label
    var tint: Color = MicaboColor.accent
    var foreground: Color = MicaboColor.onAccent
    var fullWidth: Bool = true
    var minHeight: CGFloat = MicaboButtonMetrics.height
    var fontSize: CGFloat = 18
    var enabled: Bool = true
    var isPressed: Bool
    var feedback: Haptics.Press = .medium

    @Environment(\.isEnabled) private var environmentEnabled

    private var isLive: Bool { enabled && environmentEnabled }

    /// Vrai pour le bouton principal de l'app : celui qu'aucun écran n'a teinté.
    private var isCta: Bool { tint == MicaboColor.accent }

    private var fill: Color {
        guard isLive else { return V3Color.surface }
        return isCta ? V3Color.cta : tint
    }

    private var lipColor: Color {
        guard isLive else { return V3Color.line }
        return isCta ? V3Color.ctaLip : tint.darkened(by: 0.22)
    }

    /// Le texte : celui du bouton principal, ou — sur une autre teinte — une encre qui s'inverse
    /// avec le thème. Les teintes du marine sont claires (un vert, un rouge lumineux) et portent
    /// du texte sombre ; celles du clair sont soutenues et portent du blanc.
    private var ink: Color {
        guard isLive else { return V3Color.ink3 }
        guard foreground == MicaboColor.onAccent else { return foreground }
        return isCta ? V3Color.ctaInk : MicaboColor.onInk
    }

    var body: some View {
        V3ButtonPlate(
            label: label,
            fill: fill,
            lipColor: lipColor,
            foreground: ink,
            fullWidth: fullWidth,
            minHeight: minHeight,
            isPressed: isPressed && isLive,
            feedback: feedback
        )
        .animation(MicaboMotion.quick, value: isLive)
    }
}

/// Bouton d'action principal : `MicaboPrimaryFill`, un par écran.
struct MicaboPrimaryButtonStyle: ButtonStyle {
    var tint: Color = MicaboColor.accent
    var foreground: Color = MicaboColor.onAccent
    var fullWidth: Bool = true
    var feedback: Haptics.Press = .medium
    /// Gardé pour les écrans qui le passent : le bouton a la même hauteur partout.
    var isProminent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        MicaboPrimaryFill(
            label: configuration.label,
            tint: tint,
            foreground: foreground,
            fullWidth: fullWidth,
            minHeight: isProminent ? MicaboButtonMetrics.prominentHeight : MicaboButtonMetrics.height,
            isPressed: configuration.isPressed,
            feedback: feedback
        )
    }
}

/// Bouton secondaire : **le bouton secondaire de `V3Button`** — une surface à filet, à plat, de
/// la même forme que le principal pour que deux boutons empilés se lisent comme une paire.
struct MicaboSecondaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true
    var feedback: Haptics.Press = .light

    func makeBody(configuration: Configuration) -> some View {
        V3ButtonPlate(
            label: configuration.label,
            fill: V3Color.surface,
            lipColor: Color.clear,
            foreground: V3Color.ink,
            font: V3Font.buttonSecondary,
            fullWidth: fullWidth,
            lip: 0,
            border: V3Color.line,
            isPressed: configuration.isPressed,
            feedback: feedback
        )
    }
}

/// Style des boutons qui dessinent eux-mêmes leur habillage : la seule chose que
/// le style ajoute est l'enfoncement, et la vibration qui va avec. À préférer à
/// `.plain`, qui ne réagit ni à l'œil ni au doigt.
struct MicaboPressableButtonStyle: ButtonStyle {
    var dimming: Bool = true
    var feedback: Haptics.Press = .light

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .micaboPressEffect(isPressed: configuration.isPressed, dimming: dimming, feedback: feedback)
            .hoverEffect(.highlight)
    }
}

/// Petit bouton discret pour les actions annexes.
struct MicaboQuietButtonStyle: ButtonStyle {
    var feedback: Haptics.Press = .light

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(V3Font.label)
            .foregroundStyle(MicaboColor.inkSecondary)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .opacity(configuration.isPressed ? 0.55 : 1)
            .animation(MicaboPress.animation(isPressed: configuration.isPressed), value: configuration.isPressed)
            .micaboPressFeedback(isPressed: configuration.isPressed, feedback: feedback)
    }
}

enum MicaboCircleStyle: Equatable {
    case light
    case dark
    /// Posé sur une couverture, quelle que soit sa clarté.
    case glass
    /// Posé sur un panneau pastel : verre blanc, icône dans la teinte du cours.
    case tinted(Color)

    var foreground: Color {
        switch self {
        case .light: MicaboColor.ink
        case .dark, .glass: MicaboColor.onInk
        case .tinted(let color): color
        }
    }

    /// La pastille claire est une surface : c'est sa clarté sur le fond de la page qui la
    /// dessine, il n'y a plus d'ombre pour le faire.
    var background: Color {
        switch self {
        case .light: MicaboColor.surface
        case .dark: MicaboColor.accent
        case .glass: Color.black.opacity(0.32)
        case .tinted: Color.white.opacity(0.75)
        }
    }
}

/// Pastille circulaire : une surface à filet, sans ombre. Utilisée seule dans un `Menu`, ou
/// enveloppée par `MicaboCircleButton`.
struct MicaboCircleIcon: View {
    let systemImage: String
    var style: MicaboCircleStyle = .light
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.4, weight: .bold))
            .foregroundStyle(style.foreground)
            .frame(width: size, height: size)
            .background(style.background, in: Circle())
            .overlay {
                if style == .light {
                    Circle().strokeBorder(MicaboColor.stroke, lineWidth: MicaboSurface.border)
                }
            }
    }
}

/// Bouton circulaire, posé sur le fond ou sur une couverture.
struct MicaboCircleButton: View {
    let systemImage: String
    var style: MicaboCircleStyle = .light
    var size: CGFloat = 40
    var accessibilityTitle: String?
    var feedback: Haptics.Press = .light
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            MicaboCircleIcon(systemImage: systemImage, style: style, size: size)
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: feedback))
        .accessibilityLabel(accessibilityTitle ?? systemImage)
    }
}

/// Zone d'action ancrée en bas d'un écran, avec fondu vers le fond. Le bouton est
/// toujours collé au bas de la zone sûre, quel que soit le fond de l'écran.
struct MicaboBottomBar<Content: View>: View {
    var background: Color = MicaboColor.canvas
    /// La hauteur du fondu qui amène la barre.
    ///
    /// Vingt-huit points suffisent sous une liste, où le fondu tombe entre deux rangées. Sous
    /// un texte, il tombe **au milieu d'une ligne** : sur une fiche, la dernière ligne
    /// lisible était systématiquement à moitié effacée, ce qui se lit comme un défaut
    /// d'affichage et pas comme une limite. Les écrans de lecture l'allongent.
    var fade: CGFloat = 28
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, MicaboSpacing.sm)
            .padding(.bottom, MicaboSpacing.sm)
            .frame(maxWidth: .infinity)
            .background(background)
            // **Le fondu recouvre le contenu**, au-dessus de la barre : posé dans la pile, il
            // tombait sous la page, qui se coupait net à son bord. Il laisse passer le doigt.
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [background.opacity(0), background],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: fade)
                .offset(y: -fade)
                .allowsHitTesting(false)
            }
    }
}

