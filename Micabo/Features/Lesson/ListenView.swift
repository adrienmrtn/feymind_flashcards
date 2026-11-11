import SwiftUI

/// **Écouter la leçon** (`docs/supports.md`) : la leçon lue à voix haute, dans la voix de sa
/// langue, chapitre par chapitre. La phrase lue s'affiche en grand ; lecture, pause,
/// chapitre précédent ou suivant, trois vitesses ; la liste des chapitres pour sauter. La
/// lecture continue écran verrouillé (`LessonSpeaker`).
struct ListenView: View {
    let lessonTitle: String
    let icon: MicaboIcon
    let tone: LessonTone

    @Environment(\.dismiss) private var dismiss
    @Environment(\.homeStill) private var still
    @State private var speaker: LessonSpeaker

    init(course: Course) {
        let digest = LessonDigest(course: course)
        self.init(
            digest: digest,
            icon: course.icon,
            tone: course.tone,
            language: AudioTranscriber.locale(for: course.writingLanguage).identifier.replacingOccurrences(of: "_", with: "-")
        )
    }

    init(digest: LessonDigest, icon: MicaboIcon, tone: LessonTone, language: String) {
        lessonTitle = digest.title
        self.icon = icon
        self.tone = tone
        _speaker = State(initialValue: LessonSpeaker(script: ListeningScript(digest: digest), title: digest.title, language: language))
    }

    var body: some View {
        VStack(spacing: 0) {
            RevisionModeHeader(mode: .listen, lessonTitle: lessonTitle) {
                speaker.stop()
                dismiss()
            }
            if speaker.script.chapters.isEmpty {
                empty
            } else if still {
                content
            } else {
                ScrollView {
                    content
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
        .onDisappear { speaker.stop() }
    }

    /// Le contenu, sans défilement : les rendus le posent seul.
    var content: some View {
        VStack(spacing: 22) {
            ListenPlayerCard(speaker: speaker, icon: icon, tone: tone)
            chapters
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 32)
    }

    private var chapters: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("ios.sup.listen.chapters", locale: .resolved()))
                .font(MicaboFont.ui(13, weight: .heavy))
                .foregroundStyle(MicaboColor.inkSecondary)
                .textCase(.uppercase)
                .tracking(0.6)
            VStack(spacing: 0) {
                ForEach(Array(speaker.script.chapters.enumerated()), id: \.offset) { index, chapter in
                    if index > 0 {
                        Rectangle().fill(MicaboColor.hairline).frame(height: 1).padding(.leading, 56)
                    }
                    Button {
                        speaker.jump(to: index)
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle().fill(index == speaker.chapter ? tone.vivid : MicaboColor.surfaceSunken)
                                if index == speaker.chapter && speaker.isPlaying {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white)
                                } else {
                                    Text(verbatim: String(index + 1))
                                        .font(MicaboFont.ui(14, weight: .black))
                                        .foregroundStyle(index == speaker.chapter ? .white : MicaboColor.inkSecondary)
                                }
                            }
                            .frame(width: 32, height: 32)
                            Text(chapter.title)
                                .font(MicaboFont.ui(16, weight: index == speaker.chapter ? .heavy : .semibold))
                                .foregroundStyle(MicaboColor.ink)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MicaboPressableButtonStyle())
                }
            }
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1))
        }
    }

    private var empty: some View {
        VStack(spacing: 14) {
            Spacer()
            MikaMascot(mood: .think, size: 140, frame: .circle)
            Text(L10n.t("ios.sup.listen.empty", locale: .resolved()))
                .font(MicaboFont.ui(17, weight: .bold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

/// Le lecteur : la leçon, le chapitre, la phrase lue, la barre, les commandes, la vitesse.
struct ListenPlayerCard: View {
    let speaker: LessonSpeaker
    let icon: MicaboIcon
    let tone: LessonTone

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                MicaboIconView(icon: icon, size: 44)
                    .frame(width: 58, height: 58)
                    .background(MicaboColor.surface.opacity(0.75), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("ios.sup.listen.chapterOf", locale: .resolved(), vars: [
                        "n": String(speaker.chapter + 1),
                        "total": String(speaker.script.chapters.count),
                    ]))
                    .font(MicaboFont.ui(13, weight: .heavy))
                    .foregroundStyle(tone.ink)
                    Text(currentChapterTitle)
                        .font(MicaboFont.ui(18, weight: .black))
                        .foregroundStyle(MicaboColor.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            Text(speaker.shownLine ?? "")
                .font(MicaboFont.ui(20, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.leading)
                .lineLimit(5)
                .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.easeInOut(duration: 0.2), value: speaker.shownLine)

            VStack(spacing: 6) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(MicaboColor.surface.opacity(0.7))
                        Capsule().fill(tone.vivid)
                            .frame(width: max(8, proxy.size.width * speaker.progress))
                    }
                }
                .frame(height: 8)
                HStack {
                    Text(L10n.t("ios.sup.listen.minutes", locale: .resolved(), vars: ["count": String(speaker.script.minutes(rate: speaker.rate))]))
                    Spacer()
                    Text(L10n.t("ios.sup.listen.background", locale: .resolved()))
                        .multilineTextAlignment(.trailing)
                }
                .font(MicaboFont.ui(12, weight: .bold))
                .foregroundStyle(MicaboColor.inkSecondary)
            }

            HStack(spacing: 28) {
                control("backward.end.fill", label: "ios.sup.listen.previous") { speaker.previousChapter() }
                Button {
                    speaker.toggle()
                } label: {
                    Image(systemName: speaker.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 76, height: 76)
                        .background(MicaboColor.accent, in: Circle())
                        .shadow(color: MicaboColor.accent.opacity(0.3), radius: 14, y: 8)
                }
                .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
                .accessibilityLabel(Text(L10n.t(speaker.isPlaying ? "ios.sup.listen.pause" : "ios.sup.listen.play", locale: .resolved())))
                control("forward.end.fill", label: "ios.sup.listen.next") { speaker.nextChapter() }
            }
            .environment(\.layoutDirection, .leftToRight)

            HStack(spacing: 8) {
                ForEach(LessonSpeaker.rates, id: \.self) { rate in
                    Button {
                        speaker.setRate(rate)
                    } label: {
                        Text(Self.rateLabel(rate))
                            .font(MicaboFont.ui(15, weight: .heavy))
                            .foregroundStyle(rate == speaker.rate ? .white : MicaboColor.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(rate == speaker.rate ? MicaboColor.ink : MicaboColor.surface.opacity(0.8), in: Capsule())
                    }
                    .buttonStyle(MicaboPressableButtonStyle())
                    .accessibilityLabel(Text(L10n.t("ios.sup.listen.speed", locale: .resolved(), vars: ["speed": Self.rateLabel(rate)])))
                }
            }
        }
        .padding(20)
        .background(tone.pale, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var currentChapterTitle: String {
        speaker.script.chapters.indices.contains(speaker.chapter) ? speaker.script.chapters[speaker.chapter].title : ""
    }

    private func control(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .frame(width: 52, height: 52)
                .background(MicaboColor.surface.opacity(0.85), in: Circle())
        }
        .buttonStyle(MicaboPressableButtonStyle())
        .accessibilityLabel(Text(L10n.t(label, locale: .resolved())))
    }

    /// « 1× », « 1,25× » : la virgule ou le point de la langue de l'app.
    static func rateLabel(_ rate: Double) -> String {
        let number = rate.formatted(.number.precision(.fractionLength(0...2)).locale(UiLocale.resolved().foundation))
        return "\(number)×"
    }
}
