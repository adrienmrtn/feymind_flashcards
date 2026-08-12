import SwiftUI

/// Nombre qui défile : SwiftUI interpole `value`, le texte suit image par image.
struct CountingText: View, Animatable {
    var value: Double
    var font: Font
    var color: Color

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(Self.formatted(Int(value.rounded())))
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
    }

    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        return formatter
    }()

    static func formatted(_ value: Int) -> String {
        formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
