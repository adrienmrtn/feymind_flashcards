import SwiftUI
import UIKit

/// Couverture d'un cours : la première page du PDF si elle existe, sinon un dégradé et l'emoji.
struct CourseCover: View {
    let course: Course
    var emojiSize: CGFloat = 34
    var imageAlignment: Alignment = .top

    private var tint: Color { Color(hexString: course.accentHex) }

    var body: some View {
        ZStack {
            if let image = coverImage {
                Color.white
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: imageAlignment)
            } else {
                LinearGradient(
                    colors: [tint, tint.darkened(by: 0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Text(course.emoji)
                    .font(.system(size: emojiSize))
            }
        }
        .clipped()
    }

    private var coverImage: UIImage? {
        guard let data = course.coverImageData else { return nil }
        return UIImage(data: data)
    }
}

/// Voile sombre appliqué au bas d'une couverture pour garder le texte lisible.
struct FeyCoverScrim: View {
    var strength: Double = 0.6

    var body: some View {
        LinearGradient(
            colors: [Color.clear, Color.black.opacity(strength * 0.5), Color.black.opacity(strength)],
            startPoint: .center,
            endPoint: .bottom
        )
    }
}
