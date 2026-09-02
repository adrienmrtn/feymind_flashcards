import SwiftUI

/// Démonstration, 1 sur 3 : le geste, et rien d'autre.
///
/// Une page de cours dense en haut, une zone de dépôt juste en dessous, une consigne de
/// quatre mots. Le doigt fait glisser la page dans la zone ; au bout de deux secondes sans
/// rien, elle se met à respirer, et un simple appui fait la même chose.
///
/// **Une flèche coule entre les deux**, et elle dit le geste mieux que la consigne : la page
/// qui respirait sur place indiquait qu'il fallait la toucher, pas où l'emmener. Trois
/// chevrons qui descendent en cascade tracent le trajet, et ils s'effacent dès que le doigt
/// s'en charge — une flèche qui montrerait encore le chemin pendant qu'on le suit serait du
/// bruit. La zone de dépôt, elle, est franchement plus grande : une cible de la hauteur d'un
/// bouton ne se lit pas comme un endroit où poser quelque chose.
///
/// Le document est **volontairement brut** : un mur de texte sans hiérarchie, tel qu'on
/// reçoit un polycopié. C'est le point de départ de la transformation que montre l'écran
/// suivant, et sans un vrai avant, il n'y a pas d'après.
struct DemoImportStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var drag: CGSize = .zero
    @State private var isDragging = false
    @State private var isDropped = false
    @State private var didSignalZone = false
    @State private var floats = false

    /// Descente à partir de laquelle le dépôt compte. La zone est juste dessous,
    /// donc large : le geste doit réussir du premier coup.
    private let dropThreshold: CGFloat = 70
    private let dropTravel: CGFloat = 150

    private var isOverZone: Bool { drag.height > dropThreshold }

    var body: some View {
        OnboardingScaffold(
            title: i18n?.t("ios.importTitle") ?? "Glisse ton cours ici.",
            titleSize: 30,
            contentSpacing: MicaboSpacing.lg,
            scrolls: false,
            // La carte se glisse au doigt : un défilement, même inerte, lui volerait le geste.
            locksScrolling: true
        ) {
            VStack(spacing: 12) {
                // La page passe **au-dessus** de la zone de dépôt, pas dessous : un
                // document qu'on fait glisser sous sa cible se lit comme un document
                // qu'on perd, et le geste ne ressemble plus à ce qu'il imite.
                thumbnail
                    .zIndex(1)

                trail
                dropZone
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear(perform: scheduleNudge)
    }

    // MARK: - La page

    private var thumbnail: some View {
        DemoRawPage()
            .frame(width: 172)
            .rotationEffect(.degrees(isDragging ? -2 : 0))
            .scaleEffect(isDropped ? 0.4 : (isDragging ? 1.02 : 1))
            .shadow(
                color: Color.black.opacity(isDragging ? 0.16 : 0.07),
                radius: isDragging ? 24 : 13,
                x: 0,
                y: isDragging ? 15 : 7
            )
            .offset(drag)
            .offset(y: floats && !isDragging && !isDropped ? 10 : 0)
            .opacity(isDropped ? 0 : 1)
            .gesture(dragGesture)
            .onTapGesture(perform: drop)
            .animation(OnboardingMotion.tap, value: isDragging)
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Cours d'exemple, \(OnboardingDemo.fileName)")
            .accessibilityHint("Appuie pour le déposer")
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard !isDropped else { return }

                if !isDragging {
                    isDragging = true
                    floats = false
                    Haptics.light()
                }

                // Le geste attendu est vertical : l'horizontale suit de loin, et la page ne
                // remonte quasiment pas.
                let height = max(-24, value.translation.height)
                drag = CGSize(width: value.translation.width * 0.45, height: height)

                let entered = height > dropThreshold
                if entered, !didSignalZone {
                    didSignalZone = true
                    Haptics.selection()
                } else if !entered {
                    didSignalZone = false
                }
            }
            .onEnded { _ in
                isDragging = false
                didSignalZone = false

                if isOverZone {
                    drop()
                } else {
                    withAnimation(OnboardingMotion.shift) {
                        drag = .zero
                    }
                }
            }
    }

    // MARK: - Le trajet

    /// Le chemin entre la page et sa cible, en trois chevrons qui descendent en cascade.
    ///
    /// Il s'efface dès que le doigt prend le relais : montrer le chemin à quelqu'un qui le
    /// suit déjà n'apprend rien, et deux animations concurrentes sur le même geste se
    /// gênent.
    private var trail: some View {
        DemoDropTrail()
            .opacity(isDragging || isDropped ? 0 : 1)
            .animation(OnboardingMotion.tap, value: isDragging)
            .animation(OnboardingMotion.tap, value: isDropped)
            .accessibilityHidden(true)
    }

    // MARK: - La zone de dépôt

    /// Une icône et un mot. Il y avait ici un symbole, un titre et un sous-titre, soit
    /// trois lignes pour dire « pose-le là ».
    ///
    /// Elle fait maintenant la moitié de la hauteur de la page qu'on y dépose : une bande de
    /// la hauteur d'un bouton se lit comme un bouton, pas comme un endroit où poser un
    /// document, et la cible du geste doit être la plus grande chose de l'écran après la
    /// page elle-même.
    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: MicaboRadius.group, style: .continuous)
                .fill(zoneFill)

            RoundedRectangle(cornerRadius: MicaboRadius.group, style: .continuous)
                .strokeBorder(
                    zoneStroke,
                    style: StrokeStyle(
                        lineWidth: (isOverZone || isDropped) ? 2.5 : 2,
                        dash: isDropped ? [] : [9, 7]
                    )
                )

            VStack(spacing: 10) {
                Image(systemName: isDropped ? "checkmark.circle.fill" : "arrow.down.circle")
                    .font(.system(size: 30, weight: .medium))

                Text(isDropped ? "Cours déposé" : "Dépose-le ici")
                    .font(MicaboFont.hanken(18, weight: .semibold))
            }
            .foregroundStyle(labelTint)
        }
        .frame(height: 136)
        .animation(OnboardingMotion.tap, value: isOverZone)
        .animation(OnboardingMotion.shift, value: isDropped)
    }

    private var zoneFill: Color {
        if isDropped { return MicaboColor.positiveSoft }
        return isOverZone ? MicaboColor.accentSoft : MicaboColor.surfaceMuted.opacity(0.45)
    }

    private var zoneStroke: Color {
        if isDropped { return MicaboColor.positive.opacity(0.6) }
        return isOverZone ? MicaboColor.accent : MicaboColor.strokeStrong
    }

    private var labelTint: Color {
        if isDropped { return MicaboColor.positive }
        return isOverZone ? MicaboColor.accent : MicaboColor.inkTertiary
    }

    // MARK: - Actions

    /// Le dépôt vaut validation : l'écran suivant enchaîne tout seul.
    private func drop() {
        guard !isDropped else { return }
        Haptics.success()

        withAnimation(OnboardingMotion.shift) {
            drag = CGSize(width: 0, height: dropTravel)
            isDropped = true
        }

        // Résolu maintenant : lire l'environnement depuis un bloc différé n'est pas sûr.
        let flow = model
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            flow.advance()
        }
    }

    /// Deux secondes sans geste : la page respire pour montrer où aller.
    private func scheduleNudge() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            guard !isDropped, !isDragging else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                floats = true
            }
            Haptics.tick()
        }
    }
}

/// Trois chevrons qui s'allument de haut en bas, en boucle : le trajet demandé, dessiné.
///
/// Les chevrons ne bougent pas, c'est leur opacité qui descend. Une flèche qui se déplacerait
/// pour de bon entre deux éléments demande de connaître leurs positions exactes, et la moindre
/// variation de hauteur d'écran la ferait passer à côté de sa cible.
private struct DemoDropTrail: View {
    private static let count = 3

    @State private var isRunning = false

    var body: some View {
        VStack(spacing: -3) {
            ForEach(0..<Self.count, id: \.self) { index in
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(MicaboColor.accent)
                    .opacity(isRunning ? 1 : 0.16)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.17),
                        value: isRunning
                    )
            }
        }
        .frame(height: 38)
        .onAppear { isRunning = true }
    }
}
