import SwiftData
import SwiftUI

/// **Home** (`docs/refonte-parcours.md` § 3) : Mika demande ce qu'on veut apprendre, la barre
/// « comme une IA » et ses cinq imports, les trois chiffres mesurés, et « Reprendre ».
struct HomeView: View {
    @Environment(ProAccess.self) private var pro: ProAccess?
    @Query(sort: \Course.createdAt, order: .reverse) private var courses: [Course]

    @State private var path = NavigationPath()
    @State private var composer = LessonComposer()
    @State private var importRequest: LessonComposer.Kind?
    @State private var creating = false
    @State private var paywall: PaywallTrigger?
    @FocusState private var focused: Bool

    private var isPro: Bool { pro?.isPro ?? true }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HomeGreeting(isThinking: composer.isReading)
                    HomeComposerBar(
                        composer: composer,
                        focused: $focused,
                        isPro: isPro,
                        onImport: tapImport,
                        onSend: send
                    )
                    HomeStatsRow(stats: HomeStats(courses: courses))
                    if let resume = ResumeTarget.pick(from: courses) {
                        ResumeCard(course: resume.0, target: resume.1) {
                            path.append(resume.0)
                        }
                    }
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            .background(MicaboColor.canvas.ignoresSafeArea())
            .tabBarClearance()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Course.self) { course in
                LessonPathView(course: course)
            }
            .lessonImportPickers(composer, request: $importRequest)
            .fullScreenCover(isPresented: $creating) {
                LessonCreationFlow(composer: composer) { course in
                    creating = false
                    composer.reset()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { path.append(course) }
                } onCancel: {
                    creating = false
                }
            }
            .micaboPaywall($paywall)
        }
        .reportsNavigationDepth(for: .today, depth: path.count)
        .returnsHome(path: $path)
    }

    /// PDF, Photo, Audio et YouTube sont Pro ; un texte collé est la leçon offerte.
    private func tapImport(_ kind: LessonComposer.Kind) {
        if kind != .text && !isPro {
            focused = false
            paywall = .generateCourse
            return
        }
        importRequest = kind
    }

    private func send() {
        guard composer.canSend else { return }
        if let trigger = LessonAllowance.gate(isPro: isPro, source: composer.source, courses: courses) {
            focused = false
            paywall = trigger
            return
        }
        focused = false
        creating = true
    }
}

// MARK: - Mika

/// Mika, et sa question dans une bulle.
struct HomeGreeting: View {
    var isThinking = false

    @State private var mood: MikaMood = .wave

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            MikaMascot(mood: isThinking ? .think : mood, size: 104, reactsToTap: true)
            Text(L10n.t("lesson.home.question", locale: .resolved()))
                .font(MicaboFont.subtitle)
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(SpeechBubble().fill(MicaboColor.surface))
                .micaboElevation(.row)
                .padding(.bottom, 34)
        }
        .task {
            try? await Task.sleep(for: .seconds(2.4))
            mood = .idle
        }
    }
}

/// Une bulle dont la pointe part vers Mika, en bas à gauche.
struct SpeechBubble: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: rect, cornerRadius: 20, style: .continuous)
        path.move(to: CGPoint(x: rect.minX + 2, y: rect.maxY - 26))
        path.addQuadCurve(to: CGPoint(x: rect.minX - 12, y: rect.maxY - 2), control: CGPoint(x: rect.minX - 2, y: rect.maxY - 8))
        path.addQuadCurve(to: CGPoint(x: rect.minX + 18, y: rect.maxY - 6), control: CGPoint(x: rect.minX + 4, y: rect.maxY - 2))
        path.closeSubpath()
        return path
    }
}

// MARK: - La barre

/// La barre « comme une IA » : les supports déposés en pastilles au-dessus, le champ, la
/// flèche d'envoi, et les cinq imports dessous.
struct HomeComposerBar: View {
    let composer: LessonComposer
    var focused: FocusState<Bool>.Binding
    let isPro: Bool
    let onImport: (LessonComposer.Kind) -> Void
    let onSend: () -> Void

    var body: some View {
        @Bindable var composer = composer
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                if !composer.supports.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(composer.supports) { support in
                                SupportChip(support: support) {
                                    withAnimation(.spring(duration: 0.3)) { composer.remove(support.id) }
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    .scrollClipDisabled()
                    if let failure = composer.supports.compactMap(\.failure).last {
                        Text(failure)
                            .font(MicaboFont.ui(13, weight: .bold))
                            .foregroundStyle(MicaboColor.wrongInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(alignment: .bottom, spacing: 10) {
                    TextField(
                        composer.supports.isEmpty
                            ? L10n.t("lesson.home.placeholder", locale: .resolved())
                            : L10n.t("lesson.home.placeholderWithSupports", locale: .resolved()),
                        text: $composer.draft,
                        axis: .vertical
                    )
                    .font(MicaboFont.ui(18, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .lineLimit(1...4)
                    .focused(focused)
                    .submitLabel(.send)
                    .onSubmit(onSend)
                    .padding(.vertical, 10)

                    Button(action: onSend) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(MicaboColor.onInk)
                            .frame(width: 44, height: 44)
                            .background(composer.canSend ? MicaboColor.ink : MicaboColor.inkTertiary, in: Circle())
                    }
                    .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
                    .disabled(!composer.canSend)
                    .accessibilityLabel(Text(L10n.t("lesson.home.send", locale: .resolved())))
                }
            }
            .padding(.leading, 18)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(focused.wrappedValue ? MicaboColor.accent : MicaboColor.stroke, lineWidth: 1.5)
            )
            .micaboElevation(.card)
            .animation(.spring(duration: 0.3), value: composer.supports.count)

            HStack(spacing: 0) {
                ForEach(LessonComposer.Kind.allCases) { kind in
                    ImportButton(kind: kind, enabled: composer.hasRoom) { onImport(kind) }
                        .frame(maxWidth: .infinity)
                }
            }

            if !composer.hasRoom {
                Text(L10n.t("lesson.home.supportsFull", locale: .resolved(), vars: ["n": String(LessonComposer.maximumSupports)]))
                    .font(MicaboFont.ui(13, weight: .bold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private extension LessonComposer.Support {
    var failure: String? {
        if case .failed(let message) = state { return message }
        return nil
    }
}

/// Une icône d'import, et son nom dessous.
struct ImportButton: View {
    let kind: LessonComposer.Kind
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                MicaboIconView(icon: kind.icon, size: 34, dimmed: !enabled)
                    .frame(width: 58, height: 58)
                    .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1))
                Text(L10n.t(kind.titleKey, locale: .resolved()))
                    .font(MicaboFont.ui(12, weight: .heavy))
                    .foregroundStyle(enabled ? MicaboColor.ink : MicaboColor.inkTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(MicaboPressableButtonStyle())
    }
}

/// Un support déposé : son icône, son nom, et où en est sa lecture.
struct SupportChip: View {
    let support: LessonComposer.Support
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                if support.state == .reading {
                    ProgressView().controlSize(.small)
                } else {
                    MicaboIconView(icon: support.kind.icon, size: 22)
                }
            }
            .frame(width: 24, height: 24)
            Text(support.title)
                .font(MicaboFont.ui(14, weight: .bold))
                .foregroundStyle(isFailed ? MicaboColor.wrongInk : MicaboColor.ink)
                .lineLimit(1)
                .frame(maxWidth: 150, alignment: .leading)
            Button(action: onRemove) {
                Image(systemName: isFailed ? "exclamationmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isFailed ? MicaboColor.wrong : MicaboColor.inkTertiary)
            }
            .buttonStyle(MicaboPressableButtonStyle())
            .accessibilityLabel(Text(L10n.t("lesson.home.removeSupport", locale: .resolved())))
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .padding(.vertical, 7)
        .background(isFailed ? MicaboColor.wrongSoft : MicaboColor.canvas, in: Capsule())
        .overlay(Capsule().strokeBorder(isFailed ? MicaboColor.wrong.opacity(0.4) : MicaboColor.stroke, lineWidth: 1))
        .transition(.scale.combined(with: .opacity))
    }

    private var isFailed: Bool {
        if case .failed = support.state { return true }
        return false
    }
}

// MARK: - Les chiffres

/// X h de révision · X leçons apprises · X flashcards apprises.
struct HomeStatsRow: View {
    let stats: HomeStats

    var body: some View {
        HStack(spacing: 10) {
            tile(stats.formattedTime(), L10n.t("lesson.home.statTime", locale: .resolved()), icon: .hourglass)
            tile(String(stats.learnedLessons), L10n.t("lesson.home.statLessons", locale: .resolved()), icon: .diploma)
            tile(String(stats.learnedCards), L10n.t("lesson.home.statCards", locale: .resolved()), icon: .cards)
        }
    }

    private func tile(_ value: String, _ label: String, icon: MicaboIcon) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            MicaboIconView(icon: icon, size: 28)
            Text(value)
                .font(MicaboFont.number(24))
                .foregroundStyle(MicaboColor.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(MicaboFont.ui(12, weight: .bold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .micaboElevation(.row)
    }
}

// MARK: - Reprendre

/// La dernière leçon ouverte : son anneau, son titre, le cercle où elle attend.
struct ResumeCard: View {
    let course: Course
    let target: ResumeTarget
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(MicaboColor.track, lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: max(0.02, CGFloat(target.percent) / 100))
                        .stroke(course.tone.vivid, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    MicaboIconView(icon: course.icon, size: 36)
                }
                .frame(width: 60, height: 60)

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("lesson.home.resume", locale: .resolved()))
                        .font(MicaboFont.small)
                        .tracking(MicaboTracking.caps)
                        .textCase(.uppercase)
                        .foregroundStyle(course.tone.ink)
                    Text(target.title)
                        .font(MicaboFont.label)
                        .foregroundStyle(MicaboColor.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(MicaboFont.ui(14, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(MicaboColor.onInk)
                    .frame(width: 40, height: 40)
                    .background(MicaboColor.ink, in: Circle())
            }
            .padding(16)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .micaboElevation(.card)
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .soft))
    }

    private var subtitle: String {
        guard let number = target.circleNumber, let title = target.circleTitle else {
            return L10n.t("lesson.home.resumeDone", locale: .resolved())
        }
        return L10n.t("lesson.home.resumeCircle", locale: .resolved(), vars: ["n": String(number), "title": title])
    }
}
