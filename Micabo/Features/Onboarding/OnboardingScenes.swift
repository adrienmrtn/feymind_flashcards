import SwiftUI

/// **Les visuels des écrans de démonstration.**
///
/// Ce fichier a porté des tuiles pastel à emoji qui respiraient, et un calendrier de mars
/// avec trois contrôles inventés. Ils sont partis, et ce n'est pas une question de goût :
/// la mesure montrait ces écrans passés en une seconde. Une grille de quatre emojis se lit
/// comme une décoration, et une décoration ne s'arrête pas.
///
/// Ce qui est là maintenant est **ce que l'app produit** : une fiche telle qu'elle l'écrit,
/// avec sa phrase surlignée, son encadré et son graphe, dans la matière que l'élève vient
/// de cocher ; et une carte de révision qu'il retourne lui-même. Rien ne flotte, rien ne
/// respire : les blocs se posent l'un après l'autre, comme une page qui s'écrit, puis la
/// page tient.

// MARK: - La fiche

/// **Une fiche telle que Micabo l'écrit**, qui se compose bloc après bloc.
///
/// Le document d'origine d'abord — son nom de fichier, et la flèche vers la fiche —, puis
/// le chapitre, le titre, un paragraphe dont une phrase est surlignée, l'encadré à retenir,
/// la formule quand il y en a une, et le graphe qui se trace en dernier. Six blocs, dans
/// l'ordre où l'œil les lit.
///
/// `revealed` est le nombre de blocs déjà posés : c'est l'écran qui décide du rythme, la
/// fiche ne fait que se dessiner. Elle ne recommence pas : une page qui s'efface et se
/// réécrit toutes les quatre secondes est un économiseur d'écran, pas un résultat.
struct OnboardingSheetCard: View {
    let sheet: DemoSheet
    /// Le nombre de blocs déjà posés, de 0 à `blockCount`.
    let revealed: Int

    static let blockCount = 6

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// Vrai une fois le dernier bloc posé : le graphe se trace alors.
    private var isDrawn: Bool { revealed >= Self.blockCount }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sourceRow
                .onboardingReveal(0, of: revealed)

            VStack(alignment: .leading, spacing: 6) {
                eyebrow
                title
            }
            .onboardingReveal(1, of: revealed)

            paragraph
                .onboardingReveal(2, of: revealed)

            keyBox
                .onboardingReveal(3, of: revealed)

            if let formula = sheet.formula {
                formulaBlock(formula)
                    .onboardingReveal(4, of: revealed)
            }

            chart
                .onboardingReveal(5, of: revealed)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .shadow(color: MicaboColor.ink.opacity(0.06), radius: 18, y: 8)
        .accessibilityElement(children: .combine)
    }

    // MARK: Les blocs

    /// Le document déposé, et ce qu'il devient : c'est la transformation que l'écran vend,
    /// dite en une ligne au-dessus du résultat.
    private var sourceRow: some View {
        HStack(spacing: 8) {
            chip(systemImage: "doc.text", text: sheet.sourceFile, tint: MicaboColor.inkSecondary, fill: MicaboColor.surfaceMuted)

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(MicaboColor.inkTertiary)

            chip(systemImage: "sparkles", text: i18n.t("ios.demo.sheet.result"), tint: MicaboColor.accent, fill: MicaboColor.accentWash)

            Spacer(minLength: 0)
        }
    }

    private func chip(systemImage: String, text: String, tint: Color, fill: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 10.5, weight: .semibold))
            Text(text)
                .font(MicaboFont.ui(11.5, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.vertical, 5)
        .padding(.horizontal, 9)
        .background(fill, in: Capsule())
    }

    private var eyebrow: some View {
        Text(i18n.t("ios.demo.sheet.eyebrow", ["n": "\(sheet.chapter)", "cards": "\(sheet.cards)"]).uppercased())
            .font(MicaboFont.ui(10.5, weight: .bold))
            .tracking(1.3)
            .foregroundStyle(MicaboColor.accent)
    }

    private var title: some View {
        Text(sheet.title)
            .font(MicaboFont.ui(20, weight: .bold))
            .tracking(-0.4)
            .foregroundStyle(MicaboColor.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Le paragraphe, avec sa phrase au surligneur : c'est le geste de l'app — un passage
    /// qu'on a marqué parce qu'il compte.
    private var paragraph: some View {
        var text = AttributedString(sheet.lead)
        var mark = AttributedString(sheet.mark)
        mark.backgroundColor = MicaboColor.sheetMarker
        text += mark

        return Text(text)
            .font(MicaboFont.reading(14.5, weight: .regular))
            .foregroundStyle(MicaboColor.inkReading)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var keyBox: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(sheet.keyLabel.uppercased())
                .font(MicaboFont.ui(10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(MicaboColor.accent)

            Text(sheet.key)
                .font(MicaboFont.reading(13.5, weight: .regular))
                .foregroundStyle(MicaboColor.inkSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
    }

    /// La formule, composée en vraie notation, sur son lavis.
    private func formulaBlock(_ source: String) -> some View {
        FormulaText(source: source, size: 18, weight: .medium, alignment: .center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(MicaboColor.accentWash, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var chart: some View {
        switch sheet.chart {
        case .timeline(let chartTitle, let marks):
            VStack(alignment: .leading, spacing: 10) {
                DemoChartTitle(text: chartTitle)
                DemoTimelineChart(marks: marks, isDrawn: isDrawn)
            }
        case .curve(let chartTitle):
            VStack(alignment: .leading, spacing: 8) {
                DemoChartTitle(text: chartTitle)
                DemoCurveChart(isDrawn: isDrawn)
            }
        case .bars(let chartTitle, let bars):
            VStack(alignment: .leading, spacing: 8) {
                DemoChartTitle(text: chartTitle)
                DemoBarsChart(bars: bars, isDrawn: isDrawn)
            }
        }
    }
}

private struct DemoChartTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(MicaboFont.ui(12, weight: .semibold))
            .foregroundStyle(MicaboColor.inkSecondary)
    }
}

// MARK: - Les graphes

/// Des repères sur une ligne du temps. La ligne se remplit de gauche à droite, et chaque
/// repère se pose au moment où elle l'atteint.
private struct DemoTimelineChart: View {
    let marks: [DemoChartMark]
    let isDrawn: Bool

    var body: some View {
        GeometryReader { proxy in
            let width: CGFloat = proxy.size.width
            let drawn: CGFloat = isDrawn ? width : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(MicaboColor.stroke)
                    .frame(height: 3)

                Capsule()
                    .fill(MicaboColor.accent)
                    .frame(width: drawn, height: 3)
                    .animation(.easeOut(duration: 0.7), value: isDrawn)

                ForEach(Array(marks.enumerated()), id: \.offset) { _, mark in
                    landmark(mark, x: CGFloat(mark.value) * width)
                }
            }
            .frame(height: 3)
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 50)
    }

    private func landmark(_ mark: DemoChartMark, x: CGFloat) -> some View {
        let delay: Double = 0.1 + mark.value * 0.6
        let scale: CGFloat = isDrawn ? 1 : 0.2
        let alpha: Double = isDrawn ? 1 : 0

        return VStack(spacing: 4) {
            Text(mark.label)
                .font(MicaboFont.ui(10.5, weight: .bold))
                .foregroundStyle(MicaboColor.ink)

            Circle()
                .fill(MicaboColor.accent)
                .frame(width: 10, height: 10)
                .overlay { Circle().strokeBorder(MicaboColor.canvas, lineWidth: 2) }

            Text(mark.caption)
                .font(MicaboFont.ui(10, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)
                .lineLimit(1)
        }
        .fixedSize()
        .scaleEffect(scale)
        .opacity(alpha)
        .animation(.easeOut(duration: 0.3).delay(delay), value: isDrawn)
        .position(x: x, y: 1.5)
    }
}

/// La suite géométrique pour q = 1,5, de u₀ à u₆, ramenée à la hauteur du cadre : elle se
/// trace de gauche à droite, puis ses points se posent.
private struct DemoCurveChart: View {
    let isDrawn: Bool

    private static let ratio: CGFloat = 1.5
    private static let terms = 7

    var body: some View {
        GeometryReader { proxy in
            let points = Self.points(in: proxy.size)
            let trim: CGFloat = isDrawn ? 1 : 0

            ZStack(alignment: .bottomLeading) {
                Rectangle()
                    .fill(MicaboColor.stroke)
                    .frame(height: 1)

                DemoPolyline(points: points)
                    .trim(from: 0, to: trim)
                    .stroke(MicaboColor.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .animation(.easeInOut(duration: 0.8), value: isDrawn)

                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    dot(index: index, at: point)
                }
            }
        }
        .frame(height: 78)
    }

    private func dot(index: Int, at point: CGPoint) -> some View {
        let delay: Double = 0.08 + Double(index) / Double(Self.terms - 1) * 0.7
        let scale: CGFloat = isDrawn ? 1 : 0.2
        let alpha: Double = isDrawn ? 1 : 0

        return Circle()
            .fill(MicaboColor.accent)
            .frame(width: 8, height: 8)
            .overlay { Circle().strokeBorder(MicaboColor.canvas, lineWidth: 1.5) }
            .scaleEffect(scale)
            .opacity(alpha)
            .animation(.easeOut(duration: 0.25).delay(delay), value: isDrawn)
            .position(point)
    }

    private static func points(in size: CGSize) -> [CGPoint] {
        let top: CGFloat = pow(ratio, CGFloat(terms - 1))
        let inset: CGFloat = 6
        return (0..<terms).map { index in
            let x: CGFloat = inset + (size.width - inset * 2) * CGFloat(index) / CGFloat(terms - 1)
            let value: CGFloat = pow(ratio, CGFloat(index)) / top
            let y: CGFloat = size.height - inset - (size.height - inset * 2) * value
            return CGPoint(x: x, y: y)
        }
    }
}

/// La ligne brisée qui passe par les points de la suite.
private struct DemoPolyline: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}

/// Des barres qui montent l'une après l'autre, chacune avec sa valeur en dessous.
private struct DemoBarsChart: View {
    let bars: [DemoChartMark]
    let isDrawn: Bool

    private static let height: CGFloat = 74

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(bars.enumerated()), id: \.offset) { index, bar in
                column(bar, index: index)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func column(_ bar: DemoChartMark, index: Int) -> some View {
        let height: CGFloat = isDrawn ? max(3, Self.height * CGFloat(bar.value)) : 3
        let delay: Double = 0.05 + Double(index) * 0.09

        return VStack(spacing: 6) {
            Text(bar.caption)
                .font(MicaboFont.ui(9.5, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)
                .lineLimit(1)
                .opacity(bar.caption.isEmpty ? 0 : 1)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(MicaboColor.accentWash)
                    .frame(height: Self.height)

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(MicaboColor.accent)
                    .frame(height: height)
                    .animation(.easeOut(duration: 0.55).delay(delay), value: isDrawn)
            }

            Text(bar.label)
                .font(MicaboFont.ui(10, weight: .semibold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - La carte qu'on retourne

/// **Une carte de révision, et c'est l'élève qui la retourne.**
///
/// La question au recto, la réponse au verso, exactement comme dans une session : même
/// surface, même rayon, même ombre que `StudyCardFace`. La différence est qu'ici rien ne
/// se passe tant qu'on n'a pas touché la carte — le bouton n'arrive qu'après. Une
/// démonstration qu'on regarde se passe en une seconde ; une démonstration qu'on fait
/// prend le temps qu'il faut.
struct OnboardingDemoFlashcardView: View {
    let card: DemoFlashcard
    let isFlipped: Bool
    var onFlip: () -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        ZStack {
            face(isBack: false)
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.6)

            face(isBack: true)
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        }
        // Une courbe monotone, comme le reste du parcours : la carte tourne et s'arrête,
        // elle ne rebondit pas sur sa charnière.
        .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.5), value: isFlipped)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isFlipped else { return }
            Haptics.medium()
            onFlip()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isFlipped ? card.back : card.front)
        .accessibilityHint(isFlipped ? "" : i18n.t("ios.demo.card.tap"))
        .accessibilityAddTraits(.isButton)
    }

    private func face(isBack: Bool) -> some View {
        VStack(alignment: isBack ? .leading : .center, spacing: 14) {
            Text(i18n.t(isBack ? "ios.demo.card.answer" : "ios.demo.card.question").uppercased())
                .font(MicaboFont.ui(11, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(MicaboColor.accent)

            if isBack {
                Text(card.front)
                    .font(MicaboFont.ui(16, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)

                MicaboHairline()

                Text(card.back)
                    .font(MicaboFont.reading(15, weight: .regular))
                    .foregroundStyle(MicaboColor.inkBody)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)

                Text(card.front)
                    .font(MicaboFont.ui(21, weight: .bold))
                    .tracking(-0.4)
                    .foregroundStyle(MicaboColor.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 12, weight: .semibold))
                    Text(i18n.t("ios.demo.card.tap"))
                        .font(MicaboFont.ui(12.5, weight: .semibold))
                }
                .foregroundStyle(MicaboColor.inkTertiary)
            }
        }
        .padding(26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isBack ? .topLeading : .center)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.xxl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.xxl, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .shadow(color: MicaboColor.ink.opacity(0.06), radius: 18, y: 8)
    }
}

// MARK: - L'entrée d'un bloc

/// Un bloc de la fiche : posé quand son rang est atteint, sinon invisible et un peu plus
/// bas. La même entrée que le reste du parcours.
private struct OnboardingReveal: ViewModifier {
    let index: Int
    let revealed: Int

    func body(content: Content) -> some View {
        let isShown = index < revealed

        return content
            .opacity(isShown ? 1 : 0)
            .offset(y: isShown ? 0 : 10)
    }
}

extension View {
    func onboardingReveal(_ index: Int, of revealed: Int) -> some View {
        modifier(OnboardingReveal(index: index, revealed: revealed))
    }
}
