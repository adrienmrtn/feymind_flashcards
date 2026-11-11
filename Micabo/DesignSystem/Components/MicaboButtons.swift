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

/// Les mesures communes aux boutons pleins et secondaires.
enum MicaboButtonMetrics {
    /// La hauteur d'un bouton : celle du pouce, partout la même. Un minimum, pas une
    /// hauteur : avec les grandes tailles de texte, le libellé pousse le bouton.
    static let height: CGFloat = 56
    /// La hauteur du bouton seul d'un parcours ou d'un paywall.
    static let prominentHeight: CGFloat = 62
    /// Le rayon d'un bouton, principal comme secondaire.
    static let radius: CGFloat = MicaboRadius.button
}

/// **Le seul rendu d'un bouton principal**, que tous les styles « pleins » de l'app dessinent.
///
/// Il y en avait quatre — `MicaboPrimaryButtonStyle` (bleu, 14 de rayon, 51 points fixes),
/// `MicaboBrandButtonStyle` (dégradé et reflet, ressort à rebond), `LessonPrimaryButtonStyle`
/// (encre noire) et `MicaboActionButtonStyle` (sans ombre) — et deux écrans voisins ne
/// montraient pas le même bouton pour la même chose. Ils gardent leurs noms et leurs
/// paramètres, et passent tous par ici : un aplat de l'accent, dix-huit de rayon, cinquante-six
/// points au moins, deux lignes avant de réduire le texte, une ombre de sa propre couleur.
///
/// **La nuit**, l'accent s'éclaircit et le texte passe au graphite (`onInk`) : le même couple
/// que les pastilles sélectionnées, lisible sur le noir sans éblouir.
struct MicaboPrimaryFill<Label: View>: View {
    let label: Label
    var tint: Color = MicaboColor.accent
    var foreground: Color = MicaboColor.onInk
    var fullWidth: Bool = true
    var minHeight: CGFloat = MicaboButtonMetrics.height
    var fontSize: CGFloat = 17
    var enabled: Bool = true
    var isPressed: Bool
    var feedback: Haptics.Press = .medium

    @Environment(\.isEnabled) private var environmentEnabled

    private var isLive: Bool { enabled && environmentEnabled }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: MicaboButtonMetrics.radius, style: .continuous)
        label
            .font(MicaboFont.ui(fontSize, weight: .heavy))
            .foregroundStyle(isLive ? foreground : MicaboColor.onInk)
            .multilineTextAlignment(.center)
            // **Le libellé passe à la ligne, il ne se coupe pas** : un bouton qui finit par
            // « … » en allemand ou en très grand texte ne dit plus ce qu'il fait.
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, fullWidth ? 20 : 24)
            .padding(.vertical, 10)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: minHeight)
            .background(isLive ? tint : MicaboColor.inkTertiary.opacity(0.55), in: shape)
            .shadow(color: tint.opacity(isLive ? 0.22 : 0), radius: 10, x: 0, y: 6)
            .contentShape(shape)
            .micaboPressEffect(isPressed: isPressed, feedback: feedback)
            .animation(MicaboMotion.quick, value: isLive)
            .hoverEffect(.highlight)
    }
}

/// Bouton d'action principal : l'aplat de l'accent (`MicaboPrimaryFill`), un par écran.
struct MicaboPrimaryButtonStyle: ButtonStyle {
    var tint: Color = MicaboColor.accent
    var foreground: Color = MicaboColor.onInk
    var fullWidth: Bool = true
    var feedback: Haptics.Press = .medium
    /// **Un peu plus grand**, pour le seul bouton d'un écran qui n'en a qu'un : le parcours
    /// d'accueil et les paywalls. Ailleurs, il écraserait les rangées autour de lui.
    var isProminent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        MicaboPrimaryFill(
            label: configuration.label,
            tint: tint,
            foreground: foreground,
            fullWidth: fullWidth,
            minHeight: isProminent ? MicaboButtonMetrics.prominentHeight : MicaboButtonMetrics.height,
            fontSize: isProminent ? 18 : 17,
            isPressed: configuration.isPressed,
            feedback: feedback
        )
    }
}

/// Bouton secondaire : surface blanche et filet, **la même forme que le principal** (rayon,
/// hauteur, retour à la ligne) pour que deux boutons empilés se lisent comme une paire.
struct MicaboSecondaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true
    var feedback: Haptics.Press = .light

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: MicaboButtonMetrics.radius, style: .continuous)
        configuration.label
            .font(MicaboFont.ui(17, weight: .bold))
            .foregroundStyle(MicaboColor.ink)
            .multilineTextAlignment(.center)
            // **Le libellé passe à la ligne, il ne se coupe pas** : un bouton qui finit par
            // « … » en allemand ou en très grand texte ne dit plus ce qu'il fait.
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, fullWidth ? 20 : 24)
            .padding(.vertical, 10)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: MicaboButtonMetrics.height)
            .background(MicaboColor.surface, in: shape)
            .overlay {
                shape.strokeBorder(MicaboColor.strokeStrong, lineWidth: 1.5)
            }
            .contentShape(shape)
            .micaboPressEffect(isPressed: configuration.isPressed, feedback: feedback)
            .hoverEffect(.highlight)
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
            .font(MicaboFont.captionEmphasis)
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

    var background: Color {
        switch self {
        case .light: MicaboColor.surface
        case .dark: MicaboColor.accent
        case .glass: Color.black.opacity(0.32)
        case .tinted: Color.white.opacity(0.75)
        }
    }

    var shadowOpacity: Double {
        switch self {
        case .light: 0.05
        case .dark: 0.12
        case .glass, .tinted: 0
        }
    }
}

/// Pastille circulaire blanche, sans bordure. Utilisée seule dans un `Menu`,
/// ou enveloppée par `MicaboCircleButton`.
struct MicaboCircleIcon: View {
    let systemImage: String
    var style: MicaboCircleStyle = .light
    var size: CGFloat = 38

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.38, weight: .medium))
            .foregroundStyle(style.foreground)
            .frame(width: size, height: size)
            .background(style.background, in: Circle())
            .shadow(color: Color.black.opacity(style.shadowOpacity), radius: 10, x: 0, y: 4)
    }
}

/// Bouton circulaire, posé sur le fond ou sur une couverture.
struct MicaboCircleButton: View {
    let systemImage: String
    var style: MicaboCircleStyle = .light
    var size: CGFloat = 38
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

