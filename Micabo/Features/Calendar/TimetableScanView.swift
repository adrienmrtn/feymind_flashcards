import SwiftUI
import UIKit

/// **Scanner mon emploi du temps** : une photo, lue sur l'appareil (`OnDeviceOCR`, celui des
/// imports, avec la place de chaque mot), puis confiée à Mika (`mika-chat`) qui rend les cours
/// de la semaine. L'élève relit la liste, corrige, supprime, ajoute, et enregistre : chaque
/// cours revient chaque semaine dans le calendrier.
///
/// La demande passe par la porte de Mika (`MikaQuota`) : la question offerte d'abord, puis
/// le paywall `mika`. Elle ne s'écrit dans aucune conversation.
struct TimetableScanView: View {
    let image: UIImage
    let onConfirm: ([TimetableEntry]) -> Void

    @Environment(\.aiService) private var aiService
    @Environment(ProAccess.self) private var pro: ProAccess?

    enum Phase: Equatable {
        case reading
        case asking
        case review
        case unreadable
        case empty
        case failed(String)
        case locked
    }

    /// En dessous, la photo n'a rien donné de lisible.
    static let minimumCharacters = 20

    @State private var phase: Phase = .reading
    @State private var entries: [TimetableEntry] = []
    @State private var text = ""
    @State private var paywall: PaywallTrigger?
    @State private var worker: Task<Void, Never>?

    var body: some View {
        Group {
            switch phase {
            case .reading, .asking:
                waiting
            case .review:
                TimetableReview(entries: $entries, onConfirm: confirm)
            case .unreadable:
                problem(loc("ios.cal.scanUnreadable"), mood: .sad, retry: false)
            case .empty:
                problem(loc("ios.cal.scanEmpty"), mood: .think, retry: true)
            case .failed(let message):
                problem(message, mood: .sad, retry: true)
            case .locked:
                problem(loc("ios.cal.scanLocked"), mood: .wink, retry: true)
            }
        }
        .animation(.spring(duration: 0.4), value: phase)
        .background(MicaboColor.canvas.ignoresSafeArea())
        .navigationTitle(loc("ios.cal.scanTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .micaboPaywall($paywall) {
            // Abonné à l'instant : la demande repart d'elle-même.
            ask()
        }
        .task {
            guard phase == .reading, worker == nil else { return }
            read()
        }
        .onDisappear { worker?.cancel() }
    }

    // MARK: Les états

    private var waiting: some View {
        VStack(spacing: 18) {
            Spacer()
            MikaMascot(mood: phase == .reading ? .look : .write, size: 128)
            Text(loc(phase == .reading ? "ios.cal.scanReading" : "ios.cal.scanAsking"))
                .font(MicaboFont.ui(19, weight: .black))
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
            ProgressView()
                .tint(MicaboColor.accent)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }

    private func problem(_ message: String, mood: MikaMood, retry: Bool) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            MicaboSpeechBubble(text: message, tail: .bottom)
                .padding(.horizontal, 28)
            MikaMascot(mood: mood, size: 120)
                .padding(.top, 16)
            Spacer(minLength: 12)
            VStack(spacing: 10) {
                if retry {
                    Button(loc("ios.cal.scanRetry"), action: ask)
                        .buttonStyle(MicaboBrandButtonStyle())
                }
                Button(loc("ios.cal.scanManual")) {
                    entries = [TimetableEntry(weekday: 1, startMinute: 8 * 60, endMinute: 9 * 60, title: "", room: "")]
                    phase = .review
                }
                .buttonStyle(MicaboSecondaryButtonStyle())
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.bottom, 16)
        }
    }

    // MARK: Lire, puis demander

    private func read() {
        phase = .reading
        worker?.cancel()
        worker = Task {
            let layout = await OnDeviceOCR.recognizeLayout(in: image)
            guard !Task.isCancelled else { return }
            guard layout.count >= Self.minimumCharacters else {
                Haptics.warning()
                Analytics.track(.timetableScanned, ["result": .text("unreadable")])
                phase = .unreadable
                return
            }
            text = layout
            ask()
        }
    }

    private func ask() {
        guard !text.isEmpty else {
            phase = .unreadable
            return
        }
        let isPro = pro?.isPro ?? false
        let quota = MikaQuota()
        guard quota.gate(isPro: isPro) == .allowed else {
            let capped = quota.gate(isPro: isPro) == .dailyCapReached
            Analytics.track(.mikaBlocked, ["reason": .text(capped ? "cap" : "paywall"), "from": .text("timetable")])
            if capped {
                phase = .failed(L10n.t("lesson.mika.capReached", locale: .resolved()))
            } else {
                phase = .locked
                paywall = .mika
            }
            return
        }
        phase = .asking
        worker?.cancel()
        let snapshot = text
        worker = Task {
            let chat = MikaChat(
                conversation: MikaConversation(messages: [], attachment: MikaAttachment(
                    kind: .document,
                    title: loc("ios.cal.scanAttachment"),
                    text: String(snapshot.prefix(MikaLimits.attachmentCharacters)),
                    courseID: nil,
                    emoji: nil
                )),
                store: { _ in },
                xp: nil
            )
            chat.draft = TimetableParser.instruction
            let gate = await chat.send(isPro: isPro, level: nil, language: language, using: aiService)
            guard !Task.isCancelled else { return }
            if gate == .paywall {
                phase = .locked
                paywall = .mika
                return
            }
            if let failure = chat.failure {
                phase = .failed(failure)
                Analytics.track(.timetableScanned, ["result": .text("failed")])
                return
            }
            let reply = chat.messages.last { $0.role == .mika }?.text ?? ""
            let found = TimetableParser.entries(from: reply)
            Analytics.track(.timetableScanned, ["result": .text(found.isEmpty ? "empty" : "ok"), "count": .number(Double(found.count))])
            if found.isEmpty {
                Haptics.warning()
                phase = .empty
            } else {
                Haptics.success()
                entries = found
                phase = .review
            }
        }
    }

    private func confirm() {
        let valid = entries.filter(\.isValid)
        guard !valid.isEmpty else { return }
        onConfirm(valid)
    }

    /// Mika répond dans la langue de l'app.
    private var language: ContentLanguage {
        ContentLanguage(rawValue: UiLocale.resolved().rawValue) ?? DeckSetup.defaultLanguage()
    }
}

// MARK: - La relecture

/// **La liste à relire** : un cours par carte, le jour, les heures, la matière, la salle. Tout
/// se corrige, une ligne se supprime, une autre s'ajoute.
struct TimetableReview: View {
    @Binding var entries: [TimetableEntry]
    let onConfirm: () -> Void

    var body: some View {
        ScrollView {
            TimetableReviewContent(entries: $entries)
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            TimetableSaveButton(count: entries.filter(\.isValid).count, onConfirm: onConfirm)
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.vertical, 8)
                .background(MicaboColor.canvas)
        }
    }
}

/// « Ajouter N cours ».
struct TimetableSaveButton: View {
    let count: Int
    let onConfirm: () -> Void

    var body: some View {
        Button(loc("ios.cal.scanSave", ["count": "\(count)"]), action: onConfirm)
            .buttonStyle(MicaboBrandButtonStyle())
            .disabled(count == 0)
    }
}

/// Le contenu de la relecture, sans défilement : la page le fait défiler, les rendus le
/// dessinent d'un bloc.
struct TimetableReviewContent: View {
    @Binding var entries: [TimetableEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                MikaAvatar(size: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc("ios.cal.scanFound", ["count": "\(entries.count)"]))
                        .font(MicaboFont.ui(18, weight: .black))
                        .foregroundStyle(MicaboColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(loc("ios.cal.scanDisclaimer"))
                        .font(MicaboFont.ui(13.5, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            ForEach(groupedDays, id: \.self) { weekday in
                VStack(alignment: .leading, spacing: 8) {
                    StudyFieldLabel(text: MicaboCalendar.weekdayName(weekday))
                    ForEach($entries) { $entry in
                        if entry.weekday == weekday {
                            TimetableEntryRow(entry: $entry) {
                                withAnimation { entries.removeAll { $0.id == entry.id } }
                            }
                        }
                    }
                }
            }
            Button {
                let last = entries.last
                withAnimation {
                    entries.append(TimetableEntry(
                        weekday: last?.weekday ?? 1,
                        startMinute: last?.endMinute ?? 8 * 60,
                        endMinute: min(CalendarTime.dayMinutes - 1, (last?.endMinute ?? 8 * 60) + 60),
                        title: "",
                        room: ""
                    ))
                }
            } label: {
                Label(loc("ios.cal.scanAddRow"), systemImage: "plus")
                    .font(MicaboFont.ui(15, weight: .black))
                    .foregroundStyle(MicaboColor.accentInk)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(MicaboColor.accentSoft, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(HomePressStyle(scale: 0.97))
        }
    }

    private var groupedDays: [Int] {
        Array(Set(entries.map(\.weekday))).sorted()
    }
}

/// Un cours lu, à relire.
struct TimetableEntryRow: View {
    @Binding var entry: TimetableEntry
    let onDelete: () -> Void

    @Environment(\.homeStill) private var still

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                dayMenu
                timeButton(minute: $entry.startMinute)
                Text("–")
                    .font(MicaboFont.ui(15, weight: .bold))
                    .foregroundStyle(MicaboColor.inkTertiary)
                timeButton(minute: $entry.endMinute)
                Spacer(minLength: 0)
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(MicaboColor.wrongInk)
                        .frame(width: 34, height: 34)
                        .background(MicaboColor.wrongSoft, in: Circle())
                }
                .buttonStyle(HomePressStyle(scale: 0.9, feedback: .warning))
                .accessibilityLabel(Text(loc("ios.cal.deleteRow")))
            }
            HStack(spacing: 8) {
                StudyTextField(placeholder: loc("ios.cal.subjectPlaceholder"), text: $entry.title, size: 16)
                StudyTextField(placeholder: loc("ios.cal.roomPlaceholder"), text: $entry.room, size: 16)
                    .frame(width: 104)
            }
            if entry.startMinute >= entry.endMinute {
                Text(loc("ios.cal.timeInvalid"))
                    .font(MicaboFont.ui(12.5, weight: .bold))
                    .foregroundStyle(MicaboColor.wrongInk)
            }
        }
        .padding(12)
        .background(MicaboColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var dayMenu: some View {
        if still {
            dayLabel
        } else {
            Menu {
                ForEach(1...7, id: \.self) { weekday in
                    Button(MicaboCalendar.weekdayName(weekday)) { entry.weekday = weekday }
                }
            } label: {
                dayLabel
            }
        }
    }

    private var dayLabel: some View {
        HStack(spacing: 4) {
            Text(MicaboCalendar.weekdayName(entry.weekday))
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10, weight: .bold))
        }
        .font(MicaboFont.ui(14, weight: .black))
        .foregroundStyle(MicaboColor.accentInk)
        .padding(.horizontal, 10)
        .frame(minHeight: 34)
        .background(MicaboColor.accentSoft, in: Capsule())
    }

    @ViewBuilder
    private func timeButton(minute: Binding<Int>) -> some View {
        if still {
            Text(CalendarTime.label(minute: minute.wrappedValue))
                .font(MicaboFont.ui(14.5, weight: .black))
                .foregroundStyle(MicaboColor.ink)
                .monospacedDigit()
                .padding(.horizontal, 10)
                .frame(minHeight: 34)
                .background(MicaboColor.surface, in: Capsule())
        } else {
            DatePicker(
                "",
                selection: Binding(
                    get: { CalendarTime.date(minute: minute.wrappedValue, on: Date()) },
                    set: { minute.wrappedValue = CalendarTime.minute(of: $0) }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .tint(MicaboColor.accent)
        }
    }
}
