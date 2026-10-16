import SwiftUI

// MARK: - La feuille

/// **La série, ouverte depuis la pastille de Home** : la flamme qui respire, le nombre de jours,
/// la semaine en sept ronds, le record, et une phrase de Mika.
///
/// La phrase change selon la journée, parce que c'est la seule chose à dire : aujourd'hui est
/// fait, et il n'y a qu'à revenir demain ; ou il ne l'est pas encore, et une leçon suffit à
/// garder la série. Une feuille qui afficherait la même phrase dans les deux cas parlerait à
/// côté de la moitié des gens qui l'ouvrent.
struct StreakSheet: View {
    /// « Faire une leçon » : la feuille se referme et rend la main à l'écran qui l'a ouverte.
    /// Sans action, le bouton dit seulement « Continuer ».
    var onStudy: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var status = StudyStreak.status()
    @State private var week = StudyStreak.week()

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                hero
                StreakWeekCard(days: week)
                record
                mikaLine
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, 22)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            button
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(MicaboColor.canvas)
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(MicaboRadius.sheet)
        .presentationBackground(MicaboColor.canvas)
        .onReceive(NotificationCenter.default.publisher(for: .micaboStreakDidChange)) { _ in refresh() }
    }

    private var header: some View {
        HStack {
            Text(i18n.t("ios.streak.title"))
                .font(MicaboFont.ui(22, weight: .heavy))
                .foregroundStyle(MicaboColor.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            MicaboCircleButton(systemImage: "xmark", style: .light, size: 36, accessibilityTitle: i18n.t("ios.streak.close")) {
                dismiss()
            }
        }
    }

    /// La flamme, et le nombre en dessous. Grise tant qu'aujourd'hui n'est pas fait : la série
    /// tient encore, mais elle attend.
    private var hero: some View {
        VStack(spacing: 0) {
            StreakFlame(lit: status.studiedToday, size: 84)
            if status.current > 0 {
                Text("\(status.current)")
                    .font(MicaboFont.number(64))
                    .foregroundStyle(status.studiedToday ? AnyShapeStyle(StreakFlame.gradient) : AnyShapeStyle(MicaboColor.inkSecondary))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(status.current)))
                    .padding(.top, -6)
                Text(i18n.t("ios.streak.unit", ["count": "\(status.current)"]))
                    .font(MicaboFont.ui(20, weight: .heavy))
                    .foregroundStyle(MicaboColor.ink)
            } else {
                Text(i18n.t("ios.streak.zeroTitle"))
                    .font(MicaboFont.display(28))
                    .foregroundStyle(MicaboColor.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// Le record, sur une rangée : un repère à côté de la série, pas un objectif fixé pour
    /// l'étudiant (voir `MicaboStreakCard`).
    private var record: some View {
        HStack(spacing: 14) {
            MicaboIconView(icon: .trophy, size: 40)
            Text(i18n.t("ios.streak.bestLabel"))
                .font(MicaboFont.ui(16, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
            Spacer(minLength: 8)
            Text(i18n.t("ios.streak.bestValue", ["count": "\(status.best)"]))
                .font(MicaboFont.number(18))
                .foregroundStyle(status.best > 0 ? MicaboColor.flameInk : MicaboColor.inkTertiary)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
        .accessibilityElement(children: .combine)
    }

    private var mikaLine: some View {
        HStack(spacing: 12) {
            MikaMascot(mood: status.studiedToday ? .happy : .wave, size: 64)
            Text(line)
                .font(MicaboFont.ui(16, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            status.studiedToday ? MicaboColor.flameSoft : MicaboColor.surfaceMuted,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    private var line: String {
        if status.studiedToday { return i18n.t("ios.streak.todayDone") }
        if status.current > 0 { return i18n.t("ios.streak.todayPending") }
        return i18n.t("ios.streak.startPending")
    }

    @ViewBuilder
    private var button: some View {
        if let onStudy, !status.studiedToday {
            Button(i18n.t("ios.streak.study")) {
                dismiss()
                onStudy()
            }
            .buttonStyle(LessonPrimaryButtonStyle())
        } else {
            Button(i18n.t("ios.streak.continue")) { dismiss() }
                .buttonStyle(LessonPrimaryButtonStyle())
        }
    }

    private func refresh() {
        withAnimation(.spring(duration: 0.4)) {
            status = StudyStreak.status()
            week = StudyStreak.week()
        }
    }
}

// MARK: - La flamme

/// **La flamme, en grand** : l'icône 3D posée sur un disque chaud, dans un halo qui respire.
///
/// L'icône ne dépasse jamais quatre-vingt-quatre points : ses images font 256 pixels, et plus
/// grande elle se brouille. C'est le halo qui donne la présence, pas la taille de l'icône.
///
/// La respiration se calcule sur l'horloge (`TimelineView`) plutôt qu'avec une animation qui
/// se répète : posée au `onAppear` d'une feuille, une animation infinie emporte aussi le
/// glissement de la feuille, et la flamme flotte pendant qu'elle monte.
struct StreakFlame: View {
    var lit = true
    var size: CGFloat = 84

    static let maximumIconSize: CGFloat = 84

    /// Le dégradé des chiffres de la série.
    static var gradient: LinearGradient {
        LinearGradient(colors: [MicaboColor.flame, MicaboColor.flameInk], startPoint: .top, endPoint: .bottom)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let icon = min(size, Self.maximumIconSize)
        let animated = lit && !reduceMotion
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !animated)) { timeline in
            // Une respiration de 2,6 s : 0 au creux, 1 au plus fort.
            let phase = timeline.date.timeIntervalSinceReferenceDate * 2 * Double.pi / 2.6
            let breath: CGFloat = animated ? CGFloat((sin(phase) + 1) / 2) : 0.5
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [MicaboColor.flame.opacity(lit ? 0.34 : 0), MicaboColor.flame.opacity(0)],
                        center: .center,
                        startRadius: icon * 0.3,
                        endRadius: icon * 0.8
                    ))
                    .scaleEffect(0.9 + 0.14 * breath)
                Circle()
                    .fill(lit ? MicaboColor.flameSoft : MicaboColor.surfaceMuted)
                    .frame(width: icon * 1.18, height: icon * 1.18)
                // Posée un rien plus petite que la place : au plus fort de la respiration, elle
                // touche les quatre-vingt-quatre points sans les passer.
                MicaboIconView(icon: .flame, size: icon / 1.04)
                    .saturation(lit ? 1 : 0)
                    .opacity(lit ? 1 : 0.45)
                    .scaleEffect(1 + 0.04 * breath, anchor: .bottom)
                    .shadow(color: MicaboColor.flame.opacity(lit ? Double(0.18 + 0.2 * breath) : 0), radius: 14, x: 0, y: 8)
            }
        }
        .frame(width: icon * 1.6, height: icon * 1.6)
        .accessibilityHidden(true)
    }
}

// MARK: - La semaine

/// **La semaine en cours, en carte** : son intitulé, « 3/7 », et les sept ronds.
struct StreakWeekCard: View {
    let days: [StudyStreak.Day]
    /// Aujourd'hui, allumé ou non, quand l'écran veut le remplir sous les yeux.
    var todayLit: Bool?

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        let row = StreakWeekRow(days: days, todayLit: todayLit)
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(i18n.t("ios.streak.week"))
                    .font(MicaboFont.small)
                    .tracking(MicaboTracking.caps)
                    .textCase(.uppercase)
                    .foregroundStyle(MicaboColor.inkSecondary)
                Spacer(minLength: 8)
                Text("\(row.litCount)/\(days.count)")
                    .font(MicaboFont.number(15))
                    .foregroundStyle(row.litCount > 0 ? MicaboColor.flameInk : MicaboColor.inkTertiary)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(row.litCount)))
            }
            row
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
        .micaboElevation(.card)
    }
}

/// **Sept ronds, du lundi au dimanche** : une flamme dans chaque jour travaillé, un rond vide
/// pour un jour passé sans rien, un pointillé pour ce qui n'est pas encore arrivé, et
/// aujourd'hui cerclé.
struct StreakWeekRow: View {
    let days: [StudyStreak.Day]
    var todayLit: Bool?

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var litCount: Int { days.filter { isLit($0) }.count }

    var body: some View {
        let initials = MicaboCalendar.weekdayInitials(locale: i18n.locale)
        HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                VStack(spacing: 8) {
                    Text(initials.indices.contains(index) ? initials[index] : "")
                        .font(MicaboFont.ui(13, weight: .heavy))
                        .foregroundStyle(day.isToday ? MicaboColor.ink : MicaboColor.inkTertiary)
                    StreakDayDot(day: day, lit: isLit(day))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(i18n.t("ios.streak.weekA11y", ["done": "\(litCount)"])))
    }

    private func isLit(_ day: StudyStreak.Day) -> Bool {
        if day.isToday, let todayLit { return todayLit }
        return day.studied
    }
}

/// Un jour de la rangée. Trente-deux points, et le cercle d'aujourd'hui autour : sept ronds
/// tiennent sur la largeur d'un iPhone mini, carte comprise.
private struct StreakDayDot: View {
    let day: StudyStreak.Day
    let lit: Bool

    var body: some View {
        ZStack {
            if lit {
                Circle().fill(MicaboColor.flameSoft)
                Circle().strokeBorder(MicaboColor.flame.opacity(0.45), lineWidth: 1.5)
                MicaboIconView(icon: .flame, size: 22)
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
            } else if day.isFuture {
                Circle().strokeBorder(MicaboColor.stroke, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            } else {
                Circle().fill(MicaboColor.surfaceMuted)
            }
        }
        .frame(width: 32, height: 32)
        .padding(3)
        .overlay {
            if day.isToday {
                Circle().strokeBorder(lit ? MicaboColor.flame : MicaboColor.inkTertiary, lineWidth: 2)
            }
        }
    }
}
