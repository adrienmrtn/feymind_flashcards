import SwiftUI

/// Écran 8a : le geste, et rien d'autre. Une vignette de PDF en haut, une zone de
/// dépôt en pointillés juste en dessous, et une consigne de quatre mots.
///
/// Le doigt fait glisser la vignette dans la zone. Au bout de deux secondes sans
/// rien, la vignette se met à respirer pour montrer où aller, et un simple appui
/// déclenche exactement la même chose.
struct DemoImportStepView: View {
    @Environment(OnboardingModel.self) private var model

    @State private var drag: CGSize = .zero
    @State private var isDragging = false
    @State private var isDropped = false
    @State private var didSignalZone = false
    @State private var floats = false
    @State private var showsTapHint = false

    /// Descente à partir de laquelle le dépôt compte. La zone est juste dessous,
    /// donc large : le geste doit réussir du premier coup.
    private let dropThreshold: CGFloat = 70
    /// Trajet de la vignette quand elle tombe dans la zone.
    private let dropTravel: CGFloat = 160

    private var isOverZone: Bool { drag.height > dropThreshold }

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Comment ça marche · 1 sur 3",
            title: "Glisse ce cours ici.",
            titleSize: 28,
            scrolls: false
        ) {
            VStack(spacing: 14) {
                thumbnail
                dropZone
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } footer: {
            hint
        }
        .onAppear(perform: scheduleNudge)
    }

    // MARK: - La vignette

    private var thumbnail: some View {
        DemoDocumentPage()
            .frame(width: 178)
            .rotationEffect(.degrees(isDragging ? -2.5 : 0))
            .scaleEffect(isDropped ? 0.38 : (isDragging ? 1.03 : 1))
            .shadow(
                color: Color.black.opacity(isDragging ? 0.18 : 0.08),
                radius: isDragging ? 26 : 14,
                x: 0,
                y: isDragging ? 16 : 8
            )
            .offset(drag)
            .offset(y: floats && !isDragging && !isDropped ? 12 : 0)
            .opacity(isDropped ? 0 : 1)
            .gesture(dragGesture)
            .onTapGesture(perform: drop)
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: isDragging)
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

                // Le geste attendu est vertical : l'horizontale suit de loin, et la
                // vignette ne remonte quasiment pas.
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
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.7)) {
                        drag = .zero
                    }
                }
            }
    }

    // MARK: - La zone de dépôt

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: MicaboRadius.group, style: .continuous)
                .fill(zoneFill)

            RoundedRectangle(cornerRadius: MicaboRadius.group, style: .continuous)
                .strokeBorder(
                    zoneStroke,
                    style: StrokeStyle(
                        lineWidth: (isOverZone || isDropped) ? 2 : 1.5,
                        dash: isDropped ? [] : [7, 6]
                    )
                )

            if isDropped {
                zoneLabel(
                    symbol: "checkmark.circle.fill",
                    title: OnboardingDemo.fileName,
                    subtitle: "1 page, prête à être lue",
                    tint: MicaboColor.positive
                )
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else {
                zoneLabel(
                    symbol: "arrow.down.circle",
                    title: "Dépose-le ici",
                    subtitle: "PDF, photo de tableau ou notes",
                    tint: isOverZone ? MicaboColor.accent : MicaboColor.inkTertiary
                )
            }
        }
        .frame(height: 106)
        .animation(.easeOut(duration: 0.18), value: isOverZone)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isDropped)
    }

    private var zoneFill: Color {
        if isDropped { return MicaboColor.positiveSoft }
        return isOverZone ? MicaboColor.accentSoft : MicaboColor.surfaceMuted.opacity(0.45)
    }

    private var zoneStroke: Color {
        if isDropped { return MicaboColor.positive.opacity(0.6) }
        return isOverZone ? MicaboColor.accent : MicaboColor.strokeStrong
    }

    private func zoneLabel(symbol: String, title: String, subtitle: String, tint: Color) -> some View {
        VStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(tint)

            Text(title)
                .font(MicaboFont.hanken(15, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .lineLimit(1)

            Text(subtitle)
                .font(MicaboFont.hanken(12, weight: .regular))
                .foregroundStyle(MicaboColor.inkTertiary)
        }
        .padding(.horizontal, MicaboSpacing.md)
    }

    // MARK: - Consigne

    @ViewBuilder
    private var hint: some View {
        HStack(spacing: 7) {
            Image(systemName: isDropped ? "checkmark.circle.fill" : "hand.draw")
                .font(.system(size: 12, weight: .semibold))

            Text(hintText)
                .font(MicaboFont.hanken(13, weight: .semibold))
        }
        .foregroundStyle(isDropped ? MicaboColor.positive : MicaboColor.ink)
        .padding(.vertical, 9)
        .padding(.horizontal, 14)
        .background(
            isDropped ? MicaboColor.positiveSoft : MicaboColor.surfaceMuted,
            in: Capsule()
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .animation(.easeOut(duration: 0.2), value: isDropped)
    }

    private var hintText: String {
        if isDropped { return "Cours déposé" }
        return showsTapHint ? "Glisse la vignette, ou appuie dessus" : "Attrape la vignette avec ton doigt"
    }

    // MARK: - Actions

    /// Le dépôt vaut validation : l'écran suivant enchaîne tout seul.
    private func drop() {
        guard !isDropped else { return }
        Haptics.success()

        withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
            drag = CGSize(width: 0, height: dropTravel)
            isDropped = true
        }

        // Résolu maintenant : lire l'environnement depuis un bloc différé n'est pas sûr.
        let flow = model
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            flow.advance()
        }
    }

    /// Deux secondes sans geste : la vignette respire et on mentionne l'appui.
    private func scheduleNudge() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            guard !isDropped, !isDragging else { return }
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                floats = true
            }
            withAnimation(.easeOut(duration: 0.3)) {
                showsTapHint = true
            }
            Haptics.tick()
        }
    }
}
