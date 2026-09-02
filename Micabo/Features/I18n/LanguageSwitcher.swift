import SwiftUI

/// La langue de l'app. Pas un drapeau : une langue n'est pas un pays.
struct LanguageSwitcher: View {
    var variant: Variant = .compact
    @Environment(UiLocaleStore.self) private var store: UiLocaleStore?
    @Environment(\.onboardingSurface) private var surface

    private var i18n: UiLocaleStore { store ?? UiLocaleStore() }

    enum Variant {
        case compact
        case card
    }

    var body: some View {
        switch variant {
        case .compact: compact
        case .card: card
        }
    }

    private var compact: some View {
        Menu {
            ForEach(UiLocale.allCases) { code in
                Button {
                    i18n.pick(code)
                } label: {
                    HStack {
                        Text(code.nativeName)
                        if code == i18n.locale {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(i18n.locale.nativeName)
                .font(MicaboFont.hanken(13, weight: .medium))
                .foregroundStyle(surface.isDark ? MicaboColor.onInk.opacity(0.78) : MicaboColor.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityLabel(i18n.t("ios.appLanguage"))
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(i18n.t("ios.appLanguage"))
                .font(MicaboFont.hanken(13, weight: .regular))
                .foregroundStyle(MicaboColor.inkTertiary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(UiLocale.allCases) { code in
                    Button {
                        i18n.pick(code)
                    } label: {
                        Text(code.nativeName)
                            .font(MicaboFont.hanken(14, weight: .medium))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(code == i18n.locale ? MicaboColor.accent : MicaboColor.ink)
                            .background(
                                code == i18n.locale ? MicaboColor.accentSoft : MicaboColor.surfaceMuted,
                                in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous)
                            )
                    }
                    .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
                    .accessibilityAddTraits(code == i18n.locale ? .isSelected : [])
                }
            }

            Text(i18n.t("ios.appLanguageHelp"))
                .font(MicaboFont.hanken(13, weight: .regular))
                .foregroundStyle(MicaboColor.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(MicaboSpacing.lg)
        .micaboGroup()
    }
}
