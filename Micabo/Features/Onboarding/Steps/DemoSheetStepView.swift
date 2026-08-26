import SwiftUI

/// Démonstration, 2 sur 3 : le cours brut devient une fiche, sous les yeux.
///
/// C'est l'écran qui remplace la génération simulée d'avant, et le changement n'est pas
/// cosmétique. L'ancien écran montrait des étapes qui se cochaient : un tourniquet
/// déguisé, qui faisait patienter devant un travail qu'on ne voyait pas. Celui-ci montre
/// **le résultat en train d'apparaître** — le plan, la définition, le passage surligné, la
/// figure — parce que c'est exactement ce que l'app produit, et que ça se regarde.
///
/// La page de gauche ne disparaît pas d'un coup : elle s'efface pendant que la fiche
/// s'écrit, de sorte qu'on voie les deux états du même document au même endroit.
///
/// **La page est au milieu de l'écran, pas sous le titre.** Elle était calée en haut avec
/// tout le vide en dessous : sur l'écran où l'on regarde un document se réécrire, c'est le
/// document qui doit tomber sous les yeux, et un bloc collé au titre avec un tiers d'écran
/// blanc sous lui se lit comme une illustration de paragraphe.
struct DemoSheetStepView: View {
    @Environment(OnboardingModel.self) private var model

    /// Position du balayage de lecture sur la page brute.
    @State private var sweep = -1.0
    /// Nombre de blocs de fiche déjà écrits.
    @State private var written = 0
    @State private var didStart = false

    private var isFinished: Bool { written >= DemoSheetPage.blockCount }

    var body: some View {
        OnboardingScaffold(
            title: "Micabo le met au propre.",
            titleSize: 30,
            contentSpacing: MicaboSpacing.lg,
            scrolls: false,
            expandsContent: true
        ) {
            VStack(spacing: 16) {
                Spacer(minLength: 0)
                stage
                caption
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } footer: {
            OnboardingContinueButton(title: "S'entraîner", isEnabled: isFinished, isShiny: true) {
                model.advance()
            }
        }
        .onAppear(perform: run)
    }

    // MARK: - La transformation

    /// Les deux états occupent la même place : c'est ce qui fait lire le passage de l'un à
    /// l'autre comme une transformation, et non comme deux illustrations côte à côte.
    private var stage: some View {
        ZStack {
            DemoRawPage(sweepProgress: sweep)
                .opacity(rawOpacity)
                .scaleEffect(written > 0 ? 0.97 : 1)
                .blur(radius: written > 0 ? 2 : 0)

            DemoSheetPage(revealed: written)
                .opacity(written > 0 ? 1 : 0)
                .scaleEffect(written > 0 ? 1 : 1.02)
        }
        .frame(width: DemoSheetPage.width)
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)
        .animation(OnboardingMotion.shift, value: written)
    }

    private var rawOpacity: Double {
        switch written {
        case 0: 1
        case 1: 0.25
        default: 0
        }
    }

    /// Une ligne qui nomme ce qu'on regarde, et qui change une fois. Pas une liste
    /// d'étapes qui se cochent : l'écran montre déjà où il en est.
    private var caption: some View {
        Text(isFinished ? "Plan, définitions, schémas. Prêt à réviser." : "Lecture du cours…")
            .font(MicaboFont.hanken(13, weight: .medium))
            .foregroundStyle(isFinished ? MicaboColor.ink : MicaboColor.inkTertiary)
            .frame(maxWidth: .infinity)
            .animation(OnboardingMotion.tap, value: isFinished)
    }

    // MARK: - Déroulé

    /// Une seconde de lecture, puis un bloc toutes les 220 ms. Deux secondes en tout : assez
    /// pour suivre, trop court pour s'ennuyer.
    private func run() {
        guard !didStart else { return }
        didStart = true

        withAnimation(.timingCurve(0.4, 0, 0.6, 1, duration: 0.95)) {
            sweep = 1
        }

        for index in 0..<DemoSheetPage.blockCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.95 + Double(index) * 0.22) {
                withAnimation(OnboardingMotion.shift) {
                    written = index + 1
                }
                Haptics.tick()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95 + Double(DemoSheetPage.blockCount) * 0.22) {
            Haptics.success()
        }
    }
}
