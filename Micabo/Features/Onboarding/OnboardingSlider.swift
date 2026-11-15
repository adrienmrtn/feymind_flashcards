import SwiftUI

/// **Le curseur à crans du parcours** (lot 14 : « améliore le curseur des notes ») : la
/// moyenne d'aujourd'hui, la moyenne visée, le temps par jour.
///
/// - **La valeur se lit en grand au-dessus** (c'est l'écran qui la dessine) ; ici, la piste.
/// - **La piste** : 10 pt, remplie d'accent jusqu'au pouce ; un point par cran.
/// - **Le pouce** : une pastille blanche de 34 pt à lèvre, comme les boutons de l'app ; il
///   grossit sous le doigt.
/// - **Les bornes** en clair sous la piste, aux deux bouts : le barème du pays, ou « 5 min » et
///   « 2 h ».
/// - **Au doigt** : on pose le doigt n'importe où sur la piste, on glisse ; chaque cran passé
///   donne un petit coup (`Haptics.selection`). Avec VoiceOver : glisser vers le haut ou le bas.
///
/// La piste se lit de gauche à droite dans toutes les langues, comme une règle graduée.
struct OnbNotchSlider: View {
    /// Le nombre de crans.
    let count: Int
    @Binding var index: Int
    let lowerBound: String
    let upperBound: String
    /// Ce que le lecteur d'écran annonce, et la valeur d'un cran.
    let accessibilityLabel: String
    let valueText: (Int) -> String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @GestureState private var isDragging = false

    static let trackHeight: CGFloat = 10
    static let thumbSize: CGFloat = 34

    private var fraction: CGFloat {
        guard count > 1 else { return 0 }
        return CGFloat(min(max(0, index), count - 1)) / CGFloat(count - 1)
    }

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                let usable = max(1, proxy.size.width - Self.thumbSize)
                let x = Self.thumbSize / 2 + usable * fraction
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(V3Color.line)
                        .frame(height: Self.trackHeight)
                        .padding(.horizontal, Self.thumbSize / 2 - Self.trackHeight / 2)
                    Capsule()
                        .fill(V3Color.accent)
                        .frame(width: max(Self.trackHeight, x - Self.thumbSize / 2 + Self.trackHeight), height: Self.trackHeight)
                        .padding(.leading, Self.thumbSize / 2 - Self.trackHeight / 2)
                    // Un point par cran.
                    ForEach(0 ..< max(1, count), id: \.self) { notch in
                        let nx = Self.thumbSize / 2 + usable * (count > 1 ? CGFloat(notch) / CGFloat(count - 1) : 0)
                        Circle()
                            .fill(notch <= index ? V3Color.onAccent.opacity(0.7) : V3Color.ink3.opacity(0.7))
                            .frame(width: 4, height: 4)
                            .position(x: nx, y: proxy.size.height / 2)
                    }
                    thumb
                        .position(x: x, y: proxy.size.height / 2)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($isDragging) { _, state, _ in state = true }
                        .onChanged { value in
                            let raw = (value.location.x - Self.thumbSize / 2) / usable
                            move(to: Int((min(1, max(0, raw)) * CGFloat(count - 1)).rounded()))
                        }
                )
            }
            .frame(height: 48)

            HStack {
                Text(lowerBound)
                Spacer(minLength: 12)
                Text(upperBound)
            }
            .font(V3Font.label)
            .foregroundStyle(V3Color.ink2)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityHidden(true)
        }
        .environment(\.layoutDirection, .leftToRight)
        .animation(MicaboMotion.resolved(MicaboMotion.quick, reduceMotion: reduceMotion), value: index)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(valueText(index))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: move(to: index + 1)
            case .decrement: move(to: index - 1)
            @unknown default: break
            }
        }
    }

    private var thumb: some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().strokeBorder(V3Color.accent, lineWidth: 3))
            .frame(width: Self.thumbSize, height: Self.thumbSize)
            .background(Circle().fill(V3Color.lip).offset(y: 3))
            .scaleEffect(isDragging ? 1.15 : 1)
            .animation(MicaboMotion.resolved(MicaboMotion.quick, reduceMotion: reduceMotion), value: isDragging)
    }

    private func move(to target: Int) {
        let clamped = min(max(0, target), max(0, count - 1))
        guard clamped != index else { return }
        index = clamped
        Haptics.selection()
    }
}

/// **La valeur du curseur, en grand** : « 16 » puis « /20 » plus petit et en couleur ; une
/// valeur sans barre (« 3.7 », « B+ », « 1 h 30 ») d'un bloc. Le mot qui qualifie le cran
/// (« Sérieux ») se pose dessous, dans une pastille.
struct OnbSliderValue: View {
    let label: String
    var qualifier: String?
    var tone: Color = V3Color.accentBright

    var body: some View {
        let parts = OnbGradeWheel.parts(of: label)
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(parts.value)
                    .font(V3Font.display(84))
                    .foregroundStyle(V3Color.ink)
                if let scale = parts.scale {
                    Text(scale)
                        .font(V3Font.display(34))
                        .foregroundStyle(tone)
                }
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.35)
            .contentTransition(.numericText())
            .environment(\.layoutDirection, .leftToRight)

            if let qualifier {
                Text(qualifier)
                    .font(V3Font.label)
                    .foregroundStyle(tone)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(tone.opacity(0.14), in: Capsule())
                    .contentTransition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}
