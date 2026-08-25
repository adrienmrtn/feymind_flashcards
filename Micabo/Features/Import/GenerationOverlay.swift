import Combine
import SwiftUI

/// Ce qu'on regarde pendant que Micabo travaille.
///
/// **L'écran d'avant cochait des étapes.** Quatre rangées, une pastille qui se remplissait
/// toutes les 2,2 secondes, une grosse pastille d'encre avec des étincelles, et une phrase
/// promettant « moins d'une minute ». Le problème n'était pas la laideur, c'était le
/// mensonge : les coches n'étaient reliées à rien, elles avançaient sur un minuteur. Un
/// tourniquet déguisé en compte rendu.
///
/// Celui-ci montre **la page en train de se faire** : un bloc de titre, des lignes de texte,
/// un passage surligné, un tableau, une figure, qui se posent l'un après l'autre pendant
/// qu'un balayage de lecture descend sur la page. C'est la même image que celle du parcours
/// d'accueil, et c'est voulu : ce qu'on a promis à l'inscription est ce qu'on montre en
/// train d'arriver. L'étape en cours est écrite en une ligne sous la page, et la jauge
/// mesure le chemin des étapes, pas un temps qu'on ne connaît pas.
struct GenerationOverlay: View {
    let title: String
    let steps: [String]

    @State private var currentStep = 0
    @State private var laidBlocks = 0
    @State private var sweep = -1.0

    /// Cadence des étapes annoncées. Elle est indicative et l'a toujours été : personne ne
    /// sait combien de temps prend un modèle. La dernière étape reste donc affichée aussi
    /// longtemps qu'il faut, au lieu de faire semblant d'avancer.
    private let stepTimer = Timer.publish(every: 2.4, on: .main, in: .common).autoconnect()
    /// Cadence de pose des blocs de la page. Plus rapide que les étapes : c'est ce qui donne
    /// à l'écran son impression de travail en cours.
    private let blockTimer = Timer.publish(every: 0.55, on: .main, in: .common).autoconnect()

    private var progress: Double {
        guard steps.count > 1 else { return 0.5 }
        return Double(currentStep + 1) / Double(steps.count)
    }

    var body: some View {
        ZStack {
            MicaboColor.canvas.ignoresSafeArea()

            VStack(spacing: MicaboSpacing.xl) {
                Spacer(minLength: 0)

                GeneratingPage(laidBlocks: laidBlocks, sweep: sweep)
                    .frame(width: 236)
                    .shadow(color: Color.black.opacity(0.07), radius: 20, x: 0, y: 12)

                VStack(spacing: MicaboSpacing.sm) {
                    Text(title)
                        .font(MicaboFont.hanken(24, weight: .bold))
                        .foregroundStyle(MicaboColor.ink)
                        .tracking(MicaboTracking.tight)
                        .multilineTextAlignment(.center)

                    Text(steps.indices.contains(currentStep) ? steps[currentStep] : "")
                        .font(MicaboFont.bodyEmphasis)
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)
                        .animation(.easeOut(duration: 0.25), value: currentStep)

                    MicaboProgressBar(progress: progress)
                        .frame(height: 4)
                        .frame(maxWidth: 190)
                        .padding(.top, MicaboSpacing.xxs)
                        .animation(.easeOut(duration: 0.4), value: progress)
                }

                Spacer(minLength: 0)
            }
            .padding(MicaboSpacing.lg)
        }
        .onAppear(perform: start)
        .onReceive(stepTimer) { _ in
            guard currentStep < steps.count - 1 else { return }
            currentStep += 1
        }
        .onReceive(blockTimer) { _ in
            guard laidBlocks < GeneratingPage.blockCount else { return }
            laidBlocks += 1
        }
        .transition(.opacity)
    }

    /// La page se remplit une fois et **reste remplie** : elle ne se vide pas pour repartir.
    /// Une page qui s'effacerait toutes les trois secondes se lirait comme un travail qui
    /// recommence, c'est-à-dire comme un échec. Ce qui tourne en boucle, c'est le balayage de
    /// lecture, et il peut tourner aussi longtemps que le modèle met à répondre.
    private func start() {
        laidBlocks = 1
        sweep = -0.35
        withAnimation(.linear(duration: GeneratingPage.sweepDuration).repeatForever(autoreverses: false)) {
            sweep = 1
        }
    }
}

/// La page en cours d'écriture : des blocs gris qui se posent, un passage surligné et une
/// figure pour dire ce qu'une fiche contient, et un balayage de lecture qui descend.
///
/// Rien n'y est du vrai contenu, et c'est assumé : le document réel n'est pas encore écrit.
/// Ce sont des **formes**, pas du faux texte — un simulacre de phrases lisibles au moment
/// où l'on n'a rien à dire serait pire qu'une silhouette.
private struct GeneratingPage: View {
    let laidBlocks: Int
    let sweep: Double

    static let blockCount = 6
    static let sweepDuration: Double = 3.3

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            block(0) { titleBlock }
            block(1) { lines(widths: [1, 0.94, 0.6]) }
            block(2) { highlightedLine }
            block(3) { lines(widths: [0.97, 0.72]) }
            block(4) { table }
            block(5) { chart }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(MicaboColor.surface)
        .overlay(alignment: .top) { readingSweep }
        .clipShape(RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
    }

    /// Un bloc posé arrive de trois points plus bas, sans ressort : c'est une ligne qui
    /// s'écrit, pas un objet qu'on lâche.
    @ViewBuilder
    private func block<Content: View>(_ index: Int, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(index < laidBlocks ? 1 : 0)
            .offset(y: index < laidBlocks ? 0 : 3)
            .animation(.easeOut(duration: 0.32), value: laidBlocks)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 7) {
            Capsule()
                .fill(MicaboColor.accent)
                .frame(width: 22, height: 3)

            bar(width: 0.66, height: 11, color: MicaboColor.surfaceSunken)
        }
    }

    private func lines(widths: [CGFloat]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(widths.enumerated()), id: \.offset) { _, width in
                bar(width: width, height: 5, color: MicaboColor.surfaceMuted)
            }
        }
    }

    /// Le passage mis en avant, montré ici parce que c'est la marque qu'on reconnaît d'une
    /// fiche Micabo, et qu'on la découvre mieux en la voyant arriver. Il portait le jaune du
    /// surligneur ; il prend le vert de la fiche, comme elle.
    private var highlightedLine: some View {
        VStack(alignment: .leading, spacing: 6) {
            bar(width: 0.88, height: 5, color: MicaboColor.sheetEmphasis.opacity(0.65))
            bar(width: 0.44, height: 5, color: MicaboColor.surfaceMuted)
        }
    }

    private var table: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { column in
                        Rectangle()
                            .fill(row == 0 ? MicaboColor.surfaceMuted : Color.clear)
                            .frame(height: 15)
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(row == 0 ? MicaboColor.surfaceSunken : MicaboColor.surfaceMuted)
                                    .frame(width: column == 0 ? 26 : 18, height: 4)
                                    .padding(.leading, 6)
                            }
                            .overlay(alignment: .bottom) {
                                if row < 2 {
                                    Rectangle()
                                        .fill(MicaboColor.stroke)
                                        .frame(height: 1)
                                }
                            }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
    }

    private static let chartRatios: [CGFloat] = [0.5, 0.85, 0.35, 0.65]

    private var chart: some View {
        HStack(alignment: .bottom, spacing: 7) {
            ForEach(Array(Self.chartRatios.enumerated()), id: \.offset) { _, ratio in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(MicaboColor.accent.opacity(0.35))
                    .frame(height: 30 * ratio)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 30, alignment: .bottom)
    }

    private func bar(width: CGFloat, height: CGFloat, color: Color) -> some View {
        Capsule()
            .fill(color)
            .frame(height: height)
            .frame(maxWidth: .infinity, alignment: .leading)
            .scaleEffect(x: width, anchor: .leading)
    }

    @ViewBuilder
    private var readingSweep: some View {
        if sweep >= -0.5 {
            GeometryReader { proxy in
                LinearGradient(
                    colors: [
                        MicaboColor.progress.opacity(0),
                        MicaboColor.progress.opacity(0.16),
                        MicaboColor.progress.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 70)
                .offset(y: sweep * (proxy.size.height + 70) - 70)
            }
            .allowsHitTesting(false)
        }
    }
}

#Preview {
    GenerationOverlay(
        title: "Écriture de la fiche",
        steps: ["Lecture du document", "Repérage du plan", "Rédaction de la fiche", "Mise en page"]
    )
}
