import SwiftUI

/// **Ce que ça donne : la moyenne qui monte, semaine après semaine.**
///
/// Un seul chiffre, et il arrive après tout le reste : le produit a été montré, la méthode
/// expliquée, la préparation d'une épreuve détaillée. C'est le moment où l'on a le droit de
/// dire ce que ça change, parce que l'étudiant sait maintenant de quoi on parle.
///
/// **La courbe est imparfaite, et c'est délibéré.** Une droite qui monte de gauche à droite
/// ne ressemble à aucun semestre réel : elle se lit comme un argument de vente. Trois
/// passages à vide - une semaine de partiels, un week-end sans réviser - et la même moyenne
/// à l'arrivée : la promesse devient une trajectoire, ce qui est bien plus proche de ce qui
/// se passe.
struct ResultsStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingScaffold(
            title: i18n?.t("ios.resultsTitle") ?? "En moyenne, les notes\nmontent de 17 %.",
            subtitle: i18n?.t("ios.resultsLead"),
            titleSize: 28
        ) {
            ResultsCurve()
        } footer: {
            OnboardingContinueButton {
                model.advance()
            }
        }
    }
}

/// Douze semaines de moyenne, de 74 % à 91 %, avec ses creux.
private struct ResultsCurve: View {
    /// Les douze relevés, en pourcentage. Les creux sont aux semaines 4, 7 et 10.
    private let weeks: [Double] = [74, 76, 79, 77, 81, 84, 82, 86, 88, 86, 90, 91]

    @State private var drawn: CGFloat = 0
    @State private var showsEnds = false
    @State private var didStart = false

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private func t(_ key: String, _ vars: [String: String] = [:]) -> String {
        i18n?.t(key, vars) ?? L10n.t(key, locale: .fr, vars: vars)
    }

    private var lowest: Double { weeks.min() ?? 0 }
    private var highest: Double { weeks.max() ?? 100 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            chart
            legend
        }
        .padding(MicaboSpacing.md)
        .frame(maxWidth: .infinity)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.group, style: .continuous))
        .onAppear(perform: run)
    }

    private var chart: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack(alignment: .topLeading) {
                // L'aire sous la courbe, très diluée : elle donne du poids à la montée sans
                // que le tracé cesse d'être la seule chose qu'on regarde.
                area(in: size)
                    .fill(
                        LinearGradient(
                            colors: [MicaboColor.accent.opacity(0.18), MicaboColor.accent.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(drawn)

                line(in: size)
                    .trim(from: 0, to: drawn)
                    .stroke(
                        MicaboColor.accent,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )

                // Le point d'arrivée, posé une fois le trait fini.
                Circle()
                    .fill(MicaboColor.accent)
                    .frame(width: 9, height: 9)
                    .position(point(at: weeks.count - 1, in: size))
                    .opacity(showsEnds ? 1 : 0)
            }
        }
        .frame(height: 150)
        .animation(.timingCurve(0.25, 0.6, 0.2, 1, duration: 1.5), value: drawn)
        .animation(.easeOut(duration: 0.3), value: showsEnds)
    }

    private func point(at index: Int, in size: CGSize) -> CGPoint {
        let span = Swift.max(1, weeks.count - 1)
        let x = size.width * CGFloat(index) / CGFloat(span)
        // L'échelle s'ajuste aux relevés, avec une marge : une courbe collée aux bords se
        // lit comme un graphe tronqué.
        let range = Swift.max(1, highest - lowest)
        let ratio = (weeks[index] - lowest) / range
        let y = size.height - (size.height - 16) * CGFloat(ratio) - 8
        return CGPoint(x: x, y: y)
    }

    private func line(in size: CGSize) -> Path {
        var path = Path()
        for index in weeks.indices {
            let position = point(at: index, in: size)
            if index == 0 {
                path.move(to: position)
            } else {
                path.addLine(to: position)
            }
        }
        return path
    }

    private func area(in size: CGSize) -> Path {
        var path = line(in: size)
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }

    /// Le départ et l'arrivée, en toutes lettres : une courbe sans ses deux bornes ne dit
    /// pas de combien elle monte.
    private var legend: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            bound(label: t("ios.resultsBefore"), value: "\(Int(weeks.first ?? 0)) %", tint: MicaboColor.inkTertiary)
            Spacer(minLength: MicaboSpacing.sm)
            bound(label: t("ios.resultsAfter"), value: "\(Int(weeks.last ?? 0)) %", tint: MicaboColor.accent)
        }
        .opacity(showsEnds ? 1 : 0)
        .animation(.easeOut(duration: 0.35), value: showsEnds)
    }

    private func bound(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(MicaboFont.hanken(11, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)
            Text(value)
                .font(MicaboFont.number(18, weight: .bold))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
    }

    private func run() {
        guard !didStart else { return }
        didStart = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { drawn = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            showsEnds = true
            Haptics.success()
        }
    }
}
