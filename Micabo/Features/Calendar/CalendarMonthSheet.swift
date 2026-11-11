import SwiftUI

/// **Le mois** : la grille du lundi au dimanche, un point par couleur de ce qui attend chaque
/// jour, les flèches pour changer de mois. Toucher un jour le montre dans l'agenda.
struct CalendarMonthSheet: View {
    let selected: Date
    let dots: (Date) -> [Int]
    let onSelect: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var month: Date

    init(selected: Date, dots: @escaping (Date) -> [Int], onSelect: @escaping (Date) -> Void) {
        self.selected = selected
        self.dots = dots
        self.onSelect = onSelect
        _month = State(initialValue: selected)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .frame(width: 34, height: 34)
                        .background(MicaboColor.surfaceMuted, in: Circle())
                }
                .buttonStyle(HomePressStyle(scale: 0.9))
                .accessibilityLabel(Text(loc("ios.cal.close")))
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, 14)

            ScrollView {
                MonthGrid(month: $month, selected: selected, dots: dots) { day in
                    onSelect(day)
                    dismiss()
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// La grille d'un mois, et ses flèches. Sans état propre : les rendus la dessinent telle quelle.
struct MonthGrid: View {
    @Binding var month: Date
    let selected: Date
    let dots: (Date) -> [Int]
    let onSelect: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                arrow("chevron.backward", by: -1, label: "ios.cal.prevMonth")
                Spacer()
                Text(MicaboCalendar.monthLabel(month))
                    .font(MicaboFont.ui(21, weight: .black))
                    .foregroundStyle(MicaboColor.ink)
                    .contentTransition(.numericText())
                Spacer()
                arrow("chevron.forward", by: 1, label: "ios.cal.nextMonth")
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(MicaboCalendar.veryShortWeekdays().enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(MicaboFont.ui(12, weight: .black))
                        .foregroundStyle(MicaboColor.inkTertiary)
                        .frame(maxWidth: .infinity)
                }
                ForEach(MicaboCalendar.monthGrid(of: month), id: \.self) { day in
                    cell(day)
                }
            }

            Button {
                let today = Date()
                month = today
                onSelect(today)
            } label: {
                Text(loc("ios.cal.today"))
                    .font(MicaboFont.ui(15, weight: .heavy))
                    .foregroundStyle(MicaboColor.accentInk)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 40)
                    .background(MicaboColor.accentSoft, in: Capsule())
            }
            .buttonStyle(HomePressStyle(scale: 0.95, feedback: .selection))
        }
    }

    private func arrow(_ symbol: String, by months: Int, label: String) -> some View {
        Button {
            withAnimation(MicaboMotion.standard) {
                month = MicaboCalendar.shared.date(byAdding: .month, value: months, to: month) ?? month
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(MicaboColor.ink)
                .frame(width: 40, height: 40)
                .background(MicaboColor.surface, in: Circle())
                .overlay(Circle().strokeBorder(MicaboColor.stroke, lineWidth: 1))
                .flipsForRightToLeftLayoutDirection(true)
        }
        .buttonStyle(HomePressStyle(scale: 0.9, feedback: .selection))
        .accessibilityLabel(Text(loc(label)))
    }

    private func cell(_ day: Date) -> some View {
        let calendar = MicaboCalendar.shared
        let inMonth = calendar.isDate(day, equalTo: month, toGranularity: .month)
        let isSelected = calendar.isDate(day, inSameDayAs: selected)
        let isToday = calendar.isDateInToday(day)
        let tints = inMonth ? dots(day) : []
        return Button {
            onSelect(day)
        } label: {
            VStack(spacing: 3) {
                Text(MicaboCalendar.dayNumber(day))
                    .font(MicaboFont.ui(16, weight: isSelected || isToday ? .black : .bold))
                    .foregroundStyle(isSelected ? Color.white : (isToday ? MicaboColor.accentInk : MicaboColor.ink))
                    .monospacedDigit()
                    .frame(width: 36, height: 36)
                    .background {
                        if isSelected {
                            Circle().fill(MicaboStage.fill)
                        } else if isToday {
                            Circle().strokeBorder(MicaboColor.accent.opacity(0.6), lineWidth: 1.5)
                        }
                    }
                HStack(spacing: 2) {
                    ForEach(tints, id: \.self) { tint in
                        Circle().fill(CalendarTint.at(tint).color).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity)
            .opacity(inMonth ? 1 : 0.32)
            .contentShape(Rectangle())
        }
        .buttonStyle(HomePressStyle(scale: 0.9, feedback: .selection))
        .accessibilityLabel(Text(MicaboCalendar.dayLabel(day)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
