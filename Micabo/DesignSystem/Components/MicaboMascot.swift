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
/// direction, et son humeur change les sourcils, la bouche, les mains et ce qui flotte
/// autour. Une image aurait donné un autocollant.
///
/// **Huit humeurs, pas trois.** Avec trois humeurs, la mascotte faisait la même tête sur
/// quinze écrans de suite, et un personnage qui ne réagit à rien cesse d'être un
/// personnage. Elle salue quand on lui donne son prénom, penche la tête quand elle demande
/// où l'on étudie, lit quand on choisit ses matières, s'inquiète quand on part de zéro, et
/// se redresse quand on a fini. Ce sont des réactions, pas des poses.
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
    enum Mood: Equatable {
        /// Le regard droit, le sourire tranquille : elle écoute.
        case happy
        /// Les yeux vers le haut, la bouche plate, trois points qui flottent : elle travaille.
        case thinking
        /// Grand sourire, yeux plissés, les deux mains en l'air, des étincelles : c'est fait.
        case celebrating
        /// Une main qui salue, les joues qui rosissent : bonjour.
        case waving
        /// La tête penchée, un sourcil levé, la bouche en « o » : elle demande.
        case curious
        /// Les yeux qui balaient une ligne, les sourcils froncés : elle lit.
        case reading
        /// Les sourcils inquiets, le regard en bas, une goutte : elle n'est pas sûre.
        case unsure
        /// Le sourire large, les yeux mi-clos, les mains sur les hanches : elle est fière.
        case proud
    }

    var mood: Mood = .happy
    var size: CGFloat = 120

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var breathe = false
    @State private var blink = false
    @State private var sparkle = false
    /// Le va-et-vient de la main qui salue et des mains levées.
    @State private var wave = false
    /// Le balayage du regard quand elle lit.
    @State private var scan = false

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
        let browWidth: CGFloat
        let browLine: CGFloat
        let browRise: CGFloat
        let browLift: CGFloat
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
        let oWidth: CGFloat
        let cheekGap: CGFloat
        let cheek: CGFloat
        let cheekRise: CGFloat
        let hand: CGFloat
        let handSide: CGFloat
        let handUp: CGFloat
        let handHip: CGFloat
        let handWaveDY: CGFloat
        let dropX: CGFloat
        let dropY: CGFloat
        let dropSize: CGFloat

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
            browWidth = size * 0.15
            browLine = size * 0.032
            browRise = size * -0.075
            browLift = size * 0.03
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
            oWidth = size * 0.1
            cheekGap = size * 0.44
            cheek = size * 0.09
            cheekRise = size * -0.06
            hand = size * 0.17
            handSide = size * 0.5
            handUp = size * -0.3
            handHip = size * 0.2
            handWaveDY = size * 0.04
            dropX = size * 0.46
            dropY = size * -0.4
            dropSize = size * 0.15
        }
    }

    var body: some View {
        let metrics = Metrics(size: size)
        let sway: Double = breathe ? 2.5 : -2.5
        let tilt: Double = sway + headTilt
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

            if mood == .unsure {
                drop(metrics)
            }
        }
        .frame(width: metrics.frameWidth, height: metrics.frameHeight)
        // Une humeur qui change sous les yeux se fond dans la suivante : la bouche et les
        // sourcils ne sautent pas d'une forme à l'autre.
        .animation(.easeOut(duration: 0.22), value: mood)
        .accessibilityHidden(true)
        .onAppear(perform: start)
        // **Dans `.task`, pas dans un `Task {}` lancé à l'apparition** : la mascotte est sur
        // quinze écrans, et une boucle qui survit à sa vue en laisserait quinze tourner à
        // vide en fin de parcours. `.task` est annulé quand la vue disparaît.
        .task { await blinkLoop() }
    }

    /// La tête penchée : c'est la curiosité, ou le doute.
    private var headTilt: Double {
        switch mood {
        case .curious: -7
        case .unsure: 4
        default: 0
        }
    }

    // MARK: - Le corps

    private func figure(_ metrics: Metrics) -> some View {
        ZStack {
            hands(metrics)

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

    // MARK: - Les mains

    /// Deux petites mains rondes, un ton plus sombre que le corps. Elles ne sont là que
    /// quand elles font quelque chose : saluer, se lever, se poser sur les hanches. Le reste
    /// du temps la carte garde sa silhouette.
    @ViewBuilder
    private func hands(_ metrics: Metrics) -> some View {
        switch mood {
        case .waving:
            hand(metrics, x: -metrics.handSide, y: metrics.handHip)
            wavingHand(metrics)
        case .celebrating:
            let bounce: CGFloat = wave ? -metrics.handWaveDY : metrics.handWaveDY
            hand(metrics, x: -metrics.handSide, y: metrics.handUp + bounce)
            hand(metrics, x: metrics.handSide, y: metrics.handUp - bounce)
        case .proud:
            hand(metrics, x: -metrics.handSide, y: metrics.handHip)
            hand(metrics, x: metrics.handSide, y: metrics.handHip)
        default:
            EmptyView()
        }
    }

    private func hand(_ metrics: Metrics, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(Self.handInk)
            .frame(width: metrics.hand, height: metrics.hand)
            .offset(x: x, y: y)
            .animation(.easeInOut(duration: 0.42).repeatForever(autoreverses: true), value: wave)
    }

    /// La main droite, levée à côté de la tête, qui pivote autour du poignet.
    private func wavingHand(_ metrics: Metrics) -> some View {
        let swing: Double = wave ? 22 : -22
        let reach: CGFloat = metrics.handSide + metrics.hand * 0.3

        return Circle()
            .fill(Self.handInk)
            .frame(width: metrics.hand, height: metrics.hand)
            .offset(x: reach, y: metrics.handUp)
            .rotationEffect(.degrees(swing), anchor: .bottom)
            .animation(.easeInOut(duration: 0.42).repeatForever(autoreverses: true), value: wave)
    }

    /// Le violet d'appui de la maquette : la couleur des liens survolés, un ton sous l'accent.
    private static let handInk = Color(hex: 0x4E2FCB)

    // MARK: - Le visage

    private func face(_ metrics: Metrics) -> some View {
        VStack(spacing: metrics.faceGap) {
            HStack(spacing: metrics.eyeGap) {
                eye(metrics)
                eye(metrics)
            }
            .overlay(alignment: .top) {
                brows(metrics)
            }

            mouth(metrics)
        }
        .offset(y: metrics.faceDY)
    }

    private func eye(_ metrics: Metrics) -> some View {
        let pupilX: CGFloat = gazeX * size
        let pupilY: CGFloat = gaze.y * size
        let glintX: CGFloat = pupilX + metrics.glintDX
        let glintY: CGFloat = pupilY + metrics.glintDY
        let squint: CGFloat = blink ? 0.12 : lidLevel

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
        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: scan)
    }

    /// À quel point les paupières sont ouvertes : grand ouvertes, mi-closes de fierté,
    /// plissées de joie.
    private var lidLevel: CGFloat {
        switch mood {
        case .celebrating: 0.12
        case .proud: 0.55
        default: 1
        }
    }

    /// Où regardent les pupilles, en fraction de la taille.
    private var gaze: CGPoint {
        switch mood {
        case .happy, .waving: CGPoint(x: 0.012, y: 0.01)
        case .thinking: CGPoint(x: 0.03, y: -0.03)
        case .curious: CGPoint(x: 0.03, y: -0.02)
        case .unsure: CGPoint(x: -0.025, y: 0.03)
        case .reading: CGPoint(x: 0, y: 0.02)
        case .celebrating, .proud: .zero
        }
    }

    /// Le regard qui balaie une ligne quand elle lit ; fixe sinon.
    private var gazeX: CGFloat {
        guard mood == .reading else { return gaze.x }
        return scan ? 0.035 : -0.035
    }

    // MARK: - Les sourcils

    /// Deux traits au-dessus des yeux, et c'est ce qui donne une humeur à un regard. Le
    /// blanc en est atténué : des sourcils aussi francs que les yeux feraient une grimace.
    private func brows(_ metrics: Metrics) -> some View {
        let pose = browPose
        let gap: CGFloat = metrics.eyeGap + metrics.eyeWidth - metrics.browWidth
        let lift: CGFloat = metrics.browRise - metrics.browLift * pose.lift

        return HStack(spacing: gap) {
            brow(metrics, angle: pose.left)
            brow(metrics, angle: pose.right)
        }
        .offset(y: lift)
    }

    private func brow(_ metrics: Metrics, angle: Double) -> some View {
        Capsule()
            .fill(Color.white.opacity(0.7))
            .frame(width: metrics.browWidth, height: metrics.browLine)
            .rotationEffect(.degrees(angle))
    }

    /// L'angle de chaque sourcil et sa hauteur, par humeur. Pour le sourcil droit, un angle
    /// négatif lève le bout extérieur ; pour le gauche, c'est un angle positif.
    private var browPose: (left: Double, right: Double, lift: CGFloat) {
        switch mood {
        case .happy: (-5, 5, 0)
        case .thinking: (0, -12, 0.6)
        case .curious: (3, -14, 0.9)
        case .reading: (6, -6, -0.3)
        case .unsure: (-14, 14, 0.5)
        case .celebrating, .waving, .proud: (7, -7, 0.8)
        }
    }

    // MARK: - La bouche

    @ViewBuilder
    private func mouth(_ metrics: Metrics) -> some View {
        switch mood {
        case .happy, .reading:
            smile(metrics)
        case .thinking:
            Capsule()
                .fill(Color.white)
                .frame(width: metrics.flatWidth, height: metrics.flatHeight)
        case .unsure:
            // Une bouche plate qui penche : l'hésitation, sans aller jusqu'à la moue.
            Capsule()
                .fill(Color.white)
                .frame(width: metrics.flatWidth, height: metrics.flatHeight)
                .rotationEffect(.degrees(-9))
        case .curious:
            Circle()
                .stroke(Color.white, lineWidth: metrics.smileLine)
                .frame(width: metrics.oWidth, height: metrics.oWidth)
        case .waving:
            ZStack {
                smile(metrics)
                cheeks(metrics)
            }
        case .celebrating, .proud:
            ZStack {
                Smile(depth: metrics.grinDepth)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: metrics.grinLine, lineCap: .round))
                    .frame(width: metrics.grinWidth, height: metrics.grinDepth)
                cheeks(metrics)
            }
        }
    }

    private func smile(_ metrics: Metrics) -> some View {
        Smile(depth: metrics.smileDepth)
            .stroke(Color.white, style: StrokeStyle(lineWidth: metrics.smileLine, lineCap: .round))
            .frame(width: metrics.smileWidth, height: metrics.smileDepth)
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

    /// Une goutte à la tempe : le doute, dit comme dans une bande dessinée.
    private func drop(_ metrics: Metrics) -> some View {
        let bob: CGFloat = breathe ? -metrics.breatheDY : metrics.breatheDY

        return Image(systemName: "drop.fill")
            .font(.system(size: metrics.dropSize, weight: .bold))
            .foregroundStyle(MicaboColor.info)
            .offset(x: metrics.dropX, y: metrics.dropY + bob)
            .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: breathe)
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

    /// Tout ce qui bat est lancé à l'apparition, quelle que soit l'humeur : une humeur qui
    /// change en cours de route trouve ses mouvements déjà en marche.
    private func start() {
        guard !reduceMotion else { return }

        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            breathe = true
        }
        sparkle = true
        wave = true
        scan = true
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

// MARK: - Le petit saut

/// **La mascotte sursaute quand quelque chose change.**
///
/// Un nouvel écran, une réponse donnée : elle se soulève d'un rien et retombe. C'est la
/// réaction qui manquait — une mascotte posée dans un coin qui ne bronche pas quand on lui
/// répond n'écoute pas.
private struct MascotHop<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lifted = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(lifted ? 1.16 : 1)
            .offset(y: lifted ? -4 : 0)
            .onChange(of: trigger) { _, _ in
                guard !reduceMotion else { return }
                withAnimation(.spring(response: 0.26, dampingFraction: 0.55)) {
                    lifted = true
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(180))
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.62)) {
                        lifted = false
                    }
                }
            }
    }
}

extension View {
    /// Fait sursauter la mascotte à chaque changement de `trigger`.
    func mascotHop<Trigger: Equatable>(on trigger: Trigger) -> some View {
        modifier(MascotHop(trigger: trigger))
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
