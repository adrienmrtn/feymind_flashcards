import SwiftUI

// MARK: - Le contenu du tiroir

/// **Le tiroir des conversations** (lot 12), dessiné sans base : en tête Mika, le prénom et
/// les réglages ; « Nouveau chat », bien visible ; la recherche ; puis les conversations,
/// rangées par jour, chacune avec l'icône de son origine (une question, une page passée à la
/// caméra, une leçon) et sa leçon liée. Un appui long : renommer, supprimer.
///
/// **Pas de raccourcis vers les leçons, le calendrier ou la concentration** : ils ont leur
/// onglet dans la barre du bas, toujours visible ; les répéter ici ferait deux portes pour la
/// même pièce, et repousserait les conversations — la seule chose que ce tiroir range.
///
/// Le même contenu sert de page d'historique (`ChatHistoryView`), une croix à la place de
/// l'engrenage.
struct ChatDrawerContent: View {
    let rows: [ChatHistoryRow]
    var totalCount: Int
    var name: String?
    var currentID: UUID?
    @Binding var query: String
    let onOpen: (UUID) -> Void
    var onNew: () -> Void = {}
    var onRename: (UUID) -> Void = { _ in }
    var onDelete: (UUID) -> Void = { _ in }
    var onSettings: (() -> Void)?
    var onClose: (() -> Void)?
    var now = Date()
    var still = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 16)
            V3Button(L10n.t("ios.chat12.new", locale: .resolved()), systemImage: "square.and.pencil", action: onNew)
                .padding(.horizontal, V3Metric.screenMargin)
                .padding(.bottom, 14)
            if totalCount == 0 {
                empty
            } else {
                search
                    .padding(.bottom, 4)
                if still {
                    list.frame(maxHeight: .infinity, alignment: .top).clipped()
                } else {
                    ScrollView { list }
                        .scrollDismissesKeyboard(.interactively)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(V3Color.bg.ignoresSafeArea())
    }

    // MARK: L'en-tête

    private var header: some View {
        HStack(spacing: 12) {
            MikaMascot(mood: .idle, size: 34)
                .frame(width: 48, height: 48)
                .background(V3Color.accentWash, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(name ?? L10n.t("ios.chat12.drawer.anonymous", locale: .resolved()))
                    .font(V3Font.cardTitle)
                    .foregroundStyle(V3Color.ink)
                    .lineLimit(1)
                Text(L10n.t("ios.chat12.drawer.subtitle", locale: .resolved()))
                    .font(V3Font.caption)
                    .foregroundStyle(V3Color.ink2)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            if let onSettings {
                round("gearshape.fill", label: L10n.t("ios.chat12.drawer.settings", locale: .resolved()), action: onSettings)
            } else if let onClose {
                round("xmark", label: L10n.t("ios.cal.close", locale: .resolved()), action: onClose)
            }
        }
        .padding(.horizontal, V3Metric.screenMargin)
        .padding(.top, 12)
    }

    private func round(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(V3Font.text(.body, weight: .bold))
                .foregroundStyle(V3Color.ink2)
                .frame(width: 44, height: 44)
                .background(V3Color.surface, in: Circle())
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .light))
        .accessibilityLabel(Text(label))
    }

    // MARK: La recherche

    private var search: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(V3Color.ink3)
                .accessibilityHidden(true)
            if still {
                Text(query.isEmpty ? L10n.t("ios.chat11.history.search", locale: .resolved()) : query)
                    .foregroundStyle(query.isEmpty ? V3Color.ink3 : V3Color.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField(text: $query, prompt: Text(L10n.t("ios.chat11.history.search", locale: .resolved())).foregroundStyle(V3Color.ink3)) {
                    Text(L10n.t("ios.chat11.history.search", locale: .resolved()))
                }
                .foregroundStyle(V3Color.ink)
                .tint(V3Color.accent)
                .submitLabel(.search)
                .autocorrectionDisabled()
            }
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(V3Color.ink3)
                }
                .accessibilityLabel(Text(L10n.t("app.common.cancel", locale: .resolved())))
            }
        }
        .font(V3Font.text(.body, weight: .medium))
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(V3Color.surface, in: Capsule())
        .padding(.horizontal, V3Metric.screenMargin)
    }

    // MARK: La liste

    private var list: some View {
        LazyVStack(alignment: .leading, spacing: 2) {
            if rows.isEmpty {
                VStack(spacing: 6) {
                    Text(L10n.t("ios.chat11.history.noResult", locale: .resolved()))
                        .font(V3Font.bodyStrong)
                        .foregroundStyle(V3Color.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.t("ios.chat12.search.hint", locale: .resolved()))
                        .font(V3Font.caption)
                        .foregroundStyle(V3Color.ink2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 28)
                .padding(.horizontal, V3Metric.screenMargin)
                .frame(maxWidth: .infinity)
            }
            let groups = ChatHistorySection.group(rows, date: \.date, now: now)
            ForEach(groups.indices, id: \.self) { index in
                Text(groups[index].0.title())
                    .font(V3Font.eyebrow)
                    .foregroundStyle(V3Color.ink3)
                    .textCase(.uppercase)
                    .padding(.top, 16)
                    .padding(.bottom, 4)
                    .padding(.horizontal, V3Metric.screenMargin)
                    .accessibilityAddTraits(.isHeader)
                ForEach(groups[index].1) { row in
                    rowView(row)
                }
            }
        }
        .padding(.bottom, 24)
    }

    private func rowView(_ row: ChatHistoryRow) -> some View {
        let family = row.origin.family
        let isCurrent = row.id == currentID
        return Button { onOpen(row.id) } label: {
            HStack(spacing: 12) {
                Image(systemName: family.symbol)
                    .font(V3Font.text(.subheadline, weight: .bold))
                    .foregroundStyle(family.tone)
                    .frame(width: 34, height: 34)
                    .background(family.tone.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title.isEmpty ? L10n.t("ios.chat11.title.untitled", locale: .resolved()) : row.title)
                        .font(V3Font.text(.body, weight: .semibold))
                        .foregroundStyle(V3Color.ink)
                        .lineLimit(1)
                    if let course = row.courseTitle {
                        Label {
                            Text(course).lineLimit(1)
                        } icon: {
                            Image(systemName: "book.fill")
                        }
                        .font(V3Font.caption)
                        .foregroundStyle(V3Color.accentBright)
                        .labelStyle(.titleAndIcon)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 52)
            .background(isCurrent ? V3Color.accentWash : Color.clear, in: RoundedRectangle(cornerRadius: V3Metric.radiusInner, style: .continuous))
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .light))
        .contextMenu {
            Button { onRename(row.id) } label: {
                Label(L10n.t("ios.chat11.rename.action", locale: .resolved()), systemImage: "pencil")
            }
            Button(role: .destructive) { onDelete(row.id) } label: {
                Label(L10n.t("app.common.delete", locale: .resolved()), systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text(family.spoken()))
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
        .accessibilityAction(named: Text(L10n.t("ios.chat11.rename.action", locale: .resolved()))) { onRename(row.id) }
        .accessibilityAction(named: Text(L10n.t("app.common.delete", locale: .resolved()))) { onDelete(row.id) }
    }

    // MARK: Vide

    private var empty: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 12)
            MikaMascot(mood: .sleep, size: 120)
                .accessibilityHidden(true)
            Text(L10n.t("ios.chat12.empty.title", locale: .resolved()))
                .font(V3Font.cardTitle)
                .foregroundStyle(V3Color.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.t("ios.chat12.empty.body", locale: .resolved()))
                .font(V3Font.body)
                .foregroundStyle(V3Color.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, V3Metric.screenMargin)
    }
}

// MARK: - Le tiroir

/// **Un tiroir latéral, natif et suivi au doigt** (lot 12) : il sort du bord d'attaque — la
/// gauche, la droite en arabe —, la page glisse avec lui sous un voile ; un appui sur le voile,
/// un glissement vers le bord ou l'échappement de VoiceOver le referment. Ouvert, la page
/// derrière est cachée à VoiceOver et le tiroir se dit modal.
///
/// Le glissement depuis le bord se prend sur une bande de 16 pt seulement : le reste de la page
/// garde ses propres gestes (la rangée d'outils qui défile, le champ).
struct SideDrawer<Main: View, Drawer: View>: View {
    @Binding var isOpen: Bool
    /// Faux quand un écran est poussé : le bord appartient alors au retour par glissement.
    var enabled = true
    /// Ouvert par le glissement du bord, pour les statistiques.
    var onSwipeOpen: () -> Void = {}
    /// Le tiroir posé ouvert, sans geste ni animation (les rendus).
    var still = false
    @ViewBuilder let main: () -> Main
    @ViewBuilder let drawer: () -> Drawer

    @Environment(\.layoutDirection) private var direction
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Le déplacement du doigt, vers l'ouverture, pendant un glissement.
    @State private var drag: CGFloat?

    static func width(for container: CGFloat) -> CGFloat {
        min(container * 0.84, 340)
    }

    /// De 0 (fermé) à 1 (ouvert), suivi au doigt.
    static func progress(isOpen: Bool, drag: CGFloat?, width: CGFloat) -> CGFloat {
        let base: CGFloat = isOpen ? 1 : 0
        guard let drag, width > 0 else { return base }
        return min(1, max(0, base + drag / width))
    }

    /// Lâché : ouvert si le tiroir a passé la moitié, ou si le geste était vif.
    static func settles(open progress: CGFloat, velocity: CGFloat) -> Bool {
        if velocity > 600 { return true }
        if velocity < -600 { return false }
        return progress > 0.5
    }

    var body: some View {
        GeometryReader { proxy in
            let width = Self.width(for: proxy.size.width)
            let progress = Self.progress(isOpen: isOpen, drag: drag, width: width)
            // En arabe, la mise en page est retournée, `offset` compris (vu au rendu
            // `scan12-tiroir-ar`) : les décalages s'écrivent vers le bord de fuite, sans signe.
            // Le doigt, lui, se lit dans le repère de l'écran (`.global`, jamais retourné) :
            // l'ouverture est un glissement vers la gauche en arabe.
            let sign: CGFloat = direction == .rightToLeft ? -1 : 1
            ZStack(alignment: .leading) {
                main()
                    .accessibilityHidden(isOpen)
                    .offset(x: progress * width)
                if progress > 0 {
                    Color.black.opacity(0.5 * progress)
                        .ignoresSafeArea()
                        .offset(x: progress * width)
                        .contentShape(Rectangle())
                        .onTapGesture { set(false) }
                        .accessibilityHidden(true)
                }
                if progress > 0 || isOpen {
                    drawer()
                        .frame(width: width)
                        .frame(maxHeight: .infinity)
                        .background(V3Color.bg.ignoresSafeArea())
                        .overlay(alignment: .trailing) {
                            Rectangle().fill(V3Color.line).frame(width: 1).ignoresSafeArea()
                        }
                        .offset(x: (progress - 1) * width)
                        .accessibilityAddTraits(.isModal)
                        .accessibilityAction(.escape) { set(false) }
                }
            }
            .simultaneousGesture(isOpen && !still ? closeGesture(width: width, sign: sign) : nil)
            .overlay(alignment: .leading) {
                if !isOpen, !still, enabled {
                    Color.clear
                        .frame(width: 16)
                        .contentShape(Rectangle())
                        .gesture(openGesture(width: width, sign: sign))
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private func openGesture(width: CGFloat, sign: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                drag = max(0, sign * value.translation.width)
            }
            .onEnded { value in
                let progress = Self.progress(isOpen: false, drag: max(0, sign * value.translation.width), width: width)
                let velocity = sign * (value.predictedEndTranslation.width - value.translation.width) * 4
                let open = Self.settles(open: progress, velocity: velocity)
                settle(open)
                if open { onSwipeOpen() }
            }
    }

    private func closeGesture(width: CGFloat, sign: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 14, coordinateSpace: .global)
            .onChanged { value in
                // Un glissement vertical appartient à la liste.
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                drag = min(0, sign * value.translation.width)
            }
            .onEnded { value in
                guard drag != nil else { return }
                let progress = Self.progress(isOpen: true, drag: min(0, sign * value.translation.width), width: width)
                let velocity = sign * (value.predictedEndTranslation.width - value.translation.width) * 4
                settle(Self.settles(open: progress, velocity: velocity))
            }
    }

    private func settle(_ open: Bool) {
        withAnimation(MicaboMotion.resolved(MicaboMotion.standard, reduceMotion: reduceMotion)) {
            drag = nil
            isOpen = open
        }
    }

    private func set(_ open: Bool) {
        settle(open)
    }
}
