import SwiftUI

/// **Une phrase à la première ouverture d'un outil** (lot 10, HOME.md § 3).
///
/// « J'comprends rien aux fonctionnalités » : chaque outil dit ce qu'il fait la première fois
/// qu'on l'ouvre, en une phrase, par la voix de Mika, en tête de son écran — pas un tutoriel,
/// pas une visite guidée. Un appui la range ; la fois suivante, elle n'est plus là.
///
/// « Corriger un texte » et « À voix haute » portent déjà leur phrase dans leur écran : ils
/// n'en reçoivent pas une seconde.
enum ToolIntro: String, CaseIterable {
    case scan
    case quickQuiz
    case mock
    case notes
    case quiz
    case cards
    case mika
    case listen
    case mindMap
    case sheet

    /// La phrase de l'outil.
    var key: String {
        switch self {
        case .scan: "ios.home10.intro.scan"
        case .quickQuiz: "ios.home10.intro.quickQuiz"
        case .mock: "ios.home10.intro.mock"
        case .notes: "ios.home10.intro.notes"
        case .quiz: "ios.home10.intro.quiz"
        case .cards: "ios.home10.intro.cards"
        case .mika: "ios.home10.intro.mika"
        case .listen: "ios.home10.intro.listen"
        case .mindMap: "ios.home10.intro.mindMap"
        case .sheet: "ios.home10.intro.sheet"
        }
    }

    func text(locale: UiLocale = .resolved()) -> String {
        L10n.t(key, locale: locale)
    }

    /// Le réglage qui retient qu'un outil a déjà été ouvert.
    var storageKey: String { "micabo.home10.intro.\(rawValue)" }

    /// Vrai tant que l'outil n'a jamais été ouvert sur cet appareil.
    static func isFirstOpen(_ tool: ToolIntro, defaults: UserDefaults = .standard) -> Bool {
        !defaults.bool(forKey: tool.storageKey)
    }

    static func markOpened(_ tool: ToolIntro, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: tool.storageKey) else { return }
        defaults.set(true, forKey: tool.storageKey)
    }
}

extension View {
    /// Pose la phrase de l'outil en tête de son écran, à sa première ouverture seulement.
    func toolIntro(_ tool: ToolIntro) -> some View {
        modifier(ToolIntroBanner(tool: tool))
    }
}

/// La bulle de Mika en tête d'un outil ouvert pour la première fois. Elle est là quand l'écran
/// arrive — rien ne l'amène — et s'efface d'un appui.
private struct ToolIntroBanner: ViewModifier {
    let tool: ToolIntro

    @State private var shown: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(tool: ToolIntro) {
        self.tool = tool
        _shown = State(initialValue: ToolIntro.isFirstOpen(tool))
    }

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                if shown {
                    Button {
                        withAnimation(MicaboMotion.resolved(MicaboMotion.quick, reduceMotion: reduceMotion)) {
                            shown = false
                        }
                    } label: {
                        MikaAsk(tool.text())
                            .padding(.horizontal, MicaboSpacing.screen)
                            .padding(.bottom, 10)
                            .frame(maxWidth: .infinity)
                            .background(V3Color.bg.ignoresSafeArea(edges: .top))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text(L10n.t("ios.home10.intro.dismiss", locale: .resolved())))
                    .transition(.opacity)
                }
            }
            .onAppear { ToolIntro.markOpened(tool) }
    }
}
