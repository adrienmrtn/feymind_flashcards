import SwiftUI

/// **Une vraie page de cours, prise au téléphone** (retour testeur du build 179 : « une vraie
/// photo de fausses notes »).
///
/// Une page de cahier à petits carreaux, la marge rouge, écrite au stylo bille d'une main
/// d'élève : le titre souligné, le triangle rectangle et ses côtés, la formule encadrée au
/// surligneur, un essai raté barré (« 3 + 4 = 7 »), puis le bon calcul. Un peu de travers,
/// avec l'ombre et la lumière d'une photo prise sur une table.
///
/// **Des maths, pour valoir dans toutes les langues** : seul le titre se traduit, le reste
/// s'écrit pareil partout (et toujours de gauche à droite). Rien n'est une image : tout est
/// dessiné ici, en vectoriel, avec une écriture manuscrite du système (`Noteworthy`), donc
/// net à toutes les tailles, et sans poids pour l'app.
///
/// La leçon qui en sort (`NotebookLesson`) reprend **ce qui est écrit sur la page** : la
/// règle, un exercice, une carte.
struct NotebookPhoto: View {
    /// La hauteur de la page ; sa largeur suit (un format de cahier).
    var height: CGFloat = 300

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// La largeur sur la hauteur d'une page de cahier.
    static let ratio: CGFloat = 0.78
    /// L'inclinaison de la photo.
    static let tilt: Double = -3.2

    /// L'encre d'un stylo bille bleu, et celle du stylo rouge du prof (ou de l'élève qui
    /// corrige).
    static let ink = Color(red: 0.13, green: 0.20, blue: 0.52)
    static let red = Color(red: 0.80, green: 0.16, blue: 0.20)
    static let paper = Color(red: 0.98, green: 0.97, blue: 0.93)
    static let grid = Color(red: 0.55, green: 0.68, blue: 0.86).opacity(0.38)
    static let highlighter = Color(red: 1.0, green: 0.90, blue: 0.25).opacity(0.65)

    private var unit: CGFloat { height / 300 }

    private func hand(_ size: CGFloat) -> Font {
        .custom("Noteworthy-Bold", size: size * unit)
    }

    var body: some View {
        page
            .frame(width: height * Self.ratio, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 4 * unit, style: .continuous))
            .overlay {
                // La lumière d'une photo prise sous une lampe : plus claire en haut à gauche,
                // un peu d'ombre en bas à droite.
                LinearGradient(
                    colors: [.white.opacity(0.18), .clear, .black.opacity(0.14)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 4 * unit, style: .continuous))
                .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.35), radius: 12 * unit, x: 0, y: 8 * unit)
            .rotationEffect(.degrees(Self.tilt))
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(i18n.t("ios.onb12.notebook.title")))
    }

    private var page: some View {
        ZStack(alignment: .topLeading) {
            Self.paper
            Canvas { context, size in
                let step = 12 * unit
                var lines = Path()
                var x: CGFloat = 0
                while x <= size.width {
                    lines.move(to: CGPoint(x: x, y: 0))
                    lines.addLine(to: CGPoint(x: x, y: size.height))
                    x += step
                }
                var y: CGFloat = 0
                while y <= size.height {
                    lines.move(to: CGPoint(x: 0, y: y))
                    lines.addLine(to: CGPoint(x: size.width, y: y))
                    y += step
                }
                context.stroke(lines, with: .color(Self.grid), lineWidth: 0.6 * unit)
                // La marge rouge.
                var margin = Path()
                margin.move(to: CGPoint(x: 30 * unit, y: 0))
                margin.addLine(to: CGPoint(x: 30 * unit, y: size.height))
                context.stroke(margin, with: .color(Self.red.opacity(0.55)), lineWidth: 1.1 * unit)
            }

            VStack(alignment: .leading, spacing: 0) {
                // Le titre, souligné deux fois d'un trait qui tremble un peu.
                Text(i18n.t("ios.onb12.notebook.title"))
                    .font(hand(19))
                    .foregroundStyle(Self.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                NotebookUnderline()
                    .stroke(Self.red, style: StrokeStyle(lineWidth: 1.6 * unit, lineCap: .round))
                    .frame(width: 120 * unit, height: 6 * unit)
                    .padding(.top, 1 * unit)

                HStack(alignment: .center, spacing: 14 * unit) {
                    NotebookTriangle(unit: unit)
                        .frame(width: 92 * unit, height: 74 * unit)
                    // La formule, encadrée et passée au surligneur.
                    Text(verbatim: "a² + b² = c²")
                        .font(hand(18))
                        .foregroundStyle(Self.ink)
                        .padding(.horizontal, 6 * unit)
                        .padding(.vertical, 3 * unit)
                        .background { Self.highlighter.rotationEffect(.degrees(-1.5)) }
                        .overlay {
                            RoundedRectangle(cornerRadius: 3 * unit)
                                .stroke(Self.red, lineWidth: 1.4 * unit)
                                .rotationEffect(.degrees(1))
                        }
                        .fixedSize()
                }
                .padding(.top, 14 * unit)

                // Un premier essai, raté, barré.
                Text(verbatim: "3 + 4 = 7")
                    .font(hand(15))
                    .foregroundStyle(Self.ink.opacity(0.75))
                    .overlay {
                        NotebookScribble()
                            .stroke(Self.ink, style: StrokeStyle(lineWidth: 1.3 * unit, lineCap: .round, lineJoin: .round))
                    }
                    .fixedSize()
                    .padding(.top, 12 * unit)

                Text(verbatim: "3² + 4² = 5²")
                    .font(hand(16))
                    .foregroundStyle(Self.ink)
                    .fixedSize()
                    .padding(.top, 6 * unit)
                HStack(spacing: 6 * unit) {
                    Text(verbatim: "9 + 16 = 25")
                        .font(hand(16))
                        .foregroundStyle(Self.ink)
                    Text(verbatim: "✓")
                        .font(hand(18))
                        .foregroundStyle(Self.red)
                }
                .fixedSize()
                .padding(.top, 2 * unit)
            }
            .padding(.leading, 38 * unit)
            .padding(.trailing, 10 * unit)
            .padding(.top, 16 * unit)
        }
    }
}

/// Le triangle rectangle, au stylo : ses trois côtés, l'angle droit, et leurs noms.
private struct NotebookTriangle: View {
    let unit: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, size in
                let left = CGPoint(x: 8 * unit, y: size.height - 10 * unit)
                let right = CGPoint(x: size.width - 10 * unit, y: size.height - 10 * unit)
                let top = CGPoint(x: 8 * unit, y: 6 * unit)
                var sides = Path()
                sides.move(to: top)
                sides.addLine(to: left)
                sides.addLine(to: right)
                sides.addLine(to: CGPoint(x: top.x + 1 * unit, y: top.y + 1 * unit))
                context.stroke(sides, with: .color(NotebookPhoto.ink), style: StrokeStyle(lineWidth: 1.5 * unit, lineCap: .round, lineJoin: .round))
                // L'angle droit.
                let mark = 9 * unit
                var square = Path()
                square.move(to: CGPoint(x: left.x, y: left.y - mark))
                square.addLine(to: CGPoint(x: left.x + mark, y: left.y - mark))
                square.addLine(to: CGPoint(x: left.x + mark, y: left.y))
                context.stroke(square, with: .color(NotebookPhoto.ink), lineWidth: 1.1 * unit)
            }
            label("a", x: -2, y: 26)
            label("b", x: 36, y: 62)
            label("c", x: 46, y: 18, color: NotebookPhoto.red)
        }
    }

    private func label(_ text: String, x: CGFloat, y: CGFloat, color: Color = NotebookPhoto.ink) -> some View {
        Text(verbatim: text)
            .font(.custom("Noteworthy-Bold", size: 15 * unit))
            .foregroundStyle(color)
            .offset(x: x * unit, y: y * unit)
    }
}

/// Un trait de soulignement tracé à la main : il ondule à peine.
private struct NotebookUnderline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY - 1),
            control1: CGPoint(x: rect.width * 0.3, y: rect.midY + 2),
            control2: CGPoint(x: rect.width * 0.7, y: rect.midY - 2)
        )
        return path
    }
}

/// La rature d'un calcul faux : un zigzag serré par-dessus.
private struct NotebookScribble: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 7
        path.move(to: CGPoint(x: rect.minX - 2, y: rect.midY + 2))
        for index in 1 ... steps {
            let x = rect.minX + rect.width * CGFloat(index) / CGFloat(steps)
            let y = index.isMultiple(of: 2) ? rect.midY + 3 : rect.midY - 3
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}

// MARK: - La leçon qui en sort

/// **La leçon tirée de la page photographiée** : son titre, et ce qui est vraiment écrit sur
/// la page, devenu une note, une question de quiz et une carte.
struct NotebookLesson: View {
    var compact = false

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnbPanel(padding: compact ? 14 : 18) {
            Text(i18n.t("ios.onb12.notebook.title"))
                .font(V3Font.heading(compact ? 22 : 26))
                .foregroundStyle(V3Color.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            row(.notes, label: i18n.t("lesson.nav.notes"), text: i18n.t("ios.onb12.notebook.note"), tone: V3Color.iconBlue)
            row(.quiz, label: i18n.t("lesson.nav.quiz"), text: i18n.t("ios.onb12.notebook.quiz"), tone: V3Color.iconPink)
            row(.cards, label: i18n.t("lesson.nav.flashcards"), text: i18n.t("ios.onb12.notebook.card"), tone: V3Color.iconGreen)
        }
    }

    private func row(_ icon: MicaboIcon, label: String, text: String, tone: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            MicaboIconView(icon: icon, size: 22 * 1.35, tint: tone)
                .frame(width: 36, height: 36)
                .background(V3Color.wash(of: tone), in: RoundedRectangle(cornerRadius: V3Metric.radiusTile, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(V3Font.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(tone)
                Text(text)
                    .font(V3Font.support)
                    .foregroundStyle(V3Color.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
