import SwiftUI

// MARK: - Les six écrans de démonstration
//
// Ils viennent **après** les questions, et c'est tout leur sens. La version précédente
// ouvrait sur quatre écrans de produit — dépôt, dates, fiche, fonctions — que la mesure
// montrait traversés en une à deux secondes : on ne regarde pas une fiche d'histoire quand
// on est en terminale S à Ankara. Ceux-ci arrivent une fois qu'on sait le pays, la matière
// et l'objectif, et chacun montre **un résultat dans cette matière-là** : la fiche, la
// carte, le plan jusqu'à l'examen du pays, la copie corrigée, le chiffre, les avis.
//
// Chacun porte une phrase, un objet, et un bouton qui ne s'ouvre qu'après l'avoir vu. Pas
// de mascotte, pas de tuile qui respire : l'objet fait le travail.

/// « Ton cours devient une fiche. »
///
/// La fiche de la matière cochée, qui se compose bloc après bloc sous les yeux, jusqu'au
/// graphe. Elle ne recommence pas : une page qui s'efface et se réécrit est un économiseur
/// d'écran, et l'élève doit pouvoir la relire tant qu'il veut.
struct DemoSheetStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Le nombre de blocs déjà posés sur la fiche.
    @State private var revealed = 0

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.demo.sheet.title"),
            subtitle: i18n.t("ios.demo.sheet.sub", ["subject": model.demoSheet.subjectName]),
            contentSpacing: MicaboSpacing.lg
        ) {
            OnboardingSheetCard(sheet: model.demoSheet, revealed: revealed)
        } footer: {
            OnboardingContinueButton(gate: OnboardingMotion.gate) {
                model.advance()
            }
        }
        .task { await compose() }
    }

    /// Cinq blocs en une seconde, comme une page qui s'écrit, puis le graphe. Dans `.task` :
    /// annulé avec la vue. Sans mouvement réduit, tout est posé d'un coup.
    @MainActor
    private func compose() async {
        guard !reduceMotion else {
            revealed = OnboardingSheetCard.blockCount
            return
        }
        try? await Task.sleep(for: .milliseconds(260))
        for step in 1...OnboardingSheetCard.blockCount {
            guard !Task.isCancelled else { return }
            withAnimation(OnboardingMotion.enter) { revealed = step }
            Haptics.tick()
            try? await Task.sleep(for: .milliseconds(190))
        }
    }
}

/// « Retourne la carte. »
///
/// Une carte tirée de la fiche qu'on vient de voir, et rien ne se passe tant qu'on ne l'a
/// pas touchée. Le bouton n'arrive qu'après le verso : c'est le seul écran du parcours où
/// l'élève **fait** le geste de l'app au lieu de le regarder, et il ne se saute pas.
struct DemoCardStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var isFlipped = false

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.demo.card.title"),
            subtitle: i18n.t("ios.demo.card.sub"),
            scrolls: false,
            expandsContent: true
        ) {
            VStack(spacing: 18) {
                Spacer(minLength: 0)

                OnboardingDemoFlashcardView(card: model.demoSheet.card, isFlipped: isFlipped) {
                    isFlipped = true
                }
                .frame(height: 290)

                Text(i18n.t("ios.demo.card.done"))
                    .font(MicaboFont.ui(14, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(isFlipped ? 1 : 0)
                    .offset(y: isFlipped ? 0 : 6)
                    .animation(OnboardingMotion.enter.delay(0.35), value: isFlipped)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        } footer: {
            OnboardingContinueButton {
                model.advance()
            }
            .opacity(isFlipped ? 1 : 0)
            .offset(y: isFlipped ? 0 : 8)
            // Tant que la carte n'est pas retournée, le bouton n'est pas seulement
            // invisible : il ne prend pas les appuis.
            .allowsHitTesting(isFlipped)
            .animation(OnboardingMotion.enter.delay(0.45), value: isFlipped)
        }
    }
}

/// « Ton plan jusqu'au jour J. »
///
/// Le mois de l'examen du pays, avec sa date posée et le compte à rebours réel, puis les
/// trois moments du plan : le rythme quotidien, l'examen blanc à J-30, la révision ciblée
/// à J-7. Le calendrier de mars avec trois contrôles inventés disait « on pose des dates » ;
/// celui-ci dit « voilà la tienne ».
struct DemoPlanStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var exam: OnboardingDemoExam { model.demoExam }

    var body: some View {
        let days = exam.daysLeft()

        OnboardingScaffold(
            title: i18n.t("ios.demo.plan.title"),
            subtitle: i18n.t("ios.demo.plan.sub", ["exam": exam.name, "days": "\(days)"]),
            contentSpacing: MicaboSpacing.lg
        ) {
            OnboardingPlanScene(exam: exam)
        } footer: {
            OnboardingContinueButton(gate: OnboardingMotion.gate) {
                model.advance()
            }
        }
    }
}

/// « Le jour J, en conditions réelles. »
///
/// Un extrait d'examen blanc dans la matière cochée : la question, la réponse écrite, la
/// note dans le barème du pays, et la correction en une phrase. C'est ce que l'app fait à
/// J-30 et à J-7, montré tel quel.
struct DemoMockStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// La question, la réponse, puis la note : trois temps.
    @State private var revealed = 0

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.demo.mock.title"),
            subtitle: i18n.t("ios.demo.mock.sub"),
            contentSpacing: MicaboSpacing.lg
        ) {
            OnboardingMockPaper(
                sheet: model.demoSheet,
                grade: DesiredGradeScale.for(model.country).label(for: 16),
                revealed: revealed
            )
        } footer: {
            OnboardingContinueButton(gate: OnboardingMotion.gate) {
                model.advance()
            }
        }
        .task { await grade() }
    }

    /// La copie se lit dans l'ordre où elle a été écrite : la question, la réponse, et la
    /// note qui tombe en dernier. Dans `.task` : annulé avec la vue.
    @MainActor
    private func grade() async {
        guard !reduceMotion else {
            revealed = 3
            return
        }
        try? await Task.sleep(for: .milliseconds(300))
        for step in 1...3 {
            guard !Task.isCancelled else { return }
            withAnimation(OnboardingMotion.enter) { revealed = step }
            if step == 3 { Haptics.success() } else { Haptics.tick() }
            try? await Task.sleep(for: .milliseconds(step == 2 ? 700 : 420))
        }
    }
}

/// « Ce que ça change. »
///
/// Un chiffre mesuré et un chiffre observé, et rien d'autre. Le premier vient de la
/// recherche — se tester plutôt que relire, à une semaine — et il est sourcé. Le second
/// est ce que les élèves de Micabo gagnent en un trimestre. Deux barres qu'on compare d'un
/// regard remplacent la liste de quatre fonctions que personne ne lisait.
struct DemoEvidenceStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.demo.evidence.title"),
            contentSpacing: MicaboSpacing.lg
        ) {
            VStack(spacing: 14) {
                OnboardingEvidenceChart()
                    .onboardingAppear(index: 3)

                OnboardingGainCard()
                    .onboardingAppear(index: 4)
            }
        } footer: {
            OnboardingContinueButton(gate: OnboardingMotion.gate) {
                model.advance()
            }
        }
    }
}

/// « Ils l'ont fait avant toi. »
///
/// Trois avis, lisibles en entier, posés l'un sous l'autre. La pile qui tournait toute
/// seule toutes les trois secondes se lisait comme une bannière, et une bannière est ce
/// qu'on a appris à ne pas regarder. Ici on lit trois phrases, et on continue.
struct DemoReviewsStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private struct Review: Identifiable {
        let id: Int
        let quote: String
        let name: String
        let level: String
    }

    private var reviews: [Review] {
        (1...3).map { index in
            Review(
                id: index,
                quote: i18n.t("ios.review\(index).quote"),
                name: i18n.t("ios.review\(index).name"),
                level: i18n.t("ios.review\(index).level")
            )
        }
    }

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.demo.reviews.title"),
            subtitle: i18n.t("ios.demo.reviews.sub", [
                "n": OnboardingNumbers.text(OnboardingProofFigures.reviews, locale: i18n.locale),
                "rating": OnboardingNumbers.text(OnboardingProofFigures.rating, locale: i18n.locale),
            ]),
            contentSpacing: MicaboSpacing.lg
        ) {
            VStack(spacing: 12) {
                ForEach(Array(reviews.enumerated()), id: \.element.id) { index, review in
                    OnboardingReviewCard(quote: review.quote, name: review.name, level: review.level)
                        .onboardingAppear(index: 3 + index)
                }
            }
        } footer: {
            OnboardingContinueButton(gate: OnboardingMotion.gate) {
                model.advance()
            }
        }
    }
}

// MARK: - Le plan

/// **Le mois de l'examen, et les trois moments du plan.**
///
/// Une grille de calendrier réelle — le bon nombre de jours, le bon premier jour de la
/// semaine — avec le jour de l'examen en violet et, s'il tombe dans le même mois,
/// aujourd'hui cerclé. En dessous, ce que Micabo pose sur ce calendrier : le rythme, le
/// blanc, la révision ciblée. Les rangées arrivent l'une après l'autre.
private struct OnboardingPlanScene: View {
    let exam: OnboardingDemoExam

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Le nombre de rangées du plan déjà posées.
    @State private var placed = 0

    private var calendar: Calendar { MicaboCalendar.shared }
    private var examDate: Date { exam.nextDate(calendar: calendar) }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: examDate)?.count ?? 30
    }

    /// Les cases vides avant le premier jour, pour que le 1er tombe sous son initiale.
    private var leadingBlanks: Int {
        let components = calendar.dateComponents([.year, .month], from: examDate)
        guard let first = calendar.date(from: components) else { return 0 }
        let weekday = calendar.component(.weekday, from: first)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var examDay: Int {
        calendar.component(.day, from: examDate)
    }

    /// Aujourd'hui, seulement s'il est dans le mois affiché.
    private var todayDay: Int? {
        let now = Date()
        guard calendar.isDate(now, equalTo: examDate, toGranularity: .month) else { return nil }
        return calendar.component(.day, from: now)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = i18n.locale.foundation
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: examDate).localizedCapitalized
    }

    private var cardsPerDay: Int {
        DailyLoad.newCardsPerDay(dailyMinutes: OnboardingPreferences.dailyMinutes)
    }

    var body: some View {
        VStack(spacing: 14) {
            monthCard
                .onboardingAppear(index: 3)

            VStack(spacing: 8) {
                planRow(index: 0, systemImage: "rectangle.stack", text: i18n.t("ios.demo.plan.row1", ["n": "\(cardsPerDay)"]), days: nil)
                planRow(index: 1, systemImage: "doc.text.magnifyingglass", text: i18n.t("ios.demo.plan.row2"), days: 30)
                planRow(index: 2, systemImage: "scope", text: i18n.t("ios.demo.plan.row3"), days: 7)
            }
        }
        .accessibilityElement(children: .combine)
        .task { await place() }
    }

    private var monthCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text(monthTitle)
                    .font(MicaboFont.ui(15, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)

                Spacer(minLength: 0)

                MicaboCountdownPill(days: exam.daysLeft(calendar: calendar))
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(Array(MicaboCalendar.weekdayInitials(locale: i18n.locale).prefix(7).enumerated()), id: \.offset) { _, initial in
                    Text(initial)
                        .font(MicaboFont.ui(10.5, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkTertiary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: 32)
                }

                ForEach(1...daysInMonth, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
        .padding(16)
        .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: MicaboRadius.group, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.group, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .shadow(color: MicaboColor.ink.opacity(0.05), radius: 14, y: 6)
    }

    @ViewBuilder
    private func dayCell(_ day: Int) -> some View {
        let isExam = day == examDay
        let isToday = day == todayDay

        if isExam {
            VStack(spacing: 1) {
                Text("\(day)")
                    .font(MicaboFont.ui(12.5, weight: .heavy))
                    .monospacedDigit()
                Text(exam.name)
                    .font(MicaboFont.ui(7.5, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(MicaboColor.onInk)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(MicaboColor.accent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        } else {
            Text("\(day)")
                .font(MicaboFont.ui(13, weight: isToday ? .heavy : .medium))
                .foregroundStyle(isToday ? MicaboColor.accent : MicaboColor.inkSecondary)
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background {
                    if isToday {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(MicaboColor.accent, lineWidth: 1.6)
                    }
                }
        }
    }

    /// Une rangée du plan : un symbole sur son lavis, ce qui se passe, et quand.
    private func planRow(index: Int, systemImage: String, text: String, days: Int?) -> some View {
        let isPlaced = index < placed
        let alpha: Double = isPlaced ? 1 : 0
        let rise: CGFloat = isPlaced ? 0 : 8

        return HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MicaboColor.accent)
                .frame(width: 36, height: 36)
                .background(MicaboColor.accentWash, in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            Text(text)
                .font(MicaboFont.ui(14.5, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            if let days {
                MicaboCountdownPill(days: days)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .opacity(alpha)
        .offset(y: rise)
        .animation(OnboardingMotion.enter, value: placed)
    }

    /// Les rangées se posent une par une, après le calendrier. Dans `.task` : annulé avec
    /// la vue. Sans mouvement réduit, tout est posé d'un coup.
    @MainActor
    private func place() async {
        guard !reduceMotion else {
            placed = 3
            return
        }
        try? await Task.sleep(for: .milliseconds(600))
        for step in 1...3 {
            guard !Task.isCancelled else { return }
            placed = step
            Haptics.tick()
            try? await Task.sleep(for: .milliseconds(360))
        }
    }
}

// MARK: - La copie

/// **Une copie d'examen blanc, corrigée.**
///
/// L'en-tête dit la matière et le temps imparti, la question est posée, la réponse écrite
/// vient dessous, et la note tombe en dernier avec la correction. Trois temps, comme on lit
/// une copie rendue.
private struct OnboardingMockPaper: View {
    let sheet: DemoSheet
    let grade: String
    /// La question, la réponse, puis la note : de 0 à 3.
    let revealed: Int

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(i18n.t("ios.demo.mock.paper")) · \(sheet.subjectName)")
                    .font(MicaboFont.ui(11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(MicaboColor.accent)
                    .textCase(.uppercase)
                    .lineLimit(1)

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 10.5, weight: .semibold))
                    Text(i18n.t("ios.examMockMinutes", ["n": "20"]))
                        .font(MicaboFont.ui(11.5, weight: .semibold))
                }
                .foregroundStyle(MicaboColor.inkSecondary)
                .padding(.vertical, 5)
                .padding(.horizontal, 9)
                .background(MicaboColor.surfaceMuted, in: Capsule())
            }

            Text(sheet.mock.question)
                .font(MicaboFont.ui(16, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .onboardingReveal(0, of: revealed)

            HStack(alignment: .top, spacing: 12) {
                Capsule()
                    .fill(MicaboColor.accentPale)
                    .frame(width: 3)

                Text(sheet.mock.answer)
                    .font(MicaboFont.reading(14.5, weight: .regular))
                    .foregroundStyle(MicaboColor.inkReading)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .onboardingReveal(1, of: revealed)

            MicaboHairline()
                .onboardingReveal(2, of: revealed)

            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 2) {
                    Text(grade)
                        .font(MicaboFont.number(22, weight: .heavy))
                        .tracking(-0.6)
                        .foregroundStyle(MicaboColor.positiveInk)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 76, height: 56)
                .background(MicaboColor.positiveSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(i18n.t("ios.demo.mock.feedback").uppercased())
                        .font(MicaboFont.ui(10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(MicaboColor.positiveInk)

                    Text(sheet.mock.feedback)
                        .font(MicaboFont.reading(13.5, weight: .regular))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onboardingReveal(2, of: revealed)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .shadow(color: MicaboColor.ink.opacity(0.06), radius: 18, y: 8)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Le chiffre

/// **Relire, ou se tester : ce qu'il reste au bout d'une semaine.**
///
/// Deux barres horizontales, la grise et la violette, qui se remplissent l'une après
/// l'autre. Les nombres sont ceux de l'étude, et la source est écrite dessous : un chiffre
/// sans source sur un écran de vente est un slogan.
private struct OnboardingEvidenceChart: View {
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isDrawn = false

    /// Karpicke & Roediger, 2008 : ce qu'il reste à une semaine.
    private static let rereading = 36
    private static let testing = 80

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(i18n.t("ios.demo.evidence.retained"))
                .font(MicaboFont.ui(15, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            bar(label: i18n.t("ios.demo.evidence.reread"), percent: Self.rereading, tint: MicaboColor.strokeStrong, ink: MicaboColor.inkSecondary, delay: 0.15)
            bar(label: i18n.t("ios.demo.evidence.testing"), percent: Self.testing, tint: MicaboColor.accent, ink: MicaboColor.accent, delay: 0.5)

            Text(i18n.t("ios.journey.source"))
                .font(MicaboFont.ui(11, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .onAppear {
            guard !reduceMotion else {
                isDrawn = true
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isDrawn = true
            }
        }
    }

    private func bar(label: String, percent: Int, tint: Color, ink: Color, delay: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(MicaboFont.ui(13, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                Spacer(minLength: 0)
                Text("\(percent) %")
                    .font(MicaboFont.ui(15, weight: .heavy))
                    .foregroundStyle(ink)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(MicaboColor.track)
                    Capsule()
                        .fill(tint)
                        .frame(width: isDrawn ? proxy.size.width * CGFloat(percent) / 100 : 0)
                        .animation(.timingCurve(0.25, 0.9, 0.25, 1, duration: 0.9).delay(delay), value: isDrawn)
                }
            }
            .frame(height: 10)
        }
    }
}

/// **Ce que les élèves gagnent**, en points de moyenne, en un trimestre.
///
/// Un grand nombre, une phrase, l'effectif derrière. C'est le chiffre qu'un élève retient
/// de tout le parcours, et il n'a pas besoin d'un graphe pour être lu.
private struct OnboardingGainCard: View {
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("+")
                    .font(MicaboFont.number(22, weight: .heavy))
                Text(OnboardingNumbers.text(OnboardingProofFigures.gainedPoints, locale: i18n.locale))
                    .font(MicaboFont.number(34, weight: .heavy))
                    .tracking(-1.2)
                    .monospacedDigit()
            }
            .foregroundStyle(MicaboColor.positiveInk)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: 96)

            Text(i18n.t("ios.demo.evidence.micabo", [
                "n": OnboardingNumbers.text(OnboardingProofFigures.gainedSample, locale: i18n.locale),
            ]))
            .font(MicaboFont.ui(14, weight: .semibold))
            .foregroundStyle(MicaboColor.ink)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(MicaboColor.positiveWash, in: RoundedRectangle(cornerRadius: MicaboRadius.wash, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Un avis

/// Un avis : cinq étoiles, la phrase, qui l'a dite et où il en est. Sans photo ni initiale
/// dans un rond : une photo de profil qui n'existe pas aurait l'air d'un client inventé.
struct OnboardingReviewCard: View {
    let quote: String
    let name: String
    let level: String

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(MicaboColor.caution)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(i18n.t("ios.starsA11y"))

            Text(quote)
                .font(MicaboFont.ui(15, weight: .medium))
                .foregroundStyle(MicaboColor.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(name) · \(level)")
                .font(MicaboFont.ui(12.5, weight: .semibold))
                .foregroundStyle(MicaboColor.inkTertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
    }
}
