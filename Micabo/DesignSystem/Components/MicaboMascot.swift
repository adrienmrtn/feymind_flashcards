import SwiftUI

/// **La mascotte de Micabo : une carte qui a un visage.**
///
/// Les parcours d'accueil qui marchent — Gizmo, Ahead, Hablo — ont tous la même chose que
/// le nôtre n'avait pas : quelqu'un qui parle. Un personnage sur chaque écran, qui pose la
/// question dans une bulle, qui cligne des yeux pendant qu'on hésite, qui se réjouit quand
/// on a fini. Sans lui, un parcours de vingt écrans est un formulaire ; avec lui, c'est une
/// conversation. Ce n'est pas de la décoration : c'est ce qui fait qu'on lit la question
/// comme une question et non comme un champ.
///
/// Elle est dessinée en SwiftUI pur, pas en image : elle **bouge**. Elle respire (un
/// balancement lent), elle cligne des yeux à intervalles irréguliers, son regard suit une
/// direction, et son humeur change la bouche et ce qui flotte autour. Une image aurait
/// donné un autocollant.
///
/// Sa forme est une carte de révision — un rectangle arrondi, un peu plus haut que large —
/// parce que c'est l'objet de l'app. Le violet est celui de l'accent : elle porte la
/// couleur de ce qui agit.
///
/// **Toutes les mesures sont nommées dans `Metrics`**, jamais calculées dans une chaîne de
/// modificateurs. Un `size * 0.025` posé dans un `offset` au milieu de six maillons est
/// une inconnue de plus pour l'inférence ; trente de suite, et le compilateur renonce —
/// c'est ce qui a cassé la scène d'import de la veille.
struct MicaboMascot: View {
    enum Mood {
        /// Le regard droit, le sourire tranquille : elle écoute.
        case happy
        /// Les yeux vers le haut, la bouche plate, trois points qui flottent : elle travaille.
        case thinking
        /// Grand sourire, yeux plissés, des étincelles : c'est fait.
        case celebrating
    }

    var mood: Mood = .happy
    var size: CGFloat = 120

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var breathe = false
    @State private var blink = false
    @State private var sparkle = false

    /// Les mesures, toutes dérivées de `size`, toutes en `CGFloat`, toutes nommées.
    private struct Metrics {
        let frameWidth: CGFloat
        let frameHeight: CGFloat
        let bodyWidth: CGFloat
        let bodyHeight: CGFloat
        let corner: CGFloat
        let shadowRadius: CGFloat
        let shadowY: CGFloat
        let fold: CGFloat
        let foldX: CGFloat
        let foldY: CGFloat
        let eyeGap: CGFloat
        let eyeWidth: CGFloat
        let eyeHeight: CGFloat
        let pupil: CGFloat
        let glint: CGFloat
        let glintDX: CGFloat
        let glintDY: CGFloat
        let faceDY: CGFloat
        let faceGap: CGFloat
        let breatheDY: CGFloat
        let dotGap: CGFloat
        let dotBase: CGFloat
        let dotStep: CGFloat
        let dotRise: CGFloat
        let dotsX: CGFloat
        let dotsY: CGFloat
        let smileWidth: CGFloat
        let smileDepth: CGFloat
        let smileLine: CGFloat
        let grinWidth: CGFloat
        let grinDepth: CGFloat
        let grinLine: CGFloat
        let flatWidth: CGFloat
        let flatHeight: CGFloat
        let cheekGap: CGFloat
        let cheek: CGFloat
        let cheekRise: CGFloat

        init(size: CGFloat) {
            frameWidth = size * 1.5
            frameHeight = size * 1.35
            bodyWidth = size * 0.86
            bodyHeight = size
            corner = size * 0.3
            shadowRadius = size * 0.16
            shadowY = size * 0.08
            fold = size * 0.2
            foldX = size * 0.33
            foldY = size * -0.4
            eyeGap = size * 0.13
            eyeWidth = size * 0.2
            eyeHeight = size * 0.24
            pupil = size * 0.1
            glint = size * 0.035
            glintDX = size * 0.025
            glintDY = size * -0.028
            faceDY = size * 0.02
            faceGap = size * 0.08
            breatheDY = size * 0.03
            dotGap = size * 0.05
            dotBase = size * 0.07
            dotStep = size * 0.015
            dotRise = size * 0.04
            dotsX = size * 0.5
            dotsY = size * -0.46
            smileWidth = size * 0.22
            smileDepth = size * 0.09
            smileLine = size * 0.035
            grinWidth = size * 0.3
            grinDepth = size * 0.14
            grinLine = size * 0.04
            flatWidth = size * 0.14
            flatHeight = size * 0.035
            cheekGap = size * 0.44
            cheek = size * 0.09
            cheekRise = size * -0.06
        }
    }

    var body: some View {
        let metrics = Metrics(size: size)
        let tilt: Double = breathe ? 2.5 : -2.5
        let lift: CGFloat = breathe ? -metrics.breatheDY : metrics.breatheDY

        return ZStack {
            if mood == .celebrating {
                sparkles
            }

            figure(metrics)
                .rotationEffect(.degrees(tilt))
                .offset(y: lift)

            if mood == .thinking {
                thoughtDots(metrics)
            }
        }
        .frame(width: metrics.frameWidth, height: metrics.frameHeight)
        .accessibilityHidden(true)
        .onAppear(perform: start)
        // **Dans `.task`, pas dans un `Task {}` lancé à l'apparition** : la mascotte est sur
        // quinze écrans, et une boucle qui survit à sa vue en laisserait quinze tourner à
        // vide en fin de parcours. `.task` est annulé quand la vue disparaît.
        .task { await blinkLoop() }
    }

    // MARK: - Le corps

    private func figure(_ metrics: Metrics) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: metrics.corner, style: .continuous)
                .fill(bodyGradient)
                .frame(width: metrics.bodyWidth, height: metrics.bodyHeight)
                .shadow(color: MicaboColor.accent.opacity(0.28), radius: metrics.shadowRadius, y: metrics.shadowY)

            // Le coin replié d'une fiche : ce qui dit « carte » sans un mot.
            FoldShape()
                .fill(Color.white.opacity(0.22))
                .frame(width: metrics.fold, height: metrics.fold)
                .offset(x: metrics.foldX, y: metrics.foldY)

            face(metrics)
        }
    }

    private var bodyGradient: LinearGradient {
        LinearGradient(
            colors: [MicaboColor.accent.lightened(by: 0.12), MicaboColor.accent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private struct FoldShape: Shape {
        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                path.closeSubpath()
            }
        }
    }

    // MARK: - Le visage

    private func face(_ metrics: Metrics) -> some View {
        VStack(spacing: metrics.faceGap) {
            HStack(spacing: metrics.eyeGap) {
                eye(metrics)
                eye(metrics)
            }
            mouth(metrics)
        }
        .offset(y: metrics.faceDY)
    }

    private func eye(_ metrics: Metrics) -> some View {
        let pupilX: CGFloat = gaze.x * size
        let pupilY: CGFloat = gaze.y * size
        let glintX: CGFloat = pupilX + metrics.glintDX
        let glintY: CGFloat = pupilY + metrics.glintDY
        let squint: CGFloat = (blink || mood == .celebrating) ? 0.12 : 1

        return ZStack {
            Ellipse()
                .fill(Color.white)
                .frame(width: metrics.eyeWidth, height: metrics.eyeHeight)

            Circle()
                .fill(MicaboColor.ink)
                .frame(width: metrics.pupil, height: metrics.pupil)
                .offset(x: pupilX, y: pupilY)

            // Le reflet : c'est lui qui rend le regard vivant.
            Circle()
                .fill(Color.white)
                .frame(width: metrics.glint, height: metrics.glint)
                .offset(x: glintX, y: glintY)
        }
        .scaleEffect(x: 1, y: squint, anchor: .center)
        .animation(.easeInOut(duration: 0.09), value: blink)
    }

    /// Où regardent les pupilles, en fraction de la taille.
    private var gaze: CGPoint {
        switch mood {
        case .happy: CGPoint(x: 0.012, y: 0.01)
        case .thinking: CGPoint(x: 0.03, y: -0.03)
        case .celebrating: .zero
        }
    }

    @ViewBuilder
    private func mouth(_ metrics: Metrics) -> some View {
        switch mood {
        case .happy:
            Smile(depth: metrics.smileDepth)
                .stroke(Color.white, style: StrokeStyle(lineWidth: metrics.smileLine, lineCap: .round))
                .frame(width: metrics.smileWidth, height: metrics.smileDepth)
        case .thinking:
            Capsule()
                .fill(Color.white)
                .frame(width: metrics.flatWidth, height: metrics.flatHeight)
        case .celebrating:
            ZStack {
                Smile(depth: metrics.grinDepth)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: metrics.grinLine, lineCap: .round))
                    .frame(width: metrics.grinWidth, height: metrics.grinDepth)
                cheeks(metrics)
            }
        }
    }

    /// Les joues : seulement quand elle est contente, sinon elle a l'air malade.
    private func cheeks(_ metrics: Metrics) -> some View {
        HStack(spacing: metrics.cheekGap) {
            Circle().fill(MicaboColor.flameSoft.opacity(0.9))
            Circle().fill(MicaboColor.flameSoft.opacity(0.9))
        }
        .frame(height: metrics.cheek)
        .offset(y: metrics.cheekRise)
    }

    private struct Smile: Shape {
        let depth: CGFloat

        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX, y: rect.minY),
                    control: CGPoint(x: rect.midX, y: rect.minY + depth * 2)
                )
            }
        }
    }

    // MARK: - Autour

    /// Trois points qui montent l'un après l'autre : elle réfléchit.
    private func thoughtDots(_ metrics: Metrics) -> some View {
        HStack(spacing: metrics.dotGap) {
            ForEach(0..<3, id: \.self) { index in
                thoughtDot(index, metrics)
            }
        }
        .offset(x: metrics.dotsX, y: metrics.dotsY)
    }

    private func thoughtDot(_ index: Int, _ metrics: Metrics) -> some View {
        let diameter: CGFloat = metrics.dotBase + CGFloat(index) * metrics.dotStep
        let rise: CGFloat = breathe ? -metrics.dotRise * CGFloat(index + 1) : 0
        let delay: Double = Double(index) * 0.15

        return Circle()
            .fill(MicaboColor.accent.opacity(0.55))
            .frame(width: diameter, height: diameter)
            .offset(y: rise)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(delay), value: breathe)
    }

    /// Des étincelles qui battent : la fête, sans confettis.
    private var sparkles: some View {
        ZStack {
            spark(x: -0.58, y: -0.42, share: 0.13, delay: 0)
            spark(x: 0.6, y: -0.3, share: 0.1, delay: 0.25)
            spark(x: -0.5, y: 0.34, share: 0.08, delay: 0.5)
            spark(x: 0.55, y: 0.4, share: 0.11, delay: 0.7)
        }
    }

    private func spark(x: CGFloat, y: CGFloat, share: CGFloat, delay: Double) -> some View {
        let fontSize: CGFloat = size * share
        let dx: CGFloat = x * size
        let dy: CGFloat = y * size
        let scale: CGFloat = sparkle ? 1.25 : 0.7
        let alpha: Double = sparkle ? 1 : 0.35

        return Image(systemName: "sparkle")
            .font(.system(size: fontSize, weight: .bold))
            .foregroundStyle(MicaboColor.caution)
            .scaleEffect(scale)
            .opacity(alpha)
            .offset(x: dx, y: dy)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true).delay(delay), value: sparkle)
    }

    // MARK: - La vie

    private func start() {
        guard !reduceMotion else { return }

        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            breathe = true
        }
        sparkle = true
    }

    /// Le clignement n'est pas au métronome : deux clignements à intervalle égal se
    /// remarquent, et on cesse d'y croire. Entre deux secondes et demie et quatre.
    @MainActor
    private func blinkLoop() async {
        guard !reduceMotion else { return }
        while !Task.isCancelled {
            let pause = Double.random(in: 2.5...4.0)
            try? await Task.sleep(for: .milliseconds(Int(pause * 1000)))
            guard !Task.isCancelled else { return }
            blink = true
            try? await Task.sleep(for: .milliseconds(110))
            blink = false
        }
    }
}

// MARK: - La bulle

/// **Ce que la mascotte dit.**
///
/// Une bulle blanche à filet, avec sa queue vers le personnage. Le texte y est en dix-sept
/// points demi-gras : c'est une phrase qu'on lit comme si quelqu'un venait de la dire, pas
/// un titre d'écran.
struct MicaboSpeechBubble: View {
    let text: String
    /// De quel côté pointe la queue.
    var tail: Edge = .top

    var body: some View {
        let tailAlignment: Alignment = tail == .top ? .top : .bottom
        let tailTurn: Double = tail == .top ? 0 : 180
        let tailOffset: CGFloat = tail == .top ? -11 : 11

        return Text(text)
            .font(MicaboFont.ui(17, weight: .semibold))
            .foregroundStyle(MicaboColor.ink)
            .lineSpacing(3)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(MicaboColor.stroke, lineWidth: 1.5)
            }
            .overlay(alignment: tailAlignment) {
                tailShape
                    .rotationEffect(.degrees(tailTurn))
                    .offset(y: tailOffset)
            }
            .shadow(color: MicaboColor.ink.opacity(0.05), radius: 12, y: 5)
    }

    private var tailShape: some View {
        ZStack {
            Triangle()
                .fill(MicaboColor.stroke)
                .frame(width: 22, height: 12)
            Triangle()
                .fill(MicaboColor.canvas)
                .frame(width: 18, height: 10)
                .offset(y: 1.6)
        }
    }

    private struct Triangle: Shape {
        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: rect.midX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                path.closeSubpath()
            }
        }
    }
}
