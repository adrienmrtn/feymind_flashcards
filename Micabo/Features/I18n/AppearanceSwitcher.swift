import SwiftUI

/// Jour, nuit, crépuscule. Large dans les réglages, compact dans une barre.
struct AppearanceSwitcher: View {
    var variant: Variant = .compact
    @Environment(UiLocaleStore.self) private var store: UiLocaleStore?
    @Environment(\.onboardingSurface) private var surface

    private var i18n: UiLocaleStore { store ?? UiLocaleStore() }
    private var appearance: AppearanceStore { .shared }

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
        HStack(spacing: 4) {
            ForEach(MicaboAppearance.allCases) { value in
                Button {
                    appearance.pick(value)
                } label: {
                    Circle()
                        .fill(swatch(value))
                        .frame(width: 16, height: 16)
                        .overlay {
                            Circle().strokeBorder(MicaboColor.strokeStrong, lineWidth: 1)
                        }
                        .padding(6)
                        .background(
                            value == appearance.appearance
                                ? MicaboColor.accentSoft
                                : Color.clear,
                            in: Circle()
                        )
                }
                .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
                .accessibilityLabel(label(value))
                .accessibilityAddTraits(value == appearance.appearance ? .isSelected : [])
            }
        }
        .padding(4)
        .background(
            surface.isDark ? Color.white.opacity(0.12) : MicaboColor.surfaceMuted,
            in: Capsule()
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(i18n.t("ios.appearance"))
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(i18n.t("ios.appearance"))
                .font(MicaboFont.hanken(13, weight: .regular))
                .foregroundStyle(MicaboColor.inkTertiary)

            HStack(spacing: 8) {
                ForEach(MicaboAppearance.allCases) { value in
                    Button {
                        appearance.pick(value)
                    } label: {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(swatch(value))
                                .frame(width: 16, height: 16)
                                .overlay {
                                    Circle().strokeBorder(MicaboColor.strokeStrong, lineWidth: 1)
                                }
                            Text(label(value))
                                .font(MicaboFont.hanken(13.5, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.vertical, 10)
                        .foregroundStyle(value == appearance.appearance ? MicaboColor.accent : MicaboColor.ink)
                        .background(
                            value == appearance.appearance ? MicaboColor.accentSoft : MicaboColor.surfaceMuted,
                            in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous)
                        )
                    }
                    .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
                    .accessibilityAddTraits(value == appearance.appearance ? .isSelected : [])
                    .accessibilityLabel(label(value))
                }
            }

            Text(i18n.t("ios.appearanceHelp"))
                .font(MicaboFont.hanken(13, weight: .regular))
                .foregroundStyle(MicaboColor.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(MicaboSpacing.lg)
        .micaboGroup()
    }

    private func label(_ value: MicaboAppearance) -> String {
        switch value {
        case .day: i18n.t("ios.appearanceDay")
        case .night: i18n.t("ios.appearanceNight")
        case .twilight: i18n.t("ios.appearanceTwilight")
        }
    }

    private func swatch(_ value: MicaboAppearance) -> Color {
        switch value {
        case .day: Color(hex: 0xF2F4F7)
        case .night: Color(hex: 0x101216)
        case .twilight: Color(hex: 0x2A211B)
        }
    }
}
