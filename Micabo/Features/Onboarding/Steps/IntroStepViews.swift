import SwiftUI

// MARK: - Les cinq écrans d'ouverture
//
// Ils remplacent onze écrans qui racontaient une méthode — la courbe de l'oubli, la
// répétition espacée, Feynman, la préparation d'une épreuve — avant d'avoir montré une
// seule fois ce que l'app fait. Ceux-ci décrivent le parcours réel, dans l'ordre où on le
// vivra : tu déposes tes cours, tu poses les dates de tes examens, ça devient un cours
// fiché, et voilà ce qu'il y a autour pour le retenir.
//
// Chacun porte une seule phrase et une seule image. **La phrase dit la chose entière.**
// « Tu poses tes dates » laissait deviner de quelles dates on parle ; « Pose les dates de
// tes examens » ne laisse rien deviner. Un écran d'ouverture se traverse en deux secondes :
// une phrase qu'il faut compléter de tête y est perdue. Les titres s'écrivent d'un bloc,
// sans animation mot à mot : celle-là est réservée aux questions.
//
// Le premier des cinq, l'accroche, vit dans `WelcomeStepView` : il porte la mascotte, ses
// decks, et la sortie « j'ai déjà un compte », qui n'a sa place qu'au tout début.

/// « Dépose tes cours : PDF, photos, Word, vidéos. »
///
/// Quatre tuiles, comme la grille des decks : un PDF, des photos, un Word, une vidéo. On
/// les lit en une seconde parce qu'elles sont posées comme quatre objets, et elles entrent
/// l'une après l'autre.
struct UploadStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private static let formats: [(emoji: String, key: String)] = [
        ("📄", "ios.intro.format.pdf"),
        ("📸", "ios.intro.format.photo"),
        ("📝", "ios.intro.format.word"),
        ("🎬", "ios.intro.format.video"),
    ]

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.intro.upload"),
            expandsContent: true
        ) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                LazyVGrid(columns: OnboardingScene.columns, spacing: 12) {
                    ForEach(Array(Self.formats.enumerated()), id: \.offset) { index, format in
                        OnboardingTile(
                            emoji: format.emoji,
                            title: i18n.t(format.key),
                            pastel: MicaboColor.pastel(at: index),
                            rank: index
                        )
                    }
                }

                Spacer(minLength: 0)
            }
        } footer: {
            OnboardingContinueButton { model.advance() }
        }
    }
}

/// « Pose les dates de tes examens. »
///
/// Un calendrier, la date de l'épreuve en violet, la pastille du compte à rebours : ce que
/// l'app montre vraiment, et rien d'autre.
struct DatesStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.intro.dates"),
            expandsContent: true
        ) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                OnboardingCalendarScene()
                    .onboardingAppear(index: 3)
                Spacer(minLength: 0)
            }
        } footer: {
            OnboardingContinueButton { model.advance() }
        }
    }
}

/// « Micabo en fait un cours fiché, chapitre par chapitre. »
///
/// **Une vraie page de cours, pas un plan.** L'écran montrait quatre lignes de chapitres
/// avec des pourcentages qui montaient : c'était un tableau de bord, et personne ne rêve
/// devant un tableau de bord. Ce qu'on vend ici, c'est la fiche elle-même — un chapitre
/// d'histoire avec sa phrase surlignée, son encadré « à retenir » et sa frise ; puis un
/// chapitre de maths avec sa formule composée et sa courbe. Ce sont des pages telles que
/// l'app les écrit, qui se composent sous les yeux, bloc après bloc.
struct TurnsIntoStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.intro.turnsInto"),
            expandsContent: true
        ) {
            VStack(spacing: MicaboSpacing.md) {
                Spacer(minLength: 0)
                IntroSheetPreview()
                Spacer(minLength: 0)
            }
        } footer: {
            OnboardingContinueButton { model.advance() }
        }
    }
}

/// « Et tout ce qu'il faut pour le retenir. »
///
/// Quatre façons d'apprendre, toutes disponibles. **La méthode Feynman a pris la place du
/// mode audio** : expliquer un chapitre avec ses mots est la seule des quatre qui marche
/// sans écran, et elle existe — là où le mode audio était annoncé avec un « bientôt », et
/// un « bientôt » sur le quatrième écran d'une app est une promesse qu'on n'a pas encore
/// gagné le droit de faire.
struct SmartFeaturesStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private static let features: [(emoji: String, key: String)] = [
        ("🗣️", "ios.intro.feature.feynman"),
        ("📝", "ios.intro.feature.mock"),
        ("🔘", "ios.intro.feature.quiz"),
        ("💡", "ios.intro.feature.explain"),
    ]

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.intro.features"),
            expandsContent: true
        ) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                LazyVGrid(columns: OnboardingScene.columns, spacing: 12) {
                    ForEach(Array(Self.features.enumerated()), id: \.offset) { index, feature in
                        OnboardingTile(
                            emoji: feature.emoji,
                            title: i18n.t(feature.key),
                            pastel: MicaboColor.pastel(at: index + 1),
                            rank: index
                        )
                    }
                }

                Spacer(minLength: 0)
            }
        } footer: {
            OnboardingContinueButton(title: i18n.t("ios.intro.setup"), isShiny: true) {
                model.advance()
            }
        }
    }
}

// MARK: - La fiche d'exemple

/// **Deux chapitres tels que Micabo les écrit**, qui se composent bloc après bloc.
///
/// Histoire d'abord : le sur-titre du chapitre, son titre, un paragraphe dont une phrase
/// est surlignée, l'encadré « à retenir », et une frise qui se trace. Puis maths : la même
/// page, avec une formule composée en vraie notation et la courbe de la suite qui se
/// dessine. Le premier dit « ça lit ton cours », le second dit « même en maths ».
///
/// Les blocs arrivent l'un après l'autre, comme une page qu'on écrit, puis la page tient
/// quelques secondes, s'efface, et la suivante commence. Sans mouvement réduit, tout est
/// posé d'un coup.
private struct IntroSheetPreview: View {
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// La page affichée : 0 l'histoire, 1 les maths.
    @State private var example = 0
    /// Le nombre de blocs déjà posés sur la page.
    @State private var revealed = 0

    private static let blockCount = 5
    /// Le jaune du surligneur de la maquette.
    private static let marker = Color(hex: 0xFFF0A6)

    var body: some View {
        ZStack {
            if example == 0 {
                historyPage
                    .transition(.opacity)
            } else {
                mathsPage
                    .transition(.opacity)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .shadow(color: MicaboColor.ink.opacity(0.06), radius: 18, y: 8)
        .animation(.easeInOut(duration: 0.35), value: example)
        .accessibilityHidden(true)
        .task { await cycle() }
    }

    // MARK: Les pages

    private var historyPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            eyebrow(i18n.t("ios.intro.sheet.eyebrow"))
                .reveal(0, of: revealed)
            title(i18n.t("ios.intro.sheet.title"))
                .reveal(1, of: revealed)
            paragraph(lead: i18n.t("ios.intro.sheet.lead"), marked: i18n.t("ios.intro.sheet.mark"))
                .reveal(2, of: revealed)
            keyBox(i18n.t("ios.intro.sheet.key"))
                .reveal(3, of: revealed)
            timeline
                .reveal(4, of: revealed)
        }
    }

    private var mathsPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            eyebrow(i18n.t("ios.intro.sheet2.eyebrow"))
                .reveal(0, of: revealed)
            title(i18n.t("ios.intro.sheet2.title"))
                .reveal(1, of: revealed)
            paragraph(lead: i18n.t("ios.intro.sheet2.lead"), marked: i18n.t("ios.intro.sheet2.mark"))
                .reveal(2, of: revealed)
            formula
                .reveal(3, of: revealed)
            curve
                .reveal(4, of: revealed)
        }
    }

    // MARK: Les blocs

    private func eyebrow(_ text: String) -> some View {
        Text(text)
            .font(MicaboFont.ui(10.5, weight: .bold))
            .tracking(1.3)
            .foregroundStyle(MicaboColor.accent)
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .font(MicaboFont.ui(20, weight: .bold))
            .tracking(-0.4)
            .foregroundStyle(MicaboColor.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Le paragraphe, avec sa phrase au surligneur : c'est le geste de l'app — un passage
    /// qu'on a marqué parce qu'il compte.
    private func paragraph(lead: String, marked: String) -> some View {
        var text = AttributedString(lead)
        var mark = AttributedString(marked)
        mark.backgroundColor = Self.marker
        text += mark

        return Text(text)
            .font(MicaboFont.reading(14.5, weight: .regular))
            .foregroundStyle(MicaboColor.inkReading)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func keyBox(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(i18n.t("ios.intro.sheet.keyLabel"))
                .font(MicaboFont.ui(10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(MicaboColor.accent)

            Text(text)
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
    private var formula: some View {
        FormulaText(source: "$u_n = u_0 \\times q^{n}$", size: 18, weight: .medium, alignment: .center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(MicaboColor.accentWash, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: La frise

    private struct Landmark {
        let year: String
        let key: String
        let position: CGFloat
    }

    private static let landmarks: [Landmark] = [
        Landmark(year: "1947", key: "ios.intro.sheet.t1", position: 0.06),
        Landmark(year: "1949", key: "ios.intro.sheet.t2", position: 0.3),
        Landmark(year: "1962", key: "ios.intro.sheet.t3", position: 0.62),
        Landmark(year: "1989", key: "ios.intro.sheet.t4", position: 0.94),
    ]

    /// Vrai une fois le dernier bloc posé : la frise et la courbe se tracent alors.
    private var isDrawn: Bool { revealed >= Self.blockCount }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            chartTitle(i18n.t("ios.intro.sheet.chart"))

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
                        .animation(.easeOut(duration: 1.1), value: isDrawn)

                    ForEach(Array(Self.landmarks.enumerated()), id: \.offset) { index, landmark in
                        landmarkMark(landmark, index: index, x: landmark.position * width)
                    }
                }
                .frame(height: 3)
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 50)
        }
    }

    private func landmarkMark(_ landmark: Landmark, index: Int, x: CGFloat) -> some View {
        let delay: Double = 0.15 + Double(landmark.position) * 1.0
        let scale: CGFloat = isDrawn ? 1 : 0.2
        let alpha: Double = isDrawn ? 1 : 0

        return VStack(spacing: 4) {
            Text(landmark.year)
                .font(MicaboFont.ui(10.5, weight: .bold))
                .foregroundStyle(MicaboColor.ink)

            Circle()
                .fill(MicaboColor.accent)
                .frame(width: 10, height: 10)
                .overlay { Circle().strokeBorder(MicaboColor.canvas, lineWidth: 2) }

            Text(i18n.t(landmark.key))
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

    // MARK: La courbe

    /// La suite pour q = 1,5, de u₀ à u₆, ramenée à la hauteur du cadre : elle se trace de
    /// gauche à droite, puis ses points se posent.
    private static let ratio: CGFloat = 1.5
    private static let terms = 7

    private var curve: some View {
        VStack(alignment: .leading, spacing: 8) {
            chartTitle(i18n.t("ios.intro.sheet2.chart"))

            GeometryReader { proxy in
                let points = Self.curvePoints(in: proxy.size)
                let trim: CGFloat = isDrawn ? 1 : 0

                ZStack(alignment: .bottomLeading) {
                    Rectangle()
                        .fill(MicaboColor.stroke)
                        .frame(height: 1)

                    IntroCurveShape(points: points)
                        .trim(from: 0, to: trim)
                        .stroke(MicaboColor.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .animation(.easeInOut(duration: 1.2), value: isDrawn)

                    ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                        curveDot(index: index, at: point)
                    }
                }
            }
            .frame(height: 78)
        }
    }

    private func curveDot(index: Int, at point: CGPoint) -> some View {
        let delay: Double = 0.1 + Double(index) / Double(Self.terms - 1) * 1.1
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

    private static func curvePoints(in size: CGSize) -> [CGPoint] {
        let top: CGFloat = pow(ratio, CGFloat(terms - 1))
        let inset: CGFloat = 6
        return (0..<terms).map { index in
            let x: CGFloat = inset + (size.width - inset * 2) * CGFloat(index) / CGFloat(terms - 1)
            let value: CGFloat = pow(ratio, CGFloat(index)) / top
            let y: CGFloat = size.height - inset - (size.height - inset * 2) * value
            return CGPoint(x: x, y: y)
        }
    }

    private func chartTitle(_ text: String) -> some View {
        Text(text)
            .font(MicaboFont.ui(12, weight: .semibold))
            .foregroundStyle(MicaboColor.inkSecondary)
    }

    // MARK: Le déroulé

    /// Dans `.task` : annulé avec la vue, pas une boucle qui lui survit.
    @MainActor
    private func cycle() async {
        guard !reduceMotion else {
            revealed = Self.blockCount
            return
        }
        try? await Task.sleep(for: .milliseconds(350))
        while !Task.isCancelled {
            for step in 1...Self.blockCount {
                withAnimation(OnboardingMotion.enter) { revealed = step }
                try? await Task.sleep(for: .milliseconds(360))
                guard !Task.isCancelled else { return }
            }
            try? await Task.sleep(for: .milliseconds(3800))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { revealed = 0 }
            try? await Task.sleep(for: .milliseconds(320))
            example = (example + 1) % 2
            try? await Task.sleep(for: .milliseconds(380))
        }
    }
}

/// La ligne brisée qui passe par les points de la suite.
private struct IntroCurveShape: Shape {
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

/// Un bloc de la page d'exemple : posé quand son rang est atteint, sinon invisible et un
/// peu plus bas. La même entrée que le reste du parcours.
private struct IntroReveal: ViewModifier {
    let index: Int
    let revealed: Int

    func body(content: Content) -> some View {
        let isShown = index < revealed

        return content
            .opacity(isShown ? 1 : 0)
            .offset(y: isShown ? 0 : 10)
    }
}

private extension View {
    func reveal(_ index: Int, of revealed: Int) -> some View {
        modifier(IntroReveal(index: index, revealed: revealed))
    }
}
