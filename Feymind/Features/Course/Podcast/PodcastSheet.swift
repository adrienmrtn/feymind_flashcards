import SwiftData
import SwiftUI

/// Panneau podcast : choix des deux voix, génération, puis lecture.
struct PodcastSheet: View {
    @Bindable var course: Course

    @Environment(\.aiService) private var aiService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var hostVoice = PodcastVoice.defaultHost
    @State private var guestVoice = PodcastVoice.defaultGuest
    @State private var targetMinutes = 5
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var player = PodcastPlayer()
    @State private var activePodcast: CoursePodcast?

    private var accent: Color { Color(hexString: course.accentHex) }

    var body: some View {
        NavigationStack {
            Group {
                if let podcast = activePodcast {
                    playerView(podcast)
                } else {
                    setupView
                }
            }
            .feyScreenBackground()
            .navigationTitle("Podcast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        player.stop()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(FeyColor.inkTertiary)
                    }
                }
            }
            .overlay {
                if isGenerating {
                    GenerationOverlay(
                        title: "Enregistrement du podcast",
                        steps: [
                            "Écriture du script à deux voix",
                            "Voix de \(hostVoice.label)",
                            "Voix de \(guestVoice.label)",
                            "Assemblage des répliques"
                        ],
                        accent: accent
                    )
                }
            }
            .alert("Génération impossible", isPresented: .constant(errorMessage != nil)) {
                Button("Fermer", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear {
                if let existing = course.latestPodcast {
                    hostVoice = existing.hostVoice
                    guestVoice = existing.guestVoice
                    activePodcast = existing
                    player.load(existing)
                }
            }
            .onDisappear { player.stop() }
        }
    }

    // MARK: - Configuration

    private var setupView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FeySpacing.lg) {
                introCard
                voicePickers
                durationPicker
                costNote

                Button {
                    Task { await generate() }
                } label: {
                    HStack(spacing: FeySpacing.xs) {
                        Image(systemName: "waveform")
                        Text("Générer le podcast")
                    }
                }
                .buttonStyle(FeyPrimaryButtonStyle(tint: accent))
                .disabled(isGenerating)
            }
            .padding(.horizontal, FeySpacing.screen)
            .padding(.vertical, FeySpacing.md)
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: FeySpacing.sm) {
            HStack(spacing: FeySpacing.xs) {
                Image(systemName: "headphones")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(accent, in: RoundedRectangle(cornerRadius: FeyRadius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Écouter le cours")
                        .font(FeyFont.cardTitle)
                        .foregroundStyle(FeyColor.ink)
                    Text("Deux voix discutent le cours comme un vrai podcast.")
                        .font(FeyFont.caption)
                        .foregroundStyle(FeyColor.inkTertiary)
                }
            }
        }
        .feyCard(padding: FeySpacing.md, radius: FeyRadius.lg, elevated: false)
    }

    private var voicePickers: some View {
        VStack(alignment: .leading, spacing: FeySpacing.md) {
            FeySectionHeader(title: "Les deux voix")

            voicePicker(title: "Animateur", selection: $hostVoice)
            voicePicker(title: "Expert", selection: $guestVoice)

            if hostVoice.id == guestVoice.id {
                Label("Choisissez deux voix différentes pour un vrai dialogue.", systemImage: "exclamationmark.circle")
                    .font(FeyFont.caption)
                    .foregroundStyle(FeyColor.amber)
            }
        }
    }

    private func voicePicker(title: String, selection: Binding<PodcastVoice>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(FeyFont.caption)
                .foregroundStyle(FeyColor.inkTertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FeySpacing.xs) {
                    ForEach(PodcastVoice.catalog) { voice in
                        Button {
                            selection.wrappedValue = voice
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(voice.label)
                                    .font(FeyFont.caption)
                                    .foregroundStyle(selection.wrappedValue.id == voice.id ? .white : FeyColor.ink)
                                Text(voice.vibe)
                                    .font(FeyFont.micro)
                                    .foregroundStyle(selection.wrappedValue.id == voice.id ? Color.white.opacity(0.8) : FeyColor.inkTertiary)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(
                                selection.wrappedValue.id == voice.id ? accent : FeyColor.surfaceMuted,
                                in: RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: FeySpacing.xs) {
            FeySectionHeader(title: "Durée", subtitle: "Plus court = moins cher")

            Picker("Durée", selection: $targetMinutes) {
                Text("3 min").tag(3)
                Text("5 min").tag(5)
                Text("7 min").tag(7)
            }
            .pickerStyle(.segmented)
        }
    }

    private var costNote: some View {
        HStack(alignment: .top, spacing: FeySpacing.xs) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(FeyColor.mint)
                .padding(.top, 2)
            Text("Génération économe : script court via Gemini Flash, voix MiniMax Turbo (~0,06 $/1k caractères). Un podcast de 5 min coûte en général moins de 0,25 $.")
                .font(FeyFont.micro)
                .foregroundStyle(FeyColor.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Lecteur

    private func playerView(_ podcast: CoursePodcast) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: FeySpacing.md) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(podcast.title)
                            .font(FeyFont.screenTitle)
                            .foregroundStyle(FeyColor.ink)
                        Text("\(podcast.hostVoice.label) × \(podcast.guestVoice.label) · \(podcast.durationLabel)")
                            .font(FeyFont.caption)
                            .foregroundStyle(FeyColor.inkTertiary)
                    }

                    progressCard

                    transcript
                }
                .padding(.horizontal, FeySpacing.screen)
                .padding(.top, FeySpacing.sm)
                .padding(.bottom, 140)
            }

            controlsBar(podcast)
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: FeySpacing.sm) {
            FeyProgressBar(progress: player.overallProgress, tint: accent)

            HStack {
                Text(player.overallLabel)
                    .font(FeyFont.micro)
                    .foregroundStyle(FeyColor.inkTertiary)
                Spacer()
                if player.isBuffering {
                    ProgressView()
                        .controlSize(.small)
                } else if let segment = player.currentSegment {
                    Text(segment.speaker == "guest" ? guestVoice.label : hostVoice.label)
                        .font(FeyFont.micro)
                        .foregroundStyle(accent)
                }
            }

            if let text = player.currentSegment?.text {
                Text(text)
                    .font(FeyFont.body)
                    .foregroundStyle(FeyColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .feyCard(padding: FeySpacing.md, radius: FeyRadius.lg, elevated: false)
    }

    private var transcript: some View {
        VStack(alignment: .leading, spacing: FeySpacing.sm) {
            FeySectionHeader(title: "Script")

            ForEach(Array((activePodcast?.segments ?? []).enumerated()), id: \.element.id) { index, segment in
                Button {
                    player.jump(to: index)
                    player.play()
                } label: {
                    HStack(alignment: .top, spacing: FeySpacing.sm) {
                        Circle()
                            .fill(index == player.currentIndex ? accent : FeyColor.surfaceSunken)
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(segment.speaker == "guest" ? guestVoice.label : hostVoice.label)
                                .font(FeyFont.micro)
                                .foregroundStyle(index == player.currentIndex ? accent : FeyColor.inkTertiary)
                            Text(segment.text)
                                .font(.system(size: 15))
                                .foregroundStyle(FeyColor.inkSecondary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(FeySpacing.sm)
                    .background(
                        index == player.currentIndex ? accent.opacity(0.06) : FeyColor.surface,
                        in: RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func controlsBar(_ podcast: CoursePodcast) -> some View {
        VStack(spacing: FeySpacing.sm) {
            HStack(spacing: FeySpacing.xl) {
                Button { player.skipBackward() } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(FeyColor.inkSecondary)
                }

                Button { player.toggle() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(accent, in: Circle())
                        .shadow(color: accent.opacity(0.3), radius: 12, x: 0, y: 6)
                }

                Button { player.skipForward() } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(FeyColor.inkSecondary)
                }
            }

            Button("Régénérer avec d'autres voix") {
                player.stop()
                activePodcast = nil
            }
            .font(FeyFont.caption)
            .foregroundStyle(FeyColor.inkTertiary)
        }
        .padding(.horizontal, FeySpacing.screen)
        .padding(.top, FeySpacing.sm)
        .padding(.bottom, FeySpacing.md)
        .background(FeyColor.canvas)
    }

    // MARK: - Génération

    @MainActor
    private func generate() async {
        guard !isGenerating else { return }
        guard hostVoice.id != guestVoice.id else {
            errorMessage = "Choisissez deux voix différentes."
            return
        }

        isGenerating = true
        defer { isGenerating = false }

        let request = PodcastGenerationRequest(
            courseTitle: course.title,
            courseContext: course.contextSnippet(limit: 18_000),
            hostVoiceId: hostVoice.id,
            guestVoiceId: guestVoice.id,
            targetMinutes: targetMinutes
        )

        do {
            let generated = try await aiService.generatePodcast(request)
            let podcast = CoursePodcast(
                title: generated.title,
                hostVoiceId: generated.hostVoiceId,
                guestVoiceId: generated.guestVoiceId,
                segments: generated.segments,
                course: course
            )
            modelContext.insert(podcast)
            course.updatedAt = Date()
            try modelContext.save()

            activePodcast = podcast
            player.load(podcast)
            player.play()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
