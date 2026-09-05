import SwiftUI

/// La langue de l'app. Les drapeaux ouvrent le choix ; les noms le confirment.
struct LanguageSwitcher: View {
    var variant: Variant = .compact
    @Environment(UiLocaleStore.self) private var store: UiLocaleStore?
    @Environment(\.onboardingSurface) private var surface

    private var i18n: UiLocaleStore { store ?? UiLocaleStore() }

    enum Variant {
        case compact
        case card
        /// Rangée de drapeaux, pour le premier écran du parcours.
        case flags
    }

    var body: some View {
        switch variant {
        case .compact: compact
        case .card: card
        case .flags: flags
        }
    }

    private var compact: some View {
        Menu {
            ForEach(UiLocale.allCases) { code in
                Button {
                    i18n.pick(code)
                } label: {
                    HStack {
                        Text("\(code.flag)  \(code.nativeName)")
                        if code == i18n.locale {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(i18n.locale.flag)
                    .font(.system(size: 17))
                    .accessibilityHidden(true)
                Text(i18n.locale.nativeName)
                    .font(MicaboFont.hanken(13, weight: .medium))
                    .foregroundStyle(surface.isDark ? MicaboColor.onInk.opacity(0.78) : MicaboColor.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .accessibilityLabel(i18n.t("ios.appLanguage"))
        .accessibilityValue(i18n.locale.nativeName)
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
                        HStack(spacing: 8) {
                            Text(code.flag)
                                .font(.system(size: 22))
                                .accessibilityHidden(true)
                            Text(code.nativeName)
                                .font(MicaboFont.hanken(14, weight: .medium))
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.horizontal, 10)
                        .foregroundStyle(code == i18n.locale ? MicaboColor.accent : MicaboColor.ink)
                        .background(
                            code == i18n.locale ? MicaboColor.accentSoft : MicaboColor.surfaceMuted,
                            in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous)
                        )
                    }
                    .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
                    .accessibilityAddTraits(code == i18n.locale ? .isSelected : [])
                    .accessibilityLabel(code.nativeName)
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

    private var flags: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(i18n.t("locale.choose"))
                .font(MicaboFont.hanken(13, weight: .medium))
                .foregroundStyle(surface.isDark ? MicaboColor.onInk.opacity(0.7) : MicaboColor.inkTertiary)

            HStack(spacing: 8) {
                ForEach(UiLocale.allCases) { code in
                    Button {
                        i18n.pick(code)
                    } label: {
                        VStack(spacing: 6) {
                            Text(code.flag)
                                .font(.system(size: 28))
                                .accessibilityHidden(true)
                            Text(code.nativeName)
                                .font(MicaboFont.hanken(11.5, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .foregroundStyle(code == i18n.locale ? MicaboColor.accent : MicaboColor.ink)
                        .background(
                            code == i18n.locale ? MicaboColor.accentSoft : MicaboColor.surface.opacity(0.72),
                            in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous)
                                .strokeBorder(
                                    code == i18n.locale ? MicaboColor.accent : Color.clear,
                                    lineWidth: 1.5
                                )
                        }
                    }
                    .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
                    .accessibilityAddTraits(code == i18n.locale ? .isSelected : [])
                    .accessibilityLabel(code.nativeName)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(i18n.t("ios.appLanguage"))
    }
}
