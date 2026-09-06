import Observation
import SwiftUI

/// Jour, nuit, crépuscule. Le même choix que le site, sur cet appareil.
enum MicaboAppearance: String, CaseIterable, Identifiable {
    case day
    case night
    case twilight

    var id: String { rawValue }

    var isDark: Bool { self != .day }

    var colorScheme: ColorScheme { isDark ? .dark : .light }

    static let storageKey = "micabo.appearance"

    static func fromUnknown(_ value: String?) -> MicaboAppearance {
        MicaboAppearance(rawValue: value ?? "") ?? .day
    }
}

/// Palettes des trois apparences. Le jour garde les jetons d'origine de l'iPhone.
struct MicaboPalette: Equatable {
    var canvas: Color
    var surface: Color
    var surfaceMuted: Color
    var surfaceSunken: Color
    var stroke: Color
    var strokeStrong: Color
    var hairline: Color
    var hairlineOnCanvas: Color
    var ink: Color
    var inkSecondary: Color
    var inkTertiary: Color
    var inkReading: Color
    var inkBody: Color
    var sheetMarker: Color
    var onInk: Color
    var onInkMuted: Color
    var canvasSage: Color
    var accent: Color
    var accentSoft: Color
    var accentVivid: Color
    var progressTrack: Color
    var positive: Color
    var caution: Color
    var cautionVivid: Color
    var negative: Color
    var ratingAgain: Color
    var info: Color
    var positiveSoft: Color
    var cautionSoft: Color
    var negativeSoft: Color
    var infoSoft: Color
    var offerWash: Color
    var offerWashSoft: Color
    var tilePastels: [Color]
    var cardShadow: Double
    var groupShadow: Double

    static let day = MicaboPalette(
        canvas: Color(hex: 0xF2F4F7),
        surface: .white,
        surfaceMuted: Color(hex: 0xE8ECF1),
        surfaceSunken: Color(hex: 0xDEE3EA),
        stroke: Color(hex: 0xE5E7EB),
        strokeStrong: Color(hex: 0xD1D5DB),
        hairline: Color(hex: 0xE5E7EB),
        hairlineOnCanvas: Color(hex: 0xD8DCE3),
        ink: Color(hex: 0x111827),
        inkSecondary: Color(hex: 0x6B7280),
        inkTertiary: Color(hex: 0x6B7280),
        inkReading: Color(hex: 0x1F2937),
        inkBody: Color(hex: 0x4B5563),
        sheetMarker: Color(hex: 0xF5D76E),
        onInk: .white,
        onInkMuted: Color(hex: 0x9CA3AF),
        canvasSage: Color(hex: 0xF2F4F7),
        accent: Color(hex: 0x2563EB),
        accentSoft: Color(hex: 0xDBEAFE),
        accentVivid: Color(hex: 0x3B82F6),
        progressTrack: Color(hex: 0xE5E7EB),
        positive: Color(hex: 0x3F7D53),
        caution: Color(hex: 0xB3872B),
        cautionVivid: Color(hex: 0xE8B23C),
        negative: Color(hex: 0xC93B2B),
        ratingAgain: Color(hex: 0xB5573C),
        info: Color(hex: 0x3A6FC4),
        positiveSoft: Color(hex: 0xDCFCE7),
        cautionSoft: Color(hex: 0xFEF3C7),
        negativeSoft: Color(hex: 0xFEE2E2),
        infoSoft: Color(hex: 0xDBEAFE),
        offerWash: Color(hex: 0xC4E7FA),
        offerWashSoft: Color(hex: 0xEAF7FE),
        tilePastels: [
            Color(hex: 0xDBEAFE),
            Color(hex: 0xE0E7FF),
            Color(hex: 0xE5E7EB),
            Color(hex: 0xE0F2FE),
            Color(hex: 0xF3E8FF),
            Color(hex: 0xF1F5F9)
        ],
        cardShadow: 0.04,
        groupShadow: 0.03
    )

    static let night = MicaboPalette(
        canvas: Color(hex: 0x101216),
        surface: Color(hex: 0x1A1D24),
        surfaceMuted: Color(hex: 0x252830),
        surfaceSunken: Color(hex: 0x0C0D10),
        stroke: Color.white.opacity(0.08),
        strokeStrong: Color.white.opacity(0.14),
        hairline: Color.white.opacity(0.08),
        hairlineOnCanvas: Color.white.opacity(0.06),
        ink: Color(hex: 0xE8EAEE),
        inkSecondary: Color(hex: 0x9AA1AB),
        inkTertiary: Color(hex: 0x8B919A),
        inkReading: Color(hex: 0xD5D8DE),
        inkBody: Color(hex: 0x9AA1AB),
        sheetMarker: Color(hex: 0xC9A227),
        onInk: Color(hex: 0x101216),
        onInkMuted: Color(hex: 0x6B7280),
        canvasSage: Color(hex: 0x141A16),
        accent: Color(hex: 0x60A5FA),
        accentSoft: Color(hex: 0x1E3A5F),
        accentVivid: Color(hex: 0x3B82F6),
        progressTrack: Color(hex: 0x2A2E36),
        positive: Color(hex: 0x6FBF86),
        caution: Color(hex: 0xD4A84B),
        cautionVivid: Color(hex: 0xE8B23C),
        negative: Color(hex: 0xE06A5A),
        ratingAgain: Color(hex: 0xE07A68),
        info: Color(hex: 0x7EB0E8),
        positiveSoft: Color(hex: 0x1A2A1E),
        cautionSoft: Color(hex: 0x2E2614),
        negativeSoft: Color(hex: 0x2F1A16),
        infoSoft: Color(hex: 0x182433),
        offerWash: Color(hex: 0x163247),
        offerWashSoft: Color(hex: 0x12202C),
        tilePastels: [
            Color(hex: 0x1E3A5F),
            Color(hex: 0x252830),
            Color(hex: 0x2A2E36),
            Color(hex: 0x182433),
            Color(hex: 0x2A2438),
            Color(hex: 0x1A1D24)
        ],
        cardShadow: 0.45,
        groupShadow: 0.35
    )

    static let twilight = MicaboPalette(
        canvas: Color(hex: 0x1C1612),
        surface: Color(hex: 0x2A211B),
        surfaceMuted: Color(hex: 0x362B23),
        surfaceSunken: Color(hex: 0x15110E),
        stroke: Color(hex: 0xF3E6D4).opacity(0.10),
        strokeStrong: Color(hex: 0xF3E6D4).opacity(0.16),
        hairline: Color(hex: 0xF3E6D4).opacity(0.10),
        hairlineOnCanvas: Color(hex: 0xF3E6D4).opacity(0.08),
        ink: Color(hex: 0xF3E6D4),
        inkSecondary: Color(hex: 0xC4B09A),
        inkTertiary: Color(hex: 0xA89480),
        inkReading: Color(hex: 0xEAD9C4),
        inkBody: Color(hex: 0xC4B09A),
        sheetMarker: Color(hex: 0xC9A227),
        onInk: Color(hex: 0x1C1612),
        onInkMuted: Color(hex: 0x8A7A68),
        canvasSage: Color(hex: 0x1F1A14),
        accent: Color(hex: 0x8BB0FF),
        accentSoft: Color(hex: 0x2A3348),
        accentVivid: Color(hex: 0x7AA2FF),
        progressTrack: Color(hex: 0x3A3028),
        positive: Color(hex: 0x8FBF8A),
        caution: Color(hex: 0xE0B84A),
        cautionVivid: Color(hex: 0xE8B23C),
        negative: Color(hex: 0xE07A68),
        ratingAgain: Color(hex: 0xE07A68),
        info: Color(hex: 0x8BB0FF),
        positiveSoft: Color(hex: 0x24301F),
        cautionSoft: Color(hex: 0x3A2E16),
        negativeSoft: Color(hex: 0x3A1E18),
        infoSoft: Color(hex: 0x222838),
        offerWash: Color(hex: 0x243040),
        offerWashSoft: Color(hex: 0x1C222C),
        tilePastels: [
            Color(hex: 0x2A3348),
            Color(hex: 0x362B23),
            Color(hex: 0x3A3028),
            Color(hex: 0x222838),
            Color(hex: 0x3A2E48),
            Color(hex: 0x2A211B)
        ],
        cardShadow: 0.45,
        groupShadow: 0.35
    )

    static func of(_ appearance: MicaboAppearance) -> MicaboPalette {
        switch appearance {
        case .day: .day
        case .night: .night
        case .twilight: .twilight
        }
    }
}

/// L'apparence en cours. Cookie du site, `UserDefaults` ici : l'iPhone et le
/// navigateur ne se synchronisent pas, et c'est voulu — pas de colonne tant
/// que les deux côtés n'ont pas le même sélecteur depuis assez longtemps.
@Observable
final class AppearanceStore {
    static let shared = AppearanceStore()

    var appearance: MicaboAppearance {
        didSet {
            guard appearance != oldValue else { return }
            UserDefaults.standard.set(appearance.rawValue, forKey: MicaboAppearance.storageKey)
        }
    }

    var palette: MicaboPalette { MicaboPalette.of(appearance) }

    init(appearance: MicaboAppearance = MicaboAppearance.fromUnknown(
        UserDefaults.standard.string(forKey: MicaboAppearance.storageKey)
    )) {
        self.appearance = appearance
    }

    func pick(_ next: MicaboAppearance) {
        appearance = next
    }
}
