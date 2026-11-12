import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// Les emojis proposés pour un calendrier : l'école, les matières, la vie autour.
enum CalendarEmoji {
    static let all = [
        "🏫", "📚", "📖", "✏️", "🧪", "🔬", "🧮", "📐", "🌍", "🗺️",
        "🎨", "🎵", "🎭", "⚽", "🏀", "🏊", "🧘", "💻", "🗣️", "🌐",
        "🧠", "💼", "🏠", "❤️", "⭐", "🎓", "📝", "🗓️", "☕", "🚌",
    ]
}

/// **Un champ de saisie de l'onglet**, qui se dessine en texte dans les rendus de la CI
/// (`ImageRenderer` ne dessine pas les champs UIKit).
struct StudyTextField: View {
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal
    var size: CGFloat = 17

    @Environment(\.homeStill) private var still

    var body: some View {
        Group {
            if still {
                Text(text.isEmpty ? placeholder : text)
                    .foregroundStyle(text.isEmpty ? MicaboColor.inkTertiary : MicaboColor.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField(placeholder, text: $text, axis: axis)
                    .foregroundStyle(MicaboColor.ink)
                    .tint(MicaboColor.accent)
                    .lineLimit(axis == .vertical ? 1...4 : 1...1)
            }
        }
        .font(MicaboFont.ui(size, weight: .semibold))
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: MicaboSurface.border))
    }
}

/// L'étiquette en capitales au-dessus d'un champ.
struct StudyFieldLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(MicaboFont.ui(12.5, weight: .black))
            .tracking(MicaboTracking.caps)
            .textCase(.uppercase)
            .foregroundStyle(MicaboColor.inkSecondary)
            .accessibilityAddTraits(.isHeader)
    }
}

/// **Les douze couleurs**, en deux rangées de six. La couleur choisie porte une coche.
struct CalendarColorGrid: View {
    @Binding var selection: Int

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(CalendarTint.all) { tint in
                let isOn = tint.id == selection
                Button {
                    selection = tint.id
                } label: {
                    RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous)
                        .fill(tint.color)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            if isOn {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .black))
                                    .foregroundStyle(Color.white)
                            }
                        }
                        .padding(isOn ? 3 : 0)
                        .overlay {
                            if isOn {
                                RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous)
                                    .strokeBorder(tint.color, lineWidth: 2.5)
                            }
                        }
                }
                .buttonStyle(HomePressStyle(scale: 0.9, feedback: .selection))
                .accessibilityLabel(Text(loc("ios.cal.colorA11y", ["n": "\(tint.id + 1)"])))
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}

/// Le bloc « Scanner mon emploi du temps » : deux boutons, la consigne de la photo, et la
/// phrase qui prévient qu'on pourra tout ajuster.
struct TimetableScanButtons: View {
    let canUseCamera: Bool
    let onCamera: () -> Void
    let onLibrary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if canUseCamera {
                    button(loc("ios.cal.scanCamera"), symbol: "camera.fill", action: onCamera)
                }
                button(loc("ios.cal.scanLibrary"), symbol: "photo.on.rectangle", action: onLibrary)
            }
            Text(loc("ios.cal.scanHint"))
                .font(MicaboFont.ui(13.5, weight: .semibold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MicaboColor.accentInk)
                    .padding(.top, 2)
                Text(loc("ios.cal.scanDisclaimer"))
                    .font(MicaboFont.ui(13, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func button(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(MicaboColor.accentInk)
                Text(title)
                    .font(MicaboFont.ui(14, weight: .black))
                    .foregroundStyle(MicaboColor.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: MicaboSurface.border))
        }
        .buttonStyle(HomePressStyle(scale: 0.96, feedback: .medium))
    }
}

/// Ce que la feuille d'un calendrier modifie.
enum CalendarEditTarget: Identifiable {
    case new(scan: Bool)
    /// Un calendrier existant ; `scan` ouvre l'appareil photo d'emblée, pour remplir
    /// « Cours » plutôt que d'en créer un second.
    case edit(StudyCalendar, scan: Bool = false)

    var id: String {
        switch self {
        case .new(let scan): scan ? "new-scan" : "new"
        case .edit(let calendar, let scan): calendar.id.uuidString + (scan ? "-scan" : "")
        }
    }

    var scans: Bool {
        switch self {
        case .new(let scan), .edit(_, let scan): scan
        }
    }
}

/// **« Nouveau calendrier » / « Modifier le calendrier »** : le nom et son emoji, les douze
/// couleurs, l'affichage, et le scanner d'emploi du temps qui le remplit d'un coup.
struct CalendarEditSheet: View {
    let target: CalendarEditTarget

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var emoji = "📚"
    @State private var color = CalendarTint.revisionIndex
    @State private var isVisible = true
    @State private var showsEmoji = false
    @State private var loaded = false
    @State private var saved = false
    @State private var confirmDelete = false
    @State private var showScanner = false
    @State private var showPhotoPicker = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var scanImage: ScanImage?

    private var existing: StudyCalendar? {
        if case .edit(let calendar, _) = target { return calendar }
        return nil
    }

    private var canUseCamera: Bool {
        DocumentCameraView.isSupported && CameraAccess.allowsScanner(CameraAccess.status)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                CalendarEditForm(
                    name: $name,
                    emoji: $emoji,
                    color: $color,
                    isVisible: $isVisible,
                    showsEmoji: $showsEmoji,
                    showsVisibility: existing != nil,
                    canUseCamera: canUseCamera,
                    onCamera: openCamera,
                    onLibrary: { showPhotoPicker = true }
                )
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.vertical, 16)

                if existing != nil {
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label(loc("ios.cal.deleteCalendar"), systemImage: "trash")
                            .font(MicaboFont.ui(16, weight: .bold))
                            .foregroundStyle(MicaboColor.wrongInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(MicaboPressableButtonStyle())
                    .padding(.horizontal, MicaboSpacing.screen)
                }
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(MicaboColor.canvas.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Button(loc(existing == nil ? "ios.cal.createCalendar" : "ios.cal.save"), action: save)
                    .buttonStyle(MicaboBrandButtonStyle())
                    .disabled(!canSave)
                    .padding(.horizontal, MicaboSpacing.screen)
                    .padding(.vertical, 8)
                    .background(MicaboColor.canvas)
            }
            .navigationTitle(loc(existing == nil ? "ios.cal.newCalendar" : "ios.cal.editCalendar"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("app.common.cancel", locale: .resolved())) { dismiss() }
                }
            }
            .navigationDestination(item: $scanImage) { scan in
                TimetableScanView(image: scan.image) { entries in
                    saveScanned(entries)
                }
            }
            .confirmationDialog(
                loc("ios.cal.deleteCalendarQ"),
                isPresented: $confirmDelete,
                titleVisibility: .visible
            ) {
                Button(loc("ios.cal.deleteCalendar"), role: .destructive, action: delete)
            } message: {
                Text(loc("ios.cal.deleteCalendarMsg"))
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItems, maxSelectionCount: 1, matching: .images)
        .onChange(of: photoItems) { _, items in
            guard let item = items.first else { return }
            photoItems = []
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                if let data, let image = UIImage(data: data) {
                    scanImage = ScanImage(image: image)
                } else {
                    Haptics.warning()
                    scanImage = ScanImage(image: UIImage())
                }
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            DocumentCameraView { images in
                showScanner = false
                if let page = images.first {
                    // La feuille se referme d'abord : deux présentations ne s'enchaînent pas
                    // dans la même passe.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        scanImage = ScanImage(image: page)
                    }
                }
            } onCancel: {
                showScanner = false
            }
            .ignoresSafeArea()
        }
        .onAppear(perform: load)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if target.scans {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                if canUseCamera { openCamera() } else { showPhotoPicker = true }
            }
        }
        if let existing {
            name = existing.name
            emoji = existing.emoji
            color = existing.colorIndex
            isVisible = existing.isVisible
        } else {
            // Un nouveau calendrier prend la première couleur que personne n'a encore.
            let used = Set(((try? modelContext.fetch(FetchDescriptor<StudyCalendar>())) ?? []).map(\.colorIndex))
            color = CalendarTint.all.first { !used.contains($0.id) }?.id ?? 1
            emoji = "🗓️"
            if target.scans {
                name = loc("ios.cal.default.classes")
                emoji = "🏫"
            }
        }
    }

    private func openCamera() {
        Task {
            if await CameraAccess.request() {
                showScanner = true
            } else {
                showPhotoPicker = true
            }
        }
    }

    /// Enregistre le calendrier et le rend. Un second appui ne crée pas un second calendrier.
    @discardableResult
    private func store() -> StudyCalendar {
        let cleaned = TextSanitizer.clean(name).trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = cleaned.isEmpty ? loc("ios.cal.default.classes") : String(cleaned.prefix(40))
        if let existing {
            existing.name = finalName
            existing.emoji = emoji
            existing.colorIndex = color
            existing.isVisible = isVisible
            existing.updatedAt = Date()
            try? modelContext.save()
            return existing
        }
        let position = (((try? modelContext.fetch(FetchDescriptor<StudyCalendar>())) ?? []).map(\.position).max() ?? -1) + 1
        let created = StudyCalendar(name: finalName, emoji: emoji, colorIndex: color, position: position)
        modelContext.insert(created)
        try? modelContext.save()
        Analytics.track(.calendarCreated, ["color": .number(Double(color))])
        return created
    }

    private func save() {
        guard !saved, canSave else { return }
        saved = true
        store()
        Haptics.success()
        dismiss()
    }

    private func saveScanned(_ entries: [TimetableEntry]) {
        guard !saved else { return }
        saved = true
        let calendar = store()
        let now = Date()
        // Une photo relue deux fois ne double pas les cours : ce qui est déjà là, au même
        // jour, aux mêmes heures et sous le même titre, n'est pas reposé.
        let existing = ((try? modelContext.fetch(FetchDescriptor<CalendarEvent>())) ?? [])
            .filter { $0.calendarID == calendar.id && $0.repeatsWeekly }
            .map { "\(MicaboCalendar.isoWeekday(of: $0.day))-\($0.startMinute)-\($0.endMinute)-\($0.title.lowercased())" }
        var seen = Set(existing)
        for entry in entries where entry.isValid {
            let title = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard seen.insert("\(entry.weekday)-\(entry.startMinute)-\(entry.endMinute)-\(title.lowercased())").inserted else { continue }
            modelContext.insert(CalendarEvent(
                calendarID: calendar.id,
                title: title,
                day: TimetableParser.firstDay(for: entry.weekday, from: now),
                startMinute: entry.startMinute,
                endMinute: entry.endMinute,
                repeatsWeekly: true,
                room: entry.room.trimmingCharacters(in: .whitespacesAndNewlines),
                kind: .lesson
            ))
        }
        try? modelContext.save()
        Analytics.track(.timetableSaved, ["count": .number(Double(entries.count))])
        Haptics.success()
        dismiss()
    }

    private func delete() {
        guard let existing else { return }
        let id = existing.id
        let events = (try? modelContext.fetch(FetchDescriptor<CalendarEvent>())) ?? []
        for event in events where event.calendarID == id {
            modelContext.delete(event)
        }
        modelContext.delete(existing)
        try? modelContext.save()
        StudyNotifications.refresh(in: modelContext)
        dismiss()
    }
}

/// Une photo à lire, identifiable pour la navigation.
struct ScanImage: Identifiable, Hashable {
    let id = UUID()
    let image: UIImage
}

/// **Le formulaire d'un calendrier**, sans état : la feuille le tient, les rendus le dessinent.
struct CalendarEditForm: View {
    @Binding var name: String
    @Binding var emoji: String
    @Binding var color: Int
    @Binding var isVisible: Bool
    @Binding var showsEmoji: Bool
    let showsVisibility: Bool
    let canUseCamera: Bool
    let onCamera: () -> Void
    let onLibrary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                StudyFieldLabel(text: loc("ios.cal.name"))
                HStack(spacing: 10) {
                    Button {
                        withAnimation(MicaboMotion.standard) { showsEmoji.toggle() }
                    } label: {
                        Text(emoji)
                            .font(.system(size: 28))
                            .frame(width: 54, height: 54)
                            .background(CalendarTint.at(color).wash, in: RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous).strokeBorder(CalendarTint.at(color).color.opacity(0.5), lineWidth: 1.5))
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 17))
                                    .foregroundStyle(Color.white, CalendarTint.at(color).color)
                                    .offset(x: 5, y: 5)
                            }
                    }
                    .buttonStyle(HomePressStyle(scale: 0.92, feedback: .selection))
                    .accessibilityLabel(Text(loc("ios.cal.emoji")))
                    StudyTextField(placeholder: loc("ios.cal.namePlaceholder"), text: $name)
                }
                if showsEmoji {
                    emojiGrid
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                StudyFieldLabel(text: loc("ios.cal.color"))
                CalendarColorGrid(selection: $color)
            }

            if showsVisibility {
                Toggle(isOn: $isVisible) {
                    Text(loc("ios.cal.visible"))
                        .font(MicaboFont.ui(16, weight: .bold))
                        .foregroundStyle(MicaboColor.ink)
                }
                .tint(MicaboColor.accent)
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 10) {
                StudyFieldLabel(text: loc("ios.cal.scanTitle"))
                TimetableScanButtons(canUseCamera: canUseCamera, onCamera: onCamera, onLibrary: onLibrary)
            }
        }
    }

    private var emojiGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
            ForEach(CalendarEmoji.all, id: \.self) { symbol in
                Button {
                    emoji = symbol
                    withAnimation(MicaboMotion.standard) { showsEmoji = false }
                } label: {
                    Text(symbol)
                        .font(.system(size: 25))
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(symbol == emoji ? CalendarTint.at(color).wash : MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous))
                }
                .buttonStyle(HomePressStyle(scale: 0.9, feedback: .selection))
            }
        }
        .padding(10)
        .background(MicaboColor.surfaceMuted, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
    }
}
