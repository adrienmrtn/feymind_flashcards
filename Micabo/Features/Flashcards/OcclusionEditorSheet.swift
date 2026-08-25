import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// Création de cartes à occlusion : on choisit un schéma, on trace les zones à masquer au
/// doigt, on nomme chacune, et Micabo en fait une carte par zone.
///
/// C'est le format qui manquait pour l'anatomie, la géographie et la géologie : ces
/// matières s'apprennent sur une image, pas sur une phrase.
struct OcclusionEditorSheet: View {
    let course: Course

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var imageData: Data?
    @State private var image: UIImage?
    @State private var zones: [OcclusionZone] = []
    @State private var draft: CGRect?
    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false

    private var canSave: Bool {
        imageData != nil && zones.contains { !$0.label.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MicaboSpacing.md) {
                header

                if let image {
                    canvas(for: image)
                    zoneList
                } else {
                    picker
                }
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, MicaboSpacing.xs)
            .padding(.bottom, MicaboSpacing.xl)
        }
        .scrollIndicators(.hidden)
        .micaboScreenBackground()
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
    }

    private var header: some View {
        MicaboScreenHeader(
            title: "Masquer un schéma",
            eyebrow: course.title,
            back: MicaboHeaderBack.close { dismiss() }
        ) {
            Button("Créer", action: save)
                .font(MicaboFont.hanken(15, weight: .semibold))
                .foregroundStyle(canSave ? MicaboColor.accent : MicaboColor.inkTertiary)
                .disabled(!canSave)
        }
        .padding(.top, MicaboSpacing.xs)
    }

    // MARK: - Choix du schéma

    private var picker: some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.md) {
            Button {
                showPhotoPicker = true
            } label: {
                VStack(spacing: MicaboSpacing.sm) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(MicaboColor.accent)
                        .frame(width: 52, height: 52)
                        .background(MicaboColor.accentSoft, in: RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous))

                    Text("Choisir une image")
                        .font(MicaboFont.cardTitle)
                        .foregroundStyle(MicaboColor.ink)

                    Text("Depuis ta photothèque")
                        .font(MicaboFont.caption)
                        .foregroundStyle(MicaboColor.inkTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, MicaboSpacing.xl)
                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.group, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MicaboRadius.group, style: .continuous)
                        .strokeBorder(MicaboColor.strokeStrong, style: StrokeStyle(lineWidth: 1.5, dash: [7, 6]))
                }
            }
            .buttonStyle(MicaboPressableButtonStyle(dimming: false))
        }
    }

    // MARK: - Tracé des zones

    private func canvas(for image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: "Trace les zones")

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .overlay {
                    GeometryReader { proxy in
                        ZStack(alignment: .topLeading) {
                            ForEach(Array(zones.enumerated()), id: \.element.id) { index, zone in
                                zoneOverlay(index: index + 1, rect: absolute(zone.rect, in: proxy.size), isDraft: false)
                            }

                            if let draft {
                                zoneOverlay(index: zones.count + 1, rect: absolute(draft, in: proxy.size), isDraft: true)
                            }

                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(drawGesture(in: proxy.size))
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
                .micaboGroup(radius: MicaboRadius.md)

            Text("Glisse sur l'image pour dessiner un cache. Une zone par notion : chacune devient une carte.")
                .font(MicaboFont.hanken(12, weight: .regular))
                .foregroundStyle(MicaboColor.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func zoneOverlay(index: Int, rect: CGRect, isDraft: Bool) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(MicaboColor.accent.opacity(isDraft ? 0.45 : 0.85))
            .overlay {
                Text("\(index)")
                    .font(MicaboFont.hanken(12, weight: .bold))
                    .foregroundStyle(MicaboColor.onInk)
            }
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }

    private func drawGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                draft = normalized(
                    CGRect(
                        x: min(value.startLocation.x, value.location.x),
                        y: min(value.startLocation.y, value.location.y),
                        width: abs(value.location.x - value.startLocation.x),
                        height: abs(value.location.y - value.startLocation.y)
                    ),
                    in: size
                )
            }
            .onEnded { _ in
                guard let draft, draft.width > 0.02, draft.height > 0.02 else {
                    self.draft = nil
                    return
                }
                zones.append(OcclusionZone(rect: draft))
                self.draft = nil
                Haptics.selection()
            }
    }

    private func absolute(_ rect: CGRect, in size: CGSize) -> CGRect {
        CGRect(
            x: rect.origin.x * size.width,
            y: rect.origin.y * size.height,
            width: max(10, rect.size.width * size.width),
            height: max(10, rect.size.height * size.height)
        )
    }

    private func normalized(_ rect: CGRect, in size: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0 else { return .zero }
        return CGRect(
            x: max(0, rect.origin.x / size.width),
            y: max(0, rect.origin.y / size.height),
            width: min(1, rect.size.width / size.width),
            height: min(1, rect.size.height / size.height)
        )
    }

    // MARK: - Nommage

    @ViewBuilder
    private var zoneList: some View {
        if zones.isEmpty {
            Text("Aucune zone pour l'instant.")
                .font(MicaboFont.caption)
                .foregroundStyle(MicaboColor.inkTertiary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                MicaboSectionCaption(text: "Nomme chaque zone")

                VStack(spacing: 0) {
                    ForEach(Array(zones.enumerated()), id: \.element.id) { index, zone in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(MicaboFont.hanken(12, weight: .bold))
                                .foregroundStyle(MicaboColor.onInk)
                                .frame(width: 24, height: 24)
                                .background(MicaboColor.accent, in: Circle())

                            TextField("Nom de la zone", text: label(of: zone))
                                .font(MicaboFont.body)
                                .foregroundStyle(MicaboColor.ink)
                                .tint(MicaboColor.accent)

                            Button {
                                zones.removeAll { $0.id == zone.id }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(MicaboColor.inkTertiary)
                            }
                            .buttonStyle(MicaboPressableButtonStyle())
                        }
                        .padding(.vertical, 11)
                        .padding(.horizontal, MicaboSpacing.md)

                        if index < zones.count - 1 {
                            MicaboHairline(inset: 48)
                        }
                    }
                }
                .micaboGroup()
            }
        }
    }

    /// Liaison par identifiant plutôt que par index : supprimer une zone pendant la saisie
    /// ne peut alors pas viser à côté.
    private func label(of zone: OcclusionZone) -> Binding<String> {
        Binding(
            get: { zones.first { $0.id == zone.id }?.label ?? "" },
            set: { newValue in
                guard let index = zones.firstIndex(where: { $0.id == zone.id }) else { return }
                zones[index].label = newValue
            }
        )
    }

    // MARK: - Actions

    private func load(_ item: PhotosPickerItem) async {
        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let loaded = UIImage(data: data)
        else {
            return
        }

        // On réduit avant d'enregistrer : un schéma de carte n'a pas besoin de 12 Mpx.
        let prepared = ImagePrep.jpeg(loaded, maxDimension: 1400, quality: 0.8)
        await MainActor.run {
            imageData = prepared
            image = prepared.flatMap { UIImage(data: $0) } ?? loaded
            zones = []
        }
    }

    private func save() {
        guard let imageData else { return }
        let named = zones.filter { !$0.label.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !named.isEmpty else { return }

        try? CourseRepository.addOcclusionCards(named, image: imageData, to: course, in: modelContext)
        Haptics.success()
        dismiss()
    }
}
