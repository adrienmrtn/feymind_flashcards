import SwiftUI

/// **La mascotte de Micabo : un petit personnage violet, rond, qui a un visage.**
///
/// Les parcours d'accueil qui marchent — Gizmo, Ahead, Hablo — ont tous la même chose que
/// le nôtre n'avait pas : quelqu'un qui parle. Un personnage sur chaque écran, qui pose la
/// question dans une bulle, qui cligne des yeux pendant qu'on hésite, qui se réjouit quand
/// on a fini. Sans lui, un parcours de vingt écrans est un formulaire ; avec lui, c'est une
/// conversation.
///
/// **Ce n'est plus un rectangle avec deux ellipses dessus.** La version précédente
/// superposait des formes géométriques — un rectangle arrondi, deux ellipses, deux ronds —
/// et ça se voyait : un autocollant plat, sans volume, qui faisait la même tête partout.
/// Celle-ci a un corps en haricot dessiné à la main, un dégradé qui lui donne du volume,
/// un reflet sur l'épaule, une ombre sous le ventre, une ombre au sol, deux pieds, deux
/// bras qui bougent, des yeux avec des paupières et des reflets, une bouche qui s'ouvre.
///
/// **Tout ce qui fait une expression est un nombre.** Une humeur n'est pas un dessin à
/// part : c'est un jeu de valeurs — hauteur des paupières, angle des sourcils, courbure et
/// ouverture de la bouche, angle des bras, rougeur des joues — et passer d'une humeur à
/// l'autre les interpole. La mascotte ne change pas de tête : elle **fait** une autre
/// tête, sous les yeux. C'est ce qui rend les changements crédibles.
///
/// Elle vit aussi quand rien ne se passe : elle respire (une compression lente, comme
/// quelque chose de mou), cligne des yeux à intervalles irréguliers, regarde ailleurs de
/// temps en temps, et ses bras se balancent. Elle sursaute quand on passe à l'écran suivant.
///
/// **Toutes les mesures sont nommées dans `Metrics`**, jamais calculées dans une chaîne de
/// modificateurs : trente calculs inline de suite, et le compilateur renonce. Le dessin a
/// été mis au point sur un canevas HTML aux mêmes proportions avant d'être porté ici.
struct MicaboMascot: View {
    enum Mood: Equatable {
        /// Le regard droit, le sourire tranquille : elle écoute.
        case happy
        /// Les yeux vers le haut, la bouche plate, un bras levé, trois points : elle travaille.
        case thinking
        /// Yeux plissés de joie, grand sourire ouvert, les deux bras en l'air, des étincelles.
        case celebrating
        /// Une main levée qui salue, les joues qui rosissent : bonjour.
        case waving
        /// La tête penchée, un sourcil levé, la bouche en « o » : elle demande.
        case curious
        /// Les paupières à mi-hauteur, le regard qui balaie une ligne : elle lit.
        case reading
        /// Les sourcils inquiets, le regard en bas, la bouche qui tombe, une goutte.
        case unsure
        /// Les yeux mi-clos, le sourire large, les mains sur les hanches : elle est fière.
        case proud
    }

    var mood: Mood = .happy
    var size: CGFloat = 120

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var breathe = false
    @State private var blink = false
    @State private var sparkle = false
    /// Le va-et-vient de la main qui salue et des bras levés.
    @State private var wave = false
    /// Le balayage du regard quand elle lit.
    @State private var scan = false
    /// Où elle regarde quand elle regarde ailleurs, en fraction de la taille.
    @State private var drift = CGPoint.zero

    // MARK: - Les mesures

    /// Toutes dérivées de `size`, toutes en `CGFloat`, toutes nommées. Les mêmes fractions
    /// que le canevas de mise au point.
    private struct Metrics {
        let frameWidth: CGFloat
        let frameHeight: CGFloat
        let bodyWidth: CGFloat
        let bodyHeight: CGFloat
        let footWidth: CGFloat
        let footHeight: CGFloat
        let footX: CGFloat
        let footY: CGFloat
        let shadowWidth: CGFloat
        let shadowHeight: CGFloat
        let shadowY: CGFloat
        let armWidth: CGFloat
        let armLength: CGFloat
        let armX: CGFloat
        let armY: CGFloat
        let eyeWidth: CGFloat
        let eyeHeight: CGFloat
        let eyeX: CGFloat
        let eyeY: CGFloat
        let iris: CGFloat
        let glint: CGFloat
        let glintDX: CGFloat
        let glintDY: CGFloat
        let glintSmall: CGFloat
        let glintSmallDX: CGFloat
        let glintSmallDY: CGFloat
        let lidWidth: CGFloat
        let lidHeight: CGFloat
        let browWidth: CGFloat
        let browThickness: CGFloat
        let browY: CGFloat
        let browLift: CGFloat
        let mouthWidth: CGFloat
        let mouthDepth: CGFloat
        let mouthOpen: CGFloat
        let mouthY: CGFloat
        let lip: CGFloat
        let cheek: CGFloat
        let cheekX: CGFloat
        let cheekY: CGFloat
        let breatheX: CGFloat
        let breatheY: CGFloat
        let dotBase: CGFloat
        let dotStep: CGFloat
        let dotGap: CGFloat
        let dotRise: CGFloat
        let dotsX: CGFloat
        let dotsY: CGFloat
        let dropWidth: CGFloat
        let dropHeight: CGFloat
        let dropX: CGFloat
        let dropY: CGFloat
        let driftScale: CGFloat

        init(size: CGFloat) {
            frameWidth = size * 1.5
            frameHeight = size * 1.35
            bodyWidth = size * 0.86
            bodyHeight = size
            footWidth = size * 0.22
            footHeight = size * 0.10
            footX = size * 0.19
            footY = size * 0.47
            shadowWidth = size * 0.66
            shadowHeight = size * 0.085
            shadowY = size * 0.55
            armWidth = size * 0.115
            armLength = size * 0.30
            armX = size * 0.36
            armY = size * 0.10
            eyeWidth = size * 0.23
            eyeHeight = size * 0.27
            eyeX = size * 0.17
            eyeY = size * -0.09
            iris = size * 0.125
            glint = size * 0.05
            glintDX = size * 0.028
            glintDY = size * -0.03
            glintSmall = size * 0.022
            glintSmallDX = size * -0.02
            glintSmallDY = size * 0.035
            lidWidth = size * 0.345
            lidHeight = size * 0.335
            browWidth = size * 0.15
            browThickness = size * 0.032
            browY = size * -0.16
            browLift = size * 0.03
            mouthWidth = size * 0.24
            mouthDepth = size * 0.075
            mouthOpen = size * 0.14
            mouthY = size * 0.13
            lip = size * 0.032
            cheek = size * 0.10
            cheekX = size * 0.235
            cheekY = size * 0.10
            breatheX = 0.015
            breatheY = 0.02
            dotBase = size * 0.07
            dotStep = size * 0.016
            dotGap = size * 0.05
            dotRise = size * 0.04
            dotsX = size * 0.58
            dotsY = size * -0.5
            dropWidth = size * 0.13
            dropHeight = size * 0.17
            dropX = size * 0.46
            dropY = size * -0.42
            driftScale = size
        }
    }

    // MARK: - L'expression

    /// **Ce qu'une humeur vaut, en nombres.** C'est ce que l'animation interpole quand
    /// l'humeur change : rien ici n'est un dessin, tout est une quantité.
    private struct Expression {
        /// La paupière supérieure, de 0 (ouverte) à 1 (fermée).
        var lid: CGFloat
        /// La paupière inférieure qui remonte en arc : les yeux qui rient.
        var squint: CGFloat
        var browLeft: Double
        var browRight: Double
        var browLift: CGFloat
        var gazeX: CGFloat
        var gazeY: CGFloat
        var pupil: CGFloat
        /// La courbure de la bouche, de −1 (tombe) à 1 (sourit).
        var curve: CGFloat
        /// L'ouverture de la bouche, de 0 à 1.
        var open: CGFloat
        var mouthWidth: CGFloat
        var cheeks: Double
        /// L'angle des bras, vers l'extérieur, en degrés depuis « le long du corps ».
        var armLeft: Double
        var armRight: Double
        var tilt: Double
        /// Vrai quand la main droite salue.
        var waves: Bool

        static func of(_ mood: Mood) -> Expression {
            switch mood {
            case .happy:
                Expression(lid: 0, squint: 0.15, browLeft: -5, browRight: 5, browLift: 0, gazeX: 0.012, gazeY: 0.01, pupil: 1, curve: 0.6, open: 0, mouthWidth: 1, cheeks: 0, armLeft: 18, armRight: 18, tilt: 0, waves: false)
            case .thinking:
                Expression(lid: 0.1, squint: 0, browLeft: 0, browRight: -12, browLift: 0.6, gazeX: 0.03, gazeY: -0.03, pupil: 0.95, curve: 0.05, open: 0, mouthWidth: 0.7, cheeks: 0, armLeft: 14, armRight: 118, tilt: 0, waves: false)
            case .celebrating:
                Expression(lid: 0, squint: 0.85, browLeft: 7, browRight: -7, browLift: 0.8, gazeX: 0, gazeY: 0, pupil: 1, curve: 1, open: 0.9, mouthWidth: 1.15, cheeks: 0.9, armLeft: 150, armRight: 150, tilt: 0, waves: false)
            case .waving:
                Expression(lid: 0, squint: 0.4, browLeft: 7, browRight: -7, browLift: 0.8, gazeX: 0.012, gazeY: 0.01, pupil: 1, curve: 0.75, open: 0.25, mouthWidth: 1, cheeks: 0.8, armLeft: 18, armRight: 140, tilt: 0, waves: true)
            case .curious:
                Expression(lid: 0, squint: 0, browLeft: 3, browRight: -14, browLift: 0.9, gazeX: 0.03, gazeY: -0.02, pupil: 1.15, curve: 0.15, open: 0.55, mouthWidth: 0.45, cheeks: 0, armLeft: 26, armRight: 26, tilt: -7, waves: false)
            case .reading:
                Expression(lid: 0.28, squint: 0, browLeft: 6, browRight: -6, browLift: -0.3, gazeX: 0, gazeY: 0.02, pupil: 1, curve: 0.35, open: 0, mouthWidth: 0.9, cheeks: 0, armLeft: 42, armRight: 42, tilt: 0, waves: false)
            case .unsure:
                Expression(lid: 0.12, squint: 0, browLeft: -14, browRight: 14, browLift: 0.5, gazeX: -0.025, gazeY: 0.03, pupil: 0.9, curve: -0.35, open: 0, mouthWidth: 0.75, cheeks: 0, armLeft: 8, armRight: 8, tilt: 4, waves: false)
            case .proud:
                Expression(lid: 0.32, squint: 0.45, browLeft: 7, browRight: -7, browLift: 0.6, gazeX: 0, gazeY: 0, pupil: 1, curve: 0.8, open: 0.3, mouthWidth: 1.05, cheeks: 0.7, armLeft: 58, armRight: 58, tilt: 0, waves: false)
            }
        }
    }

    // MARK: - Les couleurs

    private static let bodyLight = Color(hex: 0x8A6FF5)
    private static let bodyDeep = Color(hex: 0x4E2FCB)
    private static let mouthInside = Color(hex: 0x2B1B6B)
    private static let blush = Color(hex: 0xFFB3C7)
    private static let tongue = Color(hex: 0xFF7A9B)
    private static let sparkGold = Color(hex: 0xF5B400)

    // MARK: - Le corps de la vue

    var body: some View {
        let metrics = Metrics(size: size)
        let expression = Expression.of(mood)
        let squashX: CGFloat = breathe ? 1 + metrics.breatheX : 1 - metrics.breatheX
        let squashY: CGFloat = breathe ? 1 - metrics.breatheY : 1 + metrics.breatheY

        return ZStack {
            groundShadow(metrics)

            figure(metrics, expression)
                .scaleEffect(x: squashX, y: squashY, anchor: .bottom)
                .rotationEffect(.degrees(expression.tilt), anchor: .bottom)

            if mood == .celebrating {
                sparkles
            }
            if mood == .thinking {
                thoughtDots(metrics)
            }
            if mood == .unsure {
                drop(metrics)
            }
        }
        .frame(width: metrics.frameWidth, height: metrics.frameHeight)
        // C'est ici que les humeurs se fondent l'une dans l'autre : chaque nombre de
        // l'expression est interpolé, et la mascotte fait sa nouvelle tête sous les yeux.
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: mood)
        .animation(.easeInOut(duration: 0.28), value: drift)
        .accessibilityHidden(true)
        .onAppear(perform: start)
        // **Dans `.task`, pas dans un `Task {}` lancé à l'apparition** : la mascotte est sur
        // quinze écrans, et une boucle qui survit à sa vue en laisserait quinze tourner à
        // vide en fin de parcours. `.task` est annulé quand la vue disparaît.
        .task { await blinkLoop() }
        .task { await glanceLoop() }
    }

    // MARK: - Le personnage

    private func figure(_ metrics: Metrics, _ expression: Expression) -> some View {
        ZStack {
            feet(metrics)
            arms(metrics, expression)
            torso(metrics)
            face(metrics, expression)
        }
    }

    /// L'ombre au sol : ce qui pose le personnage sur quelque chose.
    private func groundShadow(_ metrics: Metrics) -> some View {
        Ellipse()
            .fill(MicaboColor.ink.opacity(0.11))
            .frame(width: metrics.shadowWidth, height: metrics.shadowHeight)
            .offset(y: metrics.shadowY)
    }

    private func feet(_ metrics: Metrics) -> some View {
        HStack(spacing: metrics.footX * 2 - metrics.footWidth) {
            Ellipse().fill(Self.bodyDeep)
            Ellipse().fill(Self.bodyDeep)
        }
        .frame(height: metrics.footHeight)
        .frame(width: metrics.footX * 2 + metrics.footWidth)
        .offset(y: metrics.footY)
    }

    /// Le corps : le haricot, son dégradé, l'ombre sous le ventre et le reflet sur l'épaule.
    private func torso(_ metrics: Metrics) -> some View {
        MascotBodyShape()
            .fill(bodyGradient)
            .overlay { bellyShadow }
            .overlay { shoulderHighlight }
            .clipShape(MascotBodyShape())
            .frame(width: metrics.bodyWidth, height: metrics.bodyHeight)
            .shadow(color: MicaboColor.accent.opacity(0.22), radius: size * 0.12, y: size * 0.06)
    }

    private var bodyGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Self.bodyLight, location: 0),
                .init(color: MicaboColor.accent, location: 0.55),
                .init(color: Self.bodyDeep, location: 1),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var bellyShadow: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.55),
                .init(color: Color(hex: 0x140046).opacity(0.22), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var shoulderHighlight: some View {
        RadialGradient(
            colors: [Color.white.opacity(0.28), Color.white.opacity(0)],
            center: UnitPoint(x: 0.32, y: 0.16),
            startRadius: 0,
            endRadius: size * 0.39
        )
    }

    // MARK: - Les bras

    /// Deux bras courts, un ton plus sombre que le corps, attachés à l'épaule et tournés
    /// vers l'extérieur. Ils sont derrière le corps : l'attache ne se voit pas.
    private func arms(_ metrics: Metrics, _ expression: Expression) -> some View {
        let sway: Double = breathe ? 3 : -3
        let swing: Double = wave ? 18 : -18
        let liftBounce: Double = wave ? 6 : -6
        let rightExtra: Double = expression.waves ? swing : (mood == .celebrating ? liftBounce : 0)
        let leftExtra: Double = mood == .celebrating ? -liftBounce : 0
        let leftAngle: Double = expression.armLeft + sway + leftExtra
        let rightAngle: Double = expression.armRight + sway + rightExtra

        return ZStack {
            arm(metrics, side: -1, angle: leftAngle)
            arm(metrics, side: 1, angle: rightAngle)
        }
    }

    private func arm(_ metrics: Metrics, side: CGFloat, angle: Double) -> some View {
        let turn: Double = -Double(side) * angle
        let x: CGFloat = side * metrics.armX
        let y: CGFloat = metrics.armY + metrics.armLength / 2

        return Capsule()
            .fill(Self.bodyDeep)
            .frame(width: metrics.armWidth, height: metrics.armLength)
            .rotationEffect(.degrees(turn), anchor: .top)
            .offset(x: x, y: y)
            .animation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true), value: wave)
            .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: breathe)
    }

    // MARK: - Le visage

    private func face(_ metrics: Metrics, _ expression: Expression) -> some View {
        ZStack {
            cheeks(metrics, expression)
            eye(metrics, expression, side: -1)
            eye(metrics, expression, side: 1)
            brow(metrics, side: -1, angle: expression.browLeft, lift: expression.browLift)
            brow(metrics, side: 1, angle: expression.browRight, lift: expression.browLift)
            mouth(metrics, expression)
        }
    }

    /// Les joues : deux ronds roses dont seule l'opacité change, pour qu'elles montent
    /// et s'effacent avec l'humeur au lieu d'apparaître d'un coup.
    private func cheeks(_ metrics: Metrics, _ expression: Expression) -> some View {
        HStack(spacing: metrics.cheekX * 2 - metrics.cheek) {
            Circle().fill(Self.blush)
            Circle().fill(Self.blush)
        }
        .frame(width: metrics.cheekX * 2 + metrics.cheek, height: metrics.cheek)
        .offset(y: metrics.cheekY)
        .opacity(expression.cheeks)
    }

    /// Un œil : le blanc, l'ombre de l'arcade, l'iris et ses reflets, puis deux paupières
    /// de la couleur du corps — celle du haut qui descend (lire, cligner), celle du bas
    /// qui remonte en arc (rire). Tout est découpé à l'ellipse de l'œil.
    private func eye(_ metrics: Metrics, _ expression: Expression, side: CGFloat) -> some View {
        let lid: CGFloat = blink ? 1 : expression.lid
        let scanX: CGFloat = scan ? 0.03 : -0.03
        let lookX: CGFloat = (mood == .reading ? scanX : expression.gazeX) + drift.x
        let lookY: CGFloat = expression.gazeY + drift.y
        let pupilX: CGFloat = lookX * metrics.driftScale
        let pupilY: CGFloat = lookY * metrics.driftScale
        let irisSize: CGFloat = metrics.iris * expression.pupil
        let upperLidY: CGFloat = -metrics.eyeHeight * 1.12 + metrics.eyeHeight * lid * 1.05
        let lowerLidY: CGFloat = metrics.eyeHeight * (1.12 - 0.62 * expression.squint)

        return ZStack {
            Ellipse().fill(Color.white)

            LinearGradient(
                colors: [MicaboColor.ink.opacity(0.16), MicaboColor.ink.opacity(0)],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.5)
            )

            Circle()
                .fill(MicaboColor.ink)
                .frame(width: irisSize, height: irisSize)
                .offset(x: pupilX, y: pupilY)

            // Les reflets : c'est eux qui rendent le regard vivant.
            Circle()
                .fill(Color.white)
                .frame(width: metrics.glint, height: metrics.glint)
                .offset(x: pupilX + metrics.glintDX, y: pupilY + metrics.glintDY)

            Circle()
                .fill(Color.white.opacity(0.8))
                .frame(width: metrics.glintSmall, height: metrics.glintSmall)
                .offset(x: pupilX + metrics.glintSmallDX, y: pupilY + metrics.glintSmallDY)

            Ellipse()
                .fill(MicaboColor.accent)
                .frame(width: metrics.lidWidth, height: metrics.lidHeight)
                .offset(y: upperLidY)

            Ellipse()
                .fill(MicaboColor.accent)
                .frame(width: metrics.lidWidth, height: metrics.lidHeight)
                .offset(y: lowerLidY)
        }
        .frame(width: metrics.eyeWidth, height: metrics.eyeHeight)
        .clipShape(Ellipse())
        .offset(x: side * metrics.eyeX, y: metrics.eyeY)
        .animation(.easeInOut(duration: 0.08), value: blink)
        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: scan)
    }

    /// Un sourcil : un trait blanc atténué, dont l'angle et la hauteur font l'humeur.
    private func brow(_ metrics: Metrics, side: CGFloat, angle: Double, lift: CGFloat) -> some View {
        let y: CGFloat = metrics.eyeY + metrics.browY - metrics.browLift * lift

        return Capsule()
            .fill(Color.white.opacity(0.75))
            .frame(width: metrics.browWidth, height: metrics.browThickness)
            .rotationEffect(.degrees(angle))
            .offset(x: side * metrics.eyeX, y: y)
    }

    /// La bouche : une seule forme pour toutes les humeurs, dont la courbure et
    /// l'ouverture sont des nombres. L'intérieur sombre, la langue quand elle s'ouvre
    /// assez, et la lèvre blanche par-dessus.
    private func mouth(_ metrics: Metrics, _ expression: Expression) -> some View {
        let width: CGFloat = metrics.mouthWidth * expression.mouthWidth
        let height: CGFloat = metrics.mouthDepth * 2 + metrics.mouthOpen + metrics.lip
        // Le cadre est centré plus bas que la ligne des lèvres : il doit laisser la place
        // à une bouche qui tombe (au-dessus) comme à une bouche qui s'ouvre (en dessous).
        let y: CGFloat = metrics.mouthY + height / 2 - metrics.mouthDepth
        let tongueAlpha: Double = Double(max(0, min(1, (expression.open - 0.3) * 4)))
        let tongueSize: CGFloat = width * 0.64
        let tongueY: CGFloat = metrics.mouthDepth + (metrics.mouthDepth * expression.curve + metrics.mouthOpen * expression.open) * 0.72
        let lowerLipAlpha: Double = Double(max(0, min(1, expression.open * 6)))

        return ZStack {
            MascotMouthShape(curve: expression.curve, open: expression.open, depth: metrics.mouthDepth, reach: metrics.mouthOpen)
                .fill(Self.mouthInside)
                .overlay {
                    Circle()
                        .fill(Self.tongue)
                        .frame(width: tongueSize, height: tongueSize)
                        .position(x: width / 2, y: tongueY)
                        .opacity(tongueAlpha)
                }
                .clipShape(MascotMouthShape(curve: expression.curve, open: expression.open, depth: metrics.mouthDepth, reach: metrics.mouthOpen))

            MascotLipShape(curve: expression.curve, depth: metrics.mouthDepth, lower: false, open: expression.open, reach: metrics.mouthOpen)
                .stroke(Color.white, style: StrokeStyle(lineWidth: metrics.lip, lineCap: .round))

            MascotLipShape(curve: expression.curve, depth: metrics.mouthDepth, lower: true, open: expression.open, reach: metrics.mouthOpen)
                .stroke(Color.white, style: StrokeStyle(lineWidth: metrics.lip * 0.8, lineCap: .round))
                .opacity(lowerLipAlpha)
        }
        .frame(width: width, height: height)
        .offset(y: y)
    }

    // MARK: - Autour

    /// Trois points qui montent l'un après l'autre : elle réfléchit.
    private func thoughtDots(_ metrics: Metrics) -> some View {
        HStack(alignment: .bottom, spacing: metrics.dotGap) {
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
        let bob: CGFloat = breathe ? -metrics.breatheY * size : metrics.breatheY * size

        return MascotDropShape()
            .fill(MicaboColor.info)
            .frame(width: metrics.dropWidth, height: metrics.dropHeight)
            .offset(x: metrics.dropX, y: metrics.dropY + bob)
            .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: breathe)
    }

    /// Des étincelles à quatre branches qui battent : la fête, sans confettis.
    private var sparkles: some View {
        ZStack {
            spark(x: -0.58, y: -0.42, share: 0.26, delay: 0)
            spark(x: 0.6, y: -0.3, share: 0.2, delay: 0.25)
            spark(x: -0.5, y: 0.34, share: 0.16, delay: 0.5)
            spark(x: 0.55, y: 0.4, share: 0.22, delay: 0.7)
        }
    }

    private func spark(x: CGFloat, y: CGFloat, share: CGFloat, delay: Double) -> some View {
        let side: CGFloat = size * share
        let dx: CGFloat = x * size
        let dy: CGFloat = y * size
        let scale: CGFloat = sparkle ? 1.2 : 0.7
        let alpha: Double = sparkle ? 1 : 0.35
        let turn: Double = sparkle ? 20 : -20

        return MascotSparkShape()
            .fill(Self.sparkGold)
            .frame(width: side, height: side)
            .rotationEffect(.degrees(turn))
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

        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
            breathe = true
        }
        sparkle = true
        wave = true
        scan = true
    }

    /// Le clignement n'est pas au métronome : deux clignements à intervalle égal se
    /// remarquent, et on cesse d'y croire. Entre deux secondes et demie et quatre, et un
    /// clignement sur cinq est double.
    @MainActor
    private func blinkLoop() async {
        guard !reduceMotion else { return }
        while !Task.isCancelled {
            let pause = Double.random(in: 2.5...4.2)
            try? await Task.sleep(for: .milliseconds(Int(pause * 1000)))
            guard !Task.isCancelled else { return }
            blink = true
            try? await Task.sleep(for: .milliseconds(110))
            blink = false
            if Int.random(in: 0..<5) == 0 {
                try? await Task.sleep(for: .milliseconds(160))
                guard !Task.isCancelled else { return }
                blink = true
                try? await Task.sleep(for: .milliseconds(100))
                blink = false
            }
        }
    }

    /// De temps en temps, elle regarde ailleurs — un peu, une seconde — puis revient.
    /// C'est ce qui fait qu'elle attend plutôt qu'elle ne fixe.
    @MainActor
    private func glanceLoop() async {
        guard !reduceMotion else { return }
        while !Task.isCancelled {
            let pause = Double.random(in: 3.0...5.5)
            try? await Task.sleep(for: .milliseconds(Int(pause * 1000)))
            guard !Task.isCancelled, mood != .reading else { continue }
            drift = CGPoint(x: CGFloat.random(in: -0.028...0.028), y: CGFloat.random(in: -0.015...0.02))
            try? await Task.sleep(for: .milliseconds(Int.random(in: 700...1100)))
            drift = .zero
        }
    }
}

// MARK: - Les formes

/// Le corps : un haricot doux, un peu plus large en bas, aux épaules rondes. Cinq courbes,
/// les mêmes que sur le canevas de mise au point.
private struct MascotBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
        }

        var path = Path()
        path.move(to: point(0.5, 0))
        // L'épaule droite.
        path.addCurve(to: point(0.965, 0.32), control1: point(0.80, 0), control2: point(0.965, 0.10))
        // Le flanc droit, qui s'évase.
        path.addCurve(to: point(0.86, 0.94), control1: point(0.965, 0.52), control2: point(1.0, 0.78))
        // Le bas.
        path.addCurve(to: point(0.14, 0.94), control1: point(0.76, 1.0), control2: point(0.24, 1.0))
        // Le flanc gauche.
        path.addCurve(to: point(0.035, 0.32), control1: point(0, 0.78), control2: point(0.035, 0.52))
        // L'épaule gauche.
        path.addCurve(to: point(0.5, 0), control1: point(0.035, 0.10), control2: point(0.20, 0))
        path.closeSubpath()
        return path
    }
}

/// L'intérieur de la bouche : la lèvre haute et la lèvre basse, refermées. `curve` et
/// `open` sont animables — c'est ce qui fait passer un sourire fermé à un rire ouvert sans
/// changer de forme.
private struct MascotMouthShape: Shape {
    var curve: CGFloat
    var open: CGFloat
    let depth: CGFloat
    let reach: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(curve, open) }
        set {
            curve = newValue.first
            open = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let baseline = rect.minY + depth
        let upperControl = baseline + curve * depth * 2
        let lowerControl = upperControl + open * reach * 2
        let left = CGPoint(x: rect.minX, y: baseline)
        let right = CGPoint(x: rect.maxX, y: baseline)

        var path = Path()
        path.move(to: left)
        path.addQuadCurve(to: right, control: CGPoint(x: rect.midX, y: upperControl))
        path.addQuadCurve(to: left, control: CGPoint(x: rect.midX, y: lowerControl))
        path.closeSubpath()
        return path
    }
}

/// Une lèvre seule, pour le trait blanc : la haute, ou la basse quand la bouche est ouverte.
private struct MascotLipShape: Shape {
    var curve: CGFloat
    let depth: CGFloat
    let lower: Bool
    var open: CGFloat
    let reach: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(curve, open) }
        set {
            curve = newValue.first
            open = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let baseline = rect.minY + depth
        let upperControl = baseline + curve * depth * 2
        let control = lower ? upperControl + open * reach * 2 : upperControl

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: baseline))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: baseline), control: CGPoint(x: rect.midX, y: control))
        return path
    }
}

/// Une étincelle à quatre branches, aux flancs creusés.
private struct MascotSparkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let tips: [CGPoint] = [
            CGPoint(x: center.x, y: center.y - radius),
            CGPoint(x: center.x + radius, y: center.y),
            CGPoint(x: center.x, y: center.y + radius),
            CGPoint(x: center.x - radius, y: center.y),
        ]

        var path = Path()
        path.move(to: tips[0])
        for index in 0..<4 {
            let next = tips[(index + 1) % 4]
            path.addQuadCurve(to: next, control: center)
        }
        path.closeSubpath()
        return path
    }
}

/// Une goutte : pointue en haut, ronde en bas.
private struct MascotDropShape: Shape {
    func path(in rect: CGRect) -> Path {
        let top = CGPoint(x: rect.midX, y: rect.minY)
        let bottom = CGPoint(x: rect.midX, y: rect.maxY)
        let w = rect.width

        var path = Path()
        path.move(to: top)
        path.addCurve(
            to: bottom,
            control1: CGPoint(x: rect.midX + w * 0.55, y: rect.minY + rect.height * 0.55),
            control2: CGPoint(x: rect.midX + w * 0.5, y: rect.maxY)
        )
        path.addCurve(
            to: top,
            control1: CGPoint(x: rect.midX - w * 0.5, y: rect.maxY),
            control2: CGPoint(x: rect.midX - w * 0.55, y: rect.minY + rect.height * 0.55)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Le petit saut

/// **La mascotte sursaute quand quelque chose change.**
///
/// Un nouvel écran, une réponse donnée : elle s'accroupit, saute, retombe et rebondit.
/// C'est une compression puis un étirement, comme un corps mou — pas un simple
/// agrandissement. Une mascotte posée dans un coin qui ne bronche pas quand on lui répond
/// n'écoute pas.
private struct MascotHop<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase: CaseIterable {
        case rest
        case crouch
        case jump
        case land

        var scaleX: CGFloat {
            switch self {
            case .rest: 1
            case .crouch: 1.08
            case .jump: 0.94
            case .land: 1.06
            }
        }

        var scaleY: CGFloat {
            switch self {
            case .rest: 1
            case .crouch: 0.88
            case .jump: 1.1
            case .land: 0.93
            }
        }

        var lift: CGFloat {
            switch self {
            case .rest, .crouch, .land: 0
            case .jump: -12
            }
        }

        var animation: Animation {
            switch self {
            case .crouch: .easeIn(duration: 0.09)
            case .jump: .spring(response: 0.24, dampingFraction: 0.7)
            case .land: .easeOut(duration: 0.1)
            case .rest: .spring(response: 0.32, dampingFraction: 0.55)
            }
        }
    }

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.phaseAnimator(Phase.allCases, trigger: trigger) { view, phase in
                view
                    .scaleEffect(x: phase.scaleX, y: phase.scaleY, anchor: .bottom)
                    .offset(y: phase.lift)
            } animation: { phase in
                phase.animation
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
