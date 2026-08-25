import SwiftUI

/// Le lien d'une vidéo, puis son aperçu.
///
/// L'aperçu n'est pas décoratif : coller une URL est le seul import où l'on ne voit pas ce
/// qu'on importe. Un identifiant de onze caractères ne dit rien, et se tromper de lien dans
/// un onglet YouTube est banal. On montre donc la vignette, le titre, la chaîne et la durée
/// **avant** de dépenser un appel, et c'est là aussi qu'on annonce ce qui empêche de lire la
/// vidéo, au lieu d'une alerte posée sur un écran vide.
struct YouTubeImportSection: View {
    @Binding var link: String
    let video: YouTubeVideo?
    let isChecking: Bool
    var onCheck: () -> Void
    var onReset: () -> Void

    /// Un lien incomplet n'est pas une erreur : on ne reproche rien tant que le champ est
    /// en train d'être rempli, seulement quand il contient quelque chose d'autre.
    private var showsInvalidHint: Bool {
        guard video == nil, !isChecking else { return false }
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 12 && !YouTubeLink.isValid(trimmed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.sm) {
            if let video {
                preview(video)
            } else {
                linkField
            }
        }
    }

    // MARK: - Le champ

    private var linkField: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Lien de la vidéo")
                .font(MicaboFont.captionEmphasis)
                .foregroundStyle(MicaboColor.ink)

            HStack(spacing: 10) {
                Image(systemName: "play.rectangle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(MicaboColor.inkTertiary)

                TextField("youtube.com/watch?v=…", text: $link)
                    .font(MicaboFont.body)
                    .foregroundStyle(MicaboColor.ink)
                    .tint(MicaboColor.accent)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit(onCheck)

                if isChecking {
                    ProgressView()
                        .controlSize(.small)
                        .tint(MicaboColor.progress)
                } else if !link.isEmpty {
                    Button {
                        link = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(MicaboColor.inkTertiary)
                    }
                    .buttonStyle(MicaboPressableButtonStyle())
                    .accessibilityLabel("Effacer le lien")
                }
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 15)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))

            if showsInvalidHint {
                // Le même texte que l'alerte, mais posé sous le champ : l'erreur se corrige
                // là où elle a été faite.
                message(
                    YouTubeImportError.invalidLink.errorDescription ?? "",
                    systemImage: "exclamationmark.circle",
                    tint: MicaboColor.negative
                )
            }

            if YouTubeLink.isValid(link), !isChecking {
                Button("Voir l'aperçu", action: onCheck)
                    .buttonStyle(MicaboSecondaryButtonStyle())
                    .padding(.top, MicaboSpacing.xxs)
            }
        }
    }

    // MARK: - L'aperçu

    private func preview(_ video: YouTubeVideo) -> some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.sm) {
            VStack(alignment: .leading, spacing: 0) {
                thumbnail(video)

                VStack(alignment: .leading, spacing: 6) {
                    Text(video.title)
                        .font(MicaboFont.cardTitle)
                        .foregroundStyle(MicaboColor.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if let author = video.author.nilIfBlank {
                        Text(author)
                            .font(MicaboFont.caption)
                            .foregroundStyle(MicaboColor.inkTertiary)
                            .lineLimit(1)
                    }

                    if let caption = video.chosenCaption() {
                        MicaboBadge(text: captionLabel(caption), tone: .neutral)
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
            .micaboGroup(radius: MicaboRadius.group)

            if let reason = video.blockingReason?.errorDescription {
                message(reason, systemImage: "exclamationmark.triangle", tint: MicaboColor.caution)
            }

            Button("Changer de lien", action: onReset)
                .buttonStyle(MicaboQuietButtonStyle())
                .padding(.leading, -MicaboSpacing.md)
        }
    }

    private func thumbnail(_ video: YouTubeVideo) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Rectangle()
                .fill(MicaboColor.surfaceSunken)
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay {
                    AsyncImage(url: video.thumbnailURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure:
                            Image(systemName: "play.rectangle")
                                .font(.system(size: 26, weight: .regular))
                                .foregroundStyle(MicaboColor.inkTertiary)
                        case .empty:
                            ProgressView().tint(MicaboColor.progress)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                .clipped()

            if let duration = video.durationLabel {
                MicaboGlassChip(text: duration)
                    .padding(10)
            }
        }
    }

    /// « Sous-titres français », ou l'aveu qu'ils sont automatiques : un texte transcrit à
    /// la machine n'est pas ponctué, et les cartes qui en sortent s'en ressentent.
    private func captionLabel(_ caption: YouTubeCaptionLanguage) -> String {
        let name = caption.name.nilIfBlank ?? caption.code
        return caption.isAutomatic ? "Sous-titres automatiques · \(name)" : "Sous-titres · \(name)"
    }

    private func message(_ text: String, systemImage: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .padding(.top, 1)
            Text(text)
                .font(MicaboFont.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(tint)
    }
}
