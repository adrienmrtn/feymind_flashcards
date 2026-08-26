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

/// Bouton d'action principal : bloc d'encre à coins 16 pt, qui s'enfonce à l'appui.
/// Sur un écran sombre, on inverse : surface claire, texte encre.
struct MicaboPrimaryButtonStyle: ButtonStyle {
    var tint: Color = MicaboColor.ink
    var foreground: Color = MicaboColor.onInk
    var fullWidth: Bool = true
    var feedback: Haptics.Press = .medium
    /// **Un quart plus grand**, pour le seul bouton d'un écran qui n'en a qu'un.
    ///
    /// Réservé au parcours d'accueil et aux paywalls : ce sont des écrans où l'on ne fait
    /// qu'une chose, et où le bouton est la seule cible. Ailleurs dans l'app, un bouton de
    /// cette taille écraserait les rangées et les actions secondaires autour de lui.
    ///
    /// La hauteur passe de 51 à 64 points, marges et corps compris — c'est un rapport, pas
    /// deux réglages indépendants : grossir le seul rembourrage donnerait un bouton haut au
    /// texte perdu au milieu.
    var isProminent: Bool = false

    private var font: Font {
        isProminent ? MicaboFont.hanken(19, weight: .semibold) : MicaboFont.cardTitle
    }

    private var verticalPadding: CGFloat {
        isProminent ? 20 : 16
    }

    private var radius: CGFloat {
        isProminent ? MicaboRadius.lg : MicaboRadius.button
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(foreground)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, fullWidth ? 0 : 24)
            .background(tint, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .micaboPressEffect(isPressed: configuration.isPressed, feedback: feedback)
    }
}

/// Bouton secondaire : surface blanche sans bordure, le fond ivoire suffit à la détacher.
struct MicaboSecondaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true
    var feedback: Haptics.Press = .light

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MicaboFont.cardTitle)
            .foregroundStyle(MicaboColor.ink)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 16)
            .padding(.horizontal, fullWidth ? 0 : 24)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
            .micaboPressEffect(isPressed: configuration.isPressed, feedback: feedback)
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
        case .dark: MicaboColor.ink
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
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [background.opacity(0), background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 28)

            content
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.bottom, MicaboSpacing.sm)
                .background(background)
        }
    }
}

