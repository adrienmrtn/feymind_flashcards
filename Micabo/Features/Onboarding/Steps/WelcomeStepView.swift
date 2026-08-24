import SwiftUI

/// Écran 1 : l'accroche. Un paquet de cartes se rebat tout seul, et rien d'autre.
///
/// Le paragraphe d'explication qui vivait ici est parti. Sur le premier écran d'une app,
/// personne ne lit trois lignes sur le fonctionnement d'un algorithme : on regarde. Les
/// cartes disent déjà ce que fait Micabo, et **elles montrent les trois formats** — recto
/// verso, QCM, texte à trou — ce qu'aucune phrase ne faisait.
///
/// Le paquet vit dans `WelcomeDeck.swift`. Le laisser ici faisait abandonner le
/// compilateur : trop d'expressions, et une `Face` privée que la carte ne pouvait pas lire.
struct WelcomeStepView: View {
    @Environment(OnboardingModel.self) private var model

    private let surface = OnboardingStep.welcome.surface

    var body: some View {
        layout
            .background(surface.background.ignoresSafeArea(edges: .bottom))
            .environment(\.onboardingSurface, surface)
    }

    private var layout: some View {
        VStack(spacing: 0) {
            Spacer(minLength: MicaboSpacing.md)
            deck
            Spacer(minLength: MicaboSpacing.lg)
            titleBlock
            continueBar
        }
    }

    private var deck: some View {
        WelcomeDeck()
            .frame(height: 250)
            .padding(.horizontal, MicaboSpacing.xl)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MICABO")
                .font(MicaboFont.hanken(11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(surface.eyebrow)
                .onboardingAppear(index: 0, stagger: 0.1)

            Text("Apprends tout,\nplus vite.")
                .font(MicaboFont.hanken(40, weight: .bold))
                .foregroundStyle(surface.title)
                .tracking(-1.2)
                .lineSpacing(-3)
                .fixedSize(horizontal: false, vertical: true)
                .onboardingAppear(index: 1, stagger: 0.1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.bottom, MicaboSpacing.lg)
    }

    private var continueBar: some View {
        MicaboBottomBar(background: surface.background) {
            OnboardingContinueButton(title: "Commencer") {
                model.advance()
            }
            .onboardingAppear(index: 2, stagger: 0.1)
        }
    }
}
