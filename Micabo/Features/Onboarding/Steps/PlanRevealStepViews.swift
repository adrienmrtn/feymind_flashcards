import SwiftUI

// MARK: - La révélation du plan

/// **« Lina, ton plan est prêt » — « Bac dans 7 mois »** : le moment où le parcours rend ce qu'il a
/// demandé. Juste après que Mika a calculé (`PlanBuildingStepView`), juste avant l'essai.
///
/// Tout ce qui s'affiche vient d'une réponse : le pays et la classe, l'examen et le temps
/// qu'il reste, les matières, le temps par jour et l'heure, la moyenne d'aujourd'hui et celle
/// visée dans le barème du pays. Une réponse absente retire sa ligne au lieu d'en inventer une.
/// Dessous, les trois choses que Mika va faire avec ça.
///
/// **Lot 7 : le plan est le sien, et il se voit.** « Fait avec tes réponses » sous le titre ;
/// puis **la projection** (`PlanProjection`) : une courbe qui part d'aujourd'hui, de sa
/// moyenne, et monte jusqu'au jour de l'examen, à la note qu'il vise, le trophée au bout.
/// C'est un objectif dessiné, pas une prédiction : la carte ne promet aucune date à laquelle
/// la note serait atteinte, elle met côte à côte ce qu'il a dit avoir et ce qu'il a dit
/// viser. L'examen et l'objectif ont quitté la liste du profil : ils sont sur la courbe.
///
/// Le nom de l'étape reste `profileSummary` : sa courbe dans les statistiques continue.
struct ProfileSummaryStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var name: String {
        model.displayName.nilIfBlank ?? OnboardingPreferences.displayName ?? ""
    }

    private var exam: (title: String, days: Int, date: Date)? {
        guard let choice = model.examChoice, choice.hasDate, let date = model.examDate,
              let days = model.examDaysLeft() else { return nil }
        return (choice.title(locale: i18n.locale), days, date)
    }

    private var title: String {
        name.isEmpty ? i18n.t("ios.onb5.plan.titleNoName") : i18n.t("ios.onb5.plan.title", ["name": name])
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingCenteredScroll {
                VStack(spacing: 18) {
                    VStack(spacing: 12) {
                        // Le plan révélé : un moment qui compte, Mika en entier fait la fête.
                        OnboardingMikaOnLine(mood: .celebrate, size: 128, whole: true)
                            .onboardingAppear(index: 0)
                        OnboardingAccentText(template: title, size: 27, alignment: .center)
                            .padding(.horizontal, MicaboSpacing.sm)
                            .onboardingAppear(index: 1)
                        Text(i18n.t("ios.onb7.plan.built"))
                            .font(MicaboFont.ui(15, weight: .semibold))
                            .foregroundStyle(MicaboColor.inkSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .onboardingAppear(index: 2)
                    }

                    if exam != nil || goal != nil {
                        PlanProjection(
                            headline: exam.map { exam in
                                i18n.t("ios.onb5.plan.countdown", [
                                    "exam": exam.title,
                                    "time": SchoolExams.remainingText(days: exam.days, locale: i18n.locale),
                                ])
                            } ?? i18n.t("ios.onb7.plan.path"),
                            startLabel: i18n.t("ios.onb5.trial.today"),
                            startGrade: goal?.from,
                            endLabel: exam.map { ExamStepView.dateText($0.date, locale: i18n.locale) } ?? i18n.t("ios.onb7.plan.goal"),
                            endGrade: goal?.to
                        )
                        .onboardingAppear(index: 3)
                    }

                    profileCard
                        .onboardingAppear(index: 4)

                    stepsCard
                        .onboardingAppear(index: 5)
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.vertical, MicaboSpacing.md)
            }

            OnboardingArrowBar { model.advance() }
                .onboardingAppear(index: 6)
        }
        .onboardingChromeInset()
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
    }

    // MARK: L'objectif

    /// La moyenne d'aujourd'hui et celle visée, dans le barème de l'élève. Rien sans
    /// objectif (le haut du barème déjà atteint, ou pas de réponse).
    private var goal: (from: String?, to: String)? {
        guard let target = model.targetScore, target >= TargetScore.min else { return nil }
        let scale = model.gradeScale.scale
        let from = model.currentScore.map { current in
            current < TargetScore.min
                ? i18n.t("ios.averageBelow", ["grade": scale.choices.first?.label ?? ""])
                : scale.label(for: current)
        }
        return (from, scale.label(for: target))
    }

    // MARK: Le profil

    private struct Line: Identifiable {
        var id: String { label }
        let icon: MicaboIcon
        let label: String
        let value: String
    }

    private var lines: [Line] {
        var result: [Line] = []
        let locale = i18n.locale
        let countryName: String = {
            if model.country == .other, let custom = model.customCountry { return "\(custom.flag) \(custom.name)" }
            return "\(model.country.flag) \(model.country.localizedName(locale: locale))"
        }()
        result.append(Line(icon: .globe, label: i18n.t("ios.onb5.plan.country"), value: countryName))

        let schoolClass = [model.track?.title, model.year?.title].compactMap { $0 }.joined(separator: " · ")
        if let value = schoolClass.nilIfBlank ?? model.stage?.localizedTitle {
            result.append(Line(icon: .diploma, label: i18n.t("ios.onb5.plan.class"), value: value))
        }
        let subjects = model.subjects.sorted().map { SubjectDisplay.subject($0, locale: locale) }
        if !subjects.isEmpty {
            let shown = subjects.prefix(3).joined(separator: ", ")
            let value = subjects.count > 3 ? "\(shown) +\(subjects.count - 3)" : shown
            result.append(Line(icon: .book, label: i18n.t("ios.onb5.plan.subjects"), value: value))
        }
        let daily = model.studyHour.map {
            i18n.t("ios.onb5.plan.dailyValue", ["n": "\(model.minutesPerDay)", "hour": Self.hourText($0, locale: locale)])
        } ?? i18n.t("ios.onb5.plan.dailyValueAny", ["n": "\(model.minutesPerDay)"])
        result.append(Line(icon: .alarm, label: i18n.t("ios.onb5.plan.daily"), value: daily))
        return result
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(i18n.t("ios.onb5.plan.profile").uppercased())
                .font(MicaboFont.ui(11.5, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(MicaboColor.accentInk)
                .padding(.bottom, 8)

            ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                HStack(alignment: .center, spacing: 12) {
                    MicaboIconView(icon: line.icon, size: 24)
                        .frame(width: 36, height: 36)
                        .background(MicaboColor.accentSoft, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    if dynamicTypeSize >= .xxLarge {
                        // **En très grand texte, la valeur passe sous son libellé** (lot 7) :
                        // serrée à droite, elle se coupait « Mathématiques / , Philosophie ».
                        VStack(alignment: .leading, spacing: 1) {
                            Text(line.label)
                                .font(MicaboFont.ui(14, weight: .semibold))
                                .foregroundStyle(MicaboColor.inkSecondary)
                            Text(line.value)
                                .font(MicaboFont.ui(15, weight: .heavy))
                                .foregroundStyle(MicaboColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        // Le libellé ne se coupe jamais au milieu d'un mot : c'est la valeur
                        // qui passe à la ligne.
                        Text(line.label)
                            .font(MicaboFont.ui(14, weight: .semibold))
                            .foregroundStyle(MicaboColor.inkSecondary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .layoutPriority(2)
                        Spacer(minLength: 8)
                        Text(line.value)
                            .font(MicaboFont.ui(15, weight: .heavy))
                            .foregroundStyle(MicaboColor.ink)
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)
                    }
                }
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)

                if index < lines.count - 1 {
                    Rectangle()
                        .fill(MicaboColor.stroke)
                        .frame(height: 1)
                        .padding(.leading, 48)
                }
            }
        }
        .padding(16)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
    }

    // MARK: Ce que Mika va faire

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(i18n.t("ios.onb5.plan.steps").uppercased())
                .font(MicaboFont.ui(11.5, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(MicaboColor.accentInk)

            step(1, i18n.t("ios.onb5.plan.step1"))
            step(2, i18n.t("ios.onb5.plan.step2", ["n": "\(model.minutesPerDay)"]))
            step(3, i18n.t(exam == nil ? "ios.onb5.plan.step3" : "ios.onb5.plan.step3Exam"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(MicaboColor.accentSoft.opacity(0.55), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(MicaboFont.ui(13, weight: .black))
                .foregroundStyle(Color.white)
                .frame(width: 22, height: 22)
                .background(MicaboColor.accent, in: Circle())
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
            Text(text)
                .font(MicaboFont.ui(15, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    static func hourText(_ hour: Int, locale: UiLocale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale.foundation
        formatter.setLocalizedDateFormatFromTemplate("j")
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}

// MARK: - La projection

/// **Aujourd'hui → le jour de l'examen**, en une courbe : la moyenne d'aujourd'hui au départ,
/// la note visée à l'arrivée, sous le trophée (le jaune des récompenses). La courbe se trace
/// une fois, à l'arrivée de la page ; elle se retourne en arabe.
struct PlanProjection: View {
    let headline: String
    let startLabel: String
    let startGrade: String?
    let endLabel: String
    let endGrade: String?

    @Environment(\.onboardingStill) private var still
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .bold))
                Text(headline)
                    .font(MicaboFont.ui(16, weight: .heavy))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(MicaboColor.accentInk)

            chart
                .frame(height: 112)

            HStack(alignment: .bottom) {
                end(label: startLabel, grade: startGrade, alignment: .leading, highlighted: false)
                Spacer(minLength: MicaboSpacing.sm)
                end(label: endLabel, grade: endGrade, alignment: .trailing, highlighted: true)
            }
        }
        .padding(16)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([headline, startLabel, startGrade, endLabel, endGrade].compactMap { $0 }.joined(separator: ", "))
        .onAppear {
            guard drawn == 0 else { return }
            if still || reduceMotion {
                drawn = 1
            } else {
                withAnimation(MicaboMotion.gentle.delay(OnboardingMotion.slideDuration)) { drawn = 1 }
            }
        }
    }

    private func end(label: String, grade: String?, alignment: HorizontalAlignment, highlighted: Bool) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(label)
                .font(MicaboFont.ui(13, weight: .semibold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .lineLimit(2)
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
            if let grade {
                Text(grade)
                    .font(MicaboFont.ui(22, weight: .heavy))
                    .foregroundStyle(highlighted ? MicaboColor.accentInk : MicaboColor.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private var chart: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let start = CGPoint(x: 8, y: size.height - 10)
            let finish = CGPoint(x: size.width - 22, y: 22)
            ZStack(alignment: .topLeading) {
                Path { path in
                    for fraction in [0.25, 0.6] {
                        path.move(to: CGPoint(x: 0, y: size.height * fraction))
                        path.addLine(to: CGPoint(x: size.width, y: size.height * fraction))
                    }
                }
                .stroke(MicaboColor.stroke, style: StrokeStyle(lineWidth: 1, dash: [2, 5]))

                PlanCurve(start: start, end: finish, closed: true, height: size.height)
                    .fill(LinearGradient(
                        colors: [MicaboColor.accent.opacity(0.18), MicaboColor.accent.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .opacity(Double(drawn))

                PlanCurve(start: start, end: finish, closed: false, height: size.height)
                    .trim(from: 0, to: drawn)
                    .stroke(MicaboColor.accent, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))

                Circle()
                    .fill(MicaboColor.surface)
                    .overlay(Circle().strokeBorder(MicaboColor.accent, lineWidth: 3))
                    .frame(width: 14, height: 14)
                    .position(start)

                MicaboIconView(icon: .trophy, size: 26)
                    .frame(width: 40, height: 40)
                    .background(LessonTone.yellow.pale, in: Circle())
                    .overlay(Circle().strokeBorder(MicaboColor.surface, lineWidth: 2))
                    .position(finish)
                    .scaleEffect(drawn, anchor: .center)
                    .opacity(Double(drawn))
            }
            .flipsForRightToLeftLayoutDirection(true)
        }
    }
}

/// La courbe de la projection : elle part doucement, puis monte — une progression, pas une
/// droite. Fermée, elle borde l'aire claire dessous.
private struct PlanCurve: Shape {
    let start: CGPoint
    let end: CGPoint
    let closed: Bool
    let height: CGFloat

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: start)
            let span = end.x - start.x
            path.addCurve(
                to: end,
                control1: CGPoint(x: start.x + span * 0.45, y: start.y),
                control2: CGPoint(x: start.x + span * 0.6, y: end.y + 6)
            )
            if closed {
                path.addLine(to: CGPoint(x: end.x, y: height))
                path.addLine(to: CGPoint(x: start.x, y: height))
                path.closeSubpath()
            }
        }
    }
}

// MARK: - L'essai

/// **Comment marche l'essai, en trois moments** : aujourd'hui l'accès complet, la veille de
/// la fin un rappel (réellement posé : `TrialEndReminder`), le dernier jour le début de
/// l'abonnement — avec sa date. Dessous, ce qui rassure vraiment : rien à payer aujourd'hui,
/// et on annule quand on veut, en deux touches, depuis les réglages de l'iPhone.
///
/// Il remplace trois écrans de la version 1 (« Nous tenons à ce que tu essaies », la
/// chronologie, le rappel) : une seule page, la même information, et une promesse tenue.
struct TrialOfferStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onboardingStill) private var still

    @State private var remindersOn = true
    @State private var revealed = 0

    private var milestones: [TrialTimeline.Milestone] {
        TrialTimeline.milestones(locale: i18n.locale, remindersOn: remindersOn)
    }

    private var daysText: String {
        SchoolExams.remainingText(days: TrialTimeline.freeDays, locale: i18n.locale)
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingCenteredScroll {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .bottom, spacing: 10) {
                        OnboardingAccentText(
                            template: i18n.t("ios.onb5.trial.title", ["days": daysText]),
                            size: 28,
                            alignment: .leading
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        OnboardingMikaOnLine(mood: .wink, size: 92)
                    }
                    .onboardingAppear(index: 0)

                    VStack(spacing: 0) {
                        ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                            TrialMilestoneRow(
                                milestone: milestone,
                                isLast: index == milestones.count - 1,
                                isRevealed: still || index < revealed
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        reassurance("hand.tap.fill", i18n.t("ios.onb5.trial.cancel"))
                        reassurance("creditcard.fill", i18n.t("ios.onb5.trial.noCharge"))
                    }
                    .onboardingAppear(index: 3)
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.vertical, MicaboSpacing.md)
            }

            OnboardingArrowBar { model.advance() }
        }
        .onboardingChromeInset()
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
        .task {
            // Jamais demandé : la boîte s'ouvrira à l'achat, pour ce rappel (`TrialEndReminder`).
            remindersOn = await TrialEndReminder.canBeKept()
        }
        .onAppear(perform: reveal)
    }

    private func reveal() {
        guard revealed == 0, !still else { return }
        for index in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + OnboardingMotion.slideDuration + Double(index) * 0.3) {
                withAnimation(OnboardingMotion.enter) { revealed = index + 1 }
                Haptics.tick()
            }
        }
    }

    private func reassurance(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(MicaboColor.correct)
                .frame(width: 22)
            Text(text)
                .font(MicaboFont.ui(15, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct TrialMilestoneRow: View {
    let milestone: TrialTimeline.Milestone
    let isLast: Bool
    let isRevealed: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Image(systemName: milestone.systemImage)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(milestone.tone == .current ? Color.white : MicaboColor.accentInk)
                    .frame(width: 44, height: 44)
                    .background(milestone.tone == .current ? MicaboColor.accent : MicaboColor.accentSoft, in: Circle())
                if !isLast {
                    Capsule()
                        .fill(MicaboColor.accent.opacity(0.3))
                        .frame(width: 3)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 4)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(milestone.title)
                    .font(MicaboFont.ui(17, weight: .heavy))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(milestone.detail)
                    .font(MicaboFont.ui(14.5, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 3)
            .padding(.bottom, isLast ? 0 : 20)

            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .opacity(isRevealed ? 1 : 0)
        .offset(y: isRevealed ? 0 : 8)
        .accessibilityElement(children: .combine)
    }
}
