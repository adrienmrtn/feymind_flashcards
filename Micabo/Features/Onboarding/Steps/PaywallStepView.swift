import StoreKit
import SwiftUI

/// Identifiants des abonnements. Rien n'est encore déclaré côté App Store Connect :
/// le fichier `Micabo.storekit` permet de faire tourner l'écran en local.
enum MicaboProducts {
    static let yearly = "com.micabo.app.pro.yearly"
    static let monthly = "com.micabo.app.pro.monthly"

    static let all = [yearly, monthly]
}

/// Écran 18 : paywall natif StoreKit. L'achat n'est branché à rien pour l'instant,
/// il sert uniquement à terminer le parcours.
struct PaywallStepView: View {
    var onFinish: () -> Void

    private enum StoreState {
        case loading
        case available
        case unavailable
    }

    @State private var state: StoreState = .loading

    var body: some View {
        Group {
            switch state {
            case .loading:
                loadingView
            case .available:
                storeView
            case .unavailable:
                UnavailableStoreView(onFinish: finish)
            }
        }
        .task { await loadProducts() }
    }

    // MARK: - Paywall système

    private var storeView: some View {
        SubscriptionStoreView(productIDs: MicaboProducts.all) {
            PaywallMarketingContent()
        }
        .subscriptionStoreButtonLabel(.multiline)
        .storeButton(.visible, for: .restorePurchases)
        .tint(MicaboColor.ink)
        .onInAppPurchaseCompletion { _, result in
            guard case .success(let purchase) = result, case .success = purchase else { return }
            await MainActor.run { finish() }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
                .tint(MicaboColor.ink)
            Text("Chargement de l'offre…")
                .font(MicaboFont.hanken(13, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .micaboScreenBackground()
    }

    // MARK: - Actions

    @MainActor
    private func loadProducts() async {
        let products = try? await Product.products(for: MicaboProducts.all)
        withAnimation(.easeOut(duration: 0.3)) {
            state = (products?.isEmpty == false) ? .available : .unavailable
        }
    }

    private func finish() {
        Haptics.success()
        onFinish()
    }
}

/// Bandeau de présentation affiché au-dessus des options d'abonnement.
private struct PaywallMarketingContent: View {
    private let advantages = [
        ("infinity", "Cours et flashcards illimités"),
        ("wand.and.stars", "Génération à partir de tes PDF"),
        ("chart.line.uptrend.xyaxis", "Répétition espacée et statistiques"),
        ("icloud", "Tes cours te suivent partout")
    ]

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(MicaboColor.onInk)
                .frame(width: 66, height: 66)
                .background(MicaboColor.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(spacing: 8) {
                Text("Micabo, en entier")
                    .font(MicaboFont.hanken(27, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .tracking(-0.6)

                Text("3 jours offerts, puis tu décides.")
                    .font(MicaboFont.hanken(14, weight: .regular))
                    .foregroundStyle(MicaboColor.inkSecondary)
            }

            VStack(alignment: .leading, spacing: 11) {
                ForEach(Array(advantages.enumerated()), id: \.offset) { _, advantage in
                    HStack(spacing: 11) {
                        Image(systemName: advantage.0)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(MicaboColor.accent)
                            .frame(width: 24)

                        Text(advantage.1)
                            .font(MicaboFont.hanken(14, weight: .medium))
                            .foregroundStyle(Color(hex: 0x4A463F))

                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, MicaboSpacing.xs)
        }
        .multilineTextAlignment(.center)
        .padding(.top, MicaboSpacing.lg)
    }
}

/// Repli quand aucun produit n'est disponible : sans configuration StoreKit,
/// l'écran resterait vide et le parcours n'aurait aucune sortie.
private struct UnavailableStoreView: View {
    var onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    PaywallMarketingContent()

                    VStack(spacing: 6) {
                        Text("Offre bientôt disponible")
                            .font(MicaboFont.hanken(14, weight: .semibold))
                            .foregroundStyle(MicaboColor.ink)

                        Text("Les abonnements ne sont pas encore publiés. En attendant, l'application reste ouverte.")
                            .font(MicaboFont.hanken(13, weight: .regular))
                            .foregroundStyle(MicaboColor.inkSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .background(MicaboColor.surfaceMuted, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.bottom, MicaboSpacing.lg)
            }
            .scrollIndicators(.hidden)

            MicaboBottomBar {
                OnboardingContinueButton(title: "Commencer à réviser") {
                    onFinish()
                }
            }
        }
        .micaboScreenBackground()
    }
}
