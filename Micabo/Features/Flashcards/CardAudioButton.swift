import AVFoundation
import SwiftUI

/// Bouton de lecture de la prononciation attachée à une carte.
///
/// Rien n'est demandé au système : le son est déjà dans la carte, on ne fait que le lire.
/// Pas de micro, donc pas d'autorisation à accorder pour réviser.
struct CardAudioButton: View {
    let card: Flashcard
    var title: String = "Écouter"

    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false

    var body: some View {
        Button(action: play) {
            HStack(spacing: 7) {
                Image(systemName: isPlaying ? "speaker.wave.2.fill" : "speaker.wave.2")
                    .font(.system(size: 13, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))

                Text(title)
                    .font(MicaboFont.hanken(13, weight: .semibold))
            }
            .foregroundStyle(MicaboColor.accent)
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .background(MicaboColor.accentSoft, in: Capsule())
        }
        .buttonStyle(MicaboPressableButtonStyle())
        .accessibilityLabel("Écouter la prononciation")
        .onDisappear {
            player?.stop()
            isPlaying = false
        }
    }

    private func play() {
        guard let data = card.audioData else { return }

        do {
            let player = try AVAudioPlayer(data: data)
            self.player = player
            player.prepareToPlay()
            player.play()
            isPlaying = true

            // Pas de délégué à installer pour si peu : on remet l'icône à sa place quand
            // le son est fini.
            DispatchQueue.main.asyncAfter(deadline: .now() + player.duration + 0.1) {
                isPlaying = false
            }
        } catch {
            isPlaying = false
        }
    }
}
