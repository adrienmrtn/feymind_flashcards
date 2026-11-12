import SwiftUI

// MARK: - La bulle

/// **Ce que la mascotte dit.**
///
/// Une bulle blanche à filet, avec sa queue vers le personnage. Le texte y est en dix-sept
/// points demi-gras : c'est une phrase qu'on lit comme si quelqu'un venait de la dire, pas
/// un titre d'écran.
struct MicaboSpeechBubble: View {
    let text: String
    /// De quel côté pointe la queue.
    var tail: Edge = .top

    var body: some View {
        let tailAlignment: Alignment = tail == .top ? .top : .bottom
        let tailTurn: Double = tail == .top ? 0 : 180
        let tailOffset: CGFloat = tail == .top ? -11 : 11

        return Text(text)
            .font(MicaboFont.ui(17, weight: .semibold))
            .foregroundStyle(MicaboColor.ink)
            .lineSpacing(3)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: MicaboRadius.wash, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MicaboRadius.wash, style: .continuous)
                    .strokeBorder(MicaboColor.stroke, lineWidth: 1.5)
            }
            .overlay(alignment: tailAlignment) {
                tailShape
                    .rotationEffect(.degrees(tailTurn))
                    .offset(y: tailOffset)
            }
            .shadow(color: Color.black.opacity(0.05), radius: 12, y: 5)
    }

    private var tailShape: some View {
        ZStack {
            Triangle()
                .fill(MicaboColor.stroke)
                .frame(width: 22, height: 12)
            Triangle()
                .fill(MicaboColor.canvas)
                .frame(width: 18, height: 10)
                .offset(y: 1.6)
        }
    }

    private struct Triangle: Shape {
        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: rect.midX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                path.closeSubpath()
            }
        }
    }
}
